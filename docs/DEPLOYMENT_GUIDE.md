# Kong Event Gateway Deployment Guide

## Overview

This guide covers deploying Kong Event Gateway (KEG) to AWS ECS using our service-based Terraform architecture.

## Environment Configurations

### Development (`dev/`)
- **Purpose**: Development and testing
- **Kong Event Gateway**: Minimal (256 CPU, 512 MB RAM, 1 instance)
- **MSK**: 2 brokers, kafka.t3.small, 10GB storage, KRaft mode, SCRAM-SHA-512 auth, TLS_PLAINTEXT
- **Scaling**: 1-3 instances
- **Logs**: 3-day retention
- **Security**: Open access (development only)

### Staging (`staging/`)
- **Purpose**: Pre-production testing
- **Kong Event Gateway**: Medium (512 CPU, 1024 MB RAM, 2 instances)
- **MSK**: 2 brokers, kafka.m5.large, 100GB storage, KRaft mode, SCRAM-SHA-512 auth, TLS encryption
- **Scaling**: 1-5 instances
- **Logs**: 7-day retention
- **Security**: Configurable access

### Production (`prod/`)
- **Purpose**: Production workloads
- **Kong Event Gateway**: Full (1024 CPU, 2048 MB RAM, 3 instances)
- **MSK**: 3 brokers, kafka.m5.xlarge, 1TB storage, KRaft mode, SCRAM-SHA-512 auth, full TLS encryption
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

### 1. Deploy MSK Infrastructure First

```bash
# Deploy MSK and shared networking infrastructure
./scripts/deploy-msk.sh dev deploy

# Or manually:
cd infrastructure/msk/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
terraform init
terraform apply
```

### 2. Prepare Kong Event Gateway Configuration

```bash
# Navigate to your chosen environment
cd gateway  # or staging/prod

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

### 3. Required Configuration

Update `terraform.tfvars` with your values:

```hcl
# Konnect Configuration (REQUIRED)
konnect_api_token         = "your-actual-token"
konnect_control_plane_id  = "your-actual-control-plane-id"

# Project Configuration (must match MSK infrastructure)
project_name = "keg"
environment  = "dev"  # or staging/prod
aws_region   = "us-west-2"

# Optional: SSL Certificate for HTTPS
alb_certificate_arn = "arn:aws:acm:region:account:certificate/cert-id"
```

**Note**: MSK configuration is deployed independently and shared via SSM parameters.

### KRaft Mode & SCRAM Authentication

MSK uses **KRaft mode** (Kafka Raft) with **SCRAM-SHA-512** authentication:

#### KRaft Benefits:
- **No Zookeeper**: Modern Kafka architecture without Zookeeper dependency
- **Better Performance**: Faster metadata operations and cluster startup
- **Simplified Operations**: Fewer moving parts to manage
- **Improved Scalability**: Better handling of large numbers of partitions

#### SCRAM Authentication:
- **Automatic User Creation**: A default `keg` user is created automatically
- **Secure Password Management**: Passwords are stored in AWS Secrets Manager
- **Auto-Generated Passwords**: Passwords are automatically generated if not specified
- **Non-AWS Specific**: SCRAM authentication works with any Kafka client
- **Environment Variables**: Kong Event Gateway automatically receives SCRAM credentials

### 4. Deploy Kong Event Gateway Service

#### Option A: Using Deployment Script (Recommended)
```bash
# From repository root (MSK must be deployed first)
./scripts/deploy.sh dev deploy     # Deploy Kong Event Gateway to dev
./scripts/deploy.sh staging plan   # Plan staging deployment
./scripts/deploy.sh prod deploy    # Deploy to production
```

#### Option B: Manual Deployment
```bash
# From environment directory (e.g., gateway/)
terraform init
terraform plan
terraform apply
```

### 5. Verify Deployment

```bash
# Check Kong Event Gateway service status
cd gateway  # or your environment
terraform output useful_commands

# Test the Kong Event Gateway endpoint
curl $(terraform output -raw kafka_bootstrap_endpoint)/status

# Check MSK cluster status (from MSK infrastructure)
cd ../../../infrastructure/msk/dev
terraform output msk_cluster_name
terraform output msk_bootstrap_brokers_sasl_scram
terraform output msk_default_scram_username
terraform output msk_storage_mode  # Should show "TIERED" for KRaft mode
terraform output msk_kafka_version

# Verify MSK connectivity from ECS (optional)
aws ecs execute-command \
  --cluster $(cd ../../../gateway && terraform output -raw cluster_name) \
  --task $(aws ecs list-tasks --cluster $(cd ../../../gateway && terraform output -raw cluster_name) --service-name $(cd ../../../gateway && terraform output -raw service_name) --query 'taskArns[0]' --output text) \
  --interactive \
  --command "/bin/bash"
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
  --cluster keg-dev-cluster \
  --service keg-dev-keg \
  --desired-count 3

# Permanent scaling: Update terraform.tfvars and redeploy
```

### Viewing Logs

```bash
# List log streams
aws logs describe-log-streams \
  --log-group-name /ecs/keg-dev-keg

# View recent logs
aws logs tail /ecs/keg-dev-keg --follow
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   - Check CloudWatch logs: `/ecs/keg-{env}-keg`
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
  --cluster keg-dev-cluster \
  --services keg-dev-keg

# Task details
aws ecs describe-tasks \
  --cluster keg-dev-cluster \
  --tasks $(aws ecs list-tasks \
    --cluster keg-dev-cluster \
    --service-name keg-dev-keg \
    --query 'taskArns[0]' --output text)

# Load balancer health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw nlb_target_group_arn)
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
  --alarm-name "keg-high-cpu" \
  --alarm-description "Kong Event Gateway High CPU" \
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
cd gateway
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
    key    = "keg/dev/terraform.tfstate"
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
