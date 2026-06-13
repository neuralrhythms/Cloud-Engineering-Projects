# Workload Migration: VMware on AWS → AWS Cloud Native

## Overview

This project contains all architectural, infrastructure, and operational artifacts for the migration of workloads from a VMware on AWS SDDC (Software Defined Data Center) to a fully cloud-native AWS environment.

The migration follows the AWS 6R strategies and targets a multi-account AWS Landing Zone built on AWS Organizations and AWS Control Tower.

---

## Repository Structure

```
aws/migrations/workload-migration/
├── docs/
│   └── architecture/
│       ├── ADD-Workload-Migration-v1.0.md    # Architectural Design Document (Phase 1)
│       └── diagrams/                          # Architecture diagrams (Phase 2)
├── iac/
│   └── terraform/                             # Terraform IaC modules (Phase 2)
│       ├── landing-zone/
│       ├── networking/
│       ├── compute/
│       ├── database/
│       └── security/
├── src/                                       # Application configurations (Phase 2)
├── tests/                                     # Infrastructure tests (Phase 2)
├── scripts/
│   └── discovery/                             # ADS scripts, inventory tooling
├── deployment/                                # Deployment runbooks (Phase 2)
└── README.md
```

---

## Migration Phases

| Phase | Deliverable | Status |
|-------|-------------|--------|
| Phase 1 | Architectural Design Document | ✅ Complete |
| Phase 2 | Low-Level Design, Terraform, Diagrams | 🔲 Pending |

---

## Key Contacts

| Role | Responsibility |
|------|---------------|
| Senior Solution Architect | Overall design ownership |
| Cloud Infrastructure Engineer | IaC implementation |
| Security Architect | Security controls and compliance |
| DBA | Database migration and validation |
| Application Teams | Wave planning and UAT |

---

## AWS Services in Scope

| Category | Service |
|----------|---------|
| Migration | AWS Application Migration Service (MGN), AWS Database Migration Service (DMS), AWS Application Discovery Service (ADS) |
| Compute | EC2, ECS, AWS Fargate |
| Database | Amazon RDS for SQL Server, Amazon Aurora Serverless v2 (MySQL-compatible) |
| Networking | VPC, Transit Gateway, Route 53, AWS Direct Connect / Site-to-Site VPN |
| Security | AWS IAM, AWS Organizations SCPs, AWS Security Hub, AWS GuardDuty, AWS KMS |
| Identity | AWS Managed Microsoft AD, AWS IAM Identity Center |
| Observability | Amazon CloudWatch, AWS CloudTrail, Amazon S3 (log archive) |
| File Transfer | AWS Transfer Family |
| Landing Zone | AWS Control Tower, AWS Organizations |

---

## Getting Started

1. Review the [Architectural Design Document](docs/architecture/ADD-Workload-Migration-v1.0.md)
2. Complete workload discovery using AWS Application Discovery Service
3. Validate 6R classification with application owners
4. Obtain compliance/regulatory sign-off for non-migratable workloads
5. Proceed to Phase 2 (Low-Level Design + Terraform)

---

## License

This project is licensed under the [MIT License](LICENSE).

It is intended as a public reference framework for AWS workload migration design. You are free to use, adapt, and build upon it for your own migration projects, portfolio work, or learning purposes. Attribution appreciated but not required.
