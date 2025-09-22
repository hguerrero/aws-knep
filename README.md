# Kong Native Event Proxy on AWS ECS - Service-Based Architecture

This repository contains Terraform configurations to deploy Kong Native Event Proxy (KNEP) on AWS ECS using a service-based architecture. It supports multiple environments (dev, staging, prod) with reusable modules and environment-specific configurations.

## Repository Structure

```
aws-knep/
├── modules/                    # Reusable Terraform modules
│   ├── networking/            # VPC, subnets, routing
│   ├── security/              # Security groups
│   └── ecs-service/           # Generic ECS service with ALB
├── services/
│   └── kong-knep/             # Kong Native Event Proxy service
│       ├── dev/               # Development environment
│       ├── staging/           # Staging environment
│       └── prod/              # Production environment
├── scripts/                   # Deployment and utility scripts
├── docs/                      # Additional documentation
└── README.md
```

## Architecture

- **Modular Design**: Reusable modules for networking, security, and ECS services
- **Multi-Environment**: Separate configurations for dev, staging, and production
- **VPC**: Multi-AZ setup with public, private, and database subnets
- **ECS**: Fargate-based deployment for Kong Native Event Proxy
- **Load Balancer**: Application Load Balancer with health checks
- **Auto Scaling**: CPU and memory-based scaling policies
- **Security**: Security groups with least-privilege access
- **Monitoring**: CloudWatch logs and metrics
- **VPC Endpoints**: For secure access to AWS services

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. Appropriate AWS IAM permissions for creating ECS, VPC, and related resources

## Quick Start

1. **Clone and navigate to environment**:
   ```bash
   git clone <repository>
   cd aws-knep
   ```

2. **Choose your environment and configure**:
   ```bash
   # For development
   cd services/kong-knep/dev
   cp terraform.tfvars.example terraform.tfvars

   # Edit with your Konnect credentials and settings
   vim terraform.tfvars
   ```

3. **Deploy using the script**:
   ```bash
   # From the repository root
   ./scripts/deploy.sh dev deploy
   ```

4. **Or deploy manually**:
   ```bash
   cd services/kong-knep/dev
   terraform init
   terraform plan
   terraform apply
   ```

5. **Access Kong Native Event Proxy**:
   ```bash
   terraform output kong_knep_url
   ```

## Configuration

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `us-west-2` |
| `project_name` | Name prefix for resources | `kong-ecs` |
| `environment` | Environment name | `dev` |
| `kong_knep_image` | Kong Native Event Proxy Docker image | `kong/kong-native-event-proxy:latest` |
| `kong_knep_port` | Kong Native Event Proxy port | `8080` |
| `konnect_api_token` | Konnect API token (sensitive) | Required |
| `konnect_api_hostname` | Konnect API hostname | `us.api.konghq.com` |
| `konnect_control_plane_id` | Konnect Control Plane ID (sensitive) | Required |
| `kong_cpu` | CPU units (1024 = 1 vCPU) | `512` |
| `kong_memory` | Memory in MB | `1024` |
| `kong_desired_count` | Desired number of tasks | `2` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |

### SSL/TLS Configuration

To enable HTTPS:
1. Create or import an SSL certificate in AWS Certificate Manager
2. Set `alb_certificate_arn` to the certificate ARN
3. HTTP traffic will automatically redirect to HTTPS

### Konnect Configuration

The Kong Native Event Proxy requires connection to Kong Konnect. Configure these required variables:

```hcl
konnect_api_token         = "your-konnect-api-token"
konnect_api_hostname      = "us.api.konghq.com"  # or your region's hostname
konnect_control_plane_id  = "your-control-plane-id"
```

**Getting Konnect Credentials:**
1. Log into your Kong Konnect account
2. Navigate to **Runtime Manager** → **Control Planes**
3. Select your control plane to get the Control Plane ID
4. Go to **Personal Access Tokens** to create an API token

### Environment Variables

Customize Kong Native Event Proxy behavior using the `kong_env_vars` variable:

```hcl
kong_env_vars = {
  # Add any additional environment variables for Kong Native Event Proxy
  # The main Konnect variables are configured separately above
}
```

## Monitoring and Logging

### CloudWatch Logs
- Log group: `/ecs/{project_name}-{environment}-kong-knep`
- Retention: Configurable via `log_retention_days`

### CloudWatch Metrics
- CPU and Memory utilization alarms
- ECS service metrics
- Application Load Balancer metrics

### Useful Commands

```bash
# View ECS service status
aws ecs describe-services --cluster <cluster-name> --services <service-name>

# View running tasks
aws ecs list-tasks --cluster <cluster-name> --service-name <service-name>

# View logs
aws logs describe-log-streams --log-group-name <log-group-name>

# Scale service manually
aws ecs update-service --cluster <cluster-name> --service <service-name> --desired-count <count>
```

## Auto Scaling

The deployment includes auto-scaling policies based on:
- **CPU Utilization**: Target 70% (configurable)
- **Memory Utilization**: Target 80% (configurable)

Scaling parameters:
- Min capacity: 1 task
- Max capacity: 10 tasks
- Scale up/down cooldown: 300 seconds

## Security

### Network Security
- Private subnets for ECS tasks
- Public subnets for load balancer only
- Security groups with minimal required access
- VPC endpoints for AWS service access

### IAM Roles
- **Task Execution Role**: For ECS to pull images and write logs
- **Task Role**: For application-level AWS service access

### Security Groups
- **ALB Security Group**: HTTP/HTTPS access from specified CIDR blocks
- **ECS Security Group**: Access from ALB only
- **VPC Endpoints Security Group**: HTTPS access from VPC

## Troubleshooting

### Common Issues

1. **Tasks not starting**:
   - Check CloudWatch logs for container errors
   - Verify image availability and permissions
   - Check security group rules

2. **Health check failures**:
   - Verify Kong Native Event Proxy is listening on the correct port
   - Check health check path configuration
   - Review container logs

3. **Load balancer not accessible**:
   - Verify security group rules
   - Check subnet routing
   - Confirm DNS resolution

### Debugging Commands

```bash
# Check ECS service events
aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events'

# View task definition
aws ecs describe-task-definition --task-definition <task-definition-arn>

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources including data. Make sure to backup any important data before destroying.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
