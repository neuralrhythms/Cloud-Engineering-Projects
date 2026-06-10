# Deployment Guide

Complete step-by-step guide for deploying the AWS Landing Zone from scratch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Phase 1: Bootstrap](#phase-1-bootstrap)
4. [Phase 2: Organization](#phase-2-organization)
5. [Phase 3: Security](#phase-3-security)
6. [Phase 4: Logging](#phase-4-logging)
7. [Phase 5: Networking](#phase-5-networking)
8. [Phase 6: Identity](#phase-6-identity)
9. [Phase 7: Workloads](#phase-7-workloads)
10. [Post-Deployment Verification](#post-deployment-verification)
11. [Rollback Procedures](#rollback-procedures)

---

## Prerequisites

### Tools Required

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.6.0 | Infrastructure provisioning |
| AWS CLI | v2 | AWS authentication and manual operations |
| Git | >= 2.x | Version control |
| jq | >= 1.6 | JSON processing (optional, for scripts) |

### Installation

```bash
# Terraform (Windows - using Chocolatey)
choco install terraform

# Terraform (macOS)
brew install terraform

# Terraform (Linux)
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# AWS CLI v2
# Windows: Download MSI from https://aws.amazon.com/cli/
# macOS:
brew install awscli
# Linux:
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

### AWS Account Requirements

- An AWS account designated as the **Management Account**
- Root email addresses prepared for each member account (unique per account)
- AWS Organizations must NOT already be enabled (or you must import existing org)
- IAM user or role with `AdministratorAccess` in the Management Account

### AWS CLI Configuration

```bash
# Configure the Management Account profile
aws configure --profile landing-zone-mgmt
# AWS Access Key ID: <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name: us-east-1
# Default output format: json

# Verify access
aws sts get-caller-identity --profile landing-zone-mgmt
```

---

## Pre-Deployment Checklist

Complete these items before beginning deployment:

### 1. Gather Account Emails

Each AWS account requires a unique email address. Use plus-addressing to reuse a single mailbox:

```
Management:      aws-management@yourcompany.com       (already exists)
Security:        aws+security@yourcompany.com
Log Archive:     aws+log-archive@yourcompany.com
Network:         aws+network@yourcompany.com
Shared Services: aws+shared-services@yourcompany.com
App1 Prod:       aws+app1-prod@yourcompany.com
App1 Dev:        aws+app1-dev@yourcompany.com
```

### 2. Plan CIDR Allocation

Design a non-overlapping IP address plan:

| Account/VPC | CIDR | Subnet Size |
|-------------|------|-------------|
| Egress VPC | 10.255.0.0/20 | /24 per subnet |
| Shared Services VPC | 10.254.0.0/20 | /24 per subnet |
| App1-Prod VPC | 10.1.0.0/16 | /20 per subnet |
| App1-Dev VPC | 10.11.0.0/16 | /20 per subnet |
| App2-Prod VPC | 10.2.0.0/16 | /20 per subnet |

### 3. Choose AWS Regions

Decide on:
- **Primary region**: Where all management plane resources will live (e.g., `us-east-1`)
- **Allowed regions**: Regions workloads can use (enforced via SCP)
- **DR region**: For cross-region replication (if required)

### 4. Define Team Structure

Map teams to permission sets:

| Team | Permission Set | Target Accounts |
|------|---------------|-----------------|
| Platform Engineering | AdministratorAccess | All (break-glass) |
| Security | SecurityAudit | All |
| Network | NetworkAdministrator | Network |
| App Team 1 | DeveloperAccess | App1-Dev, App1-Staging |
| App Team 1 | ReadOnlyAccess | App1-Prod |
| Finance | BillingAccess | Management |

### 5. Create Environment Configuration

Copy and customize the tfvars file:

```bash
cp environments/production.tfvars environments/mycompany.tfvars
```

Edit `environments/mycompany.tfvars` with your actual values.

---

## Phase 1: Bootstrap

**Purpose**: Create the Terraform state backend (S3 bucket + DynamoDB lock table) and optional GitHub OIDC authentication.

**Target Account**: Management Account

**Estimated Time**: 5 minutes

### Steps

```bash
cd layers/00-bootstrap

# Set the AWS profile
export AWS_PROFILE=landing-zone-mgmt

# Initialize with local backend (first time only)
terraform init

# Review the plan
terraform plan \
  -var="aws_region=us-east-1" \
  -var="enable_github_oidc=true" \
  -var="github_org=your-github-org" \
  -var="github_repo=aws-landing-zone"

# Apply
terraform apply \
  -var="aws_region=us-east-1" \
  -var="enable_github_oidc=true" \
  -var="github_org=your-github-org" \
  -var="github_repo=aws-landing-zone"
```

### Migrate State to S3

After the bootstrap apply succeeds, migrate from local to remote state:

1. Note the output values:
   ```bash
   terraform output state_bucket_name
   terraform output lock_table_name
   ```

2. Uncomment the S3 backend block in `layers/00-bootstrap/main.tf`:
   ```hcl
   backend "s3" {
     bucket         = "landing-zone-terraform-state-123456789012"
     key            = "00-bootstrap/terraform.tfstate"
     region         = "us-east-1"
     dynamodb_table = "landing-zone-terraform-locks"
     encrypt        = true
   }
   ```

3. Run state migration:
   ```bash
   terraform init -migrate-state
   ```

4. Confirm the migration when prompted.

### Update All Layer Backends

Replace `ACCOUNT_ID` in every layer's `main.tf` backend configuration with your actual Management Account ID:

```bash
# Find all backend configs that need updating
grep -r "ACCOUNT_ID" layers/
```

Replace with your actual account ID (e.g., `123456789012`).

### Outputs

| Output | Description | Used By |
|--------|-------------|---------|
| `state_bucket_name` | S3 bucket for all Terraform state | All layers |
| `lock_table_name` | DynamoDB table for state locking | All layers |
| `kms_key_arn` | KMS key for state encryption | All layers |
| `github_oidc_role_arn` | IAM role for GitHub Actions | CI/CD workflows |

---

## Phase 2: Organization

**Purpose**: Create the AWS Organization, OU hierarchy, and member accounts.

**Target Account**: Management Account

**Estimated Time**: 10-15 minutes (account creation can take a few minutes)

### Steps

```bash
cd layers/01-organization
export AWS_PROFILE=landing-zone-mgmt

terraform init

terraform plan -var-file="../../environments/mycompany.tfvars"

# Review the plan carefully - account creation is not easily reversible
terraform apply -var-file="../../environments/mycompany.tfvars"
```

### What Gets Created

- AWS Organization with all features enabled
- Organizational Units: Security, Infrastructure, Workloads/Production, Workloads/Non-Production, Sandbox, Suspended
- Member accounts: Security, Log Archive, Network, Shared Services
- Workload accounts (as defined in tfvars)
- SCPs: Deny leave organization, Deny root user actions, Region restrictions

### Important Notes

- Account creation takes 1-3 minutes per account
- Each account email must be globally unique across all of AWS
- Accounts cannot be easily deleted (only suspended then closed after 90 days)
- SCPs take effect immediately upon attachment
- Store the account IDs from outputs - you'll need them for subsequent layers

### Outputs

Record these values for use in subsequent layers:

```bash
terraform output security_account_id
terraform output log_archive_account_id
terraform output network_account_id
terraform output shared_services_account_id
terraform output workload_account_ids
```

---

## Phase 3: Security

**Purpose**: Enable organization-wide security services with the Security account as delegated administrator.

**Target Account**: Security Tooling Account (with delegated admin from Management)

**Estimated Time**: 5-10 minutes

### Prerequisites

- Layer 01 completed (Security account exists)
- Note the `security_account_id` from Layer 01 outputs

### Steps

```bash
cd layers/02-security
export AWS_PROFILE=landing-zone-mgmt

terraform init

terraform plan \
  -var="security_account_id=<SECURITY_ACCOUNT_ID>" \
  -var="config_bucket_name=landing-zone-config-<LOG_ARCHIVE_ACCOUNT_ID>"

terraform apply \
  -var="security_account_id=<SECURITY_ACCOUNT_ID>" \
  -var="config_bucket_name=landing-zone-config-<LOG_ARCHIVE_ACCOUNT_ID>"
```

### What Gets Created

- GuardDuty delegated admin designation + organization configuration
- Security Hub with AWS Foundational and CIS standards enabled
- Security Hub cross-region finding aggregation
- AWS Config organization-level aggregator
- Security baseline (EBS encryption, password policy, S3 public access block)
- SNS topic for security notifications
- EventBridge rules for high-severity findings

### Verification

```bash
# Verify GuardDuty is active in the security account
aws guardduty list-detectors \
  --profile security-account \
  --region us-east-1

# Verify Security Hub standards
aws securityhub get-enabled-standards \
  --profile security-account \
  --region us-east-1
```

---

## Phase 4: Logging

**Purpose**: Create centralized, immutable logging infrastructure in the Log Archive account.

**Target Account**: Log Archive Account

**Estimated Time**: 5-10 minutes

### Prerequisites

- Layer 01 completed (Log Archive account exists)
- Layer 02 completed (delegated admin configured)
- Note the `log_archive_account_id` and `management_account_id`

### Steps

```bash
cd layers/03-logging
export AWS_PROFILE=landing-zone-mgmt

terraform init

terraform plan \
  -var="log_archive_account_id=<LOG_ARCHIVE_ACCOUNT_ID>" \
  -var="management_account_id=<MANAGEMENT_ACCOUNT_ID>" \
  -var="organization_account_ids=[\"<ACCT1>\",\"<ACCT2>\",\"<ACCT3>\"]"

terraform apply \
  -var="log_archive_account_id=<LOG_ARCHIVE_ACCOUNT_ID>" \
  -var="management_account_id=<MANAGEMENT_ACCOUNT_ID>" \
  -var="organization_account_ids=[\"<ACCT1>\",\"<ACCT2>\",\"<ACCT3>\"]"
```

### What Gets Created

- KMS CMK for log encryption (with policy allowing CloudTrail, Config, VPC Flow Logs)
- S3 bucket for CloudTrail logs (versioned, encrypted, lifecycle policies)
- S3 bucket for Config snapshots and history
- S3 bucket for VPC Flow Logs
- All buckets: public access blocked, SSL enforced, lifecycle to IA/Glacier
- Organization CloudTrail (multi-region, with insights)

### Lifecycle Policies

All log buckets apply the following retention:

| Transition | Days |
|------------|------|
| Standard → Standard-IA | 90 |
| Standard-IA → Glacier | 365 |
| Expiration | 2555 (7 years) |

Adjust `log_retention_days` variable for compliance requirements.

### Verification

```bash
# Verify CloudTrail is logging
aws cloudtrail get-trail-status \
  --name organization-trail \
  --profile landing-zone-mgmt

# Verify S3 bucket exists
aws s3 ls \
  --profile log-archive-account | grep landing-zone
```

---

## Phase 5: Networking

**Purpose**: Create the Transit Gateway hub-and-spoke network with centralized egress.

**Target Account**: Network Account

**Estimated Time**: 10-15 minutes

### Prerequisites

- Layer 01 completed (Network account exists)
- Layer 03 completed (VPC Flow Logs bucket exists)
- Note the `network_account_id`, `organization_arn`, and `vpc_flow_logs_bucket_arn`

### Steps

```bash
cd layers/04-networking
export AWS_PROFILE=landing-zone-mgmt

terraform init

terraform plan \
  -var="network_account_id=<NETWORK_ACCOUNT_ID>" \
  -var="organization_arn=arn:aws:organizations::<MGMT_ACCT_ID>:organization/<ORG_ID>" \
  -var="flow_logs_bucket_arn=arn:aws:s3:::landing-zone-vpc-flow-logs-<LOG_ARCHIVE_ACCT_ID>"

terraform apply \
  -var="network_account_id=<NETWORK_ACCOUNT_ID>" \
  -var="organization_arn=arn:aws:organizations::<MGMT_ACCT_ID>:organization/<ORG_ID>" \
  -var="flow_logs_bucket_arn=arn:aws:s3:::landing-zone-vpc-flow-logs-<LOG_ARCHIVE_ACCT_ID>"
```

### What Gets Created

- Transit Gateway with auto-accept enabled
- 4 TGW route tables: Production, Non-Production, Shared Services, Edge
- Egress VPC with Internet Gateway and NAT Gateways (3 AZs)
- Shared Services VPC (attached to TGW)
- RAM resource share for TGW (shared with entire organization)
- Default routes from workload route tables to egress VPC
- Private Route 53 hosted zone for internal DNS

### Network Topology After Deployment

```
Internet
    │
    ▼
┌─────────────────────────┐
│  Egress VPC (Network)   │
│  ├── IGW                │
│  ├── NAT GW x3         │
│  └── TGW Attachment     │
└────────────┬────────────┘
             │
     Transit Gateway
     ├── Edge RT
     ├── Production RT ──────── (workload VPCs added in Phase 7)
     ├── Non-Production RT ──── (workload VPCs added in Phase 7)
     └── Shared Services RT
             │
┌────────────┴────────────┐
│  Shared Services VPC    │
│  ├── Private Subnets    │
│  └── Isolated Subnets   │
└─────────────────────────┘
```

### Verification

```bash
# Verify Transit Gateway
aws ec2 describe-transit-gateways \
  --profile network-account \
  --region us-east-1

# Verify TGW route tables
aws ec2 describe-transit-gateway-route-tables \
  --profile network-account \
  --region us-east-1

# Verify RAM share
aws ram get-resource-shares \
  --resource-owner SELF \
  --profile network-account \
  --region us-east-1
```

---

## Phase 6: Identity

**Purpose**: Configure IAM Identity Center (SSO) with permission sets and account assignments.

**Target Account**: Management Account (Identity Center always lives here)

**Estimated Time**: 5 minutes

### Prerequisites

- Layer 01 completed (all accounts exist)
- IAM Identity Center enabled in the Management Account console (one-time manual step if not already enabled)
- Identity source configured (AWS SSO directory, or external IdP like Okta/Azure AD)
- Group/User IDs from your identity store

### Enable IAM Identity Center (if not already enabled)

This is a one-time manual step:
1. Open the AWS Console → IAM Identity Center
2. Click "Enable"
3. Choose your identity source (AWS managed or external IdP)
4. Note the instance ARN and identity store ID

### Steps

```bash
cd layers/05-identity
export AWS_PROFILE=landing-zone-mgmt

terraform init

# Create a tfvars file with your assignments
cat > identity.tfvars << 'EOF'
account_assignments = [
  {
    principal_name = "PlatformAdmins"
    principal_id   = "g-xxxxxxxxxx"  # Group ID from identity store
    principal_type = "GROUP"
    account_id     = "123456789012"  # Management account
    permission_set = "AdministratorAccess"
  },
  {
    principal_name = "SecurityTeam"
    principal_id   = "g-yyyyyyyyyy"
    principal_type = "GROUP"
    account_id     = "222222222222"  # Security account
    permission_set = "SecurityAudit"
  },
  {
    principal_name = "Developers"
    principal_id   = "g-zzzzzzzzzz"
    principal_type = "GROUP"
    account_id     = "333333333333"  # Dev account
    permission_set = "DeveloperAccess"
  }
]
EOF

terraform plan -var-file="identity.tfvars"
terraform apply -var-file="identity.tfvars"
```

### What Gets Created

- Permission sets: AdministratorAccess, ReadOnlyAccess, SecurityAudit, DeveloperAccess, NetworkAdministrator, BillingAccess
- Account assignments linking groups/users to accounts with specific permission sets
- Inline deny policy on DeveloperAccess (prevents IAM and Organizations changes)

### Verification

```bash
# List permission sets
aws sso-admin list-permission-sets \
  --instance-arn <SSO_INSTANCE_ARN> \
  --profile landing-zone-mgmt

# Test SSO login
# Open the AWS access portal URL (found in IAM Identity Center settings)
```

---

## Phase 7: Workloads

**Purpose**: Apply account baselines and create VPCs for each workload account, connected to the Transit Gateway.

**Target Account**: Each Workload Account

**Estimated Time**: 10-20 minutes (depends on number of accounts)

### Prerequisites

- All previous layers completed
- Transit Gateway ID from Layer 04 outputs
- Config bucket name from Layer 03 outputs
- VPC Flow Logs bucket ARN from Layer 03 outputs

### Steps

```bash
cd layers/06-workloads
export AWS_PROFILE=landing-zone-mgmt

terraform init

terraform plan \
  -var="transit_gateway_id=<TGW_ID>" \
  -var="config_bucket_name=landing-zone-config-<LOG_ARCHIVE_ACCT_ID>" \
  -var="flow_logs_bucket_arn=arn:aws:s3:::landing-zone-vpc-flow-logs-<LOG_ARCHIVE_ACCT_ID>" \
  -var-file="../../environments/mycompany.tfvars"

terraform apply \
  -var="transit_gateway_id=<TGW_ID>" \
  -var="config_bucket_name=landing-zone-config-<LOG_ARCHIVE_ACCT_ID>" \
  -var="flow_logs_bucket_arn=arn:aws:s3:::landing-zone-vpc-flow-logs-<LOG_ARCHIVE_ACCT_ID>" \
  -var-file="../../environments/mycompany.tfvars"
```

### What Gets Created Per Workload Account

- Security baseline (EBS encryption, password policy, S3 public block, access analyzer)
- AWS Config recorder with delivery to centralized bucket
- Default Config rules (encryption checks, root MFA, VPC flow logs)
- VPC with private and isolated subnets across 3 AZs
- Transit Gateway VPC attachment
- Routes to TGW for internet egress
- VPC Flow Logs to centralized S3 bucket
- SNS topic for security notifications

### Verification

```bash
# Verify VPC in a workload account
aws ec2 describe-vpcs \
  --profile workload-account \
  --region us-east-1

# Verify TGW attachment
aws ec2 describe-transit-gateway-vpc-attachments \
  --profile network-account \
  --region us-east-1

# Test connectivity (from an EC2 instance in a workload VPC)
ping 8.8.8.8  # Should route through TGW → Egress VPC → NAT → Internet
```

---

## Post-Deployment Verification

### Security Validation Checklist

Run these checks after completing all phases:

```bash
# 1. Verify Organization structure
aws organizations list-organizational-units-for-parent \
  --parent-id <ROOT_ID> --profile landing-zone-mgmt

# 2. Verify SCPs are attached
aws organizations list-policies-for-target \
  --target-id <OU_ID> --filter SERVICE_CONTROL_POLICY \
  --profile landing-zone-mgmt

# 3. Verify GuardDuty is enabled org-wide
aws guardduty list-organization-admin-accounts \
  --profile landing-zone-mgmt --region us-east-1

# 4. Verify CloudTrail is logging
aws cloudtrail get-trail-status \
  --name organization-trail --profile landing-zone-mgmt

# 5. Verify Config is recording
aws configservice describe-configuration-recorder-status \
  --profile security-account --region us-east-1

# 6. Verify S3 public access is blocked
aws s3control get-public-access-block \
  --account-id <ACCOUNT_ID> --profile landing-zone-mgmt

# 7. Verify Transit Gateway connectivity
aws ec2 describe-transit-gateway-attachments \
  --profile network-account --region us-east-1
```

### Expected State After Deployment

| Component | Expected State |
|-----------|---------------|
| AWS Organizations | Enabled, all features |
| OUs | 6 OUs with correct nesting |
| Member Accounts | All active, in correct OUs |
| SCPs | Attached to appropriate OUs |
| GuardDuty | Enabled in all accounts/regions |
| Security Hub | Enabled with standards active |
| CloudTrail | Org trail logging to Log Archive |
| Config | Recording in all accounts |
| Transit Gateway | Active with route tables |
| VPC Flow Logs | Enabled for all VPCs |
| IAM Identity Center | Permission sets assigned |

---

## Rollback Procedures

### General Rollback

```bash
# Revert a specific layer
cd layers/<layer-number>
terraform plan -destroy
terraform destroy  # CAUTION: Review carefully before confirming
```

### Layer-Specific Considerations

| Layer | Rollback Risk | Notes |
|-------|--------------|-------|
| 00-bootstrap | LOW | Don't destroy if other layers use the backend |
| 01-organization | HIGH | Account closure takes 90 days, SCPs removed immediately |
| 02-security | MEDIUM | Disabling security services removes visibility |
| 03-logging | HIGH | Destroying buckets loses log data permanently |
| 04-networking | MEDIUM | Destroys connectivity for all workloads |
| 05-identity | LOW | Removes SSO access, users can't log in |
| 06-workloads | MEDIUM | Destroys VPCs and all resources within |

### Emergency: Revert an SCP

If an SCP locks out access:

```bash
# Detach the problematic SCP (from management account root user if needed)
aws organizations detach-policy \
  --policy-id p-xxxxxxxx \
  --target-id ou-xxxx-xxxxxxxx \
  --profile landing-zone-mgmt
```

### Emergency: Disable a Security Service

```bash
# If GuardDuty is generating excessive noise
aws guardduty update-detector \
  --detector-id <DETECTOR_ID> \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES \
  --profile security-account
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Resolution |
|-------|-------|-----------|
| "Account email already exists" | Email used by another account | Use a different email with +addressing |
| "SCP prevents action" | SCP is too restrictive | Use OrganizationAccountAccessRole (exempt from SCPs) |
| "Cannot assume role" | Trust policy or SCP issue | Check role trust policy and SCP conditions |
| "State lock" | Previous run interrupted | Run `terraform force-unlock <LOCK_ID>` |
| "Resource already exists" | Manual creation or import needed | Use `terraform import` to bring under management |
| "TGW attachment failed" | RAM share not accepted | Verify auto-accept is enabled on TGW |

### Getting Help

1. Check Terraform output for specific error messages
2. Review CloudTrail in the Management Account for API errors
3. Verify IAM permissions of the executing role
4. Check SCP denials in CloudTrail (look for `AccessDenied` with `PolicyType: SERVICE_CONTROL_POLICY`)
