# Kong Native Event Proxy Deployment Guide

## Overview

This guide covers deploying Kong Native Event Proxy (KNEP) to AWS ECS using our service-based Terraform architecture.

## Environment Configurations

### Development (`dev/`)
- **Purpose**: Development and testing
- **Resources**: Minimal (256 CPU, 512 MB RAM, 1 instance)
- **Scaling**: 1-3 instances
- **Logs**: 3-day retention
- **Security**: Open access (development only)

### Staging (`staging/`)
- **Purpose**: Pre-production testing
- **Resources**: Medium (512 CPU, 1024 MB RAM, 2 instances)
- **Scaling**: 1-5 instances
- **Logs**: 7-day retention
- **Security**: Configurable access

### Production (`prod/`)
- **Purpose**: Production workloads
- **Resources**: Full (1024 CPU, 2048 MB RAM, 3 instances)
- **Scaling**: 2-10 instances
- **Logs**: 30-day retention
- **Security**: Restricted access, deletion protection enabled

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with SSO or credentials
3. **Terraform** >= 1.0 installed
4. **Kong Konnect** account with:
   - API token
   - Control plane ID

## Step-by-Step Deployment

### 1. Prepare Configuration

```bash
# Navigate to your chosen environment
cd services/kong-knep/dev  # or staging/prod

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

### 2. Required Configuration

Update `terraform.tfvars` with your values:

```hcl
# Konnect Configuration (REQUIRED)
konnect_api_token         = "your-actual-token"
konnect_control_plane_id  = "your-actual-control-plane-id"

# AWS Configuration
aws_region = "us-west-2"

# Optional: SSL Certificate for HTTPS
alb_certificate_arn = "arn:aws:acm:region:account:certificate/cert-id"
```

### 3. Deploy

#### Option A: Using Deployment Script (Recommended)
```bash
# From repository root
./scripts/deploy.sh dev deploy     # Deploy to dev
./scripts/deploy.sh staging plan   # Plan staging deployment
./scripts/deploy.sh prod deploy    # Deploy to production
```

#### Option B: Manual Deployment
```bash
# From environment directory (e.g., services/kong-knep/dev/)
terraform init
terraform plan
terraform apply
```

### 4. Verify Deployment

```bash
# Check service status
terraform output useful_commands

# Test the endpoint
curl $(terraform output -raw kong_knep_url)/status
```

## Environment Management

### Switching Environments

```bash
# Deploy to different environments
./scripts/deploy.sh dev deploy
./scripts/deploy.sh staging deploy
./scripts/deploy.sh prod deploy
```

### Scaling Services

```bash
# Manual scaling (temporary)
aws ecs update-service \
  --cluster kong-knep-dev-cluster \
  --service kong-knep-dev-kong-knep \
  --desired-count 3

# Permanent scaling: Update terraform.tfvars and redeploy
```

### Viewing Logs

```bash
# List log streams
aws logs describe-log-streams \
  --log-group-name /ecs/kong-knep-dev-kong-knep

# View recent logs
aws logs tail /ecs/kong-knep-dev-kong-knep --follow
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   - Check CloudWatch logs: `/ecs/kong-knep-{env}-kong-knep`
   - Verify Konnect credentials
   - Check security group rules

2. **Health Check Failures**
   - Verify `/status` endpoint is accessible
   - Check container port configuration
   - Review target group health

3. **Auto-scaling Issues**
   - Check CloudWatch metrics
   - Verify scaling policies
   - Review service limits

### Debugging Commands

```bash
# Service status
aws ecs describe-services \
  --cluster kong-knep-dev-cluster \
  --services kong-knep-dev-kong-knep

# Task details
aws ecs describe-tasks \
  --cluster kong-knep-dev-cluster \
  --tasks $(aws ecs list-tasks \
    --cluster kong-knep-dev-cluster \
    --service-name kong-knep-dev-kong-knep \
    --query 'taskArns[0]' --output text)

# Load balancer health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw kong_knep_target_group_arn)
```

## Security Best Practices

### Production Deployment

1. **Use SSL/TLS**: Always configure `alb_certificate_arn` for production
2. **Restrict Access**: Update `allowed_cidr_blocks` to limit access
3. **Enable Protection**: Set `alb_enable_deletion_protection = true`
4. **Secure Credentials**: Use AWS Secrets Manager or Parameter Store

### Network Security

```hcl
# Production security example
allowed_cidr_blocks = [
  "10.0.0.0/8",      # Private networks only
  "172.16.0.0/12",
  "192.168.0.0/16"
]
```

## Monitoring and Alerting

### CloudWatch Metrics

- **CPU Utilization**: ECS service CPU usage
- **Memory Utilization**: ECS service memory usage
- **Target Response Time**: ALB response times
- **Healthy Host Count**: Number of healthy targets

### Setting Up Alerts

```bash
# Example: Create CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "kong-knep-high-cpu" \
  --alarm-description "Kong KNEP High CPU" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## Cleanup

### Destroy Environment

```bash
# Using script
./scripts/deploy.sh dev destroy

# Manual
cd services/kong-knep/dev
terraform destroy
```

**Warning**: This will delete all resources. Ensure you have backups if needed.

## Advanced Configuration

### Custom Environment Variables

Add to `terraform.tfvars`:

```hcl
kong_env_vars = {
  "CUSTOM_SETTING" = "value"
  "DEBUG_MODE"     = "true"
}
```

### Backend Configuration

For team collaboration, configure remote state:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "kong-knep/dev/terraform.tfstate"
    region = "us-west-2"
  }
}
```

## Support

For issues or questions:
1. Check CloudWatch logs first
2. Review this documentation
3. Check AWS ECS service events
4. Verify Konnect connectivity
