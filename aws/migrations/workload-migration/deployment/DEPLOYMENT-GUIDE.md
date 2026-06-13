# Deployment Guide
# Workload Migration: VMware on AWS SDDC → AWS Cloud Native

> This guide describes the order of operations for deploying the Terraform modules.
> All commands assume Terraform >= 1.5.0, AWS CLI v2, and appropriate IAM credentials.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| AWS CLI | v2 configured with SSO or assumed role |
| Terraform | >= 1.5.0 |
| AWS Organizations | Management account with Organizations enabled |
| AWS Control Tower | Deployed in management account |
| Network connectivity | VPN or Direct Connect to SDDC provisioned |
| Domain name | ACM certificate issued for ALB HTTPS |
| SDDC credentials | DMS source DB usernames/passwords (store in Secrets Manager) |

---

## Deployment Order

### Step 1 — Landing Zone (management account)

```bash
cd iac/terraform/landing-zone
terraform init \
  -backend-config="bucket=s3-tfstate-MANAGEMENT_ACCOUNT_ID-ap-southeast-2" \
  -backend-config="key=landing-zone/terraform.tfstate" \
  -backend-config="region=ap-southeast-2" \
  -backend-config="dynamodb_table=ddb-terraform-state-lock"

terraform plan -out=tfplan
terraform apply tfplan
```

Outputs required for subsequent steps:
- `security_ou_id`
- `infrastructure_ou_id`
- `workloads_ou_id`

---

### Step 2 — Security Baseline (deploy to each account)

Deploy in order: log-archive → security-tooling → network-hub → shared-services → workload-prod → workload-nonprod

```bash
cd iac/terraform/security

# Example: workload-prod account
terraform init -backend-config="key=security/workload-prod/terraform.tfstate" ...
terraform plan \
  -var="account_name=workload-prod" \
  -var="environment=prod" \
  -var="cloudtrail_s3_bucket=s3-cloudtrail-logs-LOG_ARCHIVE_ACCOUNT_ID" \
  -var="cloudtrail_kms_key_arn=arn:aws:kms:ap-southeast-2:LOG_ARCHIVE_ACCOUNT_ID:key/..." \
  -var="config_s3_bucket=s3-config-logs-LOG_ARCHIVE_ACCOUNT_ID" \
  -out=tfplan

terraform apply tfplan
```

**Special flags for specific accounts:**
- Shared Services: add `-var="is_shared_services=true"` — creates Terraform state S3 + DynamoDB
- Management: add `-var="is_management_account=true"` — skips per-account CloudTrail

---

### Step 3 — Networking (deploy to each account with a VPC)

Deploy in order: network-hub → shared-services → workload-nonprod → workload-prod

```bash
cd iac/terraform/networking

# workload-prod
terraform init -backend-config="key=networking/workload-prod/terraform.tfstate" ...
terraform plan \
  -var-file="tfvars/workload-prod.tfvars" \
  -var="flow_logs_s3_arn=arn:aws:s3:::s3-vpcflowlogs-LOG_ARCHIVE_ACCOUNT_ID" \
  -out=tfplan

terraform apply tfplan
```

After networking is deployed:
1. Associate TGW attachments to correct route tables in network-hub account
2. Add SDDC route propagation from VPN/DX attachment
3. Validate connectivity: ping test from a test EC2 to SDDC IP

---

### Step 4 — Database (workload-prod account)

```bash
cd iac/terraform/database

terraform init -backend-config="key=database/workload-prod/terraform.tfstate" ...

terraform plan \
  -var="environment=prod" \
  -var="vpc_id=$(terraform -chdir=../networking output -raw vpc_id)" \
  -var="vpc_cidr=10.2.0.0/16" \
  -var="kms_key_rds_mssql_arn=$(terraform -chdir=../security output -raw kms_key_rds_mssql_arn)" \
  -var="kms_key_aurora_mysql_arn=$(terraform -chdir=../security output -raw kms_key_aurora_mysql_arn)" \
  -var="kms_key_secrets_arn=$(terraform -chdir=../security output -raw kms_key_secrets_arn)" \
  -var="sns_ops_topic_arn=arn:aws:sns:ap-southeast-2:PROD_ACCOUNT_ID:ops-alerts" \
  -out=tfplan

terraform apply tfplan
```

**Post-database deployment:**
1. Validate DMS endpoint connectivity (test endpoints in DMS console)
2. Run SCT assessment against source databases
3. Execute DMS full load task — validate row counts

---

### Step 5 — Compute (workload-prod account)

```bash
cd iac/terraform/compute

terraform init -backend-config="key=compute/workload-prod/terraform.tfstate" ...

terraform plan \
  -var="environment=prod" \
  -var="vpc_id=..." \
  -var="acm_certificate_arn=arn:aws:acm:ap-southeast-2:ACCOUNT_ID:certificate/..." \
  -var="alb_access_logs_bucket=s3-alb-access-logs-ACCOUNT_ID" \
  -var="ecs_task_execution_role_arn=$(terraform -chdir=../security output -raw ecs_task_execution_role_arn)" \
  -var="kms_key_ebs_arn=$(terraform -chdir=../security output -raw kms_key_ebs_arn)" \
  -var="db_secret_arn=$(terraform -chdir=../database output -raw secret_aurora_mysql_arn)" \
  -out=tfplan

terraform apply tfplan
```

---

## Post-Deployment Validation Checklist

| Check | Command / Console |
|-------|------------------|
| SCPs applied to OUs | AWS Organizations console → Policies |
| GuardDuty enabled | `aws guardduty list-detectors` in each account |
| Security Hub active | AWS Security Hub console — check findings |
| Config recording | `aws configservice describe-configuration-recorders` |
| CloudTrail logging | S3 log-archive bucket — confirm log delivery |
| VPC Flow Logs | S3 log-archive bucket — confirm flow log delivery |
| RDS Multi-AZ | RDS console — secondary AZ shown |
| Aurora Serverless v2 | RDS console — ACU scaling visible |
| DMS endpoint connectivity | DMS console → Endpoints → Test connection |
| ECS cluster health | ECS console — cluster shows ACTIVE |
| ALB listener | `curl -I https://<alb-dns-name>/health` |
| WAF association | WAF console — ACL associated with ALB |

---

## Rollback Procedures

### Terraform Rollback

All Terraform state is versioned in S3. To roll back a specific module:

```bash
# List state versions
aws s3api list-object-versions \
  --bucket s3-tfstate-ACCOUNT_ID-ap-southeast-2 \
  --prefix database/workload-prod/terraform.tfstate

# Restore a previous version
aws s3api get-object \
  --bucket s3-tfstate-ACCOUNT_ID-ap-southeast-2 \
  --key database/workload-prod/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate.backup
```

### Database Cutover Rollback

1. Restart DMS CDC task from last checkpoint
2. Revert Secrets Manager `host` field to SDDC database IP
3. Restart application — confirm connectivity to SDDC source DB
4. Notify operations team — open incident

### EC2 (MGN) Cutover Rollback

1. Update Route 53 / DNS to point back to SDDC
2. Source VM remains running during 72-hour rollback window
3. Do NOT disconnect MGN agent until rollback window expires

---

*Deployment Guide v1.0*
*Part of the AWS Workload Migration Reference Framework*
*Licensed under the MIT License*
