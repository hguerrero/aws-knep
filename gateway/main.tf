# Kong Event Gateway — Gateway Deployment
# Step 2 of 2: run after infrastructure/
#
# Implements the Kafka DMZ pattern on AWS:
#   Internet → NLB (public subnets) → Kong Event Gateway ECS (private app subnets) → MSK (private data subnets)
#
# Konnect resources managed here:
#   - konnect_event_gateway                                          (control plane)
#   - konnect_event_gateway_data_plane_certificate                   (mTLS auth)
#   - konnect_event_gateway_backend_cluster                          (MSK connection)
#   - konnect_event_gateway_virtual_cluster                          (one per team/partner)
#   - konnect_event_gateway_listener                                 (TCP 9092)
#   - konnect_event_gateway_listener_policy_forward_to_virtual_cluster

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    konnect = {
      source  = "Kong/konnect"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "konnect" {
  personal_access_token = var.konnect_token
  server_url            = var.konnect_server_url
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Data Plane TLS Certificate
# ---------------------------------------------------------------------------
# Terraform generates the RSA key pair, writes the cert to Secrets Manager,
# and registers it with Konnect. The ECS task pulls the cert/key at startup
# via Secrets Manager injection — no manual openssl steps.

resource "tls_private_key" "data_plane" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "data_plane" {
  private_key_pem = tls_private_key.data_plane.private_key_pem

  subject {
    common_name = "kong-event-gateway"
    country     = "US"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Store cert and key in Secrets Manager — never in plaintext env vars.
resource "aws_secretsmanager_secret" "keg_dp_cert" {
  name                    = "/${var.project_name}/keg/dp-cert"
  description             = "Kong Event Gateway data plane TLS certificate (KONG_KONNECT_CLIENT_CERT)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "keg_dp_cert" {
  secret_id     = aws_secretsmanager_secret.keg_dp_cert.id
  secret_string = tls_self_signed_cert.data_plane.cert_pem
}

resource "aws_secretsmanager_secret" "keg_dp_key" {
  name                    = "/${var.project_name}/keg/dp-key"
  description             = "Kong Event Gateway data plane private key (KONG_KONNECT_CLIENT_KEY)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "keg_dp_key" {
  secret_id     = aws_secretsmanager_secret.keg_dp_key.id
  secret_string = tls_private_key.data_plane.private_key_pem
}

# ---------------------------------------------------------------------------
# Konnect Identity: Auth Server + Scope + Client
# ---------------------------------------------------------------------------
resource "konnect_identity_auth_server" "kafka" {
  provider    = konnect
  name        = "${var.project_name}-auth-server"
  audience    = var.auth_server_audience
  description = "Kong Identity auth server for ${var.project_name} Kafka clients"
}

resource "konnect_identity_auth_server_scope" "kafka" {
  provider       = konnect
  auth_server_id = konnect_identity_auth_server.kafka.id
  name                = var.auth_scope_name
  description         = "Scope for Kafka client authentication"
  default             = false
  include_in_metadata = false
  enabled             = true

  depends_on = [konnect_identity_auth_server.kafka]
}

resource "konnect_identity_auth_server_client" "kafka_client" {
  provider              = konnect
  auth_server_id        = konnect_identity_auth_server.kafka.id
  name                  = "${var.project_name}-kafka-client"
  grant_types           = ["client_credentials"]
  allow_all_scopes      = false
  allow_scopes          = [konnect_identity_auth_server_scope.kafka.id]
  access_token_duration = 3600
  id_token_duration     = 3600
  response_types        = ["id_token", "token"]

  depends_on = [konnect_identity_auth_server.kafka]
}

# ---------------------------------------------------------------------------
# Konnect Identity: Custom claim — topics
# ---------------------------------------------------------------------------
# Embeds a "topics" array claim in every access token issued by this auth server
# when the token includes the kafka scope.
#
# The topics-claim-full-access ACL policy (below) reads this claim at request
# time via: context.auth.token.claims.topics
#
# Set kafka_client_topics in terraform.tfvars to the topic names this client
# should have full produce/consume/manage access to. Leave empty to issue tokens
# with no topics claim — the client gets read-only access via the readonly-all policy.
#
# Only created when kafka_client_topics is non-empty.
resource "konnect_identity_auth_server_claim" "topics" {
  count = length(var.kafka_client_topics) > 0 ? 1 : 0

  provider       = konnect
  auth_server_id = konnect_identity_auth_server.kafka.id
  name           = "topics"

  # jsonencode produces a valid JSON array — the provider embeds it as a JSON
  # array in the token (not a string) because the value is valid JSON.
  value = jsonencode(var.kafka_client_topics)

  enabled               = true
  include_in_all_scopes = false
  include_in_scopes     = [konnect_identity_auth_server_scope.kafka.id]

  # Must be true so the claim appears in the JWT access token.
  # If false, it would only appear in the /userinfo endpoint response.
  include_in_token = true

  depends_on = [konnect_identity_auth_server_scope.kafka]
}

# ---------------------------------------------------------------------------
# Konnect: Event Gateway Control Plane
# ---------------------------------------------------------------------------
resource "konnect_event_gateway" "keg" {
  provider    = konnect
  name        = "${var.project_name}-event-gateway"
  description = "Kong Event Gateway - DMZ pattern for MSK on AWS ECS (managed by Terraform)"

  depends_on = [konnect_identity_auth_server.kafka]
}

# Register the data plane certificate with Konnect
resource "konnect_event_gateway_data_plane_certificate" "keg" {
  provider    = konnect
  name        = "${var.project_name}-dp-cert"
  certificate = tls_self_signed_cert.data_plane.cert_pem
  gateway_id  = konnect_event_gateway.keg.id

  depends_on = [konnect_event_gateway.keg]
}

# ---------------------------------------------------------------------------
# Konnect: Backend Cluster (MSK)
# ---------------------------------------------------------------------------
# The gateway connects to MSK as a single SASL/SCRAM service account.
# Client identities are managed at the Virtual Cluster layer.
resource "konnect_event_gateway_backend_cluster" "msk" {
  provider    = konnect
  name        = "msk"
  description = "Amazon MSK backend cluster — SASL/SCRAM over TLS (port 9096)"
  gateway_id  = konnect_event_gateway.keg.id

  authentication = {
    sasl_scram = {
      algorithm = "sha512"
      username  = local.msk_scram_credentials.username
      password  = local.msk_scram_credentials.password
    }
  }

  bootstrap_servers = split(",", local.msk_bootstrap_brokers_scram)

  tls = {
    enabled = true
  }

  depends_on = [konnect_event_gateway.keg]
}

# ---------------------------------------------------------------------------
# Konnect: Virtual Cluster (one per team/partner)
# ---------------------------------------------------------------------------
resource "konnect_event_gateway_virtual_cluster" "internal" {
  provider    = konnect
  name        = "internal"
  description = "Internal team virtual cluster — OAuth authentication"
  gateway_id  = konnect_event_gateway.keg.id

  destination = {
    id = konnect_event_gateway_backend_cluster.msk.id
  }

  acl_mode  = "enforce_on_gateway"
  dns_label = "internal"

  authentication = [
    {
      oauth_bearer = {
        mediation = "terminate"
        jwks = {
          endpoint = "${konnect_identity_auth_server.kafka.issuer}/.well-known/jwks"
          timeout  = "5s"
        }
      }
    }
  ]

  depends_on = [konnect_event_gateway.keg, konnect_event_gateway_backend_cluster.msk, konnect_identity_auth_server.kafka]
}

# ---------------------------------------------------------------------------
# Konnect: Virtual Cluster ACL — read-only for all authenticated users
# ---------------------------------------------------------------------------
# condition = "true" matches every authenticated principal.
# Rules grant the minimum set of Kafka operations required to consume:
#   topic  — describe (metadata) + read (fetch/offset)
#   group  — describe + read  (consumer group join / commit offsets)
#   cluster — describe (broker metadata)
resource "konnect_event_gateway_cluster_policy_acls" "readonly_all" {
  provider           = konnect
  name               = "readonly-all"
  description        = "Read-only access to all topics and resources for any authenticated user"
  gateway_id         = konnect_event_gateway.keg.id
  virtual_cluster_id = konnect_event_gateway_virtual_cluster.internal.id

  config = {
    rules = [
      {
        action     = "allow"
        operations = [
          { name = "describe" },
          { name = "read" }
        ]
        resource_type  = "topic"
        resource_names = [{ match = "*" }]
      },
      {
        action     = "allow"
        operations = [
          { name = "describe" },
          { name = "read" }
        ]
        resource_type  = "group"
        resource_names = [{ match = "*" }]
      },
      {
        action     = "allow"
        operations = [
          { name = "describe" },
          { name = "describe_configs" }
        ]
        resource_type  = "cluster"
        resource_names = [{ match = "*" }]
      }
    ]
  }

  depends_on = [konnect_event_gateway_virtual_cluster.internal]
}

# ---------------------------------------------------------------------------
# NOTE: The "topics-claim-full-access" ACL policy (full access to topics
# listed in the JWT "topics" claim via dynamic CEL expression) is managed
# outside Terraform using kongctl.
#
# The konnect Terraform provider validates resource_names as a list of objects
# and does not accept a CEL string expression. The Konnect API supports it
# natively; apply it declaratively with:
#
#   kongctl apply -f kongctl/topics-claim-full-acl.yaml
#
# See kongctl/topics-claim-full-acl.yaml for the policy definition.
# ---------------------------------------------------------------------------
# Konnect: Listener (TCP port 9092)
# ---------------------------------------------------------------------------
resource "konnect_event_gateway_listener" "kafka" {
  provider    = konnect
  name        = "kafka-listener"
  description = "Kafka listener on port 9092 — routes to Virtual Clusters by SNI"
  gateway_id  = konnect_event_gateway.keg.id

  addresses = ["0.0.0.0"]
  ports     = ["${var.kafka_client_port}-${var.kafka_port_range_end}"]

  depends_on = [konnect_event_gateway.keg]
}

# ---------------------------------------------------------------------------
# Konnect: Listener Policy → Virtual Cluster
# ---------------------------------------------------------------------------
resource "konnect_event_gateway_listener_policy_forward_to_virtual_cluster" "kafka_to_internal" {
  provider    = konnect
  name        = "forward-to-internal"
  description = "Route kafka-listener traffic to the internal virtual cluster"
  gateway_id  = konnect_event_gateway.keg.id
  listener_id = konnect_event_gateway_listener.kafka.id

  config = {
    port_mapping = {
      advertised_host = var.kafka_advertised_host
      bootstrap_port  = "none"
      destination = {
        id = konnect_event_gateway_virtual_cluster.internal.id
      }
    }
  }

  depends_on = [konnect_event_gateway_listener.kafka, konnect_event_gateway_virtual_cluster.internal]
}

# ---------------------------------------------------------------------------
# Local values
# ---------------------------------------------------------------------------
locals {
  name_prefix = var.project_name

  common_tags = {
    Project   = var.project_name
    Service   = "kong-event-gateway"
    ManagedBy = "terraform"
  }

  # Container environment variables for the Event Gateway.
  # KONG_KONNECT_CLIENT_CERT and KONG_KONNECT_CLIENT_KEY are injected via
  # Secrets Manager (see module.kong_event_gateway.secrets below).
  keg_env_vars = concat([
    {
      name  = "KONG_KONNECT_REGION"
      value = var.konnect_region
    },
    {
      name  = "KONG_KONNECT_DOMAIN"
      value = "konghq.com"
    },
    {
      name  = "KONG_KONNECT_GATEWAY_CLUSTER_ID"
      value = konnect_event_gateway.keg.id
    },
    {
      name  = "KEG__RUNTIME__DRAIN_DURATION"
      value = "1s"
    },
    {
      name  = "KEG__OBSERVABILITY__LOG_FLAGS"
      value = "info,keg=debug"
    }
  ], [
    for key, value in var.kong_env_vars : {
      name  = key
      value = value
    }
  ])
}

# ---------------------------------------------------------------------------
# Shared infrastructure — read from SSM (deployed by infrastructure/)
# ---------------------------------------------------------------------------
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project_name}/networking/vpc_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.project_name}/networking/private_subnet_ids"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/${var.project_name}/networking/public_subnet_ids"
}

data "aws_ssm_parameter" "keg_security_group_id" {
  name = "/${var.project_name}/security/keg_security_group_id"
}

data "aws_ssm_parameter" "nlb_security_group_id" {
  name = "/${var.project_name}/security/nlb_security_group_id"
}

data "aws_ssm_parameter" "msk_cluster_arn" {
  name = "/${var.project_name}/msk/cluster_arn"
}

data "aws_ssm_parameter" "msk_bootstrap_brokers_sasl_scram" {
  name = "/${var.project_name}/msk/bootstrap_brokers_sasl_scram"
}

data "aws_ssm_parameter" "msk_default_scram_secret_arn" {
  name = "/${var.project_name}/msk/default_scram_secret_arn"
}

data "aws_secretsmanager_secret_version" "msk_scram_credentials" {
  secret_id = data.aws_ssm_parameter.msk_default_scram_secret_arn.value
}

locals {
  vpc_id                = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids    = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  public_subnet_ids     = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
  keg_security_group_id = data.aws_ssm_parameter.keg_security_group_id.value
  nlb_security_group_id = data.aws_ssm_parameter.nlb_security_group_id.value

  msk_cluster_arn             = data.aws_ssm_parameter.msk_cluster_arn.value
  msk_bootstrap_brokers_scram = data.aws_ssm_parameter.msk_bootstrap_brokers_sasl_scram.value
  msk_scram_credentials       = jsondecode(data.aws_secretsmanager_secret_version.msk_scram_credentials.secret_string)
}

# ---------------------------------------------------------------------------
# Kong Event Gateway ECS Service + NLB
# ---------------------------------------------------------------------------
module "kong_event_gateway" {
  source = "../modules/ecs-service"

  service_name              = "${local.name_prefix}-keg"
  aws_region                = var.aws_region
  common_tags               = local.common_tags

  cluster_name              = "${local.name_prefix}-cluster"
  enable_container_insights = var.enable_container_insights

  # Kong Event Gateway 1.2
  container_name  = "kong-event-gateway"
  container_image = var.kong_keg_image
  container_port  = var.kong_keg_port
  cpu             = var.kong_cpu
  memory          = var.kong_memory
  desired_count   = var.kong_desired_count

  environment_variables = local.keg_env_vars

  # Inject TLS cert and key from Secrets Manager — never in plaintext env vars
  secrets = [
    {
      name      = "KONG_KONNECT_CLIENT_CERT"
      valueFrom = aws_secretsmanager_secret.keg_dp_cert.arn
    },
    {
      name      = "KONG_KONNECT_CLIENT_KEY"
      valueFrom = aws_secretsmanager_secret.keg_dp_key.arn
    }
  ]

  health_check_command = [
    "CMD-SHELL",
    "curl -f http://localhost:${var.kong_keg_port}/health/probes/liveness || exit 1"
  ]
  health_check_interval            = var.health_check_interval
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold

  # KEG ECS tasks live in private app subnets
  vpc_id                 = local.vpc_id
  ecs_subnet_ids         = local.private_subnet_ids
  ecs_security_group_ids = [local.keg_security_group_id]
  assign_public_ip       = false

  # NLB in public subnets — Kafka clients connect here on TCP 9092
  load_balancer_name         = "${local.name_prefix}-nlb"
  internal_load_balancer     = false
  nlb_subnet_ids             = local.public_subnet_ids
  nlb_security_group_ids     = [local.nlb_security_group_id]
  kafka_client_port          = var.kafka_client_port
  kafka_port_range_end       = var.kafka_port_range_end
  tls_certificate_arn        = var.nlb_tls_certificate_arn
  enable_deletion_protection = var.nlb_enable_deletion_protection

  task_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${local.name_prefix}-keg:*"
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          data.aws_ssm_parameter.msk_default_scram_secret_arn.value,
          aws_secretsmanager_secret.keg_dp_cert.arn,
          aws_secretsmanager_secret.keg_dp_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData",
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = [
          local.msk_cluster_arn,
          "${local.msk_cluster_arn}/*"
        ]
      }
    ]
  })

  log_retention_days = var.log_retention_days
}
