# MSK (Managed Streaming for Apache Kafka) Module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# MSK Configuration
resource "aws_msk_configuration" "main" {
  kafka_versions = [var.kafka_version]
  name           = "${var.name_prefix}-msk-config"

  server_properties = <<PROPERTIES
# KRaft Mode Configuration (Kafka Raft - no Zookeeper)
# AWS MSK manages KRaft configuration automatically when using TIERED storage
auto.create.topics.enable=true
default.replication.factor=2
min.insync.replicas=1
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
num.partitions=3
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=2
transaction.state.log.replication.factor=2
transaction.state.log.min.isr=1
log.retention.hours=168
log.segment.bytes=1073741824
group.initial.rebalance.delay.ms=0
PROPERTIES

  description = "MSK configuration for ${var.name_prefix}"
}

# CloudWatch Log Group for MSK
resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-msk-logs"
  })
}

# MSK Cluster
resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.name_prefix}-msk"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes
  storage_mode           = var.storage_mode  # TIERED for KRaft, LOCAL for Zookeeper
  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  broker_node_group_info {
    instance_type   = var.instance_type
    client_subnets  = var.subnet_ids
    security_groups = var.security_group_ids
    
    storage_info {
      ebs_storage_info {
        volume_size = var.volume_size
      }
    }
  }

  client_authentication {
    sasl {
      scram = var.enable_scram_auth
      iam   = var.enable_iam_auth
    }
    dynamic "tls" {
      for_each = length(var.certificate_authority_arns) > 0 ? [1] : []
      content {
        certificate_authority_arns = var.certificate_authority_arns
      }
    }
    unauthenticated = var.enable_unauthenticated_access
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.encryption_in_transit_client_broker
      in_cluster    = var.encryption_in_transit_in_cluster
    }
  }

  enhanced_monitoring = var.enhanced_monitoring

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = var.enable_jmx_exporter
      }
      node_exporter {
        enabled_in_broker = var.enable_node_exporter
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = var.enable_cloudwatch_logs
        log_group = aws_cloudwatch_log_group.msk.name
      }
      firehose {
        enabled         = var.enable_firehose_logs
        delivery_stream = var.firehose_delivery_stream
      }
      s3 {
        enabled = var.enable_s3_logs
        bucket  = var.s3_logs_bucket
        prefix  = var.s3_logs_prefix
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-msk-cluster"
  })
}

# MSK Cluster Policy (for IAM authentication)
resource "aws_msk_cluster_policy" "main" {
  count = var.enable_iam_auth ? 1 : 0

  cluster_arn = aws_msk_cluster.main.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowKafkaActions"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_principals
        }
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = aws_msk_cluster.main.arn
      },
      {
        Sid    = "AllowTopicActions"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_principals
        }
        Action = [
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = "${aws_msk_cluster.main.arn}/*"
      },
      {
        Sid    = "AllowGroupActions"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_principals
        }
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "${aws_msk_cluster.main.arn}/*"
      }
    ]
  })
}

# KMS key for MSK SCRAM secrets — AWS MSK requires a CMK, the default key is not accepted.
resource "aws_kms_key" "msk_scram" {
  count = var.enable_scram_auth ? 1 : 0

  description             = "CMK for MSK SCRAM secrets - ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-msk-scram-kms"
  })
}

resource "aws_kms_alias" "msk_scram" {
  count = var.enable_scram_auth ? 1 : 0

  name          = "alias/${var.name_prefix}-msk-scram"
  target_key_id = aws_kms_key.msk_scram[0].key_id
}

# Random password for default SCRAM user if not provided
resource "random_password" "default_scram_password" {
  count   = var.create_default_scram_user && var.default_scram_password == "" ? 1 : 0
  length  = 32
  special = true
}

# SCRAM Secret for default user
resource "aws_secretsmanager_secret" "default_scram_user" {
  count = var.create_default_scram_user ? 1 : 0

  name       = "AmazonMSK_${var.name_prefix}-${var.default_scram_username}"
  description = "SCRAM credentials for MSK user ${var.default_scram_username}"
  kms_key_id = aws_kms_key.msk_scram[0].key_id

  tags = merge(var.common_tags, {
    Name = "AmazonMSK_${var.name_prefix}-${var.default_scram_username}"
  })
}

resource "aws_secretsmanager_secret_version" "default_scram_user" {
  count = var.create_default_scram_user ? 1 : 0

  secret_id = aws_secretsmanager_secret.default_scram_user[0].id
  secret_string = jsonencode({
    username = var.default_scram_username
    password = var.default_scram_password != "" ? var.default_scram_password : random_password.default_scram_password[0].result
  })
}

# SCRAM Secrets for additional users
resource "aws_secretsmanager_secret" "scram_users" {
  count = length(var.scram_users)

  name        = "AmazonMSK_${var.name_prefix}-${var.scram_users[count.index].username}"
  description = "SCRAM credentials for MSK user ${var.scram_users[count.index].username}"
  kms_key_id  = length(aws_kms_key.msk_scram) > 0 ? aws_kms_key.msk_scram[0].key_id : null

  tags = merge(var.common_tags, {
    Name = "AmazonMSK_${var.name_prefix}-${var.scram_users[count.index].username}"
  })
}

resource "aws_secretsmanager_secret_version" "scram_users" {
  count = length(var.scram_users)

  secret_id = aws_secretsmanager_secret.scram_users[count.index].id
  secret_string = jsonencode({
    username = var.scram_users[count.index].username
    password = var.scram_users[count.index].password
  })
}

# MSK SCRAM Secret Association for default user
resource "aws_msk_scram_secret_association" "default_user" {
  count = var.create_default_scram_user && var.enable_scram_auth ? 1 : 0

  cluster_arn     = aws_msk_cluster.main.arn
  secret_arn_list = [aws_secretsmanager_secret.default_scram_user[0].arn]

  depends_on = [aws_secretsmanager_secret_version.default_scram_user]
}

# MSK SCRAM Secret Association for additional users
resource "aws_msk_scram_secret_association" "additional_users" {
  count = length(var.scram_users) > 0 && var.enable_scram_auth ? 1 : 0

  cluster_arn     = aws_msk_cluster.main.arn
  secret_arn_list = aws_secretsmanager_secret.scram_users[*].arn

  depends_on = [aws_secretsmanager_secret_version.scram_users]
}
