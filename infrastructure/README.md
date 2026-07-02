# infrastructure/

**Step 1 of 2** — deploy this root before `gateway/`.

Creates the shared AWS foundation that the gateway layer reads from SSM Parameter Store.

## What this deploys

| Resource | Details |
|----------|---------|
| VPC | 3-tier subnets (public / private-app / private-data) across 2 AZs |
| NAT Gateways | One per AZ for private-subnet egress |
| VPC Endpoints | ECR, Secrets Manager, SSM, CloudWatch Logs (interface endpoints) |
| Security groups | `sg-nlb` → `sg-keg` → `sg-msk` DMZ chain, ports 9092–9094 |
| MSK cluster | Kafka 4.0.x.kraft, SASL/SCRAM SHA-512, 2× `kafka.m5.large` |
| KMS key | CMK for MSK SCRAM secret encryption (required by MSK 4.x) |
| Secrets Manager | SCRAM credentials with `AmazonMSK_` prefix, CMK-encrypted |
| SSM Parameters | All outputs published under `/<project_name>/...` |

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit: set aws_region and project_name
terraform init
terraform apply
```

## Key variables

| Variable | Default | Notes |
|----------|---------|-------|
| `project_name` | `kong-event-gw` | Must match `gateway/terraform.tfvars` |
| `aws_region` | `us-east-1` | |
| `msk_kafka_version` | `4.0.x.kraft` | Do not change — t3.small and older versions unsupported |
| `msk_instance_type` | `kafka.m5.large` | Minimum for MSK 4.x |
| `msk_number_of_broker_nodes` | `2` | Must be a multiple of AZ count (2) |
| `kafka_port_range_end` | `9094` | Must match `gateway/terraform.tfvars` |
| `allowed_cidr_blocks` | `["0.0.0.0/0"]` | Restrict for production |

## SSM outputs consumed by gateway/

| SSM path | Value |
|----------|-------|
| `/<project_name>/networking/vpc_id` | VPC ID |
| `/<project_name>/networking/private_subnet_ids` | Comma-separated private app subnet IDs |
| `/<project_name>/networking/public_subnet_ids` | Comma-separated public subnet IDs |
| `/<project_name>/security/keg_security_group_id` | `sg-keg` ID |
| `/<project_name>/security/nlb_security_group_id` | `sg-nlb` ID |
| `/<project_name>/msk/cluster_arn` | MSK cluster ARN |
| `/<project_name>/msk/bootstrap_brokers_sasl_scram` | SASL/SCRAM bootstrap string |
| `/<project_name>/msk/default_scram_secret_arn` | Secrets Manager ARN for SCRAM credentials |
