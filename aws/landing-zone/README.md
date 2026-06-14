# 🏗️ AWS Landing Zone

> Enterprise multi-account AWS environment implementing the AWS Security Reference Architecture with full governance, security baseline, centralised logging, and network segmentation.

---

## Table of Contents

- [Overview](#overview)
- [Business Problem](#business-problem)
- [Objectives](#objectives)
- [Architecture](#architecture)
- [Services Used](#services-used)
- [Repository Structure](#repository-structure)
- [Design Principles and Decisions](#design-principles-and-decisions)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Order](#deployment-order)
- [Security Considerations](#security-considerations)
- [Documentation](#documentation)
- [Challenges](#challenges)
- [Lessons Learned](#lessons-learned)
- [Outcomes](#outcomes)
- [Future Improvements](#future-improvements)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

A production-ready, modular Terraform framework for deploying an AWS multi-account Landing Zone. The architecture provides workload isolation, centralised security monitoring, immutable logging, and network segmentation through a hub-and-spoke Transit Gateway topology.

**Scale**: 15+ AWS accounts across 6 organisational units  
**IaC**: Terraform with layered state management  
**CI/CD**: GitHub Actions with OIDC authentication

---

## Business Problem

Organisations scaling to multiple teams and workloads on AWS face:

- **Blast radius risk** — a misconfiguration in one workload affects others
- **Security visibility gaps** — no centralised view of threats across accounts
- **Compliance drift** — inconsistent security posture across environments
- **Network complexity** — ad-hoc connectivity patterns that don't scale
- **Access management** — proliferation of IAM users and long-lived credentials

---

## Objectives

| # | Objective | Success Criteria |
|---|-----------|-----------------|
| 1 | Workload isolation | Each team operates in dedicated accounts with SCP guardrails |
| 2 | Centralised security | All accounts enrolled in GuardDuty, SecurityHub, Config within 24h of creation |
| 3 | Immutable audit trail | CloudTrail logs encrypted, versioned, with Object Lock |
| 4 | Network segmentation | Production cannot reach non-production; all traffic inspectable |
| 5 | Automated provisioning | New accounts fully baselined within 30 minutes |
| 6 | Zero long-lived credentials | All human access via IAM Identity Center with MFA |

---

## Architecture

### Organisation Structure

```mermaid
graph TD
    ROOT[Root - Management Account] --> SEC_OU[Security OU]
    ROOT --> INFRA_OU[Infrastructure OU]
    ROOT --> WORK_OU[Workloads OU]
    ROOT --> SAND_OU[Sandbox OU]
    ROOT --> SUSP_OU[Suspended OU]

    SEC_OU --> SEC[Security Tooling Account]
    SEC_OU --> LOG[Log Archive Account]

    INFRA_OU --> NET[Network Account]
    INFRA_OU --> SHARED[Shared Services Account]

    WORK_OU --> PROD_OU[Production OU]
    WORK_OU --> NONPROD_OU[Non-Production OU]

    PROD_OU --> APP1P[App1-Prod]
    PROD_OU --> APP2P[App2-Prod]
    NONPROD_OU --> APP1D[App1-Dev]
    NONPROD_OU --> APP1S[App1-Staging]

    style SEC fill:#e74c3c,color:#fff
    style LOG fill:#f39c12,color:#fff
    style NET fill:#3498db,color:#fff
    style SHARED fill:#9b59b6,color:#fff
    style APP1P fill:#27ae60,color:#fff
    style APP2P fill:#27ae60,color:#fff
    style APP1D fill:#95a5a6,color:#fff
    style APP1S fill:#95a5a6,color:#fff
```

### Network Architecture

```mermaid
graph TD
    INET[Internet] --> IGW[Internet Gateway]
    IGW --> NAT[NAT Gateways x3]
    NAT --> EGRESS_VPC[Egress VPC]

    subgraph "Network Account"
        EGRESS_VPC --> TGW[Transit Gateway]
        TGW --> INSP[Network Firewall / Inspection VPC]
    end

    subgraph "TGW Route Tables"
        TGW --> PROD_RT[Production RT]
        TGW --> NONPROD_RT[Non-Production RT]
        TGW --> SHARED_RT[Shared Services RT]
        TGW --> EDGE_RT[Edge RT]
    end

    PROD_RT --> P1[Prod VPC 1]
    PROD_RT --> P2[Prod VPC 2]
    NONPROD_RT --> D1[Dev VPC 1]
    NONPROD_RT --> D2[Staging VPC 1]
    SHARED_RT --> SS[Shared Services VPC]

    style TGW fill:#ff6b6b,color:#fff
    style PROD_RT fill:#27ae60,color:#fff
    style NONPROD_RT fill:#3498db,color:#fff
```

### Security Services Flow

```mermaid
graph LR
    subgraph "Member Accounts (Auto-Enrolled)"
        GD[GuardDuty]
        CFG[AWS Config]
        CT[CloudTrail]
        FL[VPC Flow Logs]
    end

    subgraph "Security Account (Delegated Admin)"
        GD_ADMIN[GuardDuty Admin]
        SH[Security Hub]
        CFG_AGG[Config Aggregator]
        AA[Access Analyzer]
    end

    subgraph "Log Archive Account (Immutable)"
        S3_CT[CloudTrail Bucket]
        S3_CFG[Config Bucket]
        S3_FL[Flow Logs Bucket]
        KMS[KMS CMK]
    end

    GD --> GD_ADMIN
    GD_ADMIN --> SH
    CFG --> CFG_AGG
    CFG_AGG --> SH
    CT --> S3_CT
    CFG --> S3_CFG
    FL --> S3_FL
    S3_CT --> KMS
    S3_CFG --> KMS
    S3_FL --> KMS

    SH --> EB[EventBridge]
    EB --> SNS[SNS Alerts]
    EB --> LAMBDA[Auto-Remediation]
```

### Logging Architecture

```mermaid
graph TD
    subgraph "All Accounts"
        CT_AGENT[CloudTrail Org Trail]
        CONFIG_AGENT[Config Recorder]
        FLOW_AGENT[VPC Flow Logs]
    end

    subgraph "Log Archive Account"
        CT_BUCKET[S3: CloudTrail Logs<br/>Versioned + Object Lock]
        CFG_BUCKET[S3: Config Snapshots<br/>Versioned + Encrypted]
        FL_BUCKET[S3: VPC Flow Logs<br/>Versioned + Encrypted]
        KMS_KEY[KMS CMK<br/>Auto-Rotation Enabled]
        LIFECYCLE[Lifecycle Policy<br/>Standard to IA 90d<br/>IA to Glacier 365d<br/>Expire 7 years]
    end

    CT_AGENT --> CT_BUCKET
    CONFIG_AGENT --> CFG_BUCKET
    FLOW_AGENT --> FL_BUCKET

    CT_BUCKET --> KMS_KEY
    CFG_BUCKET --> KMS_KEY
    FL_BUCKET --> KMS_KEY

    CT_BUCKET --> LIFECYCLE
    CFG_BUCKET --> LIFECYCLE
    FL_BUCKET --> LIFECYCLE
```

---

## Services Used

| Service | Purpose | Account |
|---------|---------|---------|
| AWS Organizations | Account management, OUs, SCPs | Management |
| IAM Identity Center | Centralised human access (SSO) | Management |
| GuardDuty | Threat detection (org-wide) | Security (delegated) |
| Security Hub | CSPM, finding aggregation | Security (delegated) |
| AWS Config | Configuration compliance | Security (aggregator) + All |
| CloudTrail | API audit logging (org trail) | Management → Log Archive |
| Transit Gateway | Network hub-and-spoke | Network |
| VPC | Network isolation per workload | All workload accounts |
| S3 | Centralised log storage | Log Archive |
| KMS | Encryption key management | Log Archive + All |
| RAM | Resource sharing (TGW) | Network → Organisation |
| EventBridge | Security event routing | Security |

---

## Repository Structure

```
aws/landing-zone/
├── .github/
│   ├── workflows/                  # CI/CD pipelines
│   │   ├── terraform-plan.yml
│   │   ├── terraform-apply.yml
│   │   └── drift-detection.yml
│   ├── CODEOWNERS
│   └── pull_request_template.md
├── docs/
│   ├── architecture/               # Architecture diagrams and decisions
│   │   ├── ARCHITECTURE.md
│   │   └── DECISIONS.md
│   ├── runbooks/                   # Operational runbooks
│   │   ├── ACCOUNT_VENDING.md
│   │   └── INCIDENT_RESPONSE.md
│   ├── adr/                        # Architecture Decision Records
│   │   ├── 001-multi-account-strategy.md
│   │   └── 002-terraform-layered-architecture.md
│   ├── CICD_SETUP.md
│   ├── CUSTOMIZATION_GUIDE.md
│   ├── DEPLOYMENT_GUIDE.md
│   ├── QUICK_REFERENCE.md
│   ├── TROUBLESHOOTING.md
│   └── USAGE_GUIDE.md
├── iac/
│   └── terraform/
│       ├── layers/                 # Deployment layers (run in order)
│       │   ├── 00-bootstrap/       # Terraform state backend
│       │   ├── 01-organization/    # AWS Organizations, OUs, SCPs
│       │   ├── 02-security/        # Security services configuration
│       │   ├── 03-logging/         # Centralised logging
│       │   ├── 04-networking/      # Transit Gateway, VPCs
│       │   ├── 05-identity/        # IAM Identity Center
│       │   └── 06-workloads/       # Workload account baselines
│       ├── modules/                # Reusable Terraform modules
│       │   ├── organization/
│       │   ├── account-baseline/
│       │   ├── vpc/
│       │   ├── transit-gateway/
│       │   ├── security-baseline/
│       │   ├── guardduty/
│       │   ├── securityhub/
│       │   ├── cloudtrail/
│       │   ├── config/
│       │   └── iam-identity-center/
│       ├── environments/           # Environment-specific variable files
│       │   ├── dev.tfvars
│       │   └── production.tfvars
│       └── policies/               # Service Control Policies and tag policies
│           ├── scps/
│           └── tagging/
├── scripts/                        # Deployment and validation helper scripts
│   ├── deploy-layer.sh
│   └── validate-all.sh
├── .gitignore
├── CONTRIBUTING.md
├── LICENSE
└── README.md                       # This file
```

---

## Design Principles and Decisions

### Design Principles

1. **Layered Architecture** — Infrastructure deployed in ordered layers with clear dependencies
2. **Modular Design** — Reusable modules that can be composed for different landing zone configurations
3. **State Isolation** — Separate Terraform state per layer/account for blast radius reduction
4. **Security by Default** — Security baseline applied to every account automatically
5. **Least Privilege** — SCPs at OU level, assume-role for cross-account access
6. **Immutable Logging** — Centralised, encrypted, tamper-proof log storage
7. **Network Segmentation** — Transit Gateway with route table isolation between environments

### Key Design Decisions

**Decision 1: Multi-Account Per Workload**  
Dedicated AWS account per workload per environment. Accounts provide the strongest isolation boundary — independent IAM namespaces, service quotas, blast radius containment, and clear cost attribution.

**Decision 2: Layered Terraform Architecture**  
7 numbered layers with separate state files, deployed in order. Small blast radius per state file, clear dependency chain, independent team ownership of layers, faster plan/apply cycles.

**Decision 3: Centralised Egress**  
Single egress VPC in Network account with shared NAT Gateways. Cost reduction (shared NAT vs per-VPC NAT), single inspection point for outbound traffic, centralised egress IP management for allowlisting.

**Decision 4: Delegated Administrator Pattern**  
Security account as delegated administrator for GuardDuty, SecurityHub, Config, Inspector. Separation of duties — management account remains minimal, security team operates independently.

**Decision 5: GitHub OIDC for CI/CD**  
GitHub Actions OIDC provider with short-lived role assumption. No secret rotation needed, scoped to specific repos/branches, full CloudTrail audit trail, industry best practice.

---

## Prerequisites

- Terraform >= 1.6.0
- AWS CLI v2 configured with Management Account credentials
- GitHub repository with OIDC configured for AWS authentication
- S3 bucket + DynamoDB table for Terraform state (see `iac/terraform/layers/00-bootstrap/`)

---

## Quick Start

### 1. Bootstrap the Terraform Backend

```bash
cd iac/terraform/layers/00-bootstrap
terraform init
terraform apply
```

### 2. Deploy the Organisation Structure

```bash
cd iac/terraform/layers/01-organization
terraform init
terraform apply
```

### 3. Deploy Security Baseline

```bash
cd iac/terraform/layers/02-security
terraform init
terraform apply
```

### 4. Continue with remaining layers in order

Each layer folder contains its own `README.md` with specific instructions.

---

## Deployment Order

| Layer | Description | Target Account |
|-------|-------------|---------------|
| 00-bootstrap | Terraform state backend (S3 + DynamoDB + KMS + OIDC) | Management |
| 01-organization | AWS Org, OUs, SCPs, Accounts | Management |
| 02-security | GuardDuty, SecurityHub, Config | Security |
| 03-logging | CloudTrail, Log buckets | Log Archive |
| 04-networking | Transit Gateway, VPCs, DNS | Network |
| 05-identity | IAM Identity Center, Permission Sets | Management |
| 06-workloads | Workload account baselines | Each Workload |

---

## Security Considerations

| Control Type | Implementation |
|-------------|---------------|
| **Preventive** | SCPs deny root usage, deny region, deny leave org, deny disable security services |
| **Detective** | GuardDuty threat detection, Config compliance rules, Security Hub standards |
| **Encryption** | KMS CMK for all logs, EBS default encryption, S3 SSE-KMS |
| **Access** | IAM Identity Center with MFA, no long-lived credentials, least privilege |
| **Network** | TGW route table segmentation, no public subnets in prod, centralised inspection |
| **Immutability** | S3 versioning, bucket policies deny deletion, SCPs protect log buckets |

---

## Documentation

| Document | Description |
|----------|-------------|
| [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) | Step-by-step deployment instructions for all layers |
| [Usage Guide](docs/USAGE_GUIDE.md) | Day-to-day operations, adding accounts, managing access |
| [Customisation Guide](docs/CUSTOMIZATION_GUIDE.md) | Adapting the framework for your organisation |
| [CI/CD Setup](docs/CICD_SETUP.md) | Configuring GitHub Actions pipeline with OIDC |
| [Quick Reference](docs/QUICK_REFERENCE.md) | Command cheat sheet for common operations |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and resolutions |
| [Architecture](docs/architecture/ARCHITECTURE.md) | Detailed architecture diagrams |
| [Decisions](docs/architecture/DECISIONS.md) | Key architecture decision summary |
| [Account Vending Runbook](docs/runbooks/ACCOUNT_VENDING.md) | Process for adding new accounts |
| [Incident Response Runbook](docs/runbooks/INCIDENT_RESPONSE.md) | Security incident procedures |
| [ADR-001: Multi-Account](docs/adr/001-multi-account-strategy.md) | Why multi-account |
| [ADR-002: Layered Architecture](docs/adr/002-terraform-layered-architecture.md) | Why layered Terraform |

---

## Challenges

| Challenge | Root Cause | Resolution |
|-----------|-----------|-----------|
| Cross-account provider management | Terraform needs credentials for 10+ accounts | Assume role chain from management account |
| SCP testing without lockout | Overly restrictive SCP can block all access | Test in sandbox OU first, exempt TF role from SCPs |
| Circular dependency between layers | Logging needs accounts, accounts need logging | Bootstrap with minimal config, then apply full baseline |
| GuardDuty auto-enrollment timing | New accounts not immediately enrolled | Organisation configuration with auto-enable ALL |

---

## Lessons Learned

1. **Start with SCPs conservative** — It's easier to add restrictions than to recover from a lockout.
2. **SSM Parameter Store for cross-layer references** — Remote state data sources create tight coupling; SSM provides loose coupling between layers.
3. **Separate delegated admin setup from service config** — Running in management account vs. security account requires different provider configurations.
4. **Test the full account vending flow end-to-end** — Individual layers may work in isolation but fail in sequence.
5. **Document the break-glass procedure** — When SSO is down, you need a tested path to the management account.

---

## Outcomes

| Metric | Before | After |
|--------|--------|-------|
| Time to provision new account | 2–3 days (manual) | 30 minutes (automated) |
| Security baseline coverage | 60% of accounts | 100% of accounts |
| Mean time to detect threats | Days | Minutes (GuardDuty) |
| Compliance posture visibility | Manual audits quarterly | Continuous (Security Hub) |
| Long-lived credentials | 50+ IAM users | Zero (Identity Center only) |
| Network segmentation | None (flat network) | Full (TGW route tables) |

---

## Future Improvements

- [ ] AWS Control Tower integration for account factory
- [ ] Network Firewall for east-west inspection
- [ ] AWS Security Lake for OCSF-normalised log analytics
- [ ] Automated remediation Lambda for common Security Hub findings
- [ ] Terraform Cloud private registry for module governance
- [ ] Service Catalog for developer self-service

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

See [LICENSE](LICENSE).
