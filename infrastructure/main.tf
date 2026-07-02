# Kong Event Gateway — Infrastructure
# Deploys: VPC, subnets, security groups (DMZ chain), MSK cluster
# Stores all outputs in SSM Parameter Store for gateway/ to consume.
#
# DMZ pattern:
#   Internet → NLB (public subnets) → Kong Event Gateway (private app subnets) → MSK (private data subnets)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = var.project_name
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Component = "infrastructure"
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
module "networking" {
  source = "../modules/networking"

  name_prefix = local.name_prefix
  aws_region  = var.aws_region
  vpc_cidr    = var.vpc_cidr
  common_tags = local.common_tags

  vpc_endpoint_security_group_ids = [module.security.vpc_endpoints_security_group_id]
}

# ---------------------------------------------------------------------------
# Security Groups — DMZ chain: sg-nlb → sg-keg → sg-msk
# ---------------------------------------------------------------------------
module "security" {
  source = "../modules/security"

  name_prefix               = local.name_prefix
  vpc_id                    = module.networking.vpc_id
  vpc_cidr                  = var.vpc_cidr
  common_tags               = local.common_tags

  allowed_cidr_blocks       = var.allowed_cidr_blocks
  enable_admin_api          = false
  admin_allowed_cidr_blocks = []

  kafka_port_range_end      = 9094  # must match gateway/ kafka_port_range_end
  kong_proxy_port           = 8000
  kong_keg_port             = 8080  # unused in DMZ pattern but satisfies module variable
  kong_admin_port           = 8001
  kong_admin_gui_port       = 8002
}

# ---------------------------------------------------------------------------
# MSK Cluster
# ---------------------------------------------------------------------------
module "msk" {
  source = "../modules/msk"

  name_prefix = local.name_prefix
  common_tags = local.common_tags

  kafka_version          = var.msk_kafka_version
  storage_mode           = var.msk_storage_mode
  number_of_broker_nodes = var.msk_number_of_broker_nodes
  instance_type          = var.msk_instance_type
  volume_size            = var.msk_volume_size

  subnet_ids         = slice(module.networking.private_subnet_ids, 0, 2)  # 2 AZs = 2 brokers minimum
  security_group_ids = [module.security.msk_security_group_id]

  enable_scram_auth             = var.msk_enable_scram_auth
  enable_iam_auth               = var.msk_enable_iam_auth
  enable_unauthenticated_access = var.msk_enable_unauthenticated_access
  allowed_principals            = var.msk_allowed_principals

  create_default_scram_user = var.msk_create_default_scram_user
  default_scram_username    = var.msk_default_scram_username
  default_scram_password    = var.msk_default_scram_password

  encryption_in_transit_client_broker = var.msk_encryption_in_transit_client_broker
  encryption_in_transit_in_cluster    = var.msk_encryption_in_transit_in_cluster

  enhanced_monitoring    = var.msk_enhanced_monitoring
  enable_cloudwatch_logs = var.msk_enable_cloudwatch_logs
  log_retention_days     = var.log_retention_days
}

# ---------------------------------------------------------------------------
# SSM Parameters — share infrastructure values with gateway/
# ---------------------------------------------------------------------------
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project_name}/networking/vpc_id"
  type  = "String"
  value = module.networking.vpc_id
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.project_name}/networking/private_subnet_ids"
  type  = "StringList"
  value = join(",", module.networking.private_subnet_ids)
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/${var.project_name}/networking/public_subnet_ids"
  type  = "StringList"
  value = join(",", module.networking.public_subnet_ids)
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "nlb_security_group_id" {
  name  = "/${var.project_name}/security/nlb_security_group_id"
  type  = "String"
  value = module.security.nlb_security_group_id
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "keg_security_group_id" {
  name  = "/${var.project_name}/security/keg_security_group_id"
  type  = "String"
  value = module.security.keg_security_group_id
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "msk_security_group_id" {
  name  = "/${var.project_name}/security/msk_security_group_id"
  type  = "String"
  value = module.security.msk_security_group_id
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "msk_cluster_arn" {
  name  = "/${var.project_name}/msk/cluster_arn"
  type  = "String"
  value = module.msk.cluster_arn
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "msk_bootstrap_brokers_sasl_scram" {
  name  = "/${var.project_name}/msk/bootstrap_brokers_sasl_scram"
  type  = "String"
  value = module.msk.bootstrap_brokers_sasl_scram
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "msk_default_scram_secret_arn" {
  count = var.msk_create_default_scram_user ? 1 : 0
  name  = "/${var.project_name}/msk/default_scram_secret_arn"
  type  = "String"
  value = module.msk.default_scram_secret_arn
  tags  = local.common_tags
}
