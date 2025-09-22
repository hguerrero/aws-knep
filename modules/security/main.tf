# Security Module - Security Groups

# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for ALB"

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kong Admin API (if enabled)
  dynamic "ingress" {
    for_each = var.enable_admin_api ? [1] : []
    content {
      description = "Kong Admin API"
      from_port   = var.kong_admin_port
      to_port     = var.kong_admin_port
      protocol    = "tcp"
      cidr_blocks = var.admin_allowed_cidr_blocks
    }
  }

  # Kong Admin GUI (if enabled)
  dynamic "ingress" {
    for_each = var.enable_admin_api ? [1] : []
    content {
      description = "Kong Admin GUI"
      from_port   = var.kong_admin_gui_port
      to_port     = var.kong_admin_gui_port
      protocol    = "tcp"
      cidr_blocks = var.admin_allowed_cidr_blocks
    }
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs" {
  name_prefix = "${var.name_prefix}-ecs-"
  vpc_id      = var.vpc_id
  description = "Security group for ECS tasks"

  # Kong proxy port from ALB
  ingress {
    description     = "Kong proxy from ALB"
    from_port       = var.kong_proxy_port
    to_port         = var.kong_proxy_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Kong Native Event Proxy port from ALB
  ingress {
    description     = "Kong KNEP from ALB"
    from_port       = var.kong_knep_port
    to_port         = var.kong_knep_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Kong admin port from ALB (if enabled)
  dynamic "ingress" {
    for_each = var.enable_admin_api ? [1] : []
    content {
      description     = "Kong admin from ALB"
      from_port       = var.kong_admin_port
      to_port         = var.kong_admin_port
      protocol        = "tcp"
      security_groups = [aws_security_group.alb.id]
    }
  }

  # Kong admin GUI port from ALB (if enabled)
  dynamic "ingress" {
    for_each = var.enable_admin_api ? [1] : []
    content {
      description     = "Kong admin GUI from ALB"
      from_port       = var.kong_admin_gui_port
      to_port         = var.kong_admin_gui_port
      protocol        = "tcp"
      security_groups = [aws_security_group.alb.id]
    }
  }

  # Allow communication between Kong instances
  ingress {
    description = "Kong cluster communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ecs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for RDS Database
resource "aws_security_group" "rds" {
  name_prefix = "${var.name_prefix}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS database"

  # PostgreSQL access from ECS tasks
  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # PostgreSQL access from VPC (for management)
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # No outbound rules needed for RDS
  egress {
    description = "No outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.name_prefix}-vpc-endpoints-"
  vpc_id      = var.vpc_id
  description = "Security group for VPC endpoints"

  # HTTPS access from VPC
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
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

# Security Group for ECS Service Discovery
resource "aws_security_group" "service_discovery" {
  name_prefix = "${var.name_prefix}-service-discovery-"
  vpc_id      = var.vpc_id
  description = "Security group for ECS service discovery"

  # DNS queries
  ingress {
    description = "DNS from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "DNS from VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-service-discovery-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
