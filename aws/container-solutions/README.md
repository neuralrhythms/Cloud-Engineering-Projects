# AWS EKS Platform — Production-Grade Kubernetes on AWS

> **Portfolio Project** | Principal AWS Cloud Architect & Platform Engineering Lead
> AWS EKS · Terraform · Helm · Jenkins · CloudWatch · AWS Well-Architected

---

## Overview

This repository contains the architecture, infrastructure-as-code, CI/CD pipelines, Helm charts, Kubernetes manifests, and operational documentation for a **production-grade Amazon EKS platform** built on AWS.

The platform is designed to host containerised workloads at scale, following the [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) across all six pillars.

---

## Repository Structure

```
aws-eks-platform/
├── docs/                        # Architecture, design, runbooks, decisions
│   ├── architecture/            # HLD, LLD, network, security, EKS platform design
│   ├── diagrams/                # Mermaid diagram sources
│   ├── decisions/               # Architecture Decision Records (ADRs)
│   ├── runbooks/                # Operational runbooks
│   ├── operations/              # Day-2 operational guides
│   └── security/                # Security design and compliance docs
├── terraform/                   # Terraform IaC
│   ├── environments/            # Per-environment root modules (dev/test/prod)
│   └── modules/                 # Reusable Terraform modules
├── platform-pipelines/          # Infrastructure lifecycle Jenkins pipelines
│   ├── terraform-ci/
│   ├── terraform-cd/
│   ├── upgrade-pipelines/
│   └── maintenance-pipelines/
├── application-pipelines/       # Application delivery Jenkins pipelines
│   ├── build/
│   ├── release/
│   └── deployment/
├── helm/                        # Helm charts
│   ├── sample-app/
│   ├── platform-services/
│   └── environments/
├── kubernetes/                  # Raw Kubernetes manifests
│   ├── namespaces/
│   ├── rbac/
│   ├── ingress/
│   ├── network-policies/
│   └── platform-components/
├── scripts/                     # Utility and automation scripts
└── .github/                     # GitHub templates and workflows
```

---

## Architecture Summary

| Layer | Technology |
|---|---|
| Cloud Provider | Amazon Web Services (AWS) |
| Container Orchestration | Amazon EKS (Kubernetes) |
| Infrastructure as Code | Terraform |
| Container Registry | Amazon ECR |
| CI/CD Platform | Jenkins |
| Package Management | Helm |
| Networking | AWS VPC, ALB, Route 53 |
| Observability | CloudWatch, Container Insights |
| Security | IAM, IRSA, KMS, GuardDuty, Security Hub |
| Secrets | AWS Secrets Manager / Parameter Store |

---

## Environments

| Environment | Purpose | Node Group Strategy |
|---|---|---|
| `dev` | Developer testing and integration | Single AZ, Spot instances |
| `test` | QA, integration, performance testing | Multi-AZ, On-Demand |
| `prod` | Production workloads | Multi-AZ, On-Demand, Managed Node Groups |

---

## AWS Well-Architected Alignment

| Pillar | Key Design Choices |
|---|---|
| Operational Excellence | GitOps, IaC, automated pipelines, runbooks |
| Security | IAM least-privilege, IRSA, KMS encryption, GuardDuty |
| Reliability | Multi-AZ EKS, Cluster Autoscaler, health checks |
| Performance Efficiency | Managed Node Groups, HPA, right-sizing |
| Cost Optimization | Spot for non-prod, autoscaling, ECR lifecycle policies |
| Sustainability | Efficient bin-packing, autoscaling to reduce idle capacity |

---

## Quick Start

### Prerequisites

- AWS CLI ≥ 2.x configured with appropriate credentials
- Terraform ≥ 1.6.x
- `kubectl` ≥ 1.28
- `helm` ≥ 3.12
- Jenkins (self-hosted or EC2-based)

### Deploy Infrastructure (Dev)

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Configure kubectl

```bash
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name eks-dev-cluster
```

### Deploy Platform Services

```bash
helm upgrade --install aws-load-balancer-controller \
  helm/platform-services/aws-load-balancer-controller \
  --namespace kube-system \
  --values helm/environments/dev/aws-load-balancer-controller.yaml
```

---

## Documentation Index

| Document | Location |
|---|---|
| Architecture Overview | [docs/architecture/architecture-overview.md](docs/architecture/architecture-overview.md) |
| High-Level Design | [docs/architecture/high-level-design.md](docs/architecture/high-level-design.md) |
| Low-Level Design | [docs/architecture/low-level-design.md](docs/architecture/low-level-design.md) |
| Network Design | [docs/architecture/network-design.md](docs/architecture/network-design.md) |
| Security Design | [docs/security/security-design.md](docs/security/security-design.md) |
| EKS Platform Design | [docs/architecture/eks-platform-design.md](docs/architecture/eks-platform-design.md) |
| CI/CD Design | [docs/architecture/cicd-design.md](docs/architecture/cicd-design.md) |
| Disaster Recovery | [docs/architecture/disaster-recovery.md](docs/architecture/disaster-recovery.md) |
| EKS Upgrade Strategy | [docs/operations/eks-upgrade-strategy.md](docs/operations/eks-upgrade-strategy.md) |
| Node Patching Strategy | [docs/operations/node-patching-strategy.md](docs/operations/node-patching-strategy.md) |
| Terraform Standards | [docs/architecture/terraform-module-standards.md](docs/architecture/terraform-module-standards.md) |
| Helm Standards | [docs/architecture/helm-deployment-standards.md](docs/architecture/helm-deployment-standards.md) |
| Cost Optimization | [docs/architecture/cost-optimization-guide.md](docs/architecture/cost-optimization-guide.md) |
| Well-Architected Assessment | [docs/architecture/well-architected-assessment.md](docs/architecture/well-architected-assessment.md) |
| ADR Index | [docs/decisions/README.md](docs/decisions/README.md) |

---

## Architecture Decision Records (ADRs)

| ADR | Decision |
|---|---|
| [ADR-001](docs/decisions/ADR-001-eks-platform-choice.md) | Why Amazon EKS |
| [ADR-002](docs/decisions/ADR-002-terraform-iac.md) | Why Terraform |
| [ADR-003](docs/decisions/ADR-003-jenkins-cicd.md) | Why Jenkins |
| [ADR-004](docs/decisions/ADR-004-helm-packaging.md) | Why Helm |
| [ADR-005](docs/decisions/ADR-005-managed-node-groups.md) | Why Managed Node Groups |
| [ADR-006](docs/decisions/ADR-006-future-migration.md) | Future Migration Considerations |

---

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for standards, branching strategy, and code review process.

---

## License

See [LICENSE](LICENSE) for details.
