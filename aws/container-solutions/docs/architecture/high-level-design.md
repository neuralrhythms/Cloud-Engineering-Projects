# High-Level Design (HLD)

## Document Information

| Field | Value |
|---|---|
| Document Type | High-Level Design |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This High-Level Design describes the AWS EKS platform from an architectural perspective — how the major components relate to each other, the data flows, and the key design decisions made at a platform level.

---

## 2. Architecture Diagram

> See [docs/diagrams/hld-aws-architecture.md](../diagrams/hld-aws-architecture.md) for the Mermaid diagram source.

---

## 3. Component Overview

### 3.1 AWS VPC and Networking

The platform runs within a dedicated VPC per environment. The VPC is designed with:

- **Public subnets** — for load balancers (ALB/NLB) only; no workloads run here
- **Private subnets** — for EKS worker nodes, RDS, and internal services
- **NAT Gateway** — enables outbound internet access from private subnets (e.g., ECR pulls, AWS API calls)
- **VPC Endpoints** — for S3, ECR, Secrets Manager, and other AWS services to avoid NAT Gateway costs and reduce exposure
- **Three Availability Zones** — all subnets and node groups span 3 AZs for resilience

### 3.2 Amazon EKS

The EKS control plane is fully managed by AWS. Key configuration:

- **EKS version** — latest supported LTS release; version pinned in Terraform
- **API server endpoint** — private endpoint only in production; public + private in dev/test
- **Logging** — all control plane log types enabled to CloudWatch Logs
- **Add-ons** — managed EKS add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI driver

### 3.3 Managed Node Groups

Worker node compute is provided by EKS Managed Node Groups:

- **AMI** — Amazon Linux 2 EKS-optimised AMI (latest patched version)
- **Instance types** — configurable per environment (e.g., m5.xlarge for prod)
- **Autoscaling** — min/max/desired configured per node group
- **Lifecycle** — rolling updates managed by EKS during upgrades
- **Labels/Taints** — used for workload placement (e.g., dedicated node groups per workload class)

### 3.4 Amazon ECR

Container images are stored in ECR repositories:

- One ECR repository per application
- Image scanning enabled on push (basic scanning; enhanced scanning optional)
- Lifecycle policies to expire untagged images
- Cross-account access policies for multi-account deployments

### 3.5 AWS Load Balancer Controller

The AWS Load Balancer Controller provisions ALBs and NLBs from Kubernetes Ingress and Service resources:

- Deployed as a Helm chart in the `kube-system` namespace
- Uses IRSA for permissions to create/manage ELB resources
- Ingress class: `alb`
- Supports path-based and host-based routing

### 3.6 Jenkins CI/CD

Jenkins serves as the CI/CD platform for both infrastructure and application pipelines:

- Self-hosted Jenkins on EC2 or EKS (see CI/CD Design)
- Two pipeline families:
  - **Platform pipelines** — Terraform lifecycle, EKS upgrades, node patching
  - **Application pipelines** — build, test, scan, push to ECR, Helm deploy
- Credentials stored in Jenkins Credentials Store (backed by AWS Secrets Manager)

### 3.7 Amazon CloudWatch

Observability is provided by CloudWatch:

- **Container Insights** — node and pod-level metrics
- **CloudWatch Logs** — application logs, EKS control plane logs, VPC flow logs
- **CloudWatch Alarms** — critical thresholds with SNS notification
- **CloudWatch Dashboards** — per-cluster and per-application views

### 3.8 Security Services

| Service | Purpose |
|---|---|
| AWS GuardDuty | Threat detection — VPC flow, DNS, CloudTrail, EKS audit logs |
| AWS Security Hub | Security posture aggregation and compliance checks |
| AWS KMS | Encryption key management — EKS secrets, EBS volumes, S3, ECR |
| AWS Secrets Manager | Runtime secrets for application workloads |
| AWS Config | Configuration compliance recording and rules |

---

## 4. Data Flow Summary

### 4.1 User Traffic (Inbound)

```
Internet → Route 53 → ALB (Public Subnet) → EKS Service → Pod (Private Subnet)
```

### 4.2 Application to AWS Services

```
Pod (Private Subnet) → VPC Endpoint → AWS Service (ECR / S3 / Secrets Manager)
```

### 4.3 Outbound Internet (e.g., pull from public registry)

```
Pod (Private Subnet) → NAT Gateway (Public Subnet) → Internet Gateway → Internet
```

### 4.4 CI/CD — Infrastructure Pipeline

```
Git Push → Jenkins → Terraform Validate → Security Scan → Plan → Manual Approval → Apply
```

### 4.5 CI/CD — Application Pipeline

```
Git Push → Jenkins → Build → Unit Test → Container Scan → Push ECR → Helm Deploy → EKS
```

---

## 5. Availability and Resilience

| Component | Resilience Design |
|---|---|
| EKS Control Plane | Fully managed by AWS; multi-AZ by default |
| Worker Nodes | Spread across 3 AZs via Managed Node Groups |
| NAT Gateway | One per AZ (recommended for HA; single per environment for cost saving in non-prod) |
| Load Balancer | ALB is regional and highly available by default |
| ECR | Regional service; highly available |
| Jenkins | EC2 with EBS backup or EKS deployment with persistent volume |

---

## 6. Network Topology

```
┌────────────────────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                                  │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  Public      │  │  Public      │  │  Public      │              │
│  │  Subnet AZ-a │  │  Subnet AZ-b │  │  Subnet AZ-c │              │
│  │  10.0.0.0/24 │  │  10.0.1.0/24 │  │  10.0.2.0/24 │              │
│  │  [ALB / NAT] │  │  [ALB / NAT] │  │  [ALB / NAT] │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │  Private     │  │  Private     │  │  Private     │              │
│  │  Subnet AZ-a │  │  Subnet AZ-b │  │  Subnet AZ-c │              │
│  │ 10.0.10.0/24 │  │ 10.0.11.0/24 │  │ 10.0.12.0/24 │              │
│  │  [EKS Nodes] │  │  [EKS Nodes] │  │  [EKS Nodes] │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
└────────────────────────────────────────────────────────────────────┘
```

---

## 7. Related Documents

- [Architecture Overview](architecture-overview.md)
- [Low-Level Design](low-level-design.md)
- [Network Design](network-design.md)
- [EKS Platform Design](eks-platform-design.md)
