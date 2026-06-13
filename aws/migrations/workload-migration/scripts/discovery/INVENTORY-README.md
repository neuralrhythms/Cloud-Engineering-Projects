# Sample Server Inventory — RVTools Export (Simulated)

## Purpose

This is a **simulated RVTools `vInfo` export** representing the VMware SDDC server inventory
for use in migration planning, wave design workshops, and portfolio demonstration.

It covers all workload categories defined in the
[Architectural Design Document](../../docs/architecture/ADD-Workload-Migration-v1.0.md)
and can be used as a direct substitute for real ADS/RVTools output when no live SDDC is available.

---

## About RVTools

[RVTools](https://www.robware.net/rvtools/) is the industry-standard free utility for VMware
environment reporting. The `vInfo` tab is the primary VM inventory sheet, exported as CSV or XLSX.
This simulated export matches the real RVTools `vInfo` column schema.

---

## Inventory Summary

| # | VM Name | OS | CPUs | Memory (MB) | Disk (GB) | 6R Strategy | Target AWS Service | Wave |
|---|---------|----|----|------------|----------|-------------|-------------------|------|
| 1 | SDDC-AD-01 | Windows Server 2019 | 2 | 2,048 | 80 | Rehost → Replatform | AWS Managed Microsoft AD | 1 |
| 2 | SDDC-AD-02 | Windows Server 2019 | 2 | 2,048 | 80 | Rehost → Replatform | AWS Managed Microsoft AD | 1 |
| 3 | SDDC-MSSQL-01 | Windows Server 2019 | 4 | 4,096 | 500 | Replatform | Amazon RDS for SQL Server | 2 |
| 4 | SDDC-MSSQL-02 | Windows Server 2019 | 4 | 4,096 | 500 | Replatform | Amazon RDS for SQL Server | 2 |
| 5 | SDDC-MYSQL-01 | Windows Server 2016 | 4 | 2,048 | 300 | Replatform | Amazon Aurora Serverless v2 | 2 |
| 6 | SDDC-MYSQL-02 | Windows Server 2016 | 4 | 2,048 | 200 | Replatform | Amazon Aurora Serverless v2 | 2 |
| 7 | SDDC-WEB-01 | Windows Server 2019 | 2 | 2,048 | 100 | Refactor | Amazon ECS / AWS Fargate | 3 |
| 8 | SDDC-WEB-02 | Windows Server 2019 | 2 | 2,048 | 100 | Refactor | Amazon ECS / AWS Fargate | 3 |
| 9 | SDDC-APP-01 | RHEL 8 | 4 | 4,096 | 150 | Refactor | Amazon ECS / AWS Fargate | 3 |
| 10 | SDDC-APP-02 | RHEL 8 | 4 | 4,096 | 150 | Refactor | Amazon ECS / AWS Fargate | 3 |
| 11 | SDDC-LEGACY-01 | Windows Server 2012 R2 | 4 | 2,048 | 200 | Rehost | Amazon EC2 | 2 |
| 12 | SDDC-LEGACY-02 | Windows Server 2008 R2 | 2 | 2,048 | 150 | Rehost | Amazon EC2 | 2 |
| 13 | SDDC-LEGACY-03 | Windows Server 2016 | 2 | 1,024 | 100 | Rehost | Amazon EC2 | 2 |
| 14 | SDDC-FILE-01 | Windows Server 2019 | 2 | 2,048 | 500 | Replatform | AWS Transfer Family (SFTP) | 2 |
| 15 | SDDC-LINUX-01 | Ubuntu Server 20.04 | 4 | 2,048 | 100 | Rehost | Amazon EC2 | 2 |
| 16 | SDDC-LINUX-02 | Ubuntu Server 20.04 | 4 | 2,048 | 100 | Rehost | Amazon EC2 | 2 |
| 17 | SDDC-MON-01 | RHEL 8 | 4 | 4,096 | 200 | Rehost | Amazon EC2 | 2 |
| 18 | SDDC-JUMP-01 | Windows Server 2019 | 2 | 1,024 | 60 | Retire | AWS Systems Manager Session Manager | 1 |
| 19 | SDDC-NODOC-01 | Windows Server 2016 | 4 | 4,096 | 300 | Retain | SDDC — Non-Migratable | N/A |
| 20 | SDDC-NODOC-02 | Windows Server 2012 R2 | 2 | 2,048 | 150 | Retain | SDDC — Non-Migratable | N/A |
| 21 | SDDC-REG-01 | RHEL 7 | 8 | 4,096 | 1,000 | Retain (Regulatory) | SDDC — Non-Migratable | N/A |
| 22 | SDDC-REG-02 | RHEL 7 | 8 | 4,096 | 1,000 | Retain (Regulatory) | SDDC — Non-Migratable | N/A |
| 23 | SDDC-VENDOR-01 | Windows Server 2019 | 8 | 8,192 | 600 | Retain (Vendor) | SDDC — Non-Migratable | N/A |
| 24 | SDDC-BACKUP-01 | RHEL 8 | 4 | 4,096 | 4,000 | Retire | AWS Backup / S3 | 1 |
| 25 | SDDC-PROXY-01 | RHEL 8 | 2 | 2,048 | 80 | Retire | VPC Endpoints / NAT Gateway | 1 |
| 26 | SDDC-DNS-01 | Windows Server 2019 | 2 | 1,024 | 60 | Retire | Amazon Route 53 Resolver | 1 |
| 27 | SDDC-APP-NODOC-01 | Windows Server 2008 R2 | 2 | 2,048 | 200 | Retain | SDDC — Non-Migratable | N/A |
| 28 | SDDC-CICD-01 | Ubuntu Server 22.04 | 4 | 4,096 | 200 | Rehost | Amazon EC2 | 2 |
| 29 | SDDC-NTP-01 | RHEL 8 | 1 | 512 | 40 | Retire | AWS Time Sync Service | 1 |
| 30 | SDDC-SYSLOG-01 | RHEL 8 | 4 | 2,048 | 500 | Retire | CloudWatch Logs / S3 | 1 |

**Total VMs: 30**

---

## Disposition Breakdown

| 6R Category | Count | % of Estate |
|-------------|-------|------------|
| Rehost (Lift & Shift) | 7 | 23% |
| Replatform | 6 | 20% |
| Refactor / Rearchitect | 4 | 13% |
| Retire | 7 | 23% |
| Retain (Non-Migratable) | 6 | 20% |
| **Total** | **30** | **100%** |

---

## Wave Plan (Indicative)

| Wave | VMs | Focus |
|------|-----|-------|
| Wave 1 (Foundation) | SDDC-AD-01, SDDC-AD-02, SDDC-JUMP-01, SDDC-BACKUP-01, SDDC-PROXY-01, SDDC-DNS-01, SDDC-NTP-01, SDDC-SYSLOG-01 | Infrastructure services — retire replaceable infra; establish AD trust |
| Wave 2 (Databases + Rehost) | SDDC-MSSQL-01/02, SDDC-MYSQL-01/02, SDDC-FILE-01, SDDC-LEGACY-01/02/03, SDDC-LINUX-01/02, SDDC-MON-01, SDDC-CICD-01 | Database replatform + lift-and-shift rehost |
| Wave 3 (Refactor) | SDDC-WEB-01/02, SDDC-APP-01/02 | Containerisation to ECS/Fargate |
| Retained (No Wave) | SDDC-NODOC-01/02, SDDC-REG-01/02, SDDC-VENDOR-01, SDDC-APP-NODOC-01 | Non-migratable — remain in SDDC |

---

## Subnet / IP Scheme (SDDC)

| Subnet | Range | Purpose |
|--------|-------|---------|
| Infrastructure | 10.10.1.0/24 | AD, monitoring, jump, DNS, NTP, logging, CI/CD |
| Database | 10.10.2.0/24 | SQL Server, MySQL |
| Application | 10.10.3.0/24 | Web, app tier, Linux middleware, file transfer |
| Legacy | 10.10.4.0/24 | Legacy Windows applications |
| Non-Migratable | 10.10.5.0/24 | Undocumented, regulated, vendor-locked |
| VMware Hosts | 10.10.0.0/24 | ESXi host management |

---

## How to Use This File

### In Migration Planning Workshops
Import into Excel or Google Sheets. Use the `6R Classification`, `Target Service`, and `Wave`
columns to drive wave planning discussions with application owners.

### As AWS Migration Hub Import
The inventory can be reformatted to the
[AWS Migration Hub CSV import template](https://docs.aws.amazon.com/migrationhub/latest/ug/import-migration-hub-discovery.html)
for tracking in Migration Hub without deploying ADS agents.

### As Right-Sizing Input
Use `CPUs`, `Memory (MB)`, and `Total disk capacity MiB` columns as the baseline for EC2
instance type selection. Complement with utilisation data (ADS agent or CloudWatch Agent)
for right-sizing in Phase 2.

### For SCT Assessment Planning
Filter on `Replatform` rows to identify the 4 database VMs (MSSQL-01/02, MYSQL-01/02)
requiring AWS Schema Conversion Tool assessment before Wave 2.

---

## Notes on Simulated Data

- All VM names, IP addresses, hostnames, and data are **synthetic and fictitious**
- Designed to represent a realistic SME/mid-market VMware SDDC estate
- OS versions intentionally varied to reflect real-world mixed estates (including EOL versions)
- Storage figures reflect typical workload profiles; not derived from real systems
- Custom columns `6R Classification`, `Target Service`, `Wave`, and `Notes` are additions
  to the standard RVTools schema — added for migration planning purposes

---

*Part of the AWS Workload Migration Reference Framework*
*Licensed under the MIT License*
