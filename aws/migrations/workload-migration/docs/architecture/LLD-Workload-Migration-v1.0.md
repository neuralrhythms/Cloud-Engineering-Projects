# Low-Level Design Document
# Workload Migration: VMware on AWS SDDC → AWS Cloud Native

| Field | Value |
|-------|-------|
| Document Version | 1.1 |
| Status | Draft — Updated |
| Author | Senior Solution Architect |
| Date | June 2026 |
| Classification | Public — Reference Framework |
| Related ADD | [ADD-Workload-Migration-v1.0.md](ADD-Workload-Migration-v1.0.md) |

---

> **Framework Notice**
> This LLD is a reusable reference for AWS workload migration projects.
> All CIDR ranges, account IDs, and resource names are illustrative and should be
> replaced with organisation-specific values before implementation.
> Licensed under the [MIT License](../../../LICENSE).

---

## Table of Contents

1. [AWS Region and Availability Zones](#1-aws-region-and-availability-zones)
2. [Account Structure Detail](#2-account-structure-detail)
3. [Network Low-Level Design](#3-network-low-level-design)
4. [Security Groups](#4-security-groups)
5. [IAM Roles and Policies](#5-iam-roles-and-policies)
6. [Landing Zone — Control Tower and SCPs](#6-landing-zone--control-tower-and-scps)
7. [Shared Services — Active Directory on EC2](#7-shared-services--active-directory-on-ec2)
8. [Database Low-Level Design](#8-database-low-level-design)
9. [Compute — EC2 Rehost Configuration](#9-compute--ec2-rehost-configuration)
10. [Compute — ECS Fargate Configuration](#10-compute--ecs-fargate-configuration)
11. [File Transfer — AWS Transfer Family](#11-file-transfer--aws-transfer-family)
12. [Observability Configuration](#12-observability-configuration)
13. [Migration Tooling Configuration](#13-migration-tooling-configuration)
14. [Terraform State Management](#14-terraform-state-management)
15. [Tagging Strategy](#15-tagging-strategy)
16. [NAS Storage Migration — High-Level Design](#16-nas-storage-migration--high-level-design)

---

## 1. AWS Region and Availability Zones

| Parameter | Value |
|-----------|-------|
| Primary Region | `eu-central-1` (Frankfurt) — business headquartered in Germany |
| Availability Zones | `eu-central-1a`, `eu-central-1b`, `eu-central-1c` |
| DR Region | `eu-west-1` (Ireland) — disaster recovery region |
| DR Availability Zones | `eu-west-1a`, `eu-west-1b`, `eu-west-1c` |

> All CIDR ranges and resource configurations in this document apply to the primary region (`eu-central-1`). DR region configurations follow the same patterns with equivalent CIDR allocations and are addressed in the Backup and Disaster Recovery case study (Phase 3).

---

## 2. Account Structure Detail

### 2.1 Account Register

| Account Name | OU | Purpose | CIDR Block |
|-------------|-----|---------|-----------|
| `management` | Root | Billing, AWS Organizations, Control Tower management only | N/A |
| `log-archive` | Security OU | Centralised CloudTrail, VPC Flow Logs, Config log destination | N/A (no workload VPC) |
| `security-tooling` | Security OU | Security Hub delegated admin, GuardDuty master, Inspector | N/A (no workload VPC) |
| `network-hub` | Infrastructure OU | Transit Gateway, VPN/DX, Route 53 Resolver endpoints | `10.0.0.0/16` |
| `shared-services` | Infrastructure OU | AD on EC2, FSx for NetApp ONTAP, FSx for Windows File Server, Transfer Family, Terraform state, CI/CD | `10.1.0.0/16` |
| `workload-prod` | Workloads OU | Production EC2, ECS, RDS, Aurora workloads | `10.2.0.0/16` |
| `workload-nonprod` | Workloads OU | Dev/Test/Staging workloads | `10.3.0.0/16` |
| `sandbox` | Sandbox OU | Experimentation, isolated | `10.4.0.0/16` |

### 2.2 CIDR Allocation Summary

```
10.0.0.0/8  — Reserved for AWS cloud environment (non-overlapping with SDDC)
  10.0.0.0/16  — Network Hub
  10.1.0.0/16  — Shared Services
  10.2.0.0/16  — Workload Production
  10.3.0.0/16  — Workload Non-Production
  10.4.0.0/16  — Sandbox

192.168.0.0/16 — VMware SDDC (existing — do not overlap)
  10.10.0.0/16 — SDDC internal (from inventory)
```

> Verify no CIDR overlap with existing SDDC (10.10.0.0/16) before deployment.

---

## 3. Network Low-Level Design

### 3.1 Network Hub VPC (`network-hub` account)

| Subnet | AZ | CIDR | Purpose |
|--------|-----|------|---------|
| `snet-tgw-a` | eu-central-1a | `10.0.0.0/28` | Transit Gateway attachment |
| `snet-tgw-b` | eu-central-1b | `10.0.0.16/28` | Transit Gateway attachment |
| `snet-tgw-c` | eu-central-1c | `10.0.0.32/28` | Transit Gateway attachment |
| `snet-vpn-a` | eu-central-1a | `10.0.1.0/28` | VPN / DX attachment |
| `snet-vpn-b` | eu-central-1b | `10.0.1.16/28` | VPN / DX attachment |
| `snet-r53-a` | eu-central-1a | `10.0.2.0/28` | Route 53 Resolver inbound/outbound endpoints |
| `snet-r53-b` | eu-central-1b | `10.0.2.16/28` | Route 53 Resolver inbound/outbound endpoints |

**Transit Gateway Configuration:**

| Parameter | Value |
|-----------|-------|
| ASN | `64512` |
| Default route table association | Disabled (custom route tables per OU) |
| DNS support | Enabled |
| VPN ECMP | Enabled |
| Attachments | network-hub VPC, shared-services VPC, prod VPC, nonprod VPC |
| Inter-region peering | TGW peering to DR Transit Gateway in eu-west-1 |

**TGW Route Tables:**

| Route Table | Associated VPCs | Routes |
|-------------|----------------|--------|
| `rtb-prod` | workload-prod | → shared-services VPC, → network-hub (internet/SDDC egress) |
| `rtb-nonprod` | workload-nonprod, sandbox | → shared-services VPC, → network-hub; no route to prod |
| `rtb-shared` | shared-services | → prod, → nonprod, → network-hub |
| `rtb-hub` | network-hub | → all VPCs (SDDC VPN/DX route propagation) |

---

### 3.2 Shared Services VPC (`shared-services` account)

| Subnet | AZ | CIDR | Purpose |
|--------|-----|------|---------|
| `snet-tgw-a` | eu-central-1a | `10.1.0.0/28` | TGW attachment |
| `snet-tgw-b` | eu-central-1b | `10.1.0.16/28` | TGW attachment |
| `snet-tgw-c` | eu-central-1c | `10.1.0.32/28` | TGW attachment |
| `snet-ad-a` | eu-central-1a | `10.1.1.0/27` | Active Directory EC2 Domain Controllers (DC 1) |
| `snet-ad-b` | eu-central-1b | `10.1.1.32/27` | Active Directory EC2 Domain Controllers (DC 2) |
| `snet-fsx-netapp-a` | eu-central-1a | `10.1.2.0/26` | FSx for NetApp ONTAP preferred subnet |
| `snet-fsx-netapp-b` | eu-central-1b | `10.1.2.64/26` | FSx for NetApp ONTAP standby subnet |
| `snet-fsx-windows-a` | eu-central-1a | `10.1.3.0/27` | FSx for Windows File Server preferred subnet |
| `snet-fsx-windows-b` | eu-central-1b | `10.1.3.32/27` | FSx for Windows File Server standby subnet |
| `snet-transfer-a` | eu-central-1a | `10.1.4.0/27` | AWS Transfer Family endpoints |
| `snet-transfer-b` | eu-central-1b | `10.1.4.32/27` | AWS Transfer Family endpoints |
| `snet-tools-a` | eu-central-1a | `10.1.5.0/26` | CI/CD, Terraform tooling, internal services |
| `snet-tools-b` | eu-central-1b | `10.1.5.64/26` | CI/CD, Terraform tooling, internal services |

**Route Tables:**

| Route Table | Destination | Target |
|------------|-------------|--------|
| All subnets | `0.0.0.0/0` | TGW (no direct internet; egress via network-hub NAT) |
| All subnets | `10.0.0.0/8` | TGW |

---

### 3.3 Production Workload VPC (`workload-prod` account)

| Subnet | AZ | CIDR | Purpose |
|--------|-----|------|---------|
| `snet-tgw-a` | eu-central-1a | `10.2.0.0/28` | TGW attachment |
| `snet-tgw-b` | eu-central-1b | `10.2.0.16/28` | TGW attachment |
| `snet-tgw-c` | eu-central-1c | `10.2.0.32/28` | TGW attachment |
| `snet-public-a` | eu-central-1a | `10.2.1.0/26` | ALB, NAT Gateway |
| `snet-public-b` | eu-central-1b | `10.2.1.64/26` | ALB, NAT Gateway |
| `snet-public-c` | eu-central-1c | `10.2.1.128/26` | ALB |
| `snet-app-a` | eu-central-1a | `10.2.2.0/25` | EC2 (rehost), ECS tasks |
| `snet-app-b` | eu-central-1b | `10.2.2.128/25` | EC2 (rehost), ECS tasks |
| `snet-app-c` | eu-central-1c | `10.2.3.0/25` | EC2 (rehost), ECS tasks |
| `snet-data-a` | eu-central-1a | `10.2.4.0/26` | RDS for SQL Server, Aurora Serverless v2 |
| `snet-data-b` | eu-central-1b | `10.2.4.64/26` | RDS for SQL Server, Aurora Serverless v2 |
| `snet-data-c` | eu-central-1c | `10.2.4.128/26` | Aurora replica |
| `snet-mgn-a` | eu-central-1a | `10.2.5.0/27` | AWS MGN replication servers |
| `snet-mgn-b` | eu-central-1b | `10.2.5.32/27` | AWS MGN replication servers |

**Route Tables:**

| Route Table | Subnet | Destination | Target |
|------------|--------|-------------|--------|
| `rtb-public` | public subnets | `0.0.0.0/0` | Internet Gateway |
| `rtb-public` | public subnets | `10.0.0.0/8` | TGW |
| `rtb-app` | app subnets | `0.0.0.0/0` | NAT Gateway (az-a) |
| `rtb-app` | app subnets | `10.0.0.0/8` | TGW |
| `rtb-data` | data subnets | `10.0.0.0/8` | TGW only — no internet route |

---

### 3.4 Non-Production Workload VPC (`workload-nonprod` account)

Mirrors production VPC layout with smaller CIDR allocations:

| Subnet | AZ | CIDR | Purpose |
|--------|-----|------|---------|
| `snet-tgw-a/b/c` | all | `10.3.0.0/28`, `/16`, `/32` | TGW attachments |
| `snet-public-a/b` | eu-central-1a/b | `10.3.1.0/26`, `10.3.1.64/26` | ALB, NAT |
| `snet-app-a/b` | eu-central-1a/b | `10.3.2.0/25`, `10.3.2.128/25` | EC2, ECS |
| `snet-data-a/b` | eu-central-1a/b | `10.3.4.0/26`, `10.3.4.64/26` | RDS, Aurora (dev) |

---

### 3.5 VPC Endpoints

Deployed in all workload and shared-services VPCs to keep AWS API traffic private:

| Endpoint | Type | VPCs |
|----------|------|------|
| `com.amazonaws.<region>.s3` | Gateway | All |
| `com.amazonaws.<region>.dynamodb` | Gateway | All |
| `com.amazonaws.<region>.secretsmanager` | Interface | Workload, Shared Services |
| `com.amazonaws.<region>.kms` | Interface | Workload, Shared Services |
| `com.amazonaws.<region>.ecr.api` | Interface | Workload |
| `com.amazonaws.<region>.ecr.dkr` | Interface | Workload |
| `com.amazonaws.<region>.logs` | Interface | All |
| `com.amazonaws.<region>.monitoring` | Interface | All |
| `com.amazonaws.<region>.ssm` | Interface | Workload |
| `com.amazonaws.<region>.ssmmessages` | Interface | Workload |
| `com.amazonaws.<region>.ec2messages` | Interface | Workload |

---

### 3.6 Route 53 DNS Design

| Zone Type | Name | Account | Purpose |
|-----------|------|---------|---------|
| Private Hosted Zone | `cloud.internal` | Shared Services | Internal AWS service DNS |
| Private Hosted Zone | `prod.cloud.internal` | workload-prod | Production workload DNS |
| Private Hosted Zone | `nonprod.cloud.internal` | workload-nonprod | Non-prod workload DNS |
| Resolver Inbound Endpoint | — | network-hub | Receives DNS queries from SDDC (AD DNS → AWS) |
| Resolver Outbound Endpoint | — | network-hub | Forwards queries for `sddc.local` to SDDC AD DNS |
| Forwarding Rule | `sddc.local` → SDDC AD DNS IPs | network-hub | Hybrid DNS resolution during migration |

---

## 4. Security Groups

### 4.1 Naming Convention

```
sg-<account-short>-<tier>-<workload>
Example: sg-prod-app-web, sg-prod-data-rds-mssql
```

### 4.2 Production — Application Tier

**`sg-prod-app-web`** (ECS Web Tasks / EC2 Web Servers)

| Direction | Protocol | Port | Source / Destination | Purpose |
|-----------|----------|------|---------------------|---------|
| Inbound | TCP | 443 | `sg-prod-alb` | HTTPS from ALB |
| Inbound | TCP | 80 | `sg-prod-alb` | HTTP from ALB (redirect to HTTPS) |
| Outbound | TCP | 443 | `0.0.0.0/0` | HTTPS to internet (via NAT) |
| Outbound | TCP | 1433 | `sg-prod-data-rds-mssql` | SQL Server |
| Outbound | TCP | 3306 | `sg-prod-data-aurora` | Aurora MySQL |
| Outbound | TCP | 443 | VPC Endpoints SG | AWS API calls |

**`sg-prod-app-backend`** (ECS App Tasks / EC2 App Servers)

| Direction | Protocol | Port | Source / Destination | Purpose |
|-----------|----------|------|---------------------|---------|
| Inbound | TCP | 8080 | `sg-prod-app-web` | Internal app traffic from web tier |
| Outbound | TCP | 1433 | `sg-prod-data-rds-mssql` | SQL Server |
| Outbound | TCP | 3306 | `sg-prod-data-aurora` | Aurora MySQL |
| Outbound | TCP | 443 | VPC Endpoints SG | AWS APIs |

### 4.3 Production — Data Tier

**`sg-prod-data-rds-mssql`** (RDS for SQL Server)

| Direction | Protocol | Port | Source | Purpose |
|-----------|----------|------|--------|---------|
| Inbound | TCP | 1433 | `sg-prod-app-web` | App tier access |
| Inbound | TCP | 1433 | `sg-prod-app-backend` | App tier access |
| Inbound | TCP | 1433 | `sg-prod-dms` | DMS replication instance |
| Outbound | — | — | None | No outbound rules required |

**`sg-prod-data-aurora`** (Aurora Serverless v2 — MySQL)

| Direction | Protocol | Port | Source | Purpose |
|-----------|----------|------|--------|---------|
| Inbound | TCP | 3306 | `sg-prod-app-web` | App tier access |
| Inbound | TCP | 3306 | `sg-prod-app-backend` | App tier access |
| Inbound | TCP | 3306 | `sg-prod-dms` | DMS replication instance |
| Outbound | — | — | None | No outbound rules required |

### 4.4 Migration Tier

**`sg-prod-dms`** (DMS Replication Instance)

| Direction | Protocol | Port | Source / Destination | Purpose |
|-----------|----------|------|---------------------|---------|
| Outbound | TCP | 1433 | `sg-prod-data-rds-mssql` | Write to RDS SQL Server target |
| Outbound | TCP | 3306 | `sg-prod-data-aurora` | Write to Aurora target |
| Outbound | TCP | 1433 | SDDC CIDR `10.10.2.0/24` | Read from source SQL Server VMs |
| Outbound | TCP | 3306 | SDDC CIDR `10.10.2.0/24` | Read from source MySQL VMs |

**`sg-prod-mgn`** (MGN Replication Servers)

| Direction | Protocol | Port | Source / Destination | Purpose |
|-----------|----------|------|---------------------|---------|
| Inbound | TCP | 1500 | SDDC CIDR `10.10.0.0/16` | MGN agent replication traffic |
| Outbound | TCP | 443 | `0.0.0.0/0` | MGN service API (via NAT) |

### 4.5 Shared Services

**`sg-shared-ad`** (Active Directory EC2 Domain Controllers)

| Direction | Protocol | Port | Source | Purpose |
|-----------|----------|------|--------|---------|
| Inbound | TCP/UDP | 53 | `10.0.0.0/8` | DNS |
| Inbound | TCP/UDP | 88 | `10.0.0.0/8` | Kerberos |
| Inbound | TCP | 389 | `10.0.0.0/8` | LDAP |
| Inbound | TCP | 636 | `10.0.0.0/8` | LDAPS |
| Inbound | TCP | 445 | `10.0.0.0/8` | SMB (domain join) |
| Inbound | TCP | 3268-3269 | `10.0.0.0/8` | Global Catalog |
| Inbound | TCP/UDP | 49152-65535 | `10.0.0.0/8` | RPC dynamic ports |

---

## 5. IAM Roles and Policies

### 5.1 EC2 Instance Profile — Rehosted Workloads

**Role:** `role-ec2-workload-prod`

| Permission | Service | Purpose |
|-----------|---------|---------|
| SSM Managed Instance | `ssm:*` (scoped) | Systems Manager Session Manager (no bastion needed) |
| CloudWatch Agent | `cloudwatch:PutMetricData`, `logs:*` | Metrics and log shipping |
| Secrets Manager Read | `secretsmanager:GetSecretValue` (resource scoped) | App credential retrieval |
| KMS Decrypt | `kms:Decrypt`, `kms:GenerateDataKey` (key scoped) | EBS and Secrets decryption |
| S3 Read (app assets) | `s3:GetObject` (bucket scoped) | Application asset retrieval |

### 5.2 ECS Task Execution Role

**Role:** `role-ecs-task-exec-prod`

| Permission | Purpose |
|-----------|---------|
| `ecr:GetAuthorizationToken`, `ecr:BatchGetImage` | Pull container images from ECR |
| `logs:CreateLogStream`, `logs:PutLogEvents` | Ship container logs to CloudWatch |
| `secretsmanager:GetSecretValue` | Inject secrets into ECS task environment |
| `kms:Decrypt` | Decrypt secrets and ECR images |

### 5.3 ECS Task Role — Application Tasks

**Role:** `role-ecs-task-app-prod`

Scoped per application. Minimum viable permissions only:

| Permission | Purpose |
|-----------|---------|
| `secretsmanager:GetSecretValue` (specific secrets ARNs) | DB credentials |
| `s3:GetObject`, `s3:PutObject` (specific bucket ARNs) | App-specific S3 access |
| `kms:Decrypt`, `kms:GenerateDataKey` | Data encryption operations |

### 5.4 DMS Role

**Role:** `role-dms-vpc-management`

Required AWS managed policy: `AmazonDMSVPCManagementRole`
Additional scoped permissions:

| Permission | Purpose |
|-----------|---------|
| `secretsmanager:GetSecretValue` | Source/target DB credentials |
| `kms:Decrypt`, `kms:CreateGrant` | Encryption for DMS replication storage |

### 5.5 MGN Role

**Role:** `role-mgn-agent` (used by MGN agent on source VMs)

Required AWS managed policy: `AWSApplicationMigrationAgentPolicy`

### 5.6 Terraform Deployment Role

**Role:** `role-terraform-deploy` (assumed by CI/CD pipeline via IAM Identity Center)

Scoped to resource types being provisioned per module. Uses IAM permission boundaries to prevent privilege escalation.

---

## 6. Landing Zone — Control Tower and SCPs

### 6.1 SCP Definitions

**`scp-deny-root-actions`** — applied to all OUs except Root

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRootActions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
      }
    }
  ]
}
```

**`scp-restrict-regions`** — applied to Workloads and Infrastructure OUs

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyNonApprovedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*", "organizations:*", "route53:*",
        "budgets:*", "wafv2:*", "cloudfront:*",
        "sts:*", "support:*", "health:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["eu-central-1", "eu-west-1"]
        }
      }
    }
  ]
}
```

**`scp-deny-disable-security-services`** — applied to all OUs

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyDisableSecurityServices",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging", "cloudtrail:DeleteTrail",
        "guardduty:DeleteDetector", "guardduty:DisassociateFromMasterAccount",
        "securityhub:DisableSecurityHub",
        "config:DeleteConfigurationRecorder",
        "config:StopConfigurationRecorder"
      ],
      "Resource": "*"
    }
  ]
}
```

**`scp-require-encryption`** — applied to Workloads OU

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedEBS",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:volume/*",
      "Condition": {
        "Bool": { "ec2:Encrypted": "false" }
      }
    },
    {
      "Sid": "DenyUnencryptedRDS",
      "Effect": "Deny",
      "Action": ["rds:CreateDBInstance", "rds:CreateDBCluster"],
      "Resource": "*",
      "Condition": {
        "Bool": { "rds:StorageEncrypted": "false" }
      }
    }
  ]
}
```

**`scp-deny-public-s3`** — applied to all OUs

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPublicS3",
      "Effect": "Deny",
      "Action": [
        "s3:PutBucketPublicAccessBlock",
        "s3:DeletePublicAccessBlock"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "s3:publicAccessBlockConfiguration/BlockPublicAcls": "false"
        }
      }
    }
  ]
}
```

---

## 7. Shared Services — Active Directory on EC2

> Active Directory is deployed on Amazon EC2 rather than AWS Managed Microsoft AD to preserve full administrative flexibility (schema extensions, GPO depth, FSMO control, custom DNS, trust configurations). Detailed design, runbooks, and Terraform for AD on EC2 are covered in the dedicated AD Migration case study (Phase 3).

### 7.1 Domain Controller Configuration

| Parameter | Value |
|-----------|-------|
| OS | Windows Server 2022 Datacenter (latest AMI) |
| Instance type | `m6i.large` (2 vCPU, 8 GB) — scale up if object count > 50,000 |
| Number of DCs | 2 in primary region (eu-central-1) + 1 read-only DC or writable DC in DR region (eu-west-1) |
| DC 1 subnet | `snet-ad-a` (eu-central-1a) — shared-services VPC |
| DC 2 subnet | `snet-ad-b` (eu-central-1b) — shared-services VPC |
| EBS volumes | OS: 100 GB gp3 (KMS encrypted); NTDS/SYSVOL: 50 GB gp3 (KMS encrypted, separate volume) |
| Domain name | `corp.cloud.internal` |
| NetBIOS name | `CORP` |
| Forest / domain functional level | Windows Server 2016 minimum |
| AD Sites | `AWS-FRA` (eu-central-1), `AWS-DUB` (eu-west-1 DR) |
| DNS | AD-integrated DNS; Route 53 Resolver conditional forwarder for `.aws` and `.amazonaws.com` |
| IAM instance profile | `role-ec2-workload-prod` + additional SSM permissions for patch management |
| Backup | AWS Backup — daily snapshot of EBS volumes; System State backup to S3 |

### 7.2 AD Migration Path

```
Phase 1 (Foundation):
  Deploy DC1 + DC2 on EC2 in shared-services VPC (eu-central-1)
  └── Establish two-way forest trust with SDDC AD (sddc.local)
  └── Configure Route 53 Resolver forwarding rules
  └── Validate domain join of a pilot Windows EC2 instance

Wave 2–3 (Workload Migration):
  All migrated Windows workloads domain-join corp.cloud.internal
  └── Dual-forest trust in place; SDDC AD still authoritative for SDDC workloads

Wave 4 (AD Cutover):
  Transfer FSMO roles to EC2 DCs
  └── Migrate remaining AD objects (users, groups, GPOs, DNS zones)
  └── Demote SDDC AD DCs
  └── Remove forest trust
  └── SDDC AD decommissioned
```

### 7.3 Route 53 Resolver Configuration

| Rule | Type | Domain | Target IPs |
|------|------|--------|-----------|
| Forward `sddc.local` | Forward | `sddc.local` | SDDC AD DNS IPs (`10.10.1.10`, `10.10.1.11`) |
| Forward `corp.cloud.internal` | Forward | `corp.cloud.internal` | EC2 DC IPs in `snet-ad-a/b` |
| Inbound endpoint | — | — | Two IPs in `snet-r53-a/b` — registered with SDDC DNS as conditional forwarder |
| Outbound endpoint | — | — | Two IPs in `snet-r53-a/b` — forwards SDDC domain queries outbound |

### 7.4 IAM Identity Center — AD Connector

IAM Identity Center is connected to the EC2-hosted AD using **AD Connector** deployed in the shared-services account. AD Connector is a lightweight directory proxy — no user data is cached or stored in AWS.

| Parameter | Value |
|-----------|-------|
| Type | AD Connector (Simple or Large — based on user count) |
| Connected directory | `corp.cloud.internal` |
| DNS IPs | EC2 DC IPs in `snet-ad-a/b` |
| VPC | shared-services VPC |
| Subnets | `snet-ad-a`, `snet-ad-b` |

---

## 8. Database Low-Level Design

### 8.1 Amazon RDS for SQL Server

| Parameter | Value |
|-----------|-------|
| Engine | SQL Server 2019 (or match source version) |
| Edition | Standard Edition (validate Enterprise features via SCT) |
| Instance class | `db.m6i.xlarge` (4 vCPU, 16 GB) — adjust post right-sizing |
| Multi-AZ | Enabled (synchronous standby in az-b) |
| Storage type | `gp3` |
| Allocated storage | 500 GB (matches largest source VM disk) |
| Max allocated storage | 2,000 GB (auto-scaling enabled) |
| Storage encryption | KMS CMK (`key-alias/rds-mssql-prod`) |
| DB subnet group | `snet-data-a`, `snet-data-b`, `snet-data-c` |
| Security group | `sg-prod-data-rds-mssql` |
| Parameter group | Custom — enforce SSL, set timezone, query logging |
| Option group | `SQLSERVER_BACKUP_RESTORE` (for native backup/restore) |
| Backup retention | 7 days (automated); manual snapshot before cutover |
| Maintenance window | `sun:02:00-sun:03:00` (off-peak) |
| Deletion protection | Enabled |
| Enhanced Monitoring | Enabled (60-second intervals) |
| Performance Insights | Enabled (7-day free tier retention) |

**RDS Parameter Group (key settings):**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `rds.force_ssl` | `1` | Enforce SSL for all connections |
| `contained database authentication` | `1` | Enable contained databases if required |

### 8.2 Amazon Aurora Serverless v2 (MySQL-compatible)

| Parameter | Value |
|-----------|-------|
| Engine | Aurora MySQL 8.0-compatible |
| Cluster type | Serverless v2 |
| Writer instance | `db.serverless` — min 0.5 ACU, max 16 ACU (adjust per workload) |
| Reader instance | 1 reader replica (`db.serverless`) for read scaling / HA |
| Multi-AZ | Writer in az-a, reader in az-b |
| Storage encryption | KMS CMK (`key-alias/aurora-mysql-prod`) |
| DB subnet group | `snet-data-a`, `snet-data-b`, `snet-data-c` |
| Security group | `sg-prod-data-aurora` |
| Cluster parameter group | Custom — enforce `require_secure_transport=ON`, set `time_zone`, audit logging |
| Backup retention | 7 days; PITR enabled |
| Maintenance window | `sun:03:00-sun:04:00` |
| Deletion protection | Enabled |
| Enhanced Monitoring | Enabled |
| Performance Insights | Enabled |

**Aurora Cluster Parameter Group (key settings):**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `require_secure_transport` | `ON` | Enforce TLS for all connections |
| `server_audit_logging` | `1` | Enable audit logging |
| `server_audit_events` | `CONNECT,QUERY_DDL,QUERY_DML` | Audit event scope |
| `character_set_server` | `utf8mb4` | Unicode character set |
| `collation_server` | `utf8mb4_unicode_ci` | Collation |
| `time_zone` | `UTC` | Standardised timezone |

### 8.3 DMS Replication Instance

| Parameter | Value |
|-----------|-------|
| Instance class | `dms.r6i.xlarge` (4 vCPU, 32 GB) |
| Engine version | Latest stable |
| Multi-AZ | Enabled for production migrations |
| Allocated storage | 200 GB |
| VPC | workload-prod |
| Subnet group | `snet-data-a`, `snet-data-b` |
| Security group | `sg-prod-dms` |
| Publicly accessible | No |

**DMS Endpoints:**

| Endpoint | Type | Engine | Connection |
|----------|------|--------|-----------|
| `ep-src-mssql-01` | Source | sqlserver | `10.10.2.10:1433` (SDDC) via VPN/DX |
| `ep-src-mssql-02` | Source | sqlserver | `10.10.2.11:1433` (SDDC) via VPN/DX |
| `ep-src-mysql-01` | Source | mysql | `10.10.2.20:3306` (SDDC) via VPN/DX |
| `ep-src-mysql-02` | Source | mysql | `10.10.2.21:3306` (SDDC) via VPN/DX |
| `ep-tgt-rds-mssql` | Target | sqlserver | RDS endpoint (AWS-internal) |
| `ep-tgt-aurora-mysql` | Target | aurora | Aurora cluster endpoint (AWS-internal) |

**DMS Task Configuration:**

| Task | Type | Source | Target | Table Mappings |
|------|------|--------|--------|---------------|
| `task-mssql-fullload` | Full Load | ep-src-mssql-01 | ep-tgt-rds-mssql | All schemas |
| `task-mssql-cdc` | CDC only | ep-src-mssql-01 | ep-tgt-rds-mssql | All schemas |
| `task-mysql-fullload` | Full Load | ep-src-mysql-01 | ep-tgt-aurora-mysql | All schemas |
| `task-mysql-cdc` | CDC only | ep-src-mysql-01 | ep-tgt-aurora-mysql | All schemas |

---

## 9. Compute — EC2 Rehost Configuration

### 9.1 MGN Configuration

| Parameter | Value |
|-----------|-------|
| Replication subnet | `snet-mgn-a`, `snet-mgn-b` |
| Replication security group | `sg-prod-mgn` |
| Data routing | Private network (via VPN/DX — no internet) |
| Replication server type | Default (`t3.small`) |
| Use dedicated replication server | No (default) |
| Staging area subnet | `snet-mgn-a` |
| EBS volume type | `gp3` |

**Launch Template (post-migration EC2 defaults):**

| Parameter | Value |
|-----------|-------|
| AMI | Auto-converted from source (MGN) |
| EBS encryption | KMS CMK (default EBS key) |
| IMDSv2 | Required |
| Instance type | Right-sized based on ADS utilisation data |
| Subnet | `snet-app-a/b/c` (application tier) |
| Security group | `sg-prod-app-backend` (legacy) or `sg-prod-app-web` (web-facing) |
| IAM instance profile | `role-ec2-workload-prod` |
| Detailed monitoring | Enabled |
| User data | CloudWatch Agent install + config script |

### 9.2 EC2 Instance Sizing (Indicative)

Based on sample inventory — finalise from ADS utilisation data:

| Source VM | CPUs | RAM (GB) | EC2 Instance Type | Notes |
|-----------|------|----------|------------------|-------|
| SDDC-LEGACY-01 | 4 | 2 | `t3.medium` | Windows Server 2012 R2; ESU eligible on AWS |
| SDDC-LEGACY-02 | 2 | 2 | `t3.medium` | Windows Server 2008 R2; ESU eligible on AWS |
| SDDC-LEGACY-03 | 2 | 1 | `t3.small` | Windows Server 2016 |
| SDDC-LINUX-01 | 4 | 2 | `t3.medium` | Ubuntu 20.04 (RabbitMQ) |
| SDDC-LINUX-02 | 4 | 2 | `t3.medium` | Ubuntu 20.04 |
| SDDC-MON-01 | 4 | 4 | `t3.large` | RHEL 8 (Prometheus/Grafana) |
| SDDC-CICD-01 | 4 | 4 | `t3.large` | Ubuntu 22.04 (Jenkins) |

> All instances use EBS-optimised `gp3` volumes. Enable AWS Nitro-based instance types where possible for better performance and security.

---

## 10. Compute — ECS Fargate Configuration

### 10.1 ECS Cluster

| Parameter | Value |
|-----------|-------|
| Cluster name | `ecs-prod-workloads` |
| Capacity provider | Fargate + Fargate Spot (non-critical tasks only) |
| Container Insights | Enabled (CloudWatch) |
| Namespace | AWS Cloud Map — `prod.cloud.internal` |

### 10.2 Task Definition — Web Tier (Example: IIS → Containerised)

| Parameter | Value |
|-----------|-------|
| Family | `td-web-app` |
| Launch type | Fargate |
| CPU | 1024 (1 vCPU) |
| Memory | 2048 MB |
| Network mode | `awsvpc` |
| Task role | `role-ecs-task-app-prod` |
| Execution role | `role-ecs-task-exec-prod` |
| Container image | `<account>.dkr.ecr.<region>.amazonaws.com/web-app:latest` |
| Container port | 443 |
| Log driver | `awslogs` → CloudWatch log group `/ecs/prod/web-app` |
| Secrets | DB connection string from Secrets Manager |
| Read-only root filesystem | `true` |

### 10.3 ECS Service Configuration

| Parameter | Value |
|-----------|-------|
| Service name | `svc-web-app-prod` |
| Desired count | 2 (min 2 for HA) |
| Subnets | `snet-app-a`, `snet-app-b` |
| Security group | `sg-prod-app-web` |
| Load balancer | ALB target group `tg-web-app-443` |
| Health check | `/health` — 200 OK |
| Deployment | Rolling update (min 50%, max 200%) |
| Auto-scaling | Target tracking — CPU 70% |

### 10.4 Application Load Balancer

| Parameter | Value |
|-----------|-------|
| Scheme | Internet-facing |
| Subnets | `snet-public-a`, `snet-public-b`, `snet-public-c` |
| Security group | `sg-prod-alb` (443 from `0.0.0.0/0`, 80 redirect only) |
| Listener 443 | Forward to target group; ACM certificate |
| Listener 80 | Redirect to 443 |
| Access logs | S3 bucket in log-archive account |
| WAF | AWS WAF WebACL — OWASP managed rule groups |

### 10.5 ECR Repositories

| Repository | Scan on push | Lifecycle policy |
|-----------|-------------|-----------------|
| `web-app` | Enabled | Keep last 10 tagged images; expire untagged after 7 days |
| `app-backend` | Enabled | Keep last 10 tagged images; expire untagged after 7 days |

---

## 11. File Transfer — AWS Transfer Family

### 11.1 Server Configuration

| Parameter | Value |
|-----------|-------|
| Protocol | SFTP (and FTPS if required by existing partners) |
| Endpoint type | VPC (internal endpoint — no public internet exposure) |
| VPC | shared-services VPC |
| Subnets | `snet-transfer-a`, `snet-transfer-b` |
| Security group | `sg-shared-transfer` (port 22 inbound from known partner IPs only) |
| Identity provider | Service managed (SSH keys) — or AWS Directory Service for AD authentication |
| Logging | CloudWatch Logs — `/aws/transfer/<server-id>` |
| Storage backend | Amazon S3 (server-side encrypted with KMS) |

### 11.2 User Configuration

| User | Home directory | S3 bucket | Permissions |
|------|---------------|-----------|------------|
| Per partner / application | Scoped to `/bucket/prefix` | `s3-transfer-prod-<partner>` | `s3:GetObject`, `s3:PutObject` only |

---

## 12. Observability Configuration

### 12.1 CloudWatch Agent Configuration (EC2)

Installed via Systems Manager — `AmazonCloudWatch-linux` and `AmazonCloudWatch-windows` SSM documents.

**Linux metrics collected:**

```json
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/"] },
      "cpu": { "measurement": ["cpu_usage_active"], "totalcpu": true },
      "netstat": { "measurement": ["tcp_established"] }
    }
  }
}
```

**Log groups:**

| Log Group | Source | Retention |
|-----------|--------|-----------|
| `/ec2/prod/system` | OS system logs | 30 days |
| `/ec2/prod/application` | App-specific logs | 30 days |
| `/ecs/prod/<service>` | ECS container stdout/stderr | 30 days |
| `/rds/prod/mssql/error` | RDS SQL Server error log | 30 days |
| `/aurora/prod/mysql/audit` | Aurora audit log | 90 days |
| `/aws/transfer/<server-id>` | Transfer Family | 30 days |

### 12.2 CloudWatch Alarms (Key Alarms)

| Alarm | Metric | Threshold | Action |
|-------|--------|-----------|--------|
| EC2 CPU High | `CPUUtilization` | > 85% for 5 min | SNS → ops |
| EC2 Memory High | `CWAgent/mem_used_percent` | > 85% for 5 min | SNS → ops |
| RDS CPU High | `CPUUtilization` | > 80% for 5 min | SNS → DBA |
| RDS Storage Low | `FreeStorageSpace` | < 20 GB | SNS → DBA |
| RDS Connections High | `DatabaseConnections` | > 200 | SNS → DBA |
| Aurora ACU High | `ServerlessDatabaseCapacity` | > 14 ACU (87.5% of max 16) | SNS → DBA |
| DMS Replication Lag | `CDCLatencySource` | > 300 seconds | SNS → migration team |
| MGN Replication Lag | Custom MGN metric | > 3600 seconds | SNS → migration team |
| ALB 5xx Rate | `HTTPCode_Target_5XX_Count` | > 10 in 1 min | SNS → app team |
| GuardDuty High Finding | Security Hub → EventBridge | Any HIGH/CRITICAL | SNS → security |

### 12.3 CloudTrail Organisation Trail

| Parameter | Value |
|-----------|-------|
| Trail name | `org-trail` |
| Scope | All accounts (organisation trail) |
| Multi-region | Enabled |
| Log file validation | Enabled |
| S3 bucket | `s3-cloudtrail-logs-<log-archive-account-id>` (log-archive account) |
| S3 Object Lock | Compliance mode, 365-day retention |
| KMS encryption | CMK in log-archive account |
| CloudWatch Logs | Enabled — management events stream to CloudWatch |
| Data events | S3 and Lambda (production accounts only) |

---

## 13. Migration Tooling Configuration

### 13.1 AWS MGN — Rehost Workflow

```
Step 1: Create MGN service-linked role in target account
Step 2: Install MGN agent on source SDDC VMs
         Windows: msi installer via SDDC PowerShell
         Linux:   shell script installer via SDDC bash
Step 3: Agent connects to MGN service over TCP 443 (outbound from SDDC via VPN)
Step 4: Initial replication — block-level sync to staging EBS volumes
Step 5: Configure Launch Template per VM (instance type, SG, subnet, IAM role)
Step 6: Test launch — start test instance; run application smoke tests
Step 7: Cutover launch — during maintenance window:
         a. Stop writes on source (application outage)
         b. Wait for final sync (lag → 0)
         c. Launch cutover instance
         d. Update DNS / connection strings
         e. Confirm application functional
         f. Mark migration complete in Migration Hub
Step 8: Decommission source VM in SDDC (after rollback window expires)
```

### 13.2 Rollback Procedure (MGN)

- Cutover window: maximum 4 hours
- If rollback triggered: revert DNS/connection strings to SDDC; source VM remains running during window
- MGN retains source replication until explicitly disconnected

### 13.3 AWS DMS — Database Migration Workflow

```
Step 1: Deploy DMS replication instance in workload-prod VPC
Step 2: Create source endpoints (SDDC IPs via VPN/DX)
Step 3: Create target endpoints (RDS/Aurora — internal DNS)
Step 4: Test endpoint connections
Step 5: Run SCT conversion (schema pre-migration)
Step 6: Execute Full Load task — validate row counts and checksums
Step 7: Enable CDC task — monitor replication lag
Step 8: Point test environment at target DB — regression tests
Step 9: Cutover:
         a. Set application to read-only or maintenance mode
         b. Wait for CDC lag < 5 seconds
         c. Stop CDC task
         d. Final row count validation
         e. Update Secrets Manager with new DB endpoint
         f. Restart application — smoke test
         g. Monitor for 30 minutes
Step 10: Decommission source DB VM after rollback window (24-48 hours)
```

---

## 14. Terraform State Management

### 14.1 Remote State Configuration

| Parameter | Value |
|-----------|-------|
| Backend | S3 + DynamoDB |
| S3 bucket | `s3-tfstate-<shared-services-account-id>-<region>` |
| S3 versioning | Enabled |
| S3 encryption | SSE-KMS |
| S3 Object Lock | Governance mode |
| DynamoDB table | `ddb-terraform-state-lock` |
| DynamoDB billing | PAY_PER_REQUEST |

### 14.2 State File Structure

```
s3://s3-tfstate-<account-id>-eu-central-1/
├── landing-zone/terraform.tfstate
├── networking/network-hub/terraform.tfstate
├── networking/shared-services/terraform.tfstate
├── networking/workload-prod/terraform.tfstate
├── networking/workload-nonprod/terraform.tfstate
├── compute/workload-prod/terraform.tfstate
├── database/workload-prod/terraform.tfstate
└── security/terraform.tfstate
```

### 14.3 Terraform Backend Block (template)

```hcl
terraform {
  backend "s3" {
    bucket         = "s3-tfstate-<account-id>-eu-central-1"
    key            = "<module>/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "ddb-terraform-state-lock"
  }
}
```

---

## 15. Tagging Strategy

### 15.1 Mandatory Tags (enforced via AWS Config)

| Tag Key | Example Value | Purpose |
|---------|--------------|---------|
| `Environment` | `prod`, `nonprod`, `sandbox` | Environment identification |
| `Owner` | `platform-team@example.com` | Resource owner for cost and ops |
| `CostCentre` | `CC-12345` | FinOps cost allocation |
| `Application` | `crm`, `erp`, `web-portal` | Application grouping |
| `MigrationWave` | `wave-1`, `wave-2`, `wave-3` | Migration tracking |

### 15.2 Recommended Additional Tags

| Tag Key | Example Value | Purpose |
|---------|--------------|---------|
| `DataClassification` | `internal`, `confidential`, `restricted` | Data governance |
| `BackupPolicy` | `daily-7d`, `daily-30d`, `none` | AWS Backup policy selection |
| `PatchGroup` | `windows-prod`, `linux-prod` | SSM Patch Manager group |
| `TerraformManaged` | `true` | Identify IaC-managed resources |

---

## 16. NAS Storage Migration — High-Level Design

> **Scope note:** This section provides the high-level design parameters needed for network, subnet, and security group planning. A full LLD, Terraform codebase, and migration runbooks for NAS are covered in the dedicated NAS to AWS Migration case study (Phase 3).

### 16.1 Amazon FSx for NetApp ONTAP

**Replaces:** NetApp ONTAP NAS appliances in the SDDC.

| Parameter | Value |
|-----------|-------|
| Deployment type | Multi-AZ |
| Preferred subnet | `snet-fsx-netapp-a` (eu-central-1a) |
| Standby subnet | `snet-fsx-netapp-b` (eu-central-1b) |
| Storage capacity | Sized from NetApp inventory in Phase 0 |
| Storage tier | SSD (primary); capacity pool tiering to S3 for cold data |
| Throughput capacity | Set based on workload profiling (minimum 128 MB/s) |
| Protocol support | NFS v3/v4.1, SMB 2/3, iSCSI |
| AD integration | Joined to `corp.cloud.internal` (EC2-hosted AD) |
| Encryption at rest | KMS CMK |
| Encryption in transit | TLS (SMB encryption, NFS Kerberos) |
| Backups | Daily automatic FSx backups; NetApp snapshot policy retained |
| Migration tooling | NetApp SnapMirror (primary); AWS DataSync (fallback) |
| Security group | `sg-shared-fsx-netapp` — allow NFS (2049), SMB (445), iSCSI (3260), ONTAP mgmt (443) from `10.0.0.0/8` |

### 16.2 Amazon FSx for Windows File Server

**Replaces:** Windows Server-based SMB file shares in the SDDC.

| Parameter | Value |
|-----------|-------|
| Deployment type | Multi-AZ |
| Preferred subnet | `snet-fsx-windows-a` (eu-central-1a) |
| Standby subnet | `snet-fsx-windows-b` (eu-central-1b) |
| Storage capacity | Sized from file server inventory in Phase 0 |
| Storage type | SSD |
| Throughput capacity | Set based on workload profiling (minimum 32 MB/s) |
| Protocol support | SMB 2/3, DFS Namespaces |
| AD integration | Joined to `corp.cloud.internal` (EC2-hosted AD) |
| Encryption at rest | KMS CMK |
| Encryption in transit | SMB encryption enforced |
| Backups | Daily automatic FSx backups; VSS-consistent snapshots |
| Migration tooling | AWS DataSync (agent deployed in SDDC) |
| Security group | `sg-shared-fsx-windows` — allow SMB (445) from `10.0.0.0/8` |

### 16.3 Migration Approach Summary

```
NetApp ONTAP → FSx for NetApp ONTAP:
  1. Deploy FSx ONTAP cluster in shared-services VPC
  2. Create SnapMirror relationship: SDDC ONTAP → FSx ONTAP
  3. Initial baseline replication (off-peak)
  4. Incremental sync until cutover window
  5. Break SnapMirror mirror
  6. Remount NFS/SMB clients to FSx endpoint
  7. Validate data integrity and permissions

Windows File Server → FSx for Windows File Server:
  1. Deploy FSx Windows cluster in shared-services VPC
  2. Deploy DataSync agent VM in SDDC
  3. Create DataSync task: SDDC SMB shares → FSx
  4. Run initial DataSync (preserves NTFS ACLs)
  5. Run incremental sync until cutover window
  6. Update DFS namespace targets to FSx DNS name
  7. Validate share access and permissions
```

### 16.4 Dependencies

| Dependency | Required Before |
|-----------|----------------|
| EC2-hosted AD operational | FSx deployment (both services require domain join) |
| VPN/DX connectivity to SDDC | SnapMirror replication and DataSync agent |
| NAS inventory complete (share sizes, ACLs, NFS exports) | FSx capacity sizing |
| DFS namespace documentation | FSx for Windows cutover planning |

---

*Document Version 1.1 — Public Reference Framework*
*Licensed under the MIT License — free to use, adapt, and build upon.*
*Changes in v1.1: Primary region updated to Frankfurt (eu-central-1); DR region set to Ireland (eu-west-1); Section 7 rewritten — Active Directory on EC2 replacing AWS Managed AD; shared-services subnets expanded for FSx; Section 16 added — NAS migration high-level design (FSx for NetApp ONTAP, FSx for Windows File Server); all AZ and region references updated throughout.*
