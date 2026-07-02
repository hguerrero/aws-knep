# ECS Service Module - ECS service with Network Load Balancer (NLB)
# NLB is required for Kong Event Gateway: ALB is HTTP-only and cannot proxy
# the Kafka binary protocol over TCP.

# ECS Cluster (only create if cluster_id is not provided)
resource "aws_ecs_cluster" "main" {
  count = var.cluster_id == null ? 1 : 0
  name  = var.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(var.common_tags, {
    Name = var.cluster_name
  })
}

# Use existing cluster or created cluster
locals {
  cluster_id = var.cluster_id != null ? var.cluster_id : aws_ecs_cluster.main[0].id

  # Port set for the Kafka port-mapping range (strings, for for_each keys)
  kafka_ports = toset([
    for p in range(var.kafka_client_port, var.kafka_port_range_end + 1) : tostring(p)
  ])
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-logs"
  })
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.service_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-ecs-task-execution-role"
  })
}

# Attach the Amazon ECS task execution role policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Grant the execution role access to any Secrets Manager secrets injected via
# the `secrets` variable. ECS pulls these at task startup before the container
# launches — the base AmazonECSTaskExecutionRolePolicy does not include this.
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  name = "${var.service_name}-secrets-access"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [for s in var.secrets : s.valueFrom]
      }
    ]
  })
}

# ECS Task Role (for the application itself)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.service_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-ecs-task-role"
  })
}

# IAM policy for the service
resource "aws_iam_role_policy" "service_policy" {
  count = var.task_role_policy != null ? 1 : 0
  name  = "${var.service_name}-policy"
  role  = aws_iam_role.ecs_task_role.id
  policy = var.task_role_policy
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = var.container_name
      image = var.container_image
      
      essential = true
      
      portMappings = concat(
        # Kafka port-mapping range — one port per broker, plus bootstrap
        [
          for port in range(var.kafka_client_port, var.kafka_port_range_end + 1) : {
            containerPort = port
            protocol      = "tcp"
          }
        ],
        # Management / health-check port
        [
          {
            containerPort = var.container_port
            protocol      = "tcp"
          }
        ]
      )

      environment = var.environment_variables

      # Secrets from AWS Secrets Manager — injected at task start, never in logs.
      # Used for KONG_KONNECT_CLIENT_CERT and KONG_KONNECT_CLIENT_KEY.
      secrets = length(var.secrets) > 0 ? var.secrets : null

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = var.health_check_command != null ? {
        command = var.health_check_command
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      } : null
    }
  ])

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-task"
  })
}

# Network Load Balancer
# NLB operates at Layer 4 (TCP) — required for the Kafka wire protocol.
# It sits in public subnets and forwards TCP 9092 to Kong Event Gateway
# in the private app subnets. TLS termination happens at the gateway.
resource "aws_lb" "main" {
  name               = var.load_balancer_name
  internal           = var.internal_load_balancer
  load_balancer_type = "network"
  security_groups    = var.nlb_security_group_ids
  subnets            = var.nlb_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.common_tags, {
    Name = var.load_balancer_name
  })
}

# NLB Target Groups — one per port in the Kafka port-mapping range.
# KEG uses port-mapping strategy: each broker gets its own port, so clients
# connect to port 9092 for bootstrap then to broker-specific ports (9093, 9094, ...).
resource "aws_lb_target_group" "kafka" {
  for_each    = local.kafka_ports

  name        = "${var.service_name}-${each.key}"
  port        = tonumber(each.key)
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    port                = "traffic-port"
    protocol            = "TCP"
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-${each.key}-tg"
  })
}

# NLB Listeners — one per port in the Kafka port-mapping range.
# Clients hit the bootstrap port (9092) first, then broker-specific ports.
resource "aws_lb_listener" "kafka" {
  for_each = aws_lb_target_group.kafka

  load_balancer_arn = aws_lb.main.arn
  port              = tonumber(each.key)
  protocol          = var.tls_certificate_arn != null ? "TLS" : "TCP"
  certificate_arn   = var.tls_certificate_arn
  ssl_policy        = var.tls_certificate_arn != null ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null

  default_action {
    type             = "forward"
    target_group_arn = each.value.arn
  }

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-${each.key}-listener"
  })
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = var.service_name
  cluster         = local.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = var.ecs_security_group_ids
    subnets          = var.ecs_subnet_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = aws_lb_target_group.kafka
    content {
      target_group_arn = load_balancer.value.arn
      container_name   = var.container_name
      container_port   = tonumber(load_balancer.key)
    }
  }

  depends_on = [
    aws_lb_listener.kafka
  ]

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-service"
  })
}
