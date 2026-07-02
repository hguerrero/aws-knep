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

variable "secrets" {
  description = "Secrets injected from AWS Secrets Manager (name → secretsmanager ARN or SSM path). Used for KONG_KONNECT_CLIENT_CERT and KONG_KONNECT_CLIENT_KEY."
  type = list(object({
    name      = string
    valueFrom = string
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
  description = "Health check path (unused by NLB TCP health checks; kept for container-level checks)"
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

# Network Load Balancer Configuration
# NLB is required for Kong Event Gateway — ALB cannot proxy the Kafka TCP protocol.
variable "load_balancer_name" {
  description = "Name of the Network Load Balancer"
  type        = string
}

variable "internal_load_balancer" {
  description = "Whether the NLB is internal (false = internet-facing for external Kafka clients)"
  type        = bool
  default     = false
}

variable "nlb_subnet_ids" {
  description = "Public subnet IDs for the NLB"
  type        = list(string)
}

variable "nlb_security_group_ids" {
  description = "Security group IDs for the NLB (sg-nlb in the DMZ pattern)"
  type        = list(string)
}

variable "kafka_client_port" {
  description = "Bootstrap port Kafka clients connect to (start of the port-mapping range, standard: 9092)"
  type        = number
  default     = 9092
}

variable "kafka_port_range_end" {
  description = "Last port in the Kafka port-mapping range — KEG uses one port per broker (e.g. 9094 for 2 brokers)"
  type        = number
  default     = 9094
}

variable "tls_certificate_arn" {
  description = "ACM certificate ARN for TLS listener (wildcard cert for SNI-based Virtual Cluster routing)"
  type        = string
  default     = null
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the NLB"
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
