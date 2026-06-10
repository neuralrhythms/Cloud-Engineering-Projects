# ☁️ Cloud Engineering Projects

**A portfolio of Cloud Architecture, Platform Engineering, Security, Automation, Disaster Recovery, and Generative AI Projects.**

---

> This repository showcases enterprise-grade cloud engineering work spanning multi-cloud environments, security architecture, infrastructure automation, and AI/ML workloads. Each project emphasizes architecture decisions, operational excellence, and industry best practices.

---

## 🏗️ Featured Categories

| Category | Description | Cloud |
|----------|-------------|-------|
| [AWS Landing Zone](#-aws-landing-zone) | Enterprise multi-account governance and platform engineering | AWS |
| [Disaster Recovery](#-disaster-recovery) | Cross-region architectures, backup strategies, business continuity | AWS |
| [Cloud Migrations](#-cloud-migrations) | Redis, RDS, and workload migration patterns | AWS |
| [Security Engineering](#-security-engineering) | IAM, KMS, GuardDuty, Security Hub, CloudTrail | AWS |
| [Networking](#-networking) | Transit Gateway, hybrid connectivity, multi-account networking | AWS |
| [Automation](#-automation) | Lambda, Boto3, Systems Manager, event-driven architectures | AWS |
| [Serverless](#-serverless) | Event-driven, API-first serverless applications | AWS |
| [AI Workloads](#-ai-workloads) | Generative AI, RAG, Bedrock, document processing | AWS |
| [Terraform](#-terraform) | Multi-cloud Infrastructure as Code | Multi |
| [Architecture Patterns](#-architecture-patterns) | Reusable patterns for HA, DR, security, networking | Multi |

---

## 📂 Repository Structure

```
Cloud-Engineering-Projects/
├── aws/                          # Amazon Web Services projects
│   ├── landing-zone/             # Enterprise AWS Landing Zone
│   ├── disaster-recovery/        # DR architectures and implementations
│   ├── migrations/               # Cloud migration projects
│   ├── networking/               # Network architecture projects
│   ├── security/                 # Security engineering projects
│   ├── automation/               # Automation and orchestration
│   ├── serverless/               # Serverless architectures
│   ├── ai-workloads/            # Generative AI and ML projects
│   └── cost-optimization/        # FinOps and cost management
├── azure/                        # Microsoft Azure projects
├── gcp/                          # Google Cloud Platform projects
├── terraform/                    # Multi-cloud IaC modules
├── architecture-patterns/        # Reusable architecture patterns
├── runbooks/                     # Operational runbooks
├── certifications/               # Cloud certification resources
├── diagrams/                     # Architecture diagrams (source files)
└── assets/                       # Images, GIFs, media
```

---

## ☁️ AWS Landing Zone

Enterprise multi-account AWS environment with full governance, security baseline, and networking.

| Component | Status | Description |
|-----------|--------|-------------|
| [AWS Organizations](aws/landing-zone/) | ✅ Complete | OU hierarchy, SCPs, account vending |
| [Security Baseline](aws/landing-zone/) | ✅ Complete | GuardDuty, SecurityHub, Config, CloudTrail |
| [Centralized Logging](aws/landing-zone/) | ✅ Complete | Immutable log archive with S3 Object Lock |
| [Network Architecture](aws/landing-zone/) | ✅ Complete | Transit Gateway hub-and-spoke with segmentation |
| [IAM Identity Center](aws/landing-zone/) | ✅ Complete | SSO with permission sets and RBAC |

➡️ [View Full Landing Zone Project](aws/landing-zone/)

---

## 🔄 Disaster Recovery

Cross-region architectures ensuring business continuity and data durability.

| Project | Pattern | RPO | RTO |
|---------|---------|-----|-----|
| [Active-Passive DR](aws/disaster-recovery/) | Pilot Light / Warm Standby | Minutes | < 30 min |
| [Active-Active Multi-Region](aws/disaster-recovery/) | Active-Active | Zero | Zero |
| [Cross-Region Backup](aws/disaster-recovery/) | Backup & Restore | Hours | Hours |

➡️ [View DR Projects](aws/disaster-recovery/)

---

## 🚀 Cloud Migrations

Large-scale migration projects following AWS Migration Acceleration Program methodologies.

| Project | Type | Scale |
|---------|------|-------|
| [Redis Cross-Region Migration](aws/migrations/redis-cross-region-migration/) | Database Migration | Multi-TB |
| [RDS Migration](aws/migrations/rds-migration/) | Database Migration | Enterprise |
| [Workload Migration](aws/migrations/workload-migration/) | Application Migration | Multi-Account |

➡️ [View Migration Projects](aws/migrations/)

---

## 🔐 Security Engineering

Defense-in-depth security implementations across the cloud estate.

| Project | Focus Area |
|---------|-----------|
| [IAM Architecture](aws/security/iam/) | Least privilege, role design, cross-account access |
| [KMS Strategy](aws/security/kms/) | Encryption key management, key policies, rotation |
| [GuardDuty](aws/security/guardduty/) | Threat detection, automated response |
| [Security Hub](aws/security/security-hub/) | CSPM, compliance frameworks, finding aggregation |
| [CloudTrail](aws/security/cloudtrail/) | Audit logging, organization trails, integrity |

➡️ [View Security Projects](aws/security/)

---

## 🌐 Networking

Enterprise network architectures for multi-account, hybrid, and multi-region environments.

| Project | Scope |
|---------|-------|
| [Transit Gateway](aws/networking/transit-gateway/) | Hub-and-spoke with segmentation |
| [Hybrid Connectivity](aws/networking/hybrid-connectivity/) | VPN, Direct Connect, SD-WAN integration |
| [Multi-Account Networking](aws/networking/multi-account-networking/) | RAM, shared VPCs, IPAM |

➡️ [View Networking Projects](aws/networking/)

---

## ⚡ Automation

Infrastructure automation, event-driven workflows, and operational tooling.

| Project | Technology |
|---------|-----------|
| [Lambda Functions](aws/automation/lambda/) | Serverless automation |
| [Boto3 Scripts](aws/automation/boto3/) | Python SDK automation |
| [Systems Manager](aws/automation/systems-manager/) | Fleet management, patching, runbooks |

➡️ [View Automation Projects](aws/automation/)

---

## 🤖 AI Workloads

Generative AI applications, RAG architectures, and ML platforms on AWS.

| Project | Focus |
|---------|-------|
| [Generative AI Training Platform](aws/ai-workloads/generative-ai-training-platform/) | Learning platform with AI content |
| [RAG Architecture](aws/ai-workloads/rag-architecture/) | Document retrieval with LLM inference |
| [AI Chatbot](aws/ai-workloads/ai-chatbot/) | Conversational AI with guardrails |
| [Bedrock Integration](aws/ai-workloads/bedrock-integration/) | Foundation models, prompt engineering |
| [Knowledge Base Search](aws/ai-workloads/knowledge-base-search/) | Vector search with embeddings |
| [Document Processing](aws/ai-workloads/document-processing/) | PDF → Textract → Embeddings pipeline |
| [LLM Application Hosting](aws/ai-workloads/llm-application-hosting/) | Model serving at scale |

➡️ [View AI Projects](aws/ai-workloads/)

---

## 🏔️ Terraform

Multi-cloud Infrastructure as Code with reusable modules and patterns.

| Cloud | Modules |
|-------|---------|
| [AWS Modules](terraform/aws/) | VPC, EKS, RDS, Lambda, Landing Zone |
| [Azure Modules](terraform/azure/) | VNet, AKS, SQL, Functions |
| [GCP Modules](terraform/gcp/) | VPC, GKE, Cloud SQL, Cloud Functions |

➡️ [View Terraform Projects](terraform/)

---

## 📐 Architecture Patterns

Reusable, documented architecture patterns with decision matrices.

| Pattern | Category |
|---------|----------|
| [High Availability](architecture-patterns/high-availability/) | Resilience |
| [Disaster Recovery](architecture-patterns/disaster-recovery/) | Business Continuity |
| [Security](architecture-patterns/security/) | Zero Trust, Defense in Depth |
| [Networking](architecture-patterns/networking/) | Hub-Spoke, Mesh, Hybrid |
| [Landing Zones](architecture-patterns/landing-zones/) | Multi-Account Governance |
| [Observability](architecture-patterns/observability/) | Monitoring, Logging, Tracing |
| [Cost Optimization](architecture-patterns/cost-optimization/) | FinOps Patterns |

➡️ [View Architecture Patterns](architecture-patterns/)

---

## 🎓 Certifications

| Certification | Status |
|--------------|--------|
| AWS Solutions Architect Professional | ✅ |
| AWS Security Specialty | ✅ |
| AWS Advanced Networking Specialty | ✅ |
| HashiCorp Terraform Associate | ✅ |
| Azure Solutions Architect Expert | 📋 Planned |
| GCP Professional Cloud Architect | 📋 Planned |

---

## 🛠️ Technologies

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)

---

## 📬 Contact

- **LinkedIn**: [Your LinkedIn Profile]
- **Email**: [your.email@domain.com]
- **Blog**: [Your Blog URL]

---

*This portfolio is continuously updated with new projects and improvements.*
