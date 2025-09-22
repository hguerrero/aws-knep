# ECS Service Module - Generic ECS service with ALB

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
      
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = var.environment_variables

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

# Application Load Balancer
resource "aws_lb" "main" {
  name               = var.load_balancer_name
  internal           = var.internal_load_balancer
  load_balancer_type = "application"
  security_groups    = var.alb_security_group_ids
  subnets            = var.alb_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.common_tags, {
    Name = var.load_balancer_name
  })
}

# ALB Target Group
resource "aws_lb_target_group" "main" {
  name        = "${var.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-tg"
  })
}

# ALB Listener for HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.ssl_certificate_arn != null ? "redirect" : "forward"
    
    dynamic "redirect" {
      for_each = var.ssl_certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.ssl_certificate_arn == null ? [1] : []
      content {
        target_group {
          arn = aws_lb_target_group.main.arn
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-http-listener"
  })
}

# ALB Listener for HTTPS (if certificate is provided)
resource "aws_lb_listener" "https" {
  count = var.ssl_certificate_arn != null ? 1 : 0
  
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.main.arn
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-https-listener"
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

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https
  ]

  tags = merge(var.common_tags, {
    Name = "${var.service_name}-service"
  })
}
