# Architecture Overview

## Document Information

| Field | Value |
|---|---|
| Document Type | Architecture Overview |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |
| Reviewed By | — |

---

## 1. Purpose

This document provides a high-level overview of the AWS EKS platform architecture. It is intended for engineers, architects, and stakeholders who need to understand the platform's design goals, scope, and key decisions.

---

## 2. Platform Goals

The platform is designed to:

- Provide a **consistent, repeatable** Kubernetes runtime environment across dev, test, and production
- Enable **self-service application deployments** through standardised CI/CD pipelines
- Enforce **security and compliance** by default at the platform layer
- Support **operational observability** through centralised logging and metrics
- Align with the **AWS Well-Architected Framework** across all six pillars
- Minimise operational overhead through **managed services** where possible

---

## 3. Scope

### In Scope

- Amazon EKS cluster provisioning and lifecycle management
- VPC, networking, and connectivity
- IAM roles, policies, and service account bindings (IRSA)
- Container image build, scan, and storage (ECR)
- Helm-based application deployment patterns
- Jenkins CI/CD pipelines for infrastructure and application delivery
- CloudWatch-based observability
- Security controls (KMS, GuardDuty, Security Hub, Secrets Manager)
- Operational runbooks and upgrade procedures

### Out of Scope

- Application-level business logic
- Database provisioning (handled by application teams)
- Domain registration
- Third-party SaaS integrations beyond AWS native services

---

## 4. Environments

```
┌─────────────────────────────────────────────────┐
│                   AWS Account                    │
│                                                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐ │
│  │    Dev     │  │    Test    │  │    Prod    │ │
│  │  EKS Cluster│  │ EKS Cluster│  │ EKS Cluster│ │
│  └────────────┘  └────────────┘  └────────────┘ │
└─────────────────────────────────────────────────┘
```

> Note: Each environment may reside in separate AWS accounts depending on the organisation's account strategy. This repository supports both single-account and multi-account deployments.

| Environment | AWS Account Strategy | Primary Use |
|---|---|---|
| Dev | Shared or dedicated dev account | Developer testing, integration |
| Test | Shared or dedicated test account | QA, performance, regression |
| Prod | Dedicated production account | Live production traffic |

---

## 5. Platform Layers

The platform is composed of four logical layers:

### Layer 1 — AWS Infrastructure
Managed by Terraform. Includes VPC, subnets, security groups, IAM, KMS, EKS control plane, managed node groups, and ECR.

### Layer 2 — Kubernetes Platform
EKS cluster with platform-level components: namespaces, RBAC, network policies, ingress controller, cluster autoscaler, and secrets management.

### Layer 3 — CI/CD Platform
Jenkins-based pipelines for infrastructure lifecycle management and application delivery. Separate pipelines for Terraform and application workloads.

### Layer 4 — Application Layer
Application teams deploy workloads via Helm charts through the application delivery pipeline. Applications consume platform capabilities through well-defined interfaces.

---

## 6. Key Design Principles

| Principle | Implementation |
|---|---|
| Infrastructure as Code | All AWS infrastructure provisioned via Terraform |
| GitOps | All changes tracked in Git; no manual console changes |
| Immutable Infrastructure | Node groups replaced, not patched in-place |
| Least Privilege | IAM roles scoped per service; IRSA for pod-level access |
| Defence in Depth | Multiple security layers (network, IAM, runtime, image scanning) |
| Observability First | Logging and metrics enabled by default for all components |
| Cost Awareness | Autoscaling, Spot for non-prod, right-sizing guidance |

---

## 7. Technology Choices

| Component | Choice | Rationale |
|---|---|---|
| Kubernetes | Amazon EKS | Managed control plane, AWS-native integrations |
| IaC | Terraform | Multi-cloud portability, large ecosystem, state management |
| CI/CD | Jenkins | Flexible, self-hosted, widely adopted in enterprise |
| Packaging | Helm | Kubernetes-native, templating, release management |
| Registry | Amazon ECR | Native AWS integration, vulnerability scanning |
| Observability | CloudWatch | Native AWS, no additional tooling required |
| Secrets | AWS Secrets Manager | Managed, audited, integrated with IRSA |
| Networking | AWS VPC CNI | Native pod networking, VPC flow logs, security groups for pods |

---

## 8. Related Documents

- [High-Level Design](high-level-design.md)
- [Low-Level Design](low-level-design.md)
- [Network Design](network-design.md)
- [EKS Platform Design](eks-platform-design.md)
- [Security Design](../security/security-design.md)
- [CI/CD Design](cicd-design.md)
