# Kong Native Event Proxy - Development Environment Variables

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "kong-knep"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Kong Native Event Proxy Configuration
variable "kong_knep_image" {
  description = "Kong Native Event Proxy Docker image"
  type        = string
  default     = "kong/kong-native-event-proxy:latest"
}

variable "kong_knep_port" {
  description = "Kong Native Event Proxy port"
  type        = number
  default     = 8080
}

# Konnect Configuration
variable "konnect_api_token" {
  description = "Konnect API token for authentication"
  type        = string
  sensitive   = true
}

variable "konnect_api_hostname" {
  description = "Konnect API hostname"
  type        = string
  default     = "us.api.konghq.com"
}

variable "konnect_control_plane_id" {
  description = "Konnect Control Plane ID"
  type        = string
  sensitive   = true
}

# ECS Configuration
variable "kong_cpu" {
  description = "CPU units for Kong task (1024 = 1 vCPU)"
  type        = number
  default     = 1024  # Full vCPU for production
}

variable "kong_memory" {
  description = "Memory for Kong task in MB"
  type        = number
  default     = 2048  # 2 GB for production
}

variable "kong_desired_count" {
  description = "Desired number of Kong tasks"
  type        = number
  default     = 3  # Multiple instances for production
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

# Legacy Kong ports (for compatibility)
variable "kong_proxy_port" {
  description = "Kong proxy port"
  type        = number
  default     = 8000
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

# Load Balancer Configuration
variable "alb_certificate_arn" {
  description = "ARN of SSL certificate for ALB (optional)"
  type        = string
  default     = null
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = true  # Enable protection for production
}

# Health Check Configuration
variable "health_check_path" {
  description = "Health check path for Kong"
  type        = string
  default     = "/status"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks"
  type        = number
  default     = 3
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30  # Longer retention for production
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
  default     = false  # KNEP doesn't need admin API
}

variable "admin_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Kong Admin API"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

# Kong Environment Variables
variable "kong_env_vars" {
  description = "Additional environment variables for Kong"
  type        = map(string)
  default     = {}
}

# Auto Scaling Configuration
variable "kong_min_capacity" {
  description = "Minimum number of Kong tasks"
  type        = number
  default     = 2  # Higher minimum for production
}

variable "kong_max_capacity" {
  description = "Maximum number of Kong tasks"
  type        = number
  default     = 10  # Higher maximum for production
}

variable "autoscaling_target_cpu" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

variable "autoscaling_target_memory" {
  description = "Target memory utilization for auto scaling"
  type        = number
  default     = 80
}

variable "autoscaling_scale_up_cooldown" {
  description = "Scale up cooldown period in seconds"
  type        = number
  default     = 300
}

variable "autoscaling_scale_down_cooldown" {
  description = "Scale down cooldown period in seconds"
  type        = number
  default     = 300
}
