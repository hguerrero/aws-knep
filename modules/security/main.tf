# Security Module - DMZ Security Groups for Kong Event Gateway
#
# Three-group DMZ chain:
#
#   Internet / external clients
#       │ TCP 9092-9094 (port-mapping range)
#       ▼
#   sg-nlb   ← NLB in public subnets
#       │ TCP 9092-9094 → sg-keg only
#       ▼
#   sg-keg   ← Kong Event Gateway (ECS) in private app subnets
#       │ TCP 9096 → sg-msk only  (SASL/SCRAM over TLS)
#       │ TCP 443  → 0.0.0.0/0   (Konnect control plane)
#       ▼
#   sg-msk   ← MSK brokers in private data subnets; NO public access
#
# NOTE: Cross-group rules are defined as separate aws_security_group_rule resources
# below each group. This avoids the Terraform "cycle" error that occurs when inline
# ingress/egress blocks reference sibling security groups in the same module.

# ---------------------------------------------------------------------------
# sg-nlb -Network Load Balancer
# ---------------------------------------------------------------------------
resource "aws_security_group" "nlb" {
  name_prefix = "${var.name_prefix}-nlb-"
  vpc_id      = var.vpc_id
  description = "sg-nlb: Kafka client ingress to the Network Load Balancer"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nlb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "nlb_ingress_kafka" {
  security_group_id = aws_security_group.nlb.id
  type              = "ingress"
  description       = "Kafka clients (TCP ${var.kafka_client_port}-${var.kafka_port_range_end})"
  from_port         = var.kafka_client_port
  to_port           = var.kafka_port_range_end
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
}

resource "aws_security_group_rule" "nlb_egress_to_keg" {
  security_group_id        = aws_security_group.nlb.id
  type                     = "egress"
  description              = "Forward Kafka traffic to Kong Event Gateway"
  from_port                = var.kafka_client_port
  to_port                  = var.kafka_port_range_end
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.keg.id
}

# ---------------------------------------------------------------------------
# sg-keg -Kong Event Gateway ECS tasks
# ---------------------------------------------------------------------------
resource "aws_security_group" "keg" {
  name_prefix = "${var.name_prefix}-keg-"
  vpc_id      = var.vpc_id
  description = "sg-keg: Kong Event Gateway (ECS) - DMZ enforcement point"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-keg-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "keg_ingress_from_nlb" {
  security_group_id        = aws_security_group.keg.id
  type                     = "ingress"
  description              = "Kafka from NLB (TCP ${var.kafka_client_port}-${var.kafka_port_range_end})"
  from_port                = var.kafka_client_port
  to_port                  = var.kafka_port_range_end
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nlb.id
}

resource "aws_security_group_rule" "keg_egress_to_msk" {
  security_group_id        = aws_security_group.keg.id
  type                     = "egress"
  description              = "MSK SASL/SCRAM (TCP 9096)"
  from_port                = 9096
  to_port                  = 9096
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.msk.id
}

resource "aws_security_group_rule" "keg_egress_konnect" {
  security_group_id = aws_security_group.keg.id
  type              = "egress"
  description       = "Konnect control plane (TCP 443)"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# sg-msk -MSK Cluster
# ---------------------------------------------------------------------------
resource "aws_security_group" "msk" {
  name_prefix = "${var.name_prefix}-msk-"
  vpc_id      = var.vpc_id
  description = "sg-msk: MSK brokers -reachable only from Kong Event Gateway"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-msk-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "msk_ingress_from_keg" {
  security_group_id        = aws_security_group.msk.id
  type                     = "ingress"
  description              = "SASL/SCRAM from Kong Event Gateway (TCP 9096)"
  from_port                = 9096
  to_port                  = 9096
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.keg.id
}

resource "aws_security_group_rule" "msk_ingress_self" {
  security_group_id = aws_security_group.msk.id
  type              = "ingress"
  description       = "MSK broker-to-broker replication"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "msk_egress_vpc" {
  security_group_id = aws_security_group.msk.id
  type              = "egress"
  description       = "MSK internal egress (VPC only)"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr]
}

# ---------------------------------------------------------------------------
# sg-vpc-endpoints -VPC Interface Endpoints
# ---------------------------------------------------------------------------
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.name_prefix}-vpc-endpoints-"
  vpc_id      = var.vpc_id
  description = "Security group for VPC interface endpoints (ECR, CloudWatch, SSM, Secrets Manager)"

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc-endpoints-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
