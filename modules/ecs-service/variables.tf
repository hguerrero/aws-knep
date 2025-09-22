# ECS Service Module Variables

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ECS Cluster Configuration
variable "cluster_id" {
  description = "Existing ECS cluster ID (if null, will create new cluster)"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Name of the ECS cluster (used when creating new cluster)"
  type        = string
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

# Container Configuration
variable "container_name" {
  description = "Name of the container"
  type        = string
}

variable "container_image" {
  description = "Docker image for the container"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "cpu" {
  description = "CPU units for the task (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Health Check Configuration
variable "health_check_command" {
  description = "Health check command for the container"
  type        = list(string)
  default     = null
}

variable "health_check_path" {
  description = "Health check path for ALB"
  type        = string
  default     = "/health"
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

# Networking Configuration
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_ids" {
  description = "Security group IDs for ECS tasks"
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks"
  type        = bool
  default     = false
}

# Load Balancer Configuration
variable "load_balancer_name" {
  description = "Name of the load balancer"
  type        = string
}

variable "internal_load_balancer" {
  description = "Whether the load balancer is internal"
  type        = bool
  default     = false
}

variable "alb_subnet_ids" {
  description = "Subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_security_group_ids" {
  description = "Security group IDs for the ALB"
  type        = list(string)
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS"
  type        = string
  default     = null
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

# IAM Configuration
variable "task_role_policy" {
  description = "IAM policy JSON for the task role"
  type        = string
  default     = null
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
