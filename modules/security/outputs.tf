# Security Module Outputs — DMZ pattern security groups

output "nlb_security_group_id" {
  description = "ID of the NLB security group (sg-nlb) — Kafka client ingress"
  value       = aws_security_group.nlb.id
}

output "keg_security_group_id" {
  description = "ID of the Kong Event Gateway security group (sg-keg)"
  value       = aws_security_group.keg.id
}

# Alias so callers that reference ecs_security_group_id still work
output "ecs_security_group_id" {
  description = "Alias for keg_security_group_id (ECS Fargate tasks run the Event Gateway)"
  value       = aws_security_group.keg.id
}

# Alias for callers still referencing the old alb_ name
output "alb_security_group_id" {
  description = "Deprecated alias — use nlb_security_group_id"
  value       = aws_security_group.nlb.id
}

output "msk_security_group_id" {
  description = "ID of the MSK security group (sg-msk) — gateway access only"
  value       = aws_security_group.msk.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}
