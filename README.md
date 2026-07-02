# Kafka in a DMZ: Protecting AWS MSK with Kong Event Gateway

Terraform infrastructure for deploying [Kong Event Gateway](https://docs.konghq.com/event-gateway/) on AWS ECS Fargate, implementing the **Kafka DMZ pattern** for Amazon MSK.

This repository is the companion code for the blog post *"Kafka in a DMZ: Protecting AWS MSK with Kong Event Gateway."*

---

## The Problem

Amazon MSK brokers live in private subnets by default. When you need to expose Kafka access beyond your VPC boundary — to other teams, partner systems, or services in other VPCs — the common options (MSK public access, VPC peering) either expose your broker topology, add per-broker certificate overhead, or provide no enforcement point for authentication and access control.

## The Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  UNTRUSTED (internet / partner VPCs)                                 │
│  Producers / Consumers — standard Kafka clients (OAuth bearer)       │
└────────────────────────────┬─────────────────────────────────────────┘
                             │  TCP 9092–9094 (port-mapping range)
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PUBLIC SUBNETS                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Network Load Balancer  (sg-nlb)                                │ │
│  │  TCP 9092–9094 — one listener per port                          │ │
│  │  9092: bootstrap; 9093–9094: per-broker (port-mapping strategy) │ │
│  └──────────────────────────────┬──────────────────────────────────┘ │
└─────────────────────────────────┼────────────────────────────────────┘
                                  │  TCP 9092–9094 → sg-keg only
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PRIVATE APP SUBNETS                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Kong Event Gateway  (ECS Fargate, sg-keg)                      │ │
│  │  - Virtual Clusters per team / partner                          │ │
│  │  - OAuth bearer authentication (Kong Identity)                  │ │
│  │  - ACL policies (read-only by default)                          │ │
│  │  - Konnect control plane sync (TCP 443 outbound)                │ │
│  └──────────────────────────────┬──────────────────────────────────┘ │
└─────────────────────────────────┼────────────────────────────────────┘
                                  │  SASL/SCRAM over TLS → sg-msk only
                                  │  TCP 9096 (gateway service account)
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PRIVATE DATA SUBNETS                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Amazon MSK 4.x  (sg-msk)                                       │ │
│  │  No public access. Brokers unreachable except from sg-keg.      │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**One controlled crossing point, not a porous boundary.** Kafka clients never see MSK broker addresses. All authentication, authorization, and policy enforcement happen at the gateway.

---

## Port-Mapping Strategy

KEG uses the **port-mapping strategy** to route broker connections: the gateway listens on a range of ports (9092–9094) and assigns one port per MSK broker. Clients bootstrap on port 9092, then connect to broker-specific ports (9093, 9094) for produce/consume. The NLB has one listener and one target group per port in the range; security groups allow the full range end-to-end.

| Port | Role |
|------|------|
| 9092 | Bootstrap — clients connect here first |
| 9093 | Broker 1 advertised port |
| 9094 | Broker 2 advertised port |

The range is controlled by `kafka_client_port` (start) and `kafka_port_range_end` in `gateway/terraform.tfvars`. Add more ports if you scale MSK beyond 2 brokers.

---

## Security Group Chain

| SG | Lives in | Inbound | Outbound |
|----|----------|---------|----------|
| `sg-nlb` | Public subnets | TCP 9092–9094 from `0.0.0.0/0` (or partner CIDRs) | TCP 9092–9094 → `sg-keg` only |
| `sg-keg` | Private app subnets | TCP 9092–9094 from `sg-nlb` only | TCP 9096 → `sg-msk`; TCP 443 → Konnect |
| `sg-msk` | Private data subnets | TCP 9096 from `sg-keg` only | VPC-internal only |

`sg-msk` has **no inbound rule from the internet, the NLB, or any other subnet tier**. This is the critical DMZ property.

---

## Repository Structure

```
kong-event-gw-aws/
├── modules/
│   ├── networking/     # VPC, three-tier subnets, NAT gateways, VPC endpoints
│   ├── security/       # DMZ security groups: sg-nlb, sg-keg, sg-msk
│   ├── ecs-service/    # ECS Fargate service + NLB (one listener per Kafka port)
│   └── msk/            # MSK cluster (SASL/SCRAM, KRaft, private subnets only)
├── infrastructure/     # Step 1: VPC + security groups + MSK cluster
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── gateway/            # Step 2: Konnect control plane + ECS + NLB
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── autoscaling.tf
│   └── terraform.tfvars.example
├── .kafkactl.yml       # kafkactl contexts for anonymous and OAuth access
├── get-token.sh        # Fetches OAuth token from Kong Identity for kafkactl
├── scripts/
│   └── deploy.sh       # Deploy / destroy helper
└── docs/
    └── DEPLOYMENT_GUIDE.md
```

---

## Prerequisites

- AWS CLI configured with appropriate credentials and permissions
- Terraform >= 1.0
- A [Kong Konnect](https://cloud.konghq.com) account (free trial available)
- A Personal Access Token from Konnect → Settings → Personal Access Tokens

---

## Quick Start

### Step 1 — Deploy shared infrastructure (VPC, security groups, MSK)

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set your AWS region
terraform init
terraform apply
```

This creates the VPC, three subnet tiers, the DMZ security group chain, and the MSK cluster (Kafka 4.0, KRaft mode, SASL/SCRAM). All outputs are written to SSM Parameter Store; the gateway reads them automatically in Step 2.

### Step 2 — Deploy Kong Event Gateway

```bash
cd gateway
cp terraform.tfvars.example terraform.tfvars
# Required: set konnect_token and kafka_advertised_host (NLB DNS name)
terraform init
terraform apply
```

This creates:
- The **Konnect Event Gateway control plane** (via the `kong/konnect` Terraform provider)
- The **Kong Identity auth server** with an OAuth client for Kafka client authentication
- The mTLS **data plane certificate** (generated by Terraform, stored in Secrets Manager)
- The **ECS Fargate service** running `kong/kong-event-gateway:latest`
- The **Network Load Balancer** with TCP listeners on ports 9092–9094
- A **Virtual Cluster** with OAuth bearer authentication and a read-only ACL policy

Or run both steps at once:

```bash
./scripts/deploy.sh deploy
```

### Step 3 — Get the bootstrap endpoint

```bash
cd gateway && terraform output kafka_bootstrap_endpoint
# e.g. kong-event-gw-nlb-abc123.elb.us-east-1.amazonaws.com:9092
```

Set this as `kafka_advertised_host` in `gateway/terraform.tfvars`, then re-run `terraform apply` in `gateway/` so the Konnect listener policy advertises the correct address to Kafka clients.

### Step 4 — Connect with kafkactl

The repo includes `.kafkactl.yml` and `get-token.sh` for quick testing.

```bash
# Install kafkactl: https://github.com/deviceinsight/kafkactl

# Edit .kafkactl.yml — replace <NLB_DNS_NAME> with the value from Step 3
# Get OAuth credentials:
cd gateway
terraform output client_id
terraform output -raw client_secret

# List topics (OAuth context)
kafkactl get topics

# Anonymous access (no auth — only works if virtual cluster allows it)
kafkactl --context anonymous get topics
```

`get-token.sh` reads `client_id`, `client_secret`, and `token_endpoint` from Terraform outputs automatically. You can also set them as environment variables to skip the Terraform lookup:

```bash
export CLIENT_ID=...
export CLIENT_SECRET=...
export TOKEN_ENDPOINT=...
./get-token.sh kafka
```

---

## Kong Identity (OAuth)

The `gateway/` root creates a **Kong Identity auth server** that issues short-lived OAuth tokens for Kafka clients. Tokens are validated by the gateway — MSK never sees client credentials.

| Resource | Purpose |
|----------|---------|
| `konnect_identity_auth_server` | Issuer / JWKS endpoint |
| `konnect_identity_auth_server_scope` | `kafka` scope that clients must request |
| `konnect_identity_auth_server_client` | Machine-to-machine client (client_credentials flow) |

Get the token endpoint: `terraform output token_endpoint`

---

## Virtual Cluster ACL

The `internal` Virtual Cluster ships with a **read-only ACL** that allows any authenticated user to:

| Resource | Operations |
|----------|-----------|
| topic | `describe`, `read` |
| group (consumer groups) | `describe`, `read` |
| cluster | `describe`, `describe_configs` |

Write/produce access and topic management are explicitly not granted. Add a second `konnect_event_gateway_cluster_policy_acls` resource in `gateway/main.tf` with a more specific `condition` expression to grant elevated permissions to individual clients.

---

## Why NLB (not ALB)?

An Application Load Balancer is HTTP/HTTPS only — it cannot proxy the Kafka binary protocol over TCP. The Network Load Balancer operates at Layer 4 and passes TCP connections directly to the gateway.

---

## Why a gateway service account for MSK?

The gateway connects to MSK as a single SCRAM service account. All Kafka client identities — OAuth tokens — are managed at the Virtual Cluster layer. MSK sees only one identity; per-team isolation is enforced by the gateway, not by MSK ACLs. This means:

- Adding or revoking a partner's access is one Konnect policy change
- You never distribute MSK SCRAM credentials to application teams
- Broker topology is never exposed outside the VPC

---

## Terraform Provider Versions

| Provider | Version |
|----------|---------|
| `hashicorp/aws` | `~> 5.0` |
| `kong/konnect` | `~> 3.0` |
| `hashicorp/tls` | `~> 4.0` |

---

## Sizing Reference

| Use case | Gateway CPU/Memory | Desired count | MSK brokers | MSK instance |
|----------|--------------------|---------------|-------------|--------------|
| Demo / dev | 256 / 512 MB | 1 | 2 | `kafka.m5.large` |
| Production | 1024 / 2048 MB | ≥ 2 | 3 | `kafka.m5.xlarge` |

MSK 4.x requires a minimum of `kafka.m5.large` — `kafka.t3.small` is not supported. Adjust `kong_cpu`, `kong_memory`, `kong_desired_count`, `msk_number_of_broker_nodes`, and `msk_instance_type` in the respective `terraform.tfvars` files.

---

## SNI-Based Virtual Cluster Routing

For multi-team deployments, set `nlb_tls_certificate_arn` to a wildcard ACM certificate (e.g. `*.kafka.acme.com`). The NLB uses TLS listeners; the gateway terminates TLS, reads the SNI hostname, and routes to the matching Virtual Cluster.

```
bootstrap.payments.kafka.acme.com:9092   → Virtual Cluster: team-payments
bootstrap.logistics.kafka.acme.com:9092  → Virtual Cluster: partner-logistics
```

---

## Deployment Checklist

- [ ] MSK public access disabled on all brokers
- [ ] MSK brokers in private data subnets only; no routes to public subnets
- [ ] `sg-msk` has no inbound rules from NLB, internet CIDRs, or any tier except `sg-keg`
- [ ] MSK SASL/SCRAM enabled; gateway service account credential in Secrets Manager
- [ ] `kafka_advertised_host` set to the NLB DNS name in `gateway/terraform.tfvars`
- [ ] Port range (`kafka_port_range_end`) matches number of MSK brokers + 1
- [ ] NLB cross-zone load balancing enabled (avoids AZ-affinity stalls)
- [ ] Gateway deployed with ≥ 2 tasks across AZs in production
- [ ] Konnect control plane reachable from gateway (outbound TCP 443 in `sg-keg`)
- [ ] Virtual Cluster ACL scoped to minimum required operations
- [ ] CloudWatch log group `/ecs/<project_name>-keg` monitored

---

## Troubleshooting

**"Broker transport failure" in kcat / kafkactl**
Almost always a wrong `kafka_advertised_host`. KEG returns this value in Kafka metadata responses — if it's `localhost` or a placeholder, clients bootstrap on 9092 but can't reach the per-broker ports (9093, 9094). Fix: set `kafka_advertised_host` to the NLB DNS name and re-apply `gateway/`.

**ECS task not healthy / slow first connection**
A new task needs ~2 minutes to become healthy (60s `startPeriod` + two passing 30s health checks). Check all three target groups:
```bash
aws elbv2 describe-target-groups \
  --load-balancer-arn $(cd gateway && terraform output -raw nlb_arn) \
  --query 'TargetGroups[*].[Port,TargetGroupArn]' --output table --region us-east-1
aws elbv2 describe-target-health --target-group-arn <arn> --region us-east-1
```

**Intermittent connection stalls**
NLB cross-zone load balancing is off by default. If the single ECS task is in AZ-B but DNS resolves to the AZ-A NLB node, connections stall. Enable it:
```bash
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn $(cd gateway && terraform output -raw nlb_arn) \
  --attributes Key=load_balancing.cross_zone.enabled,Value=true --region us-east-1
```

**AccessDeniedException on Secrets Manager at task start**
The execution role needs `secretsmanager:GetSecretValue` for the data plane cert/key secrets. This is handled automatically — if you add new secrets, pass them via the `secrets` variable in the ECS module call so the IAM policy is updated.

**MSK SCRAM secret rejected**
MSK 4.x requires SCRAM secret names to start with `AmazonMSK_` and be encrypted with a CMK (not the default AWS-managed key). Both are handled by the MSK module. If you have a leftover secret without these properties: `aws secretsmanager delete-secret --secret-id <arn> --force-delete-without-recovery`.

**Cleanup**
Destroy gateway before infrastructure (gateway reads SSM values set by infrastructure):
```bash
cd gateway && terraform destroy
cd ../infrastructure && terraform destroy
```

---

## Further Reading

- [Kong Event Gateway documentation](https://docs.konghq.com/event-gateway/)
- [Kong Konnect Terraform provider](https://registry.terraform.io/providers/Kong/konnect/latest/docs)
- [Kong Konnect free trial](https://cloud.konghq.com)
