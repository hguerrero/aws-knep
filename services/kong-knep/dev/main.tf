# Kong Native Event Proxy - Development Environment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Service     = "kong-knep"
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}

# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Service     = "kong-knep"
    ManagedBy   = "terraform"
  }

  # Kong KNEP environment variables
  kong_knep_env_vars = concat([
    {
      name  = "KONNECT_API_TOKEN"
      value = var.konnect_api_token
    },
    {
      name  = "KONNECT_API_HOSTNAME"
      value = var.konnect_api_hostname
    },
    {
      name  = "KONNECT_CONTROL_PLANE_ID"
      value = var.konnect_control_plane_id
    },
    {
      name  = "KNEP__RUNTIME__DRAIN_DURATION"
      value = "1s"
    },
    {
      name  = "KNEP__OBSERVABILITY__LOG_FLAGS"
      value = "info,knep=debug"
    }
  ], [
    for key, value in var.kong_env_vars : {
      name  = key
      value = value
    }
  ])
}

# Networking Module
module "networking" {
  source = "../../../modules/networking"

  name_prefix  = local.name_prefix
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr
  common_tags  = local.common_tags

  vpc_endpoint_security_group_ids = [module.security.vpc_endpoints_security_group_id]
}

# Security Module
module "security" {
  source = "../../../modules/security"

  name_prefix                = local.name_prefix
  vpc_id                     = module.networking.vpc_id
  vpc_cidr                   = var.vpc_cidr
  common_tags                = local.common_tags
  
  allowed_cidr_blocks        = var.allowed_cidr_blocks
  enable_admin_api           = var.enable_admin_api
  admin_allowed_cidr_blocks  = var.admin_allowed_cidr_blocks
  
  kong_proxy_port            = var.kong_proxy_port
  kong_knep_port             = var.kong_knep_port
  kong_admin_port            = var.kong_admin_port
  kong_admin_gui_port        = var.kong_admin_gui_port
}

# Kong KNEP ECS Service
module "kong_knep_service" {
  source = "../../../modules/ecs-service"

  service_name               = "${local.name_prefix}-kong-knep"
  aws_region                 = var.aws_region
  common_tags                = local.common_tags

  # ECS Configuration
  cluster_name               = "${local.name_prefix}-cluster"
  enable_container_insights  = var.enable_container_insights

  # Container Configuration
  container_name             = "kong-knep"
  container_image            = var.kong_knep_image
  container_port             = var.kong_knep_port
  cpu                        = var.kong_cpu
  memory                     = var.kong_memory
  desired_count              = var.kong_desired_count
  environment_variables      = local.kong_knep_env_vars

  # Health Check
  health_check_command       = [
    "CMD-SHELL",
    "curl -f http://localhost:${var.kong_knep_port}/status || exit 1"
  ]
  health_check_path                = var.health_check_path
  health_check_interval            = var.health_check_interval
  health_check_timeout             = var.health_check_timeout
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold

  # Networking
  vpc_id                     = module.networking.vpc_id
  ecs_subnet_ids             = module.networking.private_subnet_ids
  ecs_security_group_ids     = [module.security.ecs_security_group_id]
  assign_public_ip           = false

  # Load Balancer
  load_balancer_name         = "${local.name_prefix}-alb"
  internal_load_balancer     = false
  alb_subnet_ids             = module.networking.public_subnet_ids
  alb_security_group_ids     = [module.security.alb_security_group_id]
  ssl_certificate_arn        = var.alb_certificate_arn
  enable_deletion_protection = var.alb_enable_deletion_protection

  # IAM
  task_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${local.name_prefix}-kong-knep:*"
      }
    ]
  })

  # Logging
  log_retention_days = var.log_retention_days
}
