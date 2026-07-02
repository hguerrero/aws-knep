# Kong Event Gateway — Infrastructure Variables

variable "project_name" {
  description = "Name prefix for all resources and SSM parameter paths"
  type        = string
  default     = "kong-event-gw"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the NLB on port 9092 (default: open to internet)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# MSK
# ---------------------------------------------------------------------------
variable "msk_kafka_version" {
  description = "Kafka version for MSK"
  type        = string
  default     = "4.0.x.kraft"
}

variable "msk_storage_mode" {
  description = "MSK storage mode (TIERED for KRaft, LOCAL for Zookeeper)"
  type        = string
  default     = "LOCAL"
}

variable "msk_number_of_broker_nodes" {
  description = "Number of MSK broker nodes (must match AZ count)"
  type        = number
  default     = 2  # must match number of subnets passed to MSK (2 AZs for demo)
}

variable "msk_instance_type" {
  description = "MSK broker instance type (kafka.t3.small removed in 4.x; smallest valid is kafka.m5.large)"
  type        = string
  default     = "kafka.m5.large"
}

variable "msk_volume_size" {
  description = "EBS volume size per broker in GB"
  type        = number
  default     = 20
}

variable "msk_enable_scram_auth" {
  description = "Enable SASL/SCRAM authentication"
  type        = bool
  default     = true
}

variable "msk_enable_iam_auth" {
  description = "Enable IAM authentication"
  type        = bool
  default     = false
}

variable "msk_enable_unauthenticated_access" {
  description = "Enable unauthenticated access (disable for production)"
  type        = bool
  default     = false
}

variable "msk_allowed_principals" {
  description = "IAM principals allowed to connect to MSK (for IAM auth)"
  type        = list(string)
  default     = []
}

variable "msk_create_default_scram_user" {
  description = "Create a default SCRAM user for Kong Event Gateway"
  type        = bool
  default     = true
}

variable "msk_default_scram_username" {
  description = "Default SCRAM username for Kong Event Gateway"
  type        = string
  default     = "kong-event-gateway"
}

variable "msk_default_scram_password" {
  description = "Default SCRAM password for Kong Event Gateway (leave empty for auto-generated)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "msk_encryption_in_transit_client_broker" {
  description = "Encryption in transit between clients and brokers (TLS, PLAINTEXT, or TLS_PLAINTEXT)"
  type        = string
  default     = "TLS"
}

variable "msk_encryption_in_transit_in_cluster" {
  description = "Encrypt data in transit between brokers"
  type        = bool
  default     = true
}

variable "msk_enhanced_monitoring" {
  description = "MSK enhanced monitoring level"
  type        = string
  default     = "DEFAULT"
}

variable "msk_enable_cloudwatch_logs" {
  description = "Enable CloudWatch logging for MSK brokers"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
