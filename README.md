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
│  Producers / Consumers — standard Kafka clients (SASL_SSL or mTLS)  │
└────────────────────────────┬─────────────────────────────────────────┘
                             │  TCP 9092 (TLS)
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PUBLIC SUBNETS                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Network Load Balancer  (sg-nlb)                                │ │
│  │  TCP 9092 — TLS listener with wildcard ACM cert                 │ │
│  │  SNI → routes to the correct Virtual Cluster                    │ │
│  └──────────────────────────────┬──────────────────────────────────┘ │
└─────────────────────────────────┼────────────────────────────────────┘
                                  │  TCP 9092 → sg-keg only
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PRIVATE APP SUBNETS                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Kong Event Gateway 1.2  (ECS Fargate, sg-keg)                  │ │
│  │  - Virtual Clusters per team / partner                          │ │
│  │  - OAuth / mTLS / SASL authentication                           │ │
│  │  - ACL policies, schema validation, field-level encryption      │ │
│  │  - Konnect control plane sync (TCP 443 outbound)                │ │
│  └──────────────────────────────┬──────────────────────────────────┘ │
└─────────────────────────────────┼────────────────────────────────────┘
                                  │  SASL/SCRAM over TLS → sg-msk only
                                  │  TCP 9096 (gateway service account)
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PRIVATE DATA SUBNETS                                                 │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Amazon MSK  (sg-msk)                                           │ │
│  │  No public access. Brokers unreachable except from sg-keg.      │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**One controlled crossing point, not a porous boundary.** Kafka clients never see MSK broker addresses. All authentication, authorization, and policy enforcement happen at the gateway.

---

## Security Group Chain

| SG | Lives in | Inbound | Outbound |
|----|----------|---------|----------|
| `sg-nlb` | Public subnets | TCP 9092 from `0.0.0.0/0` (or partner CIDRs) | TCP 9092 → `sg-keg` only |
| `sg-keg` | Private app subnets | TCP 9092 from `sg-nlb` only | TCP 9096 → `sg-msk`; TCP 443 → Konnect |
| `sg-msk` | Private data subnets | TCP 9096 from `sg-keg` only | VPC-internal only |

`sg-msk` has **no inbound rule from the internet, the NLB, or any other subnet tier**. This is the critical DMZ property.

---

## Repository Structure

```
kong-event-gw-aws/
├── modules/
│   ├── networking/     # VPC, three-tier subnets, NAT gateways, VPC endpoints
│   ├── security/       # DMZ security groups: sg-nlb, sg-keg, sg-msk
│   ├── ecs-service/    # ECS Fargate service + Network Load Balancer (TCP)
│   └── msk/            # MSK cluster (SASL/SCRAM, private subnets only)
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

This creates the VPC, three subnet tiers, the DMZ security group chain, and the MSK cluster. All outputs are written to SSM Parameter Store; the gateway reads them automatically in Step 2.

### Step 2 — Deploy Kong Event Gateway

```bash
cd gateway
cp terraform.tfvars.example terraform.tfvars
# Set konnect_token — everything else has sensible defaults
terraform init
terraform apply
```

This creates:
- The **Konnect Event Gateway control plane** (via the `kong/konnect` Terraform provider)
- The mTLS **data plane certificate** (generated by Terraform, stored in Secrets Manager)
- The **ECS Fargate service** running Kong Event Gateway 1.2
- The **Network Load Balancer** with a TCP listener on port 9092

Or run both steps at once:

```bash
./scripts/deploy.sh deploy
```

### Step 3 — Get the bootstrap endpoint

```bash
cd gateway && terraform output kafka_bootstrap_endpoint
# e.g. kong-event-gw-nlb-abc123.elb.us-east-1.amazonaws.com:9092
```

Point a DNS wildcard record (`*.kafka.acme.com`) at the NLB. Kafka clients bootstrap to `internal.kafka.acme.com:9092` (or per Virtual Cluster when using SNI routing).

### Step 4 — Configure the gateway in Konnect

The Terraform configuration deploys a default Backend Cluster (MSK), Virtual Cluster (internal), and Listener (port 9092). Customize additional Virtual Clusters per team or partner in **Konnect → Event Gateway Control Plane**.

See the [Konnect Event Gateway documentation](https://developer.konghq.com/event-gateway) for the full configuration reference.

---

## Why NLB (not ALB)?

An Application Load Balancer is HTTP/HTTPS only — it cannot proxy the Kafka binary protocol over TCP. The Network Load Balancer operates at Layer 4 and passes TCP connections directly to the gateway, which terminates TLS and inspects SNI hostnames to route to the correct Virtual Cluster.

---

## Why a gateway service account for MSK?

The gateway connects to MSK as a single SCRAM service account (`keg-service-account`). All Kafka client identities — OAuth tokens, mTLS certificates, SASL credentials — are managed at the Virtual Cluster layer. MSK sees only one identity; per-team isolation is enforced by the gateway, not by MSK ACLs. This means:

- Adding or revoking a partner's access is one Konnect policy change
- You never distribute MSK SCRAM credentials to application teams
- Broker topology is never exposed outside the VPC

---

## Terraform Provider Versions

| Provider | Version |
|----------|---------|
| `hashicorp/aws` | `~> 5.0` |
| `kong/konnect` | `~> 3.0` |

The `kong/konnect` provider manages the Konnect control plane resource so it is version-controlled and its ID is available as a Terraform output — no manual copy-paste from the UI.

---

## Sizing Reference

| Use case | Gateway CPU/Memory | Desired count | MSK brokers | MSK instance |
|----------|--------------------|---------------|-------------|--------------|
| Demo / dev | 256 / 512 MB | 1 | 2 | kafka.t3.small |
| Production | 1024 / 2048 MB | ≥ 2 | 3 | kafka.m5.xlarge |

Adjust `kong_cpu`, `kong_memory`, `kong_desired_count`, `msk_number_of_broker_nodes`, and `msk_instance_type` in `gateway/terraform.tfvars` and `infrastructure/terraform.tfvars` respectively.

---

## SNI-Based Virtual Cluster Routing

For multi-team deployments, set `nlb_tls_certificate_arn` to a wildcard ACM certificate (e.g. `*.kafka.acme.com`). The NLB uses a TLS listener; the gateway terminates TLS, reads the SNI hostname, and routes to the matching Virtual Cluster — all on port 9092, no per-team port allocations.

```
bootstrap.payments.kafka.acme.com:9092   → Virtual Cluster: team-payments
bootstrap.logistics.kafka.acme.com:9092  → Virtual Cluster: partner-logistics
bootstrap.analytics.kafka.acme.com:9092  → Virtual Cluster: analytics-platform
```

---

## Deployment Checklist

- [ ] MSK public access disabled on all brokers
- [ ] MSK brokers in private data subnets only; no routes to public subnets
- [ ] `sg-msk` has no inbound rules from NLB, internet CIDRs, or any tier except `sg-keg`
- [ ] MSK SASL/SCRAM enabled; gateway service account credential in Secrets Manager
- [ ] NLB uses TLS listener with wildcard ACM certificate (for SNI routing)
- [ ] Wildcard DNS record (`*.kafka.acme.com`) pointing to NLB
- [ ] Gateway deployed with ≥ 2 tasks across AZs (NLB health checks configured)
- [ ] Konnect control plane reachable from gateway (outbound TCP 443 allowed in `sg-keg`)
- [ ] Virtual Clusters created per team / partner with minimum ACL scope
- [ ] CloudWatch logs and OpenTelemetry export configured

---

## Further Reading

- [Kong Event Gateway documentation](https://developer.konghq.com/event-gateway)
- [Kong Konnect Terraform provider](https://registry.terraform.io/providers/Kong/konnect/latest/docs)
- [Kong Konnect free trial](https://cloud.konghq.com)
