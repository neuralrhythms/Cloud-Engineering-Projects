# Architectural Design Document
# Workload Migration: VMware on AWS SDDC → AWS Cloud Native

| Field | Value |
|-------|-------|
| Document Version | 1.1 |
| Status | Draft — Updated |
| Author | Senior Solution Architect |
| Date | June 2026 |
| Classification | Public — Reference Framework |

---

> **Framework Notice**
> This document serves as a reusable reference framework for AWS workload migration projects.
> It is published as a public portfolio artifact and can be adapted for similar VMware-to-AWS or
> on-premises-to-AWS migration scenarios. All company-specific details are intentionally generalised.
> Licensed under the [MIT License](../../../LICENSE).

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Business Case](#2-business-case)
3. [Scope](#3-scope)
4. [Migration Strategy — 6R Classification](#4-migration-strategy--6r-classification)
5. [Current State Architecture](#5-current-state-architecture)
6. [Target State Architecture](#6-target-state-architecture)
7. [Migration Approach — Phases and Waves](#7-migration-approach--phases-and-waves)
8. [Core AWS Services](#8-core-aws-services)
9. [Landing Zone Design](#9-landing-zone-design)
10. [Network Design](#10-network-design)
11. [Security and Compliance](#11-security-and-compliance)
12. [Identity and Access Management](#12-identity-and-access-management)
13. [Database Migration Design](#13-database-migration-design)
14. [Non-Migratable Workloads](#14-non-migratable-workloads)
15. [Observability Strategy](#15-observability-strategy)
16. [NAS Storage Migration](#16-nas-storage-migration)
17. [Risks and Mitigations](#17-risks-and-mitigations)
18. [Success Criteria and KPIs](#18-success-criteria-and-kpis)
19. [Assumptions and Constraints](#19-assumptions-and-constraints)
20. [Next Steps — Phase 2 Triggers](#20-next-steps--phase-2-triggers)

---

## 1. Executive Summary

This document defines the high-level architectural design for migrating workloads from a VMware on AWS Software Defined Data Center (SDDC) to a fully cloud-native AWS environment.

The current environment hosts a mixed estate of Windows and Linux servers, MS SQL Server and MySQL databases, and a range of applications — all co-located within a single SDDC with no logical account or workload separation.

The target architecture establishes:

- A **multi-account AWS Landing Zone** based on AWS Organizations and AWS Control Tower, deployed in **Frankfurt (eu-central-1)** as the primary region with **Ireland (eu-west-1)** as the Disaster Recovery region
- **Workload separation** across production, non-production, and shared services accounts
- **Database replatforming** of MS SQL Server to Amazon RDS for SQL Server and MySQL to Amazon Aurora Serverless v2
- **Application modernisation** of selected workloads to containers via Amazon ECS and AWS Fargate
- **Identity migration** from VMware-hosted Active Directory to **Active Directory on Amazon EC2**, preserving full administrative control
- **NAS storage migration** from NetApp ONTAP and Windows file servers to Amazon FSx for NetApp ONTAP and Amazon FSx for Windows File Server respectively
- **Retention** of non-migratable workloads in a governed disposition state

The migration is structured into phased delivery waves, prioritising foundation infrastructure, then workload migration by risk and complexity.

---

## 2. Business Case

### 2.1 Business Drivers

| Driver | Detail |
|--------|--------|
| Cost Optimisation | VMware on AWS SDDC licensing and compute costs are significantly higher than equivalent AWS-native services. Eliminating VMware license overhead reduces total cost of ownership. |
| Operational Agility | Native AWS services provide elasticity, managed patching, automated backups, and reduced operational burden. |
| Security Posture | Consolidation into a governed multi-account structure with centralised security controls improves threat detection and compliance auditability. |
| Platform Modernisation | Containerisation of eligible workloads improves deployment velocity, resource efficiency, and developer experience. |
| Strategic Alignment | Full cloud-native adoption aligns with the organisation's cloud-first strategy and removes dependency on VMware SDDC infrastructure. |

### 2.2 Cost Considerations

| Category | Current State | Target State |
|----------|--------------|--------------|
| Compute | VMware SDDC hosts (dedicated EC2) | Right-sized EC2 / Fargate / ECS |
| Database | SQL Server and MySQL on Windows VMs (OS + license) | RDS for SQL Server (License Included or BYOL), Aurora Serverless v2 |
| Networking | NSX-based SDN | AWS VPC, Transit Gateway |
| Operations | Manual VM management | Managed services, automation, IaC |
| Licensing | VMware vSphere/NSX/vSAN + Windows Server | Reduced to AWS managed service costs |

> **Note:** A detailed cost model should be produced using the AWS Pricing Calculator as part of Phase 2, based on right-sizing outputs from AWS Application Discovery Service.

### 2.3 Strategic Outcomes

- Decommission VMware SDDC post-migration
- Achieve full infrastructure-as-code coverage via Terraform
- Establish a repeatable, governed cloud operating model
- Enable future modernisation initiatives (serverless, AI/ML) on a clean cloud-native foundation

---

## 3. Scope

### 3.1 In Scope

| Workload Category | Migration Strategy | Target |
|------------------|--------------------|--------|
| Legacy Windows/Linux servers (documented, stable) | Rehost (Lift & Shift) | EC2 |
| MySQL databases on Windows VMs | Replatform | Amazon Aurora Serverless v2 (MySQL-compatible) |
| MS SQL Server databases | Replatform | Amazon RDS for SQL Server |
| Applications suitable for containerisation | Refactor / Rearchitect | Amazon ECS / AWS Fargate |
| Active Directory (VMware-hosted) | Rehost | EC2 (Windows Server, domain-joined) |
| NAS storage — NetApp ONTAP | Replatform | Amazon FSx for NetApp ONTAP |
| NAS storage — Windows File Server | Replatform | Amazon FSx for Windows File Server |
| File transfer services | Replatform | AWS Transfer Family |
| Application infrastructure networking | Replace | AWS VPC, Transit Gateway, Route 53 |

### 3.2 Out of Scope (Non-Migratable — See Section 14)

| Exclusion Category | Rationale |
|-------------------|-----------|
| Undocumented legacy applications | No documentation, original developers departed, no vendor handover |
| Regulatory/compliance-restricted workloads | Privacy and data protection obligations prevent cloud hosting |
| Vendor-locked applications without cloud-compatible licensing | Incumbent vendor constraints |

### 3.3 Assumptions on Workload Inventory

Detailed workload inventory will be established via **AWS Application Discovery Service (ADS)** agent-based discovery prior to wave planning. The 6R classification in this document is indicative and will be refined following discovery outputs.

---

## 4. Migration Strategy — 6R Classification

### 4.1 Classification Matrix

| 6R Strategy | Description | Applicable Workloads | AWS Target |
|-------------|-------------|---------------------|------------|
| **Rehost** | Lift and shift — migrate VM as-is to EC2 | Legacy apps with no modernisation path; VMware-hosted Active Directory Domain Controllers | Amazon EC2, AWS MGN |
| **Replatform** | Lift, shift, and optimise — minimal code change, better managed service | MS SQL Server on VMs → RDS; MySQL on Windows VMs → Aurora Serverless v2; File services → Transfer Family; NAS → FSx | Amazon RDS for SQL Server, Amazon Aurora Serverless v2, AWS Transfer Family, Amazon FSx |
| **Refactor / Rearchitect** | Re-architect for cloud-native patterns | Applications with active development teams capable of containerisation | Amazon ECS, AWS Fargate |
| **Repurchase** | Move to SaaS alternative | To be assessed during discovery (e.g., ITSM, monitoring tools) | SaaS vendors (TBD) |
| **Retain** | Keep in current environment | Non-migratable workloads (undocumented, regulatory, vendor-locked) | VMware SDDC (controlled decommission excluded) |
| **Retire** | Decommission | Applications identified as redundant or unused during discovery | N/A — decommission |

### 4.2 Decision Criteria

```
Is the workload documented and supported?
  ├── No → Retain (with risk register entry) or Retire
  └── Yes → Is there a regulatory/compliance restriction?
              ├── Yes → Retain
              └── No → Can it be containerised?
                          ├── Yes → Refactor (ECS/Fargate)
                          └── No → Is it a database?
                                      ├── Yes → Replatform (RDS/Aurora)
                                      └── No → Rehost (EC2 via MGN)
```

---

## 5. Current State Architecture

### 5.1 Environment Overview

| Attribute | Current State |
|-----------|--------------|
| Platform | VMware on AWS (SDDC) |
| Virtualisation | VMware vSphere / vSAN / NSX |
| Server OS | Windows Server (various versions), Linux (various distributions) |
| Databases | MS SQL Server (on Windows VMs), MySQL (on Windows VMs) |
| NAS Storage | NetApp ONTAP appliances and Windows file servers providing SMB/NFS shared storage |
| Networking | VMware NSX software-defined networking — flat SDDC, no logical account separation |
| Identity | Active Directory hosted on VMware Windows VMs |
| Workload Separation | None — all workloads co-located in single SDDC |
| IaC | None (manual VM provisioning assumed) |
| Monitoring | VMware-native tooling (vRealize / CloudWatch limited) |

### 5.2 Key Architectural Gaps

| Gap | Risk | Impact |
|-----|------|--------|
| No account or workload isolation | High | Blast radius of security incidents spans all workloads |
| No IaC | High | No repeatable, auditable infrastructure provisioning |
| Databases on VMs | Medium | No managed patching, backup, HA, or read replica capability |
| No centralised logging or SIEM | High | Limited security observability |
| Flat network — no micro-segmentation | High | Lateral movement risk |
| AD on VMware VMs | Medium | Single point of failure; not integrated with AWS IAM |
| NAS on-premises / SDDC-hosted | Medium | No managed HA, snapshots, or cloud-native access patterns |
| No DR strategy | High | Recovery objectives undefined and untested |

---

## 6. Target State Architecture

### 6.1 Architecture Principles

- **Multi-account** structure using AWS Organizations and Control Tower
- **Primary region: Frankfurt (eu-central-1)** — business headquartered in Germany; data residency and GDPR alignment
- **DR region: Ireland (eu-west-1)** — paired AWS region for disaster recovery
- **Workload isolation** — production and non-production in separate accounts
- **Shared services** — centralised logging, security, networking, and identity
- **Infrastructure as Code** — all resources provisioned via Terraform
- **Least privilege** — IAM policies scoped to minimum required permissions
- **Defence in depth** — layered security controls across network, identity, data, and application tiers
- **Managed services first** — prefer RDS, Aurora, ECS, FSx over self-managed equivalents
- **Observability by default** — CloudWatch, CloudTrail, Security Hub enabled on all accounts from day 1

### 6.2 Account Structure

```
AWS Organizations (Root)
│
├── Management Account (billing, governance only)
│
├── Security OU
│   ├── Log Archive Account        (centralised S3 log storage, CloudTrail org trail)
│   └── Security Tooling Account   (Security Hub, GuardDuty, Inspector, Config)
│
├── Infrastructure OU
│   ├── Network Hub Account        (Transit Gateway, VPN/Direct Connect, DNS)
│   └── Shared Services Account    (AWS Managed AD, internal tooling, Transfer Family)
│
├── Workloads OU
│   ├── Production Account(s)      (production workloads, RDS, Aurora, ECS)
│   └── Non-Production Account(s)  (dev, test, staging workloads)
│
└── Sandbox OU
    └── Sandbox Account            (experimentation, isolated from production)
```

### 6.3 High-Level Component Overview

| Layer | Components |
|-------|-----------|
| Edge / Ingress | AWS WAF, Application Load Balancer, Route 53 |
| Compute — Rehosted | Amazon EC2 (migrated via AWS MGN) |
| Compute — Containerised | Amazon ECS with AWS Fargate |
| Database — SQL Server | Amazon RDS for SQL Server (Multi-AZ) |
| Database — MySQL | Amazon Aurora Serverless v2 (MySQL-compatible) |
| Storage — NAS (NetApp) | Amazon FSx for NetApp ONTAP |
| Storage — NAS (Windows) | Amazon FSx for Windows File Server |
| Identity | Active Directory on Amazon EC2 (Windows Server, full admin control) |
| SSO | AWS IAM Identity Center (AD-connected) |
| File Transfer | AWS Transfer Family (SFTP/FTPS/FTP) |
| Networking | VPC per account, Transit Gateway (hub-and-spoke), Route 53 Resolver |
| Security | AWS KMS, Secrets Manager, Security Hub, GuardDuty, CloudTrail, Config |
| Observability | Amazon CloudWatch, AWS CloudTrail (org trail), Amazon S3 (log archive) |
| IaC | Terraform (all accounts and resources) |

---

## 7. Migration Approach — Phases and Waves

### 7.1 Phase Overview

| Phase | Name | Objective |
|-------|------|-----------|
| **Phase 0** | Discovery and Assessment | Complete workload inventory, dependency mapping, 6R finalisation |
| **Phase 1** | Foundation | Deploy Landing Zone, networking, shared services, identity |
| **Phase 2** | Wave 1 — Pilot | Migrate 1–3 low-risk, non-production workloads to validate tooling and process |
| **Phase 3** | Wave 2 — Database Replatform | Migrate MS SQL Server → RDS; MySQL → Aurora Serverless v2 |
| **Phase 4** | Wave 3 — Rehost | Lift and shift remaining eligible workloads via AWS MGN |
| **Phase 5** | Wave 4 — Refactor | Containerise eligible applications to ECS/Fargate |
| **Phase 6** | Cutover and Decommission | Final cutover, SDDC decommission, hypercare period |

### 7.2 Phase 0 — Discovery and Assessment Detail

| Activity | Tooling | Output |
|----------|---------|--------|
| Agent-based discovery | AWS Application Discovery Service (ADS) | Server inventory, CPU/memory/disk utilisation, network dependencies |
| Dependency mapping | ADS / Migration Hub | Application dependency map |
| Database assessment | AWS Schema Conversion Tool (SCT) | Schema compatibility report for SQL Server → RDS and MySQL → Aurora |
| 6R classification | Workshop with application owners | Finalised 6R matrix |
| Regulatory review | Legal / Compliance team | Confirmed non-migratable workload list |
| Wave planning | Migration Hub | Prioritised wave plan |

### 7.3 Phase 1 — Foundation Detail

| Activity | Service | Detail |
|----------|---------|--------|
| Landing Zone deployment | AWS Control Tower | Baseline account structure, guardrails, SCPs — primary region eu-central-1 |
| Network Hub | Transit Gateway | Hub-and-spoke VPC connectivity; TGW peering to DR region (eu-west-1) |
| DNS | Route 53 Resolver | Hybrid DNS resolution (SDDC AD ↔ AWS) |
| Connectivity | Site-to-Site VPN or Direct Connect | Secure channel between SDDC and AWS during migration |
| Centralised logging | CloudTrail (org trail) + S3 | All accounts log to Log Archive account |
| Security baseline | Security Hub, GuardDuty, Config | Enabled on all accounts via Control Tower |
| Identity foundation | Active Directory on EC2 | Deploy AD DCs on EC2 in shared-services VPC; establish forest trust with SDDC AD |
| IAM Identity Center | AWS IAM Identity Center | SSO for all accounts — connected to EC2-hosted AD via AD Connector or self-managed |
| Secrets management | AWS Secrets Manager + KMS | Encryption keys and credential storage |

### 7.4 Wave Sequencing Principles

- Non-production before production
- Low-complexity, low-risk workloads first
- Dependencies migrated before dependent workloads
- Database migration preceded by SCT assessment and test migration
- AD trust established before any workload migration; full AD migration in final wave

---

## 8. Core AWS Services

### 8.1 Migration Services

| Service | Purpose |
|---------|---------|
| **AWS Application Discovery Service (ADS)** | Agent-based discovery of on-premises (SDDC) servers — inventory, utilisation, dependencies |
| **AWS Migration Hub** | Centralised tracking of migration status across all tools and waves |
| **AWS Application Migration Service (MGN)** | Continuous block-level replication of VMs to EC2 (rehost strategy) |
| **AWS Database Migration Service (DMS)** | Continuous data replication for MS SQL Server → RDS and MySQL → Aurora migrations |
| **AWS Schema Conversion Tool (SCT)** | Schema and stored procedure conversion assessment and execution |
| **AWS Transfer Family** | Managed SFTP/FTPS/FTP service replacing file transfer servers |

### 8.2 Service Selection Rationale

| Decision | Recommendation | Alternatives Considered | Rationale |
|----------|---------------|------------------------|-----------|
| VM rehost tooling | AWS MGN | CloudEndure (deprecated), manual AMI | MGN is AWS-native, free, supports continuous replication, minimal cutover window |
| MySQL target | Aurora Serverless v2 | RDS MySQL, Aurora Provisioned | Serverless v2 provides auto-scaling, cost optimisation for variable workloads, MySQL compatibility |
| SQL Server target | RDS for SQL Server Multi-AZ | EC2 self-managed, RDS Single-AZ | Managed patching, automated backups, Multi-AZ HA without operational overhead |
| Container platform | ECS + Fargate | EKS, EC2-based ECS | Fargate removes node management; ECS simpler than EKS for teams without Kubernetes expertise |
| Identity | Active Directory on EC2 | AWS Managed Microsoft AD, Entra ID | Full administrative flexibility required; AWS Managed AD limits schema extensions, GPO depth, and forest-level control; EC2-hosted AD preserves existing operational model |
| NAS — NetApp | Amazon FSx for NetApp ONTAP | EFS, FSx for Lustre, S3 | Native ONTAP protocol support (NFS/SMB/iSCSI); zero-effort data migration via SnapMirror; preserves NetApp operational tooling |
| NAS — Windows File Server | Amazon FSx for Windows File Server | EFS, FSx for NetApp ONTAP | Native Windows SMB, DFS, AD integration; purpose-built for Windows file share replacement |

---

## 9. Landing Zone Design

### 9.1 AWS Control Tower Configuration

| Control | Detail |
|---------|--------|
| Baseline guardrails | AWS Control Tower mandatory and strongly recommended guardrails enabled |
| Custom SCPs | Deny root account usage, deny disabling CloudTrail, deny leaving AWS Organizations, restrict to approved regions |
| Account vending | Account Factory for Terraform (AFT) for automated account provisioning |
| Tagging policy | Enforced via AWS Config rules — mandatory tags: Environment, Owner, CostCentre, Application, MigrationWave |

### 9.2 Service Control Policies (SCPs)

| SCP | Scope | Purpose |
|-----|-------|---------|
| Deny root account actions | All accounts | Prevent root credential usage |
| Restrict to approved regions | Workload OUs | Limit resource creation to approved AWS regions |
| Deny disabling security services | All accounts | Prevent disabling CloudTrail, GuardDuty, Config, Security Hub |
| Require encryption | Workload OUs | Deny creation of unencrypted S3 buckets, EBS volumes, RDS instances |
| Deny public S3 buckets | All accounts | Enforce S3 Block Public Access |

### 9.3 Shared Services Account

| Service | Purpose |
|---------|---------|
| Active Directory on EC2 | Domain Controllers on Windows Server EC2 — full admin control; min 2 DCs across AZs |
| Amazon FSx for NetApp ONTAP | Managed NetApp ONTAP file system for NAS migration (NetApp source workloads) |
| Amazon FSx for Windows File Server | Managed Windows file shares for NAS migration (Windows file server source workloads) |
| AWS Transfer Family | Managed file transfer (SFTP/FTPS) |
| Internal tooling | CI/CD pipelines, Terraform state (S3 + DynamoDB) |
| Route 53 Resolver | Centralised DNS resolution shared via Transit Gateway |

---

## 10. Network Design

### 10.1 VPC Architecture

```
Network Hub Account
├── Transit Gateway (centralised routing hub — eu-central-1)
├── TGW Peering → DR Transit Gateway (eu-west-1)
├── VPN / Direct Connect (SDDC ↔ AWS migration path)
└── Route 53 Resolver (inbound/outbound endpoints)

Production Account VPC
├── Public Subnets (ALB, NAT Gateway)
├── Application Subnets (EC2, ECS Tasks)
└── Data Subnets (RDS, Aurora, FSx — no internet route)

Non-Production Account VPC
├── Application Subnets
└── Data Subnets

Shared Services Account VPC
├── AD subnets — EC2 Domain Controllers (min 2 AZs)
├── FSx for NetApp ONTAP subnets
├── FSx for Windows File Server subnets
└── Transfer Family subnets
```

### 10.2 Connectivity

| Connection | Purpose | Detail |
|-----------|---------|--------|
| Site-to-Site VPN / Direct Connect | SDDC ↔ AWS (migration traffic) | Established in Phase 1 Foundation; required for MGN and DMS replication |
| Transit Gateway | VPC-to-VPC routing | Hub-and-spoke; route table segmentation between prod, non-prod, shared services |
| VPC Peering | N/A (TGW preferred) | Not used — Transit Gateway covers all inter-VPC connectivity |
| Route 53 Resolver | DNS | Hybrid resolution — VMware-hosted AD DNS ↔ AWS Route 53 private hosted zones |

### 10.3 Network Security

| Control | Implementation |
|---------|---------------|
| Security Groups | Least-privilege, application-tier scoped |
| Network ACLs | Subnet-level additional controls for data tier |
| VPC Flow Logs | Enabled on all VPCs, delivered to Log Archive account |
| No direct internet access for data tier | Data subnets — no NAT Gateway route |
| Egress filtering | VPC endpoints for AWS services (S3, Secrets Manager, KMS, ECR) |

---

## 11. Security and Compliance

### 11.1 Security Architecture — Defence in Depth

| Layer | Controls |
|-------|---------|
| **Perimeter** | AWS WAF (web workloads), Security Groups, NACLs |
| **Identity** | AWS IAM (least privilege), IAM Identity Center (SSO), Managed AD |
| **Data** | KMS encryption at rest (RDS, Aurora, S3, EBS), TLS in transit |
| **Detection** | GuardDuty (threat detection), Security Hub (aggregated findings), Config (compliance rules) |
| **Audit** | CloudTrail (org trail), VPC Flow Logs, RDS/Aurora audit logging |
| **Response** | Security Hub + EventBridge → SNS/Lambda for automated remediation (Phase 2) |

### 11.2 Encryption Standards

| Resource | Encryption |
|----------|-----------|
| RDS for SQL Server | Encrypted at rest (KMS CMK), SSL/TLS in transit |
| Aurora Serverless v2 | Encrypted at rest (KMS CMK), TLS in transit |
| EBS volumes (EC2) | Encrypted by default (KMS) |
| S3 (log archive, Terraform state) | SSE-KMS |
| Secrets (DB credentials, API keys) | AWS Secrets Manager with KMS CMK |

### 11.3 Compliance Posture

| Requirement | Control |
|-------------|---------|
| Data residency | SCPs restrict resource creation to approved regions |
| Audit logging | CloudTrail org trail + S3 archive (immutable with S3 Object Lock) |
| Access reviews | IAM Access Analyzer, quarterly access reviews |
| Vulnerability management | Amazon Inspector on EC2 and ECR images |
| Privacy / data protection | Non-migratable workloads retained in SDDC; data classification to be completed in Phase 0 |

---

## 12. Identity and Access Management

### 12.1 Identity Strategy — Active Directory on EC2

Active Directory will be rehosted to Amazon EC2 rather than migrated to AWS Managed Microsoft AD. This decision preserves full administrative flexibility including:

- Unrestricted schema extensions
- Full Group Policy Object (GPO) depth and custom ADMX templates
- Forest and domain functional level control
- Custom DNS zones and delegation
- Fine-grained password policies without restriction
- Direct access to AD database (ntds.dit) and SYSVOL
- Support for complex trust configurations

> **Note:** A dedicated solution design for the AD-on-EC2 migration is planned as a separate repository and case study (Phase 3). This section provides a high-level design sufficient for migration wave planning.

### 12.2 AD Migration Path

```
Phase 1 (Foundation):
  Deploy new EC2-hosted AD DCs in shared-services VPC (eu-central-1)
  └── Establish two-way forest trust with SDDC AD (sddc.local)
  └── Domain join migrated Windows workloads to AWS AD domain

Phase 4 (Final Wave):
  Migrate remaining AD objects (users, groups, GPOs, DNS zones)
  └── Full FSMO role transfer to EC2 DCs
  └── Demote SDDC AD DCs
  └── Remove forest trust
  └── SDDC AD decommissioned
```

### 12.3 EC2 Domain Controller Configuration (High-Level)

| Parameter | Value |
|-----------|-------|
| OS | Windows Server 2022 (latest) |
| Instance type | `m6i.large` (minimum); right-size based on object count |
| Deployment | Minimum 2 DCs across 2 AZs in shared-services VPC |
| DR | 1 DC replicated to eu-west-1 DR region (read-only DC or writable depending on DR requirements) |
| Domain name | `corp.cloud.internal` (new AWS domain) |
| Trust | Two-way forest trust with `sddc.local` during migration period |
| DNS | EC2 AD DNS integrated with Route 53 Resolver for hybrid resolution |
| Storage | EBS `gp3` encrypted with KMS CMK for OS and SYSVOL/NTDS volumes |

### 12.4 AWS IAM Identity Center (SSO)

IAM Identity Center is connected to the EC2-hosted AD using **AD Connector** (a lightweight proxy — no data replicated to AWS) or directly via the self-managed AD identity source option.

| Configuration | Detail |
|--------------|--------|
| Identity source | EC2-hosted AD via AD Connector (eu-central-1) |
| Permission sets | Defined per role (ReadOnly, Developer, DBA, SecurityAudit, PlatformAdmin) |
| MFA | Enforced for all users |
| Account access | Assigned via IAM Identity Center — no long-term IAM users for human access |

### 12.5 IAM Principles

- No long-term access keys for human users
- EC2 and ECS workloads use IAM roles (instance profiles / task roles)
- DMS and MGN use scoped IAM roles with minimum required permissions
- All privileged actions require MFA
- Break-glass accounts exist in Management account with strict alerting
- AD admin credentials stored in AWS Secrets Manager with KMS encryption

---

## 13. Database Migration Design

### 13.1 MS SQL Server → Amazon RDS for SQL Server

| Attribute | Detail |
|-----------|--------|
| Source | MS SQL Server on Windows VMs (VMware SDDC) |
| Target | Amazon RDS for SQL Server (Multi-AZ deployment) |
| Migration tooling | AWS DMS (full load + CDC for ongoing replication), AWS SCT (schema assessment) |
| Licensing | License Included (RDS) or BYOL — to be determined based on existing licence agreements |
| Edition | To be confirmed via SCT assessment (Standard or Enterprise feature usage) |
| HA | Multi-AZ enabled (synchronous standby in second AZ) |
| Backups | Automated RDS backups (retention 7–35 days), manual snapshots pre-cutover |
| Encryption | KMS CMK at rest, SSL enforcement in transit |
| Cutover approach | DMS CDC keeps target in sync; cutover during maintenance window with application connection string update |

**SCT Pre-Assessment Actions:**
- Identify SQL Server-specific features (linked servers, CLR, SSRS, SSIS) — these may require remediation or alternative services
- Document stored procedures requiring conversion
- Identify any unsupported data types

### 13.2 MySQL → Amazon Aurora Serverless v2 (MySQL-compatible)

| Attribute | Detail |
|-----------|--------|
| Source | MySQL on Windows VMs (VMware SDDC) |
| Target | Amazon Aurora Serverless v2 (MySQL-compatible) |
| Migration tooling | AWS DMS (full load + CDC), mysqldump for initial assessment |
| Aurora version | MySQL 8.0-compatible (verify source MySQL version compatibility) |
| Scaling | Aurora Serverless v2 — ACU min/max to be set based on workload profiling from ADS |
| HA | Aurora Multi-AZ (writer + reader replicas); Serverless v2 scales per AZ automatically |
| Backups | Automated Aurora backups, point-in-time recovery (PITR) |
| Encryption | KMS CMK at rest, TLS in transit |
| Cutover approach | DMS CDC replication to near-zero lag; application connection string update; DNS cutover via Route 53 |

**SCT Pre-Assessment Actions:**
- Identify MySQL-specific stored procedures, triggers, and events
- Validate character set and collation compatibility with Aurora MySQL 8.0
- Review any application-level MySQL drivers for Aurora compatibility

### 13.3 Database Migration Workflow

```
1. SCT Assessment
   └── Generate compatibility report
   └── Identify and remediate schema issues

2. DMS Replication Instance Setup
   └── Size replication instance based on data volume and throughput

3. Full Load
   └── DMS full load task (source → target)
   └── Validate row counts and data integrity

4. Change Data Capture (CDC)
   └── Enable DMS CDC task
   └── Monitor replication lag

5. Application Testing
   └── Point test environment at target database
   └── Execute regression tests

6. Cutover
   └── Drain application connections
   └── Stop DMS CDC task
   └── Final data validation
   └── Update connection strings / Route 53 DNS
   └── Monitor post-cutover

7. Rollback Plan
   └── DMS reverse replication (target → source) pre-cutover
   └── Rollback window: defined per wave
```

---

## 14. Non-Migratable Workloads

### 14.1 Exclusion Register

| Category | Examples | Exclusion Reason | Disposition |
|----------|----------|-----------------|-------------|
| Undocumented legacy applications | Applications with no documentation, departed developers, no vendor handover | Cannot assess migration risk or validate post-migration behaviour | Retain in SDDC; initiate documentation effort; plan for future retirement |
| Regulatory/compliance-restricted | Workloads subject to data residency or privacy obligations that preclude cloud hosting | Legal and regulatory constraints | Retain; obtain written compliance determination; review annually |
| Vendor-locked applications | Applications with licensing or contractual restrictions preventing cloud deployment | Incumbent vendor constraints | Engage vendor for cloud licensing path; escalate to commercial team |

### 14.2 Governance of Retained Workloads

- Each retained workload must have a named owner and an entry in the risk register
- Retained workloads remain in the VMware SDDC under existing operational processes
- A formal review gate is scheduled quarterly to assess if retained workloads can be re-classified
- SDDC decommission is conditional on all retained workloads being resolved (migrated, retired, or formally accepted as permanent)

---

## 15. Observability Strategy

### 15.1 Logging Architecture

| Log Type | Source | Destination | Retention |
|----------|--------|-------------|-----------|
| CloudTrail (management events) | All accounts (org trail) | S3 — Log Archive account | 1 year (S3 Object Lock) |
| CloudTrail (data events) | Production accounts | S3 — Log Archive account | 90 days |
| VPC Flow Logs | All VPCs | S3 — Log Archive account | 90 days |
| RDS / Aurora logs | Error, slow query, audit | CloudWatch Logs | 30 days |
| Application logs | ECS tasks, EC2 | CloudWatch Logs | 30 days |
| GuardDuty findings | Security Tooling account | Security Hub | 90 days |

### 15.2 Monitoring and Alerting

| Monitoring Area | Service | Alerts |
|----------------|---------|--------|
| Infrastructure | Amazon CloudWatch | EC2 CPU, memory (CW Agent), ECS task health |
| Database | CloudWatch + RDS Enhanced Monitoring | CPU, connections, replication lag (DMS), storage |
| Security | Security Hub + GuardDuty | Critical and high findings → SNS → operations team |
| Cost | AWS Cost Explorer + Budgets | Per-account budget alerts |
| Migration progress | AWS Migration Hub | Wave completion, replication lag, cutover readiness |

### 15.3 Migration-Specific Monitoring

| Metric | Tool | Threshold |
|--------|------|-----------|
| MGN replication lag | AWS MGN console / CloudWatch | Alert if lag > 1 hour |
| DMS replication lag | DMS CloudWatch metrics | Alert if lag > 5 minutes pre-cutover |
| DMS task errors | DMS CloudWatch | Alert on any task error |
| Network throughput (SDDC ↔ AWS) | VPN/DX CloudWatch | Baseline and alert on saturation |

---

## 16. NAS Storage Migration

> **Scope note:** NAS migration is included in this ADD at a high level to establish scope and service selection. A dedicated solution design, detailed runbooks, and Terraform codebase for NAS migration will be published as a separate repository and case study (Phase 3).

### 16.1 NAS Workload Categories in Scope

| Source | Target | Migration Path |
|--------|--------|---------------|
| NetApp ONTAP (NAS appliances) | Amazon FSx for NetApp ONTAP | NetApp SnapMirror replication |
| Windows Server file shares (SMB) | Amazon FSx for Windows File Server | AWS DataSync |

### 16.2 Amazon FSx for NetApp ONTAP

**Use case:** Replaces existing NetApp ONTAP NAS appliances. Preserves NFS, SMB, and iSCSI protocols, ONTAP CLI/API tooling, and native snapshot and replication capabilities.

| Attribute | Detail |
|-----------|--------|
| Deployment | Multi-AZ (primary + standby in eu-central-1) |
| Capacity | Sized from ADS/NetApp inventory during Phase 0 |
| Storage tier | SSD (primary); capacity pool tiering to S3 for cold data |
| Protocol support | NFS v3/v4, SMB 2/3, iSCSI |
| HA | Automatic failover between primary and standby file systems |
| Encryption | KMS CMK at rest; TLS in transit |
| Backups | Daily automatic FSx backups; NetApp snapshots retained |
| Migration tooling | NetApp SnapMirror (preferred — zero-downtime cutover); AWS DataSync as alternative |
| AD integration | Domain-joined to EC2-hosted AD (`corp.cloud.internal`) |

### 16.3 Amazon FSx for Windows File Server

**Use case:** Replaces Windows Server-based file shares and DFS namespaces. Fully managed, AD-integrated SMB file service.

| Attribute | Detail |
|-----------|--------|
| Deployment | Multi-AZ (eu-central-1) |
| Capacity | Sized from file server inventory during Phase 0 |
| Storage type | SSD |
| Protocol support | SMB 2/3, DFS Namespaces |
| HA | Automatic Multi-AZ failover |
| Encryption | KMS CMK at rest; SMB encryption in transit |
| Backups | Daily automatic FSx backups; VSS snapshots |
| Migration tooling | AWS DataSync (agent deployed in SDDC) |
| AD integration | Joined to EC2-hosted AD (`corp.cloud.internal`); DFS namespace migration included |

### 16.4 Migration Approach (High-Level)

```
NetApp ONTAP:
  SDDC NetApp ONTAP  ──SnapMirror──►  FSx for NetApp ONTAP
                                       └── Cutover: break mirror, remount clients

Windows File Server:
  SDDC Windows SMB shares  ──DataSync agent──►  FSx for Windows File Server
                                                  └── Cutover: update DFS namespace target
                                                       or client drive mappings
```

### 16.5 Key Dependencies

- EC2-hosted AD must be operational before FSx deployment (both FSx services require domain join)
- Network connectivity (VPN/DX) must be in place for DataSync agent and SnapMirror replication
- DFS namespace structure must be documented during Phase 0 discovery
- Share permissions (ACLs) migrated alongside data — DataSync preserves NTFS ACLs for Windows shares

---

## 17. Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|-----------|
| 1 | Incomplete workload inventory leading to missed dependencies | High | High | Mandatory ADS agent deployment; no wave planning until discovery complete |
| 2 | Non-migratable workloads blocking dependency chains | Medium | High | Dependency mapping in Phase 0; decouple dependencies where possible |
| 3 | SQL Server feature incompatibility with RDS (CLR, SSRS, linked servers) | Medium | High | SCT assessment in Phase 0; remediation sprint before migration wave |
| 4 | MySQL version incompatibility with Aurora MySQL 8.0 | Medium | Medium | SCT assessment; test migration in non-production before production wave |
| 5 | EC2-hosted AD failure causing authentication outage for all domain-joined workloads | High | High | Minimum 2 DCs across AZs; DR DC in eu-west-1; automated EC2 health checks and CloudWatch alarms |
| 6 | AD forest trust misconfiguration blocking workload domain join during migration | Medium | High | Test trust in Phase 1 Foundation with non-critical workload before wave migrations begin |
| 7 | Network bandwidth saturation during DMS/MGN/SnapMirror/DataSync replication | Medium | Medium | Schedule replication during off-peak hours; monitor VPN/DX throughput; stagger waves |
| 8 | Regulatory-restricted workloads incorrectly migrated | Low | Critical | Formal compliance sign-off gate (GDPR / German data protection); tagging policy for restricted workloads |
| 9 | NAS share permission loss during DataSync migration | Medium | Medium | Test DataSync NTFS ACL preservation in non-prod before production; validate permissions post-migration |
| 10 | NetApp SnapMirror incompatibility between ONTAP versions | Low | Medium | Validate ONTAP version compatibility between source and FSx target in Phase 0 |
| 11 | Undocumented applications causing post-migration failures | High | Medium | Retain undocumented workloads; do not migrate without documentation gate |
| 12 | Terraform state corruption or loss | Low | High | Remote Terraform state in S3 with versioning and DynamoDB locking; state in dedicated account |
| 13 | SDDC decommission initiated before all workloads resolved | Low | Critical | Formal decommission checklist; sign-off from application owners and compliance |

---

## 17. Success Criteria and KPIs

### 17.1 Migration Success Criteria

| Criterion | Measurement |
|-----------|------------|
| All in-scope workloads migrated or formally retained | Migration Hub — 100% workload disposition |
| Zero unplanned outages during cutover windows | Cutover incident log |
| RTO/RPO targets met for all production workloads | DR test results post-migration |
| All production databases encrypted at rest and in transit | Config rule compliance report |
| FSx file systems accessible and permissions validated post-migration | Post-migration acceptance test |
| EC2-hosted AD operational across 2 AZs; DR DC in eu-west-1 confirmed | AD health check, replication test |
| CloudTrail enabled on all accounts | AWS Config rule: cloud-trail-enabled |
| GuardDuty enabled on all accounts | AWS Config rule: guardduty-enabled-centralized |
| No critical Security Hub findings unresolved > 7 days | Security Hub dashboard |
| All resources tagged per tagging policy | Config rule: required-tags |
| SDDC decommissioned within agreed timeline | Project milestone tracker |

### 17.2 Go / No-Go Gates

| Gate | Condition |
|------|-----------|
| Foundation complete | Landing Zone deployed (eu-central-1), networking validated, EC2-hosted AD trust established, VPN/DX live |
| Wave ready | All workloads in wave dependency-mapped; non-prod test migration passed; rollback plan documented |
| Cutover ready | DMS/MGN replication lag < threshold; application testing passed; business sign-off obtained |
| NAS cutover ready | SnapMirror/DataSync sync complete; share permissions validated; DFS namespace updated in test |
| SDDC decommission ready | All in-scope workloads migrated; retained workloads formally accepted; DR tests passed |

---

## 18. Assumptions and Constraints

### Assumptions

| # | Assumption |
|---|-----------|
| 1 | Primary AWS region is Frankfurt (eu-central-1); DR region is Ireland (eu-west-1) |
| 2 | All production workloads and data must remain within the EU for GDPR and German data protection compliance |
| 3 | AWS Direct Connect or Site-to-Site VPN is available or will be provisioned for migration traffic |
| 4 | Application teams are available to support testing and cutover activities |
| 5 | Legal and compliance team will provide written determination on non-migratable workloads |
| 6 | Existing SQL Server and MySQL licenses have been reviewed for BYOL eligibility |
| 7 | AWS Control Tower is available in the target AWS Organisation |
| 8 | Source MySQL version is compatible with Aurora MySQL 8.0 (to be validated by SCT) |
| 9 | Source NetApp ONTAP version supports SnapMirror to FSx for NetApp ONTAP (to be validated in Phase 0) |
| 10 | AD team has capacity and expertise to deploy and manage Active Directory on EC2 |
| 11 | Business stakeholders will attend and sign off on Phase 0 discovery workshops |

### Constraints

| # | Constraint |
|---|-----------|
| 1 | All workloads and data must be deployed in EU regions only (eu-central-1 primary, eu-west-1 DR) |
| 2 | Non-migratable workloads cannot be moved to AWS until compliance review is complete |
| 3 | AWS Managed Microsoft AD is not to be used — Active Directory will be hosted on EC2 for full administrative control |
| 4 | Terraform is the mandated IaC tooling — no CloudFormation or CDK |
| 5 | All production workloads require Multi-AZ deployment |
| 6 | Cutover windows must be agreed with business stakeholders — no unilateral cutovers |
| 7 | SDDC cannot be decommissioned until all retained workload dispositions are formally resolved |

---

## 19. Next Steps — Phase 2 Triggers

Phase 2 (Low-Level Design, Terraform, Architecture Diagrams) will commence upon:

| Trigger | Owner |
|---------|-------|
| ✅ ADD v1.1 reviewed and approved by stakeholders | Solution Architect + Stakeholders |
| ✅ Phase 0 discovery complete — ADS agent deployed, inventory exported | Infrastructure Engineer |
| ✅ 6R classification finalised with application owners | Solution Architect + App Teams |
| ✅ SCT assessments complete for SQL Server and MySQL | DBA |
| ✅ NAS inventory complete — NetApp ONTAP versions and share sizes confirmed | Storage Engineer |
| ✅ Compliance determination documented for non-migratable workloads | Legal / Compliance |
| ✅ Target AWS regions confirmed (eu-central-1 primary, eu-west-1 DR) | Architecture Board |
| ✅ Landing Zone account structure approved | Cloud Platform Team |

### Phase 2 Deliverables

| Artifact | Description |
|----------|-------------|
| Low-Level Design document | Detailed subnet design, security group rules, IAM policies, RDS/Aurora config, ECS task definitions |
| Terraform codebase | Landing zone, networking, compute, database, security modules |
| AWS Architecture Diagram | Current state → target state; landing zone; network topology; database migration flow |
| DMS / MGN runbooks | Step-by-step migration execution runbooks |
| Rollback playbooks | Per-wave rollback procedures |
| Cost model | AWS Pricing Calculator output based on right-sizing data |

### Phase 3 Planned Separate Repositories

| Repository / Case Study | Scope |
|-------------------------|-------|
| AD on EC2 Migration | Detailed design, runbooks, and Terraform for on-premises AD → EC2-hosted AD |
| NAS to AWS Migration | Detailed design for NetApp ONTAP → FSx for NetApp ONTAP and Windows File Server → FSx for Windows File Server |
| Workload Containerisation | ECS/Fargate containerisation design patterns and CI/CD pipeline |
| Backup and Disaster Recovery | AWS Backup, DR architecture (eu-central-1 → eu-west-1), and runbooks |

---

*Document Version 1.1 — Public Reference Framework*
*Licensed under the MIT License — free to use, adapt, and build upon.*
*Changes in v1.1: Primary region set to Frankfurt (eu-central-1); DR region Ireland (eu-west-1); AD strategy changed to EC2-hosted (full admin control); NAS migration scope added (FSx for NetApp ONTAP, FSx for Windows File Server); risks and assumptions updated.*
