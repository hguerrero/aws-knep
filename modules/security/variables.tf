# Security Module Variables

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Kong"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_admin_api" {
  description = "Unused — Kong Event Gateway has no admin API. Kept for module compatibility."
  type        = bool
  default     = false
}

variable "admin_allowed_cidr_blocks" {
  description = "Unused — kept for module compatibility."
  type        = list(string)
  default     = []
}

# Port Configuration — DMZ pattern
variable "kafka_client_port" {
  description = "TCP port Kafka clients use to connect (NLB listener and sg-nlb ingress, start of range)"
  type        = number
  default     = 9092
}

variable "kafka_port_range_end" {
  description = "Last port in the Kafka listener range — KEG uses one port per broker (e.g. 9094 covers 2 brokers)"
  type        = number
  default     = 9094
}

# Legacy port variables — kept for compatibility with existing callers
variable "kong_proxy_port" {
  description = "Unused — kept for compatibility"
  type        = number
  default     = 8000
}

variable "kong_keg_port" {
  description = "Unused — kept for compatibility"
  type        = number
  default     = 8080
}

variable "kong_admin_port" {
  description = "Unused — kept for compatibility"
  type        = number
  default     = 8001
}

variable "kong_admin_gui_port" {
  description = "Unused — kept for compatibility"
  type        = number
  default     = 8002
}
