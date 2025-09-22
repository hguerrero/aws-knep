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
  description = "Enable Kong Admin API access"
  type        = bool
  default     = false
}

variable "admin_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Kong Admin API"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

# Port Configuration
variable "kong_proxy_port" {
  description = "Kong proxy port"
  type        = number
  default     = 8000
}

variable "kong_knep_port" {
  description = "Kong Native Event Proxy port"
  type        = number
  default     = 8080
}

variable "kong_admin_port" {
  description = "Kong admin port"
  type        = number
  default     = 8001
}

variable "kong_admin_gui_port" {
  description = "Kong admin GUI port"
  type        = number
  default     = 8002
}
