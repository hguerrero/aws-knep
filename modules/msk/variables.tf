# MSK Module Variables

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# MSK Cluster Configuration
variable "kafka_version" {
  description = "Kafka version for the MSK cluster (use 3.4.0+ for KRaft mode)"
  type        = string
  default     = "3.4.0"
}

variable "storage_mode" {
  description = "Storage mode for MSK cluster (LOCAL for Zookeeper, TIERED for KRaft)"
  type        = string
  default     = "TIERED"
  validation {
    condition     = contains(["LOCAL", "TIERED"], var.storage_mode)
    error_message = "Storage mode must be either LOCAL (Zookeeper) or TIERED (KRaft)."
  }
}

variable "number_of_broker_nodes" {
  description = "Number of broker nodes in the MSK cluster"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "Instance type for MSK broker nodes"
  type        = string
  default     = "kafka.t3.small"
}

variable "volume_size" {
  description = "EBS volume size for each broker node (GB)"
  type        = number
  default     = 10
}

# Networking
variable "subnet_ids" {
  description = "List of subnet IDs for MSK cluster"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for MSK cluster"
  type        = list(string)
}

# Authentication
variable "enable_scram_auth" {
  description = "Enable SCRAM authentication"
  type        = bool
  default     = true
}

variable "enable_iam_auth" {
  description = "Enable IAM authentication"
  type        = bool
  default     = false
}

variable "enable_unauthenticated_access" {
  description = "Enable unauthenticated access"
  type        = bool
  default     = false
}

variable "certificate_authority_arns" {
  description = "List of certificate authority ARNs for TLS authentication"
  type        = list(string)
  default     = []
}

variable "allowed_principals" {
  description = "List of AWS principals allowed to access MSK cluster (for IAM auth)"
  type        = list(string)
  default     = []
}

# SCRAM Authentication Variables
variable "scram_users" {
  description = "List of SCRAM users to create"
  type = list(object({
    username = string
    password = string
  }))
  default = []
  sensitive = true
}

variable "create_default_scram_user" {
  description = "Create a default SCRAM user for Kong Event Gateway"
  type        = bool
  default     = true
}

variable "default_scram_username" {
  description = "Default SCRAM username for Kong Event Gateway"
  type        = string
  default     = "kong-event-gateway"
}

variable "default_scram_password" {
  description = "Default SCRAM password for Kong Event Gateway"
  type        = string
  default     = ""
  sensitive   = true
}

# Encryption
variable "kms_key_id" {
  description = "KMS key ID for encryption at rest"
  type        = string
  default     = null
}

variable "encryption_in_transit_client_broker" {
  description = "Encryption in transit between clients and brokers"
  type        = string
  default     = "TLS"
  validation {
    condition     = contains(["TLS", "TLS_PLAINTEXT", "PLAINTEXT"], var.encryption_in_transit_client_broker)
    error_message = "Valid values are TLS, TLS_PLAINTEXT, or PLAINTEXT."
  }
}

variable "encryption_in_transit_in_cluster" {
  description = "Encryption in transit within the cluster"
  type        = bool
  default     = true
}

# Monitoring
variable "enhanced_monitoring" {
  description = "Enhanced monitoring level"
  type        = string
  default     = "DEFAULT"
  validation {
    condition     = contains(["DEFAULT", "PER_BROKER", "PER_TOPIC_PER_BROKER", "PER_TOPIC_PER_PARTITION"], var.enhanced_monitoring)
    error_message = "Valid values are DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, or PER_TOPIC_PER_PARTITION."
  }
}

variable "enable_jmx_exporter" {
  description = "Enable JMX exporter for Prometheus monitoring"
  type        = bool
  default     = false
}

variable "enable_node_exporter" {
  description = "Enable Node exporter for Prometheus monitoring"
  type        = bool
  default     = false
}

# Logging
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "enable_firehose_logs" {
  description = "Enable Firehose logs"
  type        = bool
  default     = false
}

variable "firehose_delivery_stream" {
  description = "Firehose delivery stream name"
  type        = string
  default     = null
}

variable "enable_s3_logs" {
  description = "Enable S3 logs"
  type        = bool
  default     = false
}

variable "s3_logs_bucket" {
  description = "S3 bucket for logs"
  type        = string
  default     = null
}

variable "s3_logs_prefix" {
  description = "S3 prefix for logs"
  type        = string
  default     = null
}
