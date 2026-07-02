# Kong Event Gateway — Infrastructure Outputs

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NLB placement)"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (KEG ECS task placement)"
  value       = module.networking.private_subnet_ids
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------
output "nlb_security_group_id" {
  description = "sg-nlb: NLB security group ID"
  value       = module.security.nlb_security_group_id
}

output "keg_security_group_id" {
  description = "sg-keg: Kong Event Gateway ECS security group ID"
  value       = module.security.keg_security_group_id
}

output "msk_security_group_id" {
  description = "sg-msk: MSK security group ID"
  value       = module.security.msk_security_group_id
}

# ---------------------------------------------------------------------------
# MSK
# ---------------------------------------------------------------------------
output "msk_cluster_arn" {
  description = "MSK cluster ARN"
  value       = module.msk.cluster_arn
}

output "msk_bootstrap_brokers_sasl_scram" {
  description = "MSK SASL/SCRAM bootstrap brokers (port 9096)"
  value       = module.msk.bootstrap_brokers_sasl_scram
  sensitive   = true
}

output "msk_default_scram_secret_arn" {
  description = "Secrets Manager ARN for the KEG SCRAM credentials"
  value       = module.msk.default_scram_secret_arn
}

# ---------------------------------------------------------------------------
# SSM Parameter paths (for gateway/ to reference)
# ---------------------------------------------------------------------------
output "ssm_parameters" {
  description = "SSM parameter paths written by this root — consumed by gateway/"
  value = {
    vpc_id                       = aws_ssm_parameter.vpc_id.name
    private_subnet_ids           = aws_ssm_parameter.private_subnet_ids.name
    public_subnet_ids            = aws_ssm_parameter.public_subnet_ids.name
    nlb_security_group_id        = aws_ssm_parameter.nlb_security_group_id.name
    keg_security_group_id        = aws_ssm_parameter.keg_security_group_id.name
    msk_cluster_arn              = aws_ssm_parameter.msk_cluster_arn.name
    msk_bootstrap_brokers_scram  = aws_ssm_parameter.msk_bootstrap_brokers_sasl_scram.name
    msk_default_scram_secret_arn = var.msk_create_default_scram_user ? aws_ssm_parameter.msk_default_scram_secret_arn[0].name : null
  }
}

output "useful_commands" {
  description = "Handy AWS CLI commands for this deployment"
  value = {
    view_msk_cluster    = "aws kafka describe-cluster --cluster-arn ${module.msk.cluster_arn} --region ${var.aws_region}"
    get_brokers         = "aws kafka get-bootstrap-brokers --cluster-arn ${module.msk.cluster_arn} --region ${var.aws_region}"
    view_ssm_parameters = "aws ssm get-parameters-by-path --path /${var.project_name}/ --recursive --region ${var.aws_region}"
  }
}
