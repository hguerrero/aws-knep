# MSK Module Outputs

output "cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.main.cluster_name
}

output "bootstrap_brokers" {
  description = "Comma separated list of one or more hostname:port pairs of kafka brokers suitable for bootstrapping connectivity to the kafka cluster"
  value       = aws_msk_cluster.main.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "Comma separated list of one or more DNS names (or IP addresses) and TLS port pairs kafka brokers suitable for bootstrapping connectivity to the kafka cluster"
  value       = aws_msk_cluster.main.bootstrap_brokers_tls
}

output "bootstrap_brokers_sasl_scram" {
  description = "Comma separated list of one or more DNS names (or IP addresses) and SASL SCRAM port pairs kafka brokers suitable for bootstrapping connectivity to the kafka cluster"
  value       = aws_msk_cluster.main.bootstrap_brokers_sasl_scram
}

output "bootstrap_brokers_sasl_iam" {
  description = "Comma separated list of one or more DNS names (or IP addresses) and SASL IAM port pairs kafka brokers suitable for bootstrapping connectivity to the kafka cluster"
  value       = aws_msk_cluster.main.bootstrap_brokers_sasl_iam
}

output "storage_mode" {
  description = "Storage mode of the MSK cluster (TIERED for KRaft, LOCAL for Zookeeper)"
  value       = aws_msk_cluster.main.storage_mode
}

output "kafka_version" {
  description = "Kafka version of the MSK cluster"
  value       = aws_msk_cluster.main.kafka_version
}

output "configuration_arn" {
  description = "ARN of the MSK configuration"
  value       = aws_msk_configuration.main.arn
}

output "configuration_latest_revision" {
  description = "Latest revision of the MSK configuration"
  value       = aws_msk_configuration.main.latest_revision
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.msk.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.msk.arn
}

# SCRAM Authentication Outputs
output "default_scram_secret_arn" {
  description = "ARN of the default SCRAM user secret"
  value       = var.create_default_scram_user ? aws_secretsmanager_secret.default_scram_user[0].arn : null
}

output "default_scram_username" {
  description = "Default SCRAM username"
  value       = var.create_default_scram_user ? var.default_scram_username : null
}

output "scram_secret_arns" {
  description = "ARNs of all SCRAM user secrets"
  value       = aws_secretsmanager_secret.scram_users[*].arn
}

# Connection information for applications
output "connection_info" {
  description = "Connection information for different authentication methods"
  value = {
    bootstrap_brokers_plaintext = aws_msk_cluster.main.bootstrap_brokers
    bootstrap_brokers_tls       = aws_msk_cluster.main.bootstrap_brokers_tls
    bootstrap_brokers_sasl_iam  = aws_msk_cluster.main.bootstrap_brokers_sasl_iam
    bootstrap_brokers_sasl_scram = aws_msk_cluster.main.bootstrap_brokers_sasl_scram
    # KRaft mode information
    storage_mode                = aws_msk_cluster.main.storage_mode
    kafka_version               = aws_msk_cluster.main.kafka_version
    kraft_enabled               = aws_msk_cluster.main.storage_mode == "TIERED"
    # SCRAM connection info
    scram_enabled               = var.enable_scram_auth
    default_scram_username      = var.create_default_scram_user ? var.default_scram_username : null
    default_scram_secret_arn    = var.create_default_scram_user ? aws_secretsmanager_secret.default_scram_user[0].arn : null
  }
}
