# Kong Event Gateway — Gateway Variables

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources (must match infrastructure/)"
  type        = string
  default     = "kong-event-gw"
}

# ---------------------------------------------------------------------------
# Kong Event Gateway Container
# ---------------------------------------------------------------------------
variable "kong_keg_image" {
  description = "Kong Event Gateway container image — use a pinned tag, not :latest"
  type        = string
  default     = "kong/kong-event-gateway:latest"
}

variable "kong_keg_port" {
  description = "Internal port the Event Gateway container listens on (health/management)"
  type        = number
  default     = 8080
}

# ---------------------------------------------------------------------------
# Kong Identity
# ---------------------------------------------------------------------------
variable "auth_server_audience" {
  description = "Audience claim for the Kong Identity auth server (e.g. your API or service URL)"
  type        = string
  default     = "https://kafka.example.com"
}

variable "auth_scope_name" {
  description = "OAuth scope Kafka clients must request to authenticate"
  type        = string
  default     = "kafka"
}

# ---------------------------------------------------------------------------
# Konnect — managed by kong/konnect Terraform provider
# ---------------------------------------------------------------------------
variable "konnect_token" {
  description = "Konnect Personal Access Token (Settings → Personal Access Tokens)"
  type        = string
  sensitive   = true
}

variable "konnect_server_url" {
  description = "Konnect API URL (e.g. https://us.api.konghq.com)"
  type        = string
  default     = "https://us.api.konghq.com"
}

variable "konnect_region" {
  description = "Konnect region for KONG_KONNECT_REGION env var (us | eu | au)"
  type        = string
  default     = "us"
}

variable "kafka_advertised_host" {
  description = "Hostname the gateway advertises to Kafka clients as the bootstrap address. Set to your wildcard DNS hostname (e.g. internal.kafka.acme.com) or the NLB DNS name."
  type        = string
  default     = "localhost"
}

# ---------------------------------------------------------------------------
# ECS / Fargate
# ---------------------------------------------------------------------------
variable "kong_cpu" {
  description = "ECS task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "kong_memory" {
  description = "ECS task memory in MB"
  type        = number
  default     = 512
}

variable "kong_desired_count" {
  description = "Desired number of Event Gateway tasks"
  type        = number
  default     = 1
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights on the ECS cluster"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Network Load Balancer
# NLB is required — ALB is HTTP-only and cannot proxy the Kafka TCP protocol.
# ---------------------------------------------------------------------------
variable "kafka_client_port" {
  description = "Bootstrap port Kafka clients connect to on the NLB (start of the port-mapping range, standard: 9092)"
  type        = number
  default     = 9092
}

variable "kafka_port_range_end" {
  description = "Last port in the KEG port-mapping range — one port per broker (e.g. 9094 for 2 MSK brokers)"
  type        = number
  default     = 9094
}

variable "nlb_tls_certificate_arn" {
  description = "ACM wildcard certificate ARN for SNI-based Virtual Cluster routing (*.kafka.acme.com). Set null for plain TCP."
  type        = string
  default     = null
}

variable "nlb_enable_deletion_protection" {
  description = "Enable deletion protection for the NLB"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Health Check (NLB TCP)
# ---------------------------------------------------------------------------
variable "health_check_interval" {
  description = "NLB health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_healthy_threshold" {
  description = "Consecutive successful checks before marking target healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failed checks before marking target unhealthy"
  type        = number
  default     = 3
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# ---------------------------------------------------------------------------
# Additional Event Gateway environment variables
# ---------------------------------------------------------------------------
variable "kong_env_vars" {
  description = "Extra environment variables injected into the Event Gateway container"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Auto Scaling
# ---------------------------------------------------------------------------
variable "kong_min_capacity" {
  description = "Minimum number of Event Gateway tasks"
  type        = number
  default     = 1
}

variable "kong_max_capacity" {
  description = "Maximum number of Event Gateway tasks"
  type        = number
  default     = 3
}

variable "autoscaling_target_cpu" {
  description = "Target CPU utilization % for auto scaling"
  type        = number
  default     = 70
}

variable "autoscaling_target_memory" {
  description = "Target memory utilization % for auto scaling"
  type        = number
  default     = 80
}

variable "autoscaling_scale_up_cooldown" {
  description = "Scale-out cooldown in seconds"
  type        = number
  default     = 300
}

variable "autoscaling_scale_down_cooldown" {
  description = "Scale-in cooldown in seconds"
  type        = number
  default     = 300
}
