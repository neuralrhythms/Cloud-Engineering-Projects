# Architecture Diagram Specification
# Workload Migration: VMware on AWS SDDC → AWS Cloud Native

> This specification describes the diagrams to be produced using draw.io, Lucidchart,
> or the [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/).
> All diagrams reference the LLD and ADD for exact CIDR, service, and account values.

---

## Diagram 1 — Multi-Account Landing Zone

**Purpose:** Show the AWS Organizations structure, OU hierarchy, and account layout.

**Actors / Boundaries:**

```
AWS Organizations Root
├── Management Account
├── Security OU
│   ├── Log Archive Account
│   └── Security Tooling Account
├── Infrastructure OU
│   ├── Network Hub Account
│   └── Shared Services Account
├── Workloads OU
│   ├── workload-prod Account
│   └── workload-nonprod Account
└── Sandbox OU
    └── Sandbox Account
```

**Services to show per account:**

| Account | Services |
|---------|---------|
| Management | AWS Organizations, Control Tower, Account Factory for Terraform |
| Log Archive | S3 (CloudTrail, VPC Flow Logs, Config), S3 Object Lock |
| Security Tooling | Security Hub, GuardDuty, Inspector, Config (delegated admin) |
| Network Hub | Transit Gateway, VPN/DX, Route 53 Resolver endpoints |
| Shared Services | AWS Managed Microsoft AD, Transfer Family, Terraform state S3+DynamoDB |
| workload-prod | EC2, ECS/Fargate, ALB, RDS SQL Server, Aurora Serverless v2 |
| workload-nonprod | EC2, ECS/Fargate, RDS, Aurora (dev/test) |

**Data flows to show:**
- SCP enforcement arrows (Management → OUs)
- CloudTrail org trail → Log Archive S3
- GuardDuty/Security Hub findings → Security Tooling
- TGW hub-and-spoke connectivity lines

---

## Diagram 2 — Network Topology (Hub-and-Spoke)

**Purpose:** Show VPC layout, subnet tiers, Transit Gateway routing, and SDDC connectivity.

**Accounts/VPCs:**

```
SDDC (VMware on AWS)          Network Hub VPC (10.0.0.0/16)
10.10.0.0/16                  ├── TGW Subnets
     │                        ├── VPN/DX Termination
     └──── VPN/DX ────────────► Transit Gateway
                                    │
               ┌─────────────────┬──┴──────────────────┐
               │                 │                      │
     Shared Services VPC    workload-prod VPC    workload-nonprod VPC
     10.1.0.0/16             10.2.0.0/16           10.3.0.0/16
     ├── AD Subnets          ├── Public Subnets     ├── Public Subnets
     ├── Transfer Subnets    ├── App Subnets        ├── App Subnets
     └── Tools Subnets       └── Data Subnets       └── Data Subnets
```

**Elements to include:**
- Internet Gateway on prod public subnets
- NAT Gateway (prod — per AZ; nonprod — single)
- Route 53 Resolver inbound/outbound endpoints in Network Hub
- VPC Endpoint icons in app subnets
- Security Group boundary indicators on each subnet tier
- CIDR labels on all subnets
- AZ boundaries (az-a, az-b, az-c)

---

## Diagram 3 — Target State Application Architecture (Production)

**Purpose:** Show the full application stack in the production workload account.

**Left-to-right flow:**

```
Internet
  │
  ▼
Route 53 (DNS)
  │
  ▼
AWS WAF (Web ACL)
  │
  ▼
Application Load Balancer (public subnets)
  │                │
  ▼                ▼
ECS Fargate     ECS Fargate
Web Tasks       Web Tasks
(snet-app-a)    (snet-app-b)
  │
  ▼
ECS Fargate App Backend Tasks (snet-app-a/b)
  │               │
  ▼               ▼
RDS SQL Server  Aurora Serverless v2
Multi-AZ        (MySQL-compatible)
(snet-data-a/b) (snet-data-a/b)
  │
  ▼
Secrets Manager (credentials)
KMS (encryption)
```

**Rehosted EC2 workloads** (parallel track):
```
EC2 (Legacy Apps) — snet-app-a/b
  ├── SSM Session Manager (no bastion)
  ├── CloudWatch Agent → CloudWatch Logs
  └── EBS (gp3, KMS encrypted)
```

**Shared services dependencies (via TGW):**
```
workload-prod ──TGW──► Shared Services
                        ├── AWS Managed AD (domain join)
                        └── Transfer Family (SFTP)
```

---

## Diagram 4 — Database Migration Flow

**Purpose:** Show the DMS/SCT migration path from SDDC to AWS.

```
SDDC (Source)                    AWS (Target)
─────────────                    ────────────

SQL Server VM                    RDS for SQL Server
10.10.2.10:1433                  Multi-AZ
     │                                │
     │  ◄── AWS SCT (schema) ────────►│
     │                                │
     └──── DMS Full Load ────────────►│
     └──── DMS CDC (ongoing) ────────►│
                                      │
                                  Cutover
                               (connection string
                                update via Secrets
                                Manager)

MySQL VM                         Aurora Serverless v2
10.10.2.20:3306                  MySQL 8.0-compatible
     │                                │
     │  ◄── AWS SCT (schema) ────────►│
     │                                │
     └──── DMS Full Load ────────────►│
     └──── DMS CDC (ongoing) ────────►│
                                      │
                                  Cutover
                               (Route 53 DNS update)
```

**Show:**
- VPN/DX connectivity between SDDC and AWS
- DMS Replication Instance in data subnet
- SCT running from admin workstation
- Secrets Manager storing new credentials
- CloudWatch alarm for replication lag

---

## Diagram 5 — Migration Wave Timeline

**Purpose:** Gantt-style or swimlane diagram showing migration phases and waves.

```
Phase 0  │ Discovery & Assessment (ADS, SCT, workshops)
─────────┼──────────────────────────────────────────────────────
Phase 1  │ Foundation (Landing Zone, TGW, AD Trust, VPN)
─────────┼──────────────────────────────────────────────────────
Wave 1   │ Retire infra (bastion, DNS, NTP, proxy, syslog, backup)
─────────┼──────────────────────────────────────────────────────
Wave 2   │ Database replatform (MSSQL→RDS, MySQL→Aurora)
         │ Rehost (Legacy EC2, Linux, CI/CD, monitoring)
         │ Replatform (Transfer Family SFTP)
─────────┼──────────────────────────────────────────────────────
Wave 3   │ Refactor (ECS/Fargate — web app, app backend)
─────────┼──────────────────────────────────────────────────────
Wave 4   │ AD full migration → AWS Managed AD cutover
─────────┼──────────────────────────────────────────────────────
Post     │ SDDC decommission (after retained workload review)
         │ Non-migratable workloads: quarterly review cadence
```

---

## Tooling Recommendation

| Tool | Use |
|------|-----|
| [draw.io (diagrams.net)](https://app.diagrams.net) | Free, AWS shape library built-in, exports SVG/PNG/XML |
| [Lucidchart](https://lucidchart.com) | Collaborative, AWS shapes |
| [Cloudcraft](https://cloudcraft.co) | 3D AWS-style diagrams, auto-import from live accounts |
| [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/) | Official PNG/SVG assets for all diagrams |

*Recommended format: SVG (scalable) + PNG (preview) + draw.io XML (editable source)*

---

*Diagram specification v1.0 — Phase 2*
*Part of the AWS Workload Migration Reference Framework*
