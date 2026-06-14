# Documentation Index

## Architecture

| Document | Description |
|---|---|
| [Architecture Overview](architecture/architecture-overview.md) | Platform goals, scope, layers, and technology choices |
| [High-Level Design](architecture/high-level-design.md) | Component overview, data flows, network topology |
| [Low-Level Design](architecture/low-level-design.md) | Naming conventions, resource specs, configuration parameters |
| [Network Design](architecture/network-design.md) | VPC, subnets, NAT, security groups, DNS, VPC endpoints |
| [EKS Platform Design](architecture/eks-platform-design.md) | Cluster config, namespaces, RBAC, pod security, secrets |
| [CI/CD Design](architecture/cicd-design.md) | Platform and application pipeline architecture |
| [Disaster Recovery](architecture/disaster-recovery.md) | RTO/RPO targets, failure scenarios, recovery procedures |
| [Terraform Module Standards](architecture/terraform-module-standards.md) | IaC coding standards and conventions |
| [Helm Deployment Standards](architecture/helm-deployment-standards.md) | Helm chart standards and deployment patterns |
| [Cost Optimization Guide](architecture/cost-optimization-guide.md) | Compute, network, storage, and operational cost strategies |
| [Well-Architected Assessment](architecture/well-architected-assessment.md) | AWS WAF pillar assessments and gap analysis |

## Security

| Document | Description |
|---|---|
| [Security Design](security/security-design.md) | IAM, network, data protection, threat detection, compliance |

## Diagrams

| Diagram | Description |
|---|---|
| [HLD AWS Architecture](diagrams/hld-aws-architecture.md) | Top-level AWS architecture (Mermaid) |
| [EKS Platform Architecture](diagrams/eks-platform-architecture.md) | Kubernetes platform components (Mermaid) |
| [Infrastructure Pipeline](diagrams/infrastructure-cicd-pipeline.md) | Terraform CI/CD flow (Mermaid) |
| [Application Pipeline](diagrams/application-cicd-pipeline.md) | App delivery pipeline (Mermaid) |
| [Security Architecture](diagrams/security-architecture.md) | Layered security controls (Mermaid) |
| [Observability Architecture](diagrams/observability-architecture.md) | CloudWatch observability stack (Mermaid) |

## Architecture Decision Records

| ADR | Decision |
|---|---|
| [ADR-001](decisions/ADR-001-eks-platform-choice.md) | Why Amazon EKS |
| [ADR-002](decisions/ADR-002-terraform-iac.md) | Why Terraform |
| [ADR-003](decisions/ADR-003-jenkins-cicd.md) | Why Jenkins |
| [ADR-004](decisions/ADR-004-helm-packaging.md) | Why Helm |
| [ADR-005](decisions/ADR-005-managed-node-groups.md) | Why Managed Node Groups |
| [ADR-006](decisions/ADR-006-future-migration.md) | Future migration considerations |

## Operations

| Document | Description |
|---|---|
| [EKS Upgrade Strategy](operations/eks-upgrade-strategy.md) | Kubernetes version upgrade procedure |
| [Node Patching Strategy](operations/node-patching-strategy.md) | Monthly node AMI patching procedure |

## Runbooks

| Runbook | Description |
|---|---|
| [Cluster Health Check](runbooks/cluster-health-check.md) | Routine cluster health verification |
| [Node NotReady](runbooks/node-not-ready.md) | Diagnose and resolve NotReady nodes |
| [Security Incident Response](runbooks/security-incident-response.md) | Security incident handling procedure |
