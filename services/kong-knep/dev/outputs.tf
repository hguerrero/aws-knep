# Kong Native Event Proxy - Development Environment Outputs

# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

# ECS Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.kong_knep_service.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.kong_knep_service.cluster_name
}

output "kong_knep_service_name" {
  description = "Name of the Kong Native Event Proxy ECS service"
  value       = module.kong_knep_service.service_name
}

output "kong_knep_service_arn" {
  description = "ARN of the Kong Native Event Proxy ECS service"
  value       = module.kong_knep_service.service_arn
}

output "kong_knep_task_definition_arn" {
  description = "ARN of the Kong Native Event Proxy task definition"
  value       = module.kong_knep_service.task_definition_arn
}

# Load Balancer Outputs
output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.kong_knep_service.load_balancer_dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = module.kong_knep_service.load_balancer_zone_id
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = module.kong_knep_service.load_balancer_arn
}

output "kong_knep_target_group_arn" {
  description = "ARN of the Kong Native Event Proxy target group"
  value       = module.kong_knep_service.target_group_arn
}

output "kong_knep_url" {
  description = "URL to access Kong Native Event Proxy"
  value       = module.kong_knep_service.service_url
}

# Security Outputs
output "security_group_alb_id" {
  description = "ID of the ALB security group"
  value       = module.security.alb_security_group_id
}

output "security_group_ecs_id" {
  description = "ID of the ECS security group"
  value       = module.security.ecs_security_group_id
}

# Logging Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Kong Native Event Proxy"
  value       = module.kong_knep_service.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for Kong Native Event Proxy"
  value       = module.kong_knep_service.cloudwatch_log_group_arn
}

# IAM Outputs
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.kong_knep_service.task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.kong_knep_service.task_role_arn
}

# Useful commands for management
output "useful_commands" {
  description = "Useful AWS CLI commands for managing the deployment"
  value = {
    view_ecs_service = "aws ecs describe-services --cluster ${module.kong_knep_service.cluster_name} --services ${module.kong_knep_service.service_name} --region ${var.aws_region}"
    view_tasks       = "aws ecs list-tasks --cluster ${module.kong_knep_service.cluster_name} --service-name ${module.kong_knep_service.service_name} --region ${var.aws_region}"
    view_logs        = "aws logs describe-log-streams --log-group-name ${module.kong_knep_service.cloudwatch_log_group_name} --region ${var.aws_region}"
    scale_service    = "aws ecs update-service --cluster ${module.kong_knep_service.cluster_name} --service ${module.kong_knep_service.service_name} --desired-count <NEW_COUNT> --region ${var.aws_region}"
  }
}
