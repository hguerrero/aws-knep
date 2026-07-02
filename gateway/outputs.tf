# Kong Event Gateway — Outputs

# ---------------------------------------------------------------------------
# Kong Identity
# ---------------------------------------------------------------------------
output "auth_server_issuer" {
  description = "Kong Identity issuer URL"
  value       = konnect_identity_auth_server.kafka.issuer
}

output "token_endpoint" {
  description = "OAuth token endpoint — used by get-token.sh"
  value       = "${konnect_identity_auth_server.kafka.issuer}/oauth/token"
}

output "jwks_endpoint" {
  description = "JWKS endpoint the gateway uses to verify tokens"
  value       = "${konnect_identity_auth_server.kafka.issuer}/.well-known/jwks"
}

output "client_id" {
  description = "OAuth client ID for Kafka clients"
  value       = konnect_identity_auth_server_client.kafka_client.id
}

output "client_secret" {
  description = "OAuth client secret for Kafka clients"
  value       = konnect_identity_auth_server_client.kafka_client.client_secret
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Konnect Control Plane
# ---------------------------------------------------------------------------
output "event_gateway_id" {
  description = "Konnect Event Gateway ID (KONG_KONNECT_GATEWAY_CLUSTER_ID)"
  value       = konnect_event_gateway.keg.id
}

output "event_gateway_name" {
  description = "Konnect Event Gateway name"
  value       = konnect_event_gateway.keg.name
}

output "backend_cluster_id" {
  description = "MSK backend cluster ID in Konnect"
  value       = konnect_event_gateway_backend_cluster.msk.id
}

output "virtual_cluster_id" {
  description = "Internal virtual cluster ID in Konnect"
  value       = konnect_event_gateway_virtual_cluster.internal.id
}

output "data_plane_cert_arn" {
  description = "Secrets Manager ARN for the data plane TLS certificate"
  value       = aws_secretsmanager_secret.keg_dp_cert.arn
}

output "data_plane_key_arn" {
  description = "Secrets Manager ARN for the data plane private key"
  value       = aws_secretsmanager_secret.keg_dp_key.arn
  sensitive   = true
}

# ---------------------------------------------------------------------------
# NLB — Kafka client bootstrap endpoint
# ---------------------------------------------------------------------------
output "kafka_bootstrap_endpoint" {
  description = "NLB endpoint Kafka clients use to bootstrap (host:port). Point your DNS CNAME here."
  value       = module.kong_event_gateway.nlb_endpoint
}

output "nlb_dns_name" {
  description = "NLB DNS name (use for Route53 alias or CNAME)"
  value       = module.kong_event_gateway.load_balancer_dns_name
}

output "nlb_zone_id" {
  description = "NLB hosted zone ID (use for Route53 alias records)"
  value       = module.kong_event_gateway.load_balancer_zone_id
}

output "nlb_arn" {
  description = "NLB ARN"
  value       = module.kong_event_gateway.load_balancer_arn
}

# ---------------------------------------------------------------------------
# ECS
# ---------------------------------------------------------------------------
output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = module.kong_event_gateway.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.kong_event_gateway.cluster_name
}

output "event_gateway_service_name" {
  description = "ECS service name for the Event Gateway"
  value       = module.kong_event_gateway.service_name
}

output "event_gateway_task_definition_arn" {
  description = "Task definition ARN"
  value       = module.kong_event_gateway.task_definition_arn
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group for the Event Gateway"
  value       = module.kong_event_gateway.cloudwatch_log_group_name
}

# ---------------------------------------------------------------------------
# Quick-reference commands
# ---------------------------------------------------------------------------
output "useful_commands" {
  description = "Handy AWS CLI commands for this deployment"
  value = {
    view_ecs_service  = "aws ecs describe-services --cluster ${module.kong_event_gateway.cluster_name} --services ${module.kong_event_gateway.service_name} --region ${var.aws_region}"
    view_tasks        = "aws ecs list-tasks --cluster ${module.kong_event_gateway.cluster_name} --service-name ${module.kong_event_gateway.service_name} --region ${var.aws_region}"
    view_logs         = "aws logs tail ${module.kong_event_gateway.cloudwatch_log_group_name} --follow --region ${var.aws_region}"
    scale_service     = "aws ecs update-service --cluster ${module.kong_event_gateway.cluster_name} --service ${module.kong_event_gateway.service_name} --desired-count <N> --region ${var.aws_region}"
    view_nlb_health   = "aws elbv2 describe-target-health --target-group-arn ${module.kong_event_gateway.target_group_arn} --region ${var.aws_region}"
    view_msk          = "aws kafka describe-cluster --cluster-arn ${nonsensitive(local.msk_cluster_arn)} --region ${var.aws_region}"
  }
}
