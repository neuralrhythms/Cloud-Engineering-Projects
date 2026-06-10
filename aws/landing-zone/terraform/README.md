# AWS Landing Zone - Terraform Framework

A production-ready, modular Terraform framework for deploying an AWS multi-account Landing Zone following AWS best practices and the AWS Security Reference Architecture (SRA).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AWS Organization                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Root (Management Account)                                               │
│  │                                                                       │
│  ├── Security OU                                                         │
│  │   ├── Security Tooling Account (GuardDuty, SecurityHub, Config)       │
│  │   └── Log Archive Account (CloudTrail, VPC Flow Logs, Config Logs)    │
│  │                                                                       │
│  ├── Infrastructure OU                                                   │
│  │   ├── Network Account (Transit Gateway, DNS, Firewalls)               │
│  │   └── Shared Services Account (CI/CD, Directories)                    │
│  │                                                                       │
│  ├── Workloads OU                                                        │
│  │   ├── Production OU                                                   │
│  │   │   └── Workload Accounts (App1-Prod, App2-Prod, ...)              │
│  │   └── Non-Production OU                                               │
│  │       └── Workload Accounts (App1-Dev, App1-Staging, ...)            │
│  │                                                                       │
│  ├── Sandbox OU                                                          │
│  │   └── Developer Sandbox Accounts                                      │
│  │                                                                       │
│  └── Suspended OU                                                        │
│      └── Decommissioned Accounts                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
aws-landing-zone/
├── .github/
│   ├── workflows/             # CI/CD pipelines
│   │   ├── terraform-plan.yml
│   │   ├── terraform-apply.yml
│   │   └── drift-detection.yml
│   ├── CODEOWNERS
│   └── pull_request_template.md
├── docs/
│   ├── architecture/          # Architecture diagrams and decisions
│   ├── runbooks/              # Operational runbooks
│   └── adr/                   # Architecture Decision Records
├── modules/                   # Reusable Terraform modules
│   ├── organization/
│   ├── account-baseline/
│   ├── vpc/
│   ├── transit-gateway/
│   ├── security-baseline/
│   ├── guardduty/
│   ├── securityhub/
│   ├── cloudtrail/
│   ├── config/
│   └── iam-identity-center/
├── layers/                    # Deployment layers (ordered)
│   ├── 00-bootstrap/          # Terraform state backend
│   ├── 01-organization/       # AWS Organizations, OUs, SCPs
│   ├── 02-security/           # Security services configuration
│   ├── 03-logging/            # Centralized logging
│   ├── 04-networking/         # Transit Gateway, VPCs
│   ├── 05-identity/           # IAM Identity Center
│   └── 06-workloads/          # Workload account baselines
├── policies/
│   ├── scps/                  # Service Control Policies
│   └── tagging/               # Tag policies
├── scripts/                   # Helper scripts
└── environments/              # Environment-specific variable files
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

## Design Principles

1. **Layered Architecture** - Infrastructure deployed in ordered layers with clear dependencies
2. **Modular Design** - Reusable modules that can be composed for different landing zone configurations
3. **State Isolation** - Separate Terraform state per layer/account for blast radius reduction
4. **Security by Default** - Security baseline applied to every account automatically
5. **Least Privilege** - SCPs at OU level, assume-role for cross-account access
6. **Immutable Logging** - Centralized, encrypted, tamper-proof log storage
7. **Network Segmentation** - Transit Gateway with route table isolation between environments

## Prerequisites

- Terraform >= 1.6.0
- AWS CLI v2 configured with Management Account credentials
- GitHub repository with OIDC configured for AWS authentication
- S3 bucket + DynamoDB table for Terraform state (see `layers/00-bootstrap/`)

## Quick Start

### 1. Bootstrap the Terraform Backend

```bash
cd layers/00-bootstrap
terraform init
terraform apply
```

### 2. Deploy the Organization Structure

```bash
cd layers/01-organization
terraform init
terraform apply
```

### 3. Deploy Security Baseline

```bash
cd layers/02-security
terraform init
terraform apply
```

### 4. Continue with remaining layers in order

Each layer has its own README with specific instructions.

## Deployment Order

| Layer | Description | Target Account |
|-------|-------------|---------------|
| 00-bootstrap | Terraform state backend | Management |
| 01-organization | AWS Org, OUs, SCPs, Accounts | Management |
| 02-security | GuardDuty, SecurityHub, Config | Security |
| 03-logging | CloudTrail, Log buckets | Logging |
| 04-networking | Transit Gateway, VPCs, DNS | Network |
| 05-identity | IAM Identity Center, Permission Sets | Management |
| 06-workloads | Workload account baselines | Each Workload |

## Security Controls

- **Preventive** - Service Control Policies (SCPs) at OU level
- **Detective** - AWS Config Rules, GuardDuty, SecurityHub
- **Responsive** - EventBridge rules with automated remediation
- **Encryption** - KMS CMKs for all data at rest
- **Access** - IAM Identity Center with permission sets

## Documentation

| Document | Description |
|----------|-------------|
| [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) | Step-by-step deployment instructions for all layers |
| [Usage Guide](docs/USAGE_GUIDE.md) | Day-to-day operations, adding accounts, managing access |
| [Customization Guide](docs/CUSTOMIZATION_GUIDE.md) | Adapting the framework for your organization |
| [CI/CD Setup](docs/CICD_SETUP.md) | Configuring GitHub Actions pipeline with OIDC |
| [Quick Reference](docs/QUICK_REFERENCE.md) | Command cheat sheet for common operations |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and resolutions |
| [Architecture](docs/architecture/ARCHITECTURE.md) | Detailed architecture diagrams |
| [Decisions](docs/architecture/DECISIONS.md) | Key architecture decision summary |
| [Account Vending Runbook](docs/runbooks/ACCOUNT_VENDING.md) | Process for adding new accounts |
| [Incident Response Runbook](docs/runbooks/INCIDENT_RESPONSE.md) | Security incident procedures |
| [ADR-001: Multi-Account](docs/adr/001-multi-account-strategy.md) | Why multi-account |
| [ADR-002: Layered Architecture](docs/adr/002-terraform-layered-architecture.md) | Why layered Terraform |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](LICENSE) for details.
