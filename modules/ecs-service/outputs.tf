# ECS Service Module Outputs

output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = local.cluster_id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = var.cluster_id != null ? null : aws_ecs_cluster.main[0].name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = var.cluster_id != null ? null : aws_ecs_cluster.main[0].arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.main.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the bootstrap (first) Kafka target group"
  value       = aws_lb_target_group.kafka[tostring(var.kafka_client_port)].arn
}

output "nlb_endpoint" {
  description = "NLB DNS name — Kafka clients bootstrap to this address on port 9092"
  value       = "${aws_lb.main.dns_name}:${var.kafka_client_port}"
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.main.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.main.arn
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}
