# gateway/

**Step 2 of 2** — deploy after `infrastructure/`.

Creates the Konnect control plane resources, the Kong Identity OAuth server, and the AWS compute layer (ECS Fargate + NLB). Reads shared infrastructure values from SSM Parameter Store.

## What this deploys

### Konnect (via `kong/konnect` provider)

| Resource | Details |
|----------|---------|
| `konnect_event_gateway` | Event Gateway control plane |
| `konnect_event_gateway_backend_cluster` | MSK backend, SASL/SCRAM SHA-512 |
| `konnect_event_gateway_virtual_cluster` | `internal` cluster, OAuth bearer auth, ACL enforced |
| `konnect_event_gateway_listener` | Ports 9092–9094, port-mapping strategy |
| `konnect_event_gateway_listener_policy_forward_to_virtual_cluster` | Routes listener → virtual cluster |
| `konnect_event_gateway_cluster_policy_acls` | Read-only ACL for all authenticated users |
| `konnect_event_gateway_data_plane_certificate` | mTLS cert for data plane ↔ control plane |
| `konnect_identity_auth_server` | OAuth issuer / JWKS endpoint |
| `konnect_identity_auth_server_scope` | `kafka` scope |
| `konnect_identity_auth_server_client` | client_credentials OAuth client |

### AWS

| Resource | Details |
|----------|---------|
| ECS cluster + Fargate service | `kong/kong-event-gateway:latest`, private app subnets |
| Network Load Balancer | Internet-facing, one TCP listener + target group per port (9092–9094) |
| Secrets Manager secrets | Data plane TLS cert and private key (CMK-encrypted) |
| CloudWatch log group | `/ecs/<project_name>-keg` |
| IAM roles | Task execution role (pulls secrets) + task role (writes logs, reads secrets at runtime) |
| Auto-scaling | Target-tracking on CPU and memory utilization |

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Required: konnect_token, kafka_advertised_host
terraform init
terraform apply
```

### First-time deploy

`kafka_advertised_host` must be the NLB DNS name. On the very first apply you won't know it yet:

1. Set `kafka_advertised_host = "placeholder"` and run `terraform apply`
2. Run `terraform output nlb_dns_name` to get the NLB address
3. Update `kafka_advertised_host` and run `terraform apply` again (only the Konnect listener policy updates)

## Key variables

| Variable | Default | Notes |
|----------|---------|-------|
| `project_name` | `kong-event-gw` | Must match `infrastructure/terraform.tfvars` |
| `konnect_token` | — | **Required** — Konnect Personal Access Token |
| `konnect_server_url` | `https://us.api.konghq.com` | Change for EU/AU regions |
| `kafka_advertised_host` | `localhost` | **Must be set** to the NLB DNS name |
| `kafka_client_port` | `9092` | Bootstrap port (start of port-mapping range) |
| `kafka_port_range_end` | `9094` | Must match `infrastructure/terraform.tfvars` |
| `kong_keg_image` | `kong/kong-event-gateway:latest` | Pin to a specific tag for production |
| `kong_keg_port` | `8080` | Internal management/health port — not exposed via NLB |
| `kong_cpu` | `256` | ECS task CPU units |
| `kong_memory` | `512` | ECS task memory in MB |
| `kong_desired_count` | `1` | Increase to ≥ 2 for production |

## Key outputs

| Output | Description |
|--------|-------------|
| `kafka_bootstrap_endpoint` | `<NLB_DNS>:9092` — client bootstrap address |
| `nlb_dns_name` | NLB DNS name for DNS records and `kafka_advertised_host` |
| `token_endpoint` | Kong Identity OAuth token endpoint |
| `client_id` | OAuth client ID |
| `client_secret` | OAuth client secret (sensitive) |
| `useful_commands` | Pre-built AWS CLI commands for common operations |

## ACL Policy

The virtual cluster ships with a **read-only ACL** (no condition — applies to all authenticated users):

```
topic:   describe, read
group:   describe, read
cluster: describe, describe_configs
```

To grant write access to specific clients, add another `konnect_event_gateway_cluster_policy_acls` resource in `main.tf` with a CEL condition:

```hcl
condition = "context.auth.principal.name == '<client_id>'"
config = {
  rules = [{
    action        = "allow"
    operations    = [{ name = "write" }, { name = "create" }]
    resource_type = "topic"
    resource_names = [{ match = "my-topic" }]
  }]
}
```
