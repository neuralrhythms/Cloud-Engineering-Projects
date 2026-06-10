# Quick Reference

Cheat sheet for common landing zone operations.

---

## Deployment Commands

```bash
# Deploy a specific layer
cd layers/<layer>
terraform init
terraform plan -var-file="../../environments/production.tfvars"
terraform apply -var-file="../../environments/production.tfvars"

# Validate all modules
terraform fmt -check -recursive modules/
terraform fmt -check -recursive layers/

# Force unlock stuck state
terraform force-unlock <LOCK_ID>

# Import an existing resource
terraform import <RESOURCE_ADDRESS> <RESOURCE_ID>

# Destroy a layer (CAUTION)
terraform destroy -var-file="../../environments/production.tfvars"
```

---

## Layer Dependencies

```
00-bootstrap ──→ (no dependencies, deploy first)
      │
      ▼
01-organization ──→ Needs: bootstrap backend
      │
      ├──→ 02-security ──→ Needs: security_account_id
      │
      ├──→ 03-logging ──→ Needs: log_archive_account_id, management_account_id
      │
      ├──→ 04-networking ──→ Needs: network_account_id, organization_arn, flow_logs_bucket
      │
      ├──→ 05-identity ──→ Needs: all account_ids (for assignments)
      │
      └──→ 06-workloads ──→ Needs: transit_gateway_id, config_bucket, flow_logs_bucket
```

---

## Account IDs Lookup

```bash
# From Management Account
aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Status:Status}' --output table

# From SSM Parameter Store
aws ssm get-parameter --name /landing-zone/accounts/security --query Parameter.Value --output text
aws ssm get-parameter --name /landing-zone/accounts/log-archive --query Parameter.Value --output text
aws ssm get-parameter --name /landing-zone/accounts/network --query Parameter.Value --output text
aws ssm get-parameter --name /landing-zone/accounts/shared-services --query Parameter.Value --output text
```

---

## Cross-Account Access

```bash
# Assume role into member account
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/OrganizationAccountAccessRole \
  --role-session-name admin-session

# Export the credentials
export AWS_ACCESS_KEY_ID=<from output>
export AWS_SECRET_ACCESS_KEY=<from output>
export AWS_SESSION_TOKEN=<from output>

# Or use named profiles in ~/.aws/config
[profile security]
role_arn = arn:aws:iam::<SECURITY_ACCT>:role/OrganizationAccountAccessRole
source_profile = management
region = us-east-1
```

---

## SCP Operations

```bash
# List all SCPs
aws organizations list-policies --filter SERVICE_CONTROL_POLICY

# List SCPs on a target (OU or account)
aws organizations list-policies-for-target --target-id <OU_ID> --filter SERVICE_CONTROL_POLICY

# Detach an SCP (emergency)
aws organizations detach-policy --policy-id p-xxxxxxxx --target-id ou-xxxx-xxxxxxxx

# Attach an SCP
aws organizations attach-policy --policy-id p-xxxxxxxx --target-id ou-xxxx-xxxxxxxx
```

---

## Security Service Status

```bash
# GuardDuty status
aws guardduty list-detectors
aws guardduty get-detector --detector-id <ID>
aws guardduty list-members --detector-id <ID>

# Security Hub status
aws securityhub describe-hub
aws securityhub get-enabled-standards
aws securityhub get-findings --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}'

# Config status
aws configservice describe-configuration-recorder-status
aws configservice describe-compliance-by-config-rule

# CloudTrail status
aws cloudtrail get-trail-status --name organization-trail
aws cloudtrail describe-trails
```

---

## Network Diagnostics

```bash
# Transit Gateway info
aws ec2 describe-transit-gateways
aws ec2 describe-transit-gateway-attachments
aws ec2 describe-transit-gateway-route-tables

# Search TGW routes
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id <RT_ID> \
  --filters "Name=type,Values=static,propagated"

# VPC info
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=landing-zone"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<VPC_ID>"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<VPC_ID>"
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<VPC_ID>"
```

---

## Identity Center (SSO)

```bash
# List SSO instances
aws sso-admin list-instances

# List permission sets
aws sso-admin list-permission-sets --instance-arn <INSTANCE_ARN>

# List account assignments
aws sso-admin list-account-assignments \
  --instance-arn <INSTANCE_ARN> \
  --account-id <ACCOUNT_ID> \
  --permission-set-arn <PS_ARN>
```

---

## Emergency Procedures

### Break-Glass Access
1. Retrieve Management Account root credentials from secure vault
2. Log into AWS Console as root
3. Assume `OrganizationAccountAccessRole` in target account
4. Perform emergency action
5. Document all actions taken
6. Update Terraform to reflect any permanent changes

### Disable Runaway SCP
```bash
aws organizations detach-policy \
  --policy-id p-xxxxxxxx \
  --target-id ou-xxxx-xxxxxxxx
```

### Force Stop CloudTrail (testing only)
```bash
aws cloudtrail stop-logging --name organization-trail
# Re-enable immediately after testing
aws cloudtrail start-logging --name organization-trail
```

---

## File Locations

| What | Where |
|------|-------|
| Module code | `modules/<name>/main.tf` |
| Layer configuration | `layers/<number>/main.tf` |
| Environment variables | `environments/<env>.tfvars` |
| SCP policies | `policies/scps/*.json` |
| Tag policies | `policies/tagging/*.json` |
| GitHub workflows | `.github/workflows/*.yml` |
| Architecture docs | `docs/architecture/` |
| Runbooks | `docs/runbooks/` |
| ADRs | `docs/adr/` |
