# Usage Guide

Day-to-day operations, account management, and ongoing maintenance of the AWS Landing Zone.

## Table of Contents

1. [Day-to-Day Operations](#day-to-day-operations)
2. [Adding New Workload Accounts](#adding-new-workload-accounts)
3. [Managing Access](#managing-access)
4. [Network Changes](#network-changes)
5. [Security Operations](#security-operations)
6. [CI/CD Pipeline Usage](#cicd-pipeline-usage)
7. [Drift Detection and Remediation](#drift-detection-and-remediation)
8. [Cost Management](#cost-management)
9. [Compliance and Auditing](#compliance-and-auditing)
10. [Module Reference](#module-reference)

---

## Day-to-Day Operations

### Making Infrastructure Changes

All changes follow the same workflow:

```
1. Create feature branch
2. Edit Terraform code
3. Push and open PR → CI runs terraform plan
4. Review plan output in PR comments
5. Get approval from CODEOWNERS
6. Merge → CI runs terraform apply
```

### Quick Reference: Common Tasks

| Task | Layer | File to Edit |
|------|-------|-------------|
| Add new workload account | 01-organization | `layers/01-organization/main.tf` |
| Modify SCPs | 01-organization | `policies/scps/*.json` |
| Change security standards | 02-security | `layers/02-security/main.tf` |
| Adjust log retention | 03-logging | `layers/03-logging/variables.tf` |
| Add VPC CIDR | 04-networking | `layers/04-networking/variables.tf` |
| New permission set | 05-identity | `modules/iam-identity-center/main.tf` |
| New workload VPC | 06-workloads | `layers/06-workloads/main.tf` |

### Accessing AWS Accounts

Users authenticate through IAM Identity Center:

1. Navigate to your organization's AWS access portal URL
2. Authenticate with your IdP credentials (+ MFA)
3. Select the target account and permission set
4. Click "Management Console" or "Command line or programmatic access"

For CLI access:

```bash
# Configure SSO profile
aws configure sso
# SSO session name: landing-zone
# SSO start URL: https://your-org.awsapps.com/start
# SSO Region: us-east-1
# Choose account and role

# Use the profile
aws s3 ls --profile your-sso-profile

# Or export temporary credentials
eval $(aws configure export-credentials --profile your-sso-profile --format env)
```

---

## Adding New Workload Accounts

### Step 1: Update Organization Configuration

Edit `environments/mycompany.tfvars` to add the new account:

```hcl
workload_accounts = [
  # ... existing accounts ...
  {
    name        = "app3-prod"
    email       = "aws+app3-prod@company.com"
    environment = "production"
    team        = "app-team-3"
    vpc_cidr    = "10.3.0.0/16"
  },
  {
    name        = "app3-dev"
    email       = "aws+app3-dev@company.com"
    environment = "non-production"
    team        = "app-team-3"
    vpc_cidr    = "10.13.0.0/16"
  }
]
```

### Step 2: Apply Organization Changes

```bash
cd layers/01-organization
terraform plan -var-file="../../environments/mycompany.tfvars"
terraform apply -var-file="../../environments/mycompany.tfvars"
```

### Step 3: Apply Workload Baseline

```bash
cd layers/06-workloads
terraform plan -var-file="../../environments/mycompany.tfvars" \
  -var="transit_gateway_id=<TGW_ID>" \
  -var="config_bucket_name=<BUCKET>" \
  -var="flow_logs_bucket_arn=<ARN>"
terraform apply ...
```

### Step 4: Configure Access

Add account assignments in `layers/05-identity/`:

```hcl
# In your identity.tfvars
account_assignments = [
  # ... existing assignments ...
  {
    principal_name = "AppTeam3"
    principal_id   = "g-newgroupid"
    principal_type = "GROUP"
    account_id     = "<NEW_ACCOUNT_ID>"
    permission_set = "DeveloperAccess"
  }
]
```

### Step 5: Verify

- [ ] Account appears in correct OU
- [ ] Security services auto-enrolled (GuardDuty, SecurityHub, Config)
- [ ] VPC created and attached to TGW
- [ ] Flow logs flowing to centralized bucket
- [ ] Team can access via IAM Identity Center
- [ ] Connectivity verified (can reach shared services, internet)

---

## Managing Access

### Adding a New Permission Set

Edit `modules/iam-identity-center/main.tf`:

```hcl
resource "aws_ssoadmin_permission_set" "data_engineer" {
  name             = "DataEngineerAccess"
  description      = "Access for data engineering team"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "data_engineer_glue" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer.arn
}

resource "aws_ssoadmin_managed_policy_attachment" "data_engineer_athena" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
  permission_set_arn = aws_ssoadmin_permission_set.data_engineer.arn
}
```

Add to the `permission_set_arns` local map and apply Layer 05.

### Revoking Access

Remove the account assignment from the tfvars and apply:

```bash
cd layers/05-identity
terraform apply -var-file="identity.tfvars"
```

This immediately removes the user/group's ability to access that account with that permission set.

### Emergency Access (Break-Glass)

For emergencies when SSO is unavailable:

1. Use the Management Account root credentials (stored securely offline)
2. Assume the `OrganizationAccountAccessRole` into any member account
3. This role is exempt from SCPs and has full administrative access

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::<MEMBER_ACCOUNT_ID>:role/OrganizationAccountAccessRole \
  --role-session-name emergency-access
```

---

## Network Changes

### Adding a New VPC to an Existing Account

The VPC is automatically created when you add a workload account. To modify an existing VPC:

```hcl
# In layers/06-workloads/main.tf, modify the workload_accounts variable
# or override specific VPC settings per account
```

### Adjusting Transit Gateway Route Tables

To allow production workloads to communicate with each other (not default):

```hcl
# In layers/04-networking/main.tf, add propagation
resource "aws_ec2_transit_gateway_route_table_propagation" "prod_to_prod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload["app1-prod"].id
  transit_gateway_route_table_id = module.transit_gateway.production_route_table_id
}
```

### Adding VPN/Direct Connect

Edit `layers/04-networking/main.tf` to add:

```hcl
resource "aws_vpn_gateway" "on_prem" {
  vpc_id = module.transit_gateway.egress_vpc_id
  tags = { Name = "on-prem-vgw" }
}

resource "aws_customer_gateway" "on_prem" {
  bgp_asn    = 65000
  ip_address = "203.0.113.1"  # Your on-prem public IP
  type       = "ipsec.1"
  tags = { Name = "on-prem-cgw" }
}

resource "aws_vpn_connection" "on_prem" {
  vpn_gateway_id      = aws_vpn_gateway.on_prem.id
  customer_gateway_id = aws_customer_gateway.on_prem.id
  type                = "ipsec.1"
  static_routes_only  = false
  tags = { Name = "on-prem-vpn" }
}
```

### DNS Configuration

To add a new private hosted zone accessible from workload accounts:

```hcl
# In layers/04-networking/main.tf
resource "aws_route53_zone" "app_internal" {
  name = "app.internal.company.com"
  
  vpc {
    vpc_id = module.shared_services_vpc.vpc_id
  }
}

# Share with workload VPCs via association
resource "aws_route53_zone_association" "app_workload" {
  zone_id = aws_route53_zone.app_internal.zone_id
  vpc_id  = <workload_vpc_id>
}
```

---

## Security Operations

### Responding to GuardDuty Findings

High-severity findings trigger notifications via SNS. The workflow:

1. Finding detected → EventBridge rule fires → SNS notification sent
2. Security team reviews finding in Security Hub console
3. Investigate using CloudTrail logs in the Log Archive account
4. Remediate following the [Incident Response Runbook](runbooks/INCIDENT_RESPONSE.md)
5. Mark finding as resolved in Security Hub

### Suppressing False Positives

```hcl
# In modules/guardduty/main.tf, add a filter
resource "aws_guardduty_filter" "suppress_known_scanner" {
  name        = "suppress-known-scanner"
  action      = "ARCHIVE"
  detector_id = aws_guardduty_detector.this.id
  rank        = 1

  finding_criteria {
    criterion {
      field  = "service.action.networkConnectionAction.remoteIpDetails.ipAddressV4"
      equals = ["203.0.113.5"]  # Known security scanner IP
    }
  }
}
```

### Adding Custom Config Rules

```hcl
# In modules/config/main.tf, add custom rules
resource "aws_config_config_rule" "required_tags" {
  name = "required-tags"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key   = "Project"
    tag2Key   = "Environment"
    tag3Key   = "ManagedBy"
  })

  depends_on = [aws_config_configuration_recorder.this]
}
```

### Modifying SCPs

To add a new SCP:

1. Create the policy JSON in `policies/scps/`:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "DenyExpensiveInstances",
         "Effect": "Deny",
         "Action": "ec2:RunInstances",
         "Resource": "arn:aws:ec2:*:*:instance/*",
         "Condition": {
           "StringNotEquals": {
             "ec2:InstanceType": ["t3.micro", "t3.small", "t3.medium", "t3.large"]
           }
         }
       }
     ]
   }
   ```

2. Reference it in `modules/organization/main.tf`:
   ```hcl
   resource "aws_organizations_policy" "deny_expensive_instances" {
     name    = "deny-expensive-instances"
     type    = "SERVICE_CONTROL_POLICY"
     content = file("${path.module}/policies/deny-expensive-instances.json")
   }
   ```

3. Attach to the appropriate OU.

**Warning**: Always test SCPs in a sandbox OU before applying to production.

---

## CI/CD Pipeline Usage

### How the Pipeline Works

```
Feature Branch          main Branch
     │                       │
     │  Push + PR            │
     ▼                       │
┌─────────────┐              │
│ Plan Job    │              │
│ - fmt check │              │
│ - validate  │              │
│ - tfsec     │              │
│ - plan      │──── Comment  │
└─────────────┘    on PR     │
     │                       │
     │  Merge                │
     ▼                       ▼
                    ┌─────────────┐
                    │ Apply Job   │
                    │ - init      │
                    │ - apply     │
                    └─────────────┘
```

### Setting Up the Pipeline

1. **Configure GitHub Repository Variables**:
   - `AWS_OIDC_ROLE_ARN`: The IAM role ARN from Layer 00 output (`github_oidc_role_arn`)

2. **Configure GitHub Environment**:
   - Create a `production` environment with required reviewers
   - This gates the apply workflow

3. **Branch Protection Rules**:
   - Require PR for changes to `main`
   - Require status checks: "Terraform Plan" must pass
   - Require CODEOWNERS review

### Running Plans Manually

```bash
# Local plan (requires AWS credentials)
cd layers/02-security
terraform init
terraform plan -var-file="../../environments/mycompany.tfvars"
```

### Pipeline Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Error assuming role" | OIDC thumbprint changed | Update `thumbprint_list` in bootstrap |
| "State locked" | Previous run failed | `terraform force-unlock <ID>` |
| Plan shows unexpected changes | Drift occurred | Review drift, apply or adjust code |
| Security scan fails | Known false positive | Add `.tfsec-ignore` or `#tfsec:ignore` |

---

## Drift Detection and Remediation

### How Drift Detection Works

The `drift-detection.yml` workflow runs every weekday at 6 AM UTC:

1. Runs `terraform plan` against each layer
2. If changes are detected (exit code 2), creates a GitHub Issue
3. Issue contains the full plan output showing what drifted

### Responding to Drift

When a drift issue is created:

1. **Assess**: Is the drift intentional (manual hotfix) or unintentional?
2. **If intentional**: Update Terraform code to match reality, then apply
3. **If unintentional**: Apply Terraform to restore desired state

```bash
# Investigate what changed
cd layers/<affected-layer>
terraform plan

# Restore desired state
terraform apply
```

### Common Drift Sources

| Source | Example | Resolution |
|--------|---------|-----------|
| Console changes | Someone added a tag manually | Apply Terraform to revert |
| AWS service updates | New default settings | Update Terraform to match |
| Auto-scaling | ASG changed instance count | Use `lifecycle { ignore_changes }` |
| Emergency fixes | Security patch applied manually | Update Terraform to incorporate fix |

### Preventing Drift

- Educate teams: all changes go through Terraform
- Use SCPs to restrict console modifications where possible
- Config rules detect non-compliant manual changes
- Regular drift detection surfaces issues early

---

## Cost Management

### Landing Zone Baseline Costs

Expected monthly costs for the landing zone infrastructure itself:

| Component | Approximate Cost |
|-----------|-----------------|
| Transit Gateway (per attachment) | ~$36/month each |
| Transit Gateway (data processing) | $0.02/GB |
| NAT Gateway (3x for HA) | ~$97/month + $0.045/GB |
| S3 (log storage) | Variable, ~$0.023/GB/month |
| KMS keys | $1/month per key |
| Config recording | ~$2/month per account |
| GuardDuty | Based on CloudTrail events + VPC flow log volume |
| Security Hub | $0.0010 per check per account per region |

### Cost Optimization Tips

1. **Non-production**: Use `single_nat_gateway = true` to save ~$64/month
2. **Fewer AZs in dev**: Set `az_count = 2` instead of 3
3. **Log lifecycle**: Aggressive transition to Glacier for old logs
4. **GuardDuty**: Review and suppress noisy findings to reduce processing
5. **Consolidated billing**: All accounts benefit from volume discounts

### Tagging for Cost Allocation

All resources are tagged with:
- `Project` - for billing reports
- `Environment` - for env-level cost breakdown
- `Team` - for team-level cost attribution
- `ManagedBy` - to identify IaC vs manual resources

Activate cost allocation tags in the Management Account billing console.

---

## Compliance and Auditing

### Available Compliance Standards

| Standard | Enabled By Default | Service |
|----------|-------------------|---------|
| AWS Foundational Security Best Practices | Yes | Security Hub |
| CIS AWS Foundations Benchmark 1.4 | Yes | Security Hub |
| NIST 800-53 Rev 5 | No (opt-in) | Security Hub |
| PCI DSS | No (opt-in) | Security Hub |

### Generating Compliance Reports

```bash
# Get Security Hub findings summary
aws securityhub get-findings \
  --filters '{"ComplianceStatus": [{"Value": "FAILED", "Comparison": "EQUALS"}]}' \
  --profile security-account

# Export Config compliance data
aws configservice get-compliance-summary-by-config-rule \
  --profile security-account
```

### Audit Trail

All API activity is captured in CloudTrail:
- **Location**: `s3://landing-zone-cloudtrail-<LOG_ARCHIVE_ACCT_ID>/cloudtrail/`
- **Retention**: 7 years (configurable)
- **Format**: JSON, compressed, encrypted with KMS
- **Insights**: API call rate and error rate anomaly detection enabled

### Evidence Collection for Audits

1. **CloudTrail**: Who did what, when (API calls)
2. **Config**: Resource configuration history and compliance state
3. **Security Hub**: Continuous compliance posture against standards
4. **VPC Flow Logs**: Network traffic records
5. **S3 Access Logs**: Access to sensitive buckets (if enabled)

---

## Module Reference

### modules/organization

Creates AWS Organizations structure with OUs and accounts.

| Variable | Required | Description |
|----------|----------|-------------|
| `security_account_email` | Yes | Email for Security account |
| `log_archive_account_email` | Yes | Email for Log Archive account |
| `network_account_email` | Yes | Email for Network account |
| `shared_services_account_email` | Yes | Email for Shared Services account |
| `workload_accounts` | No | List of workload accounts |
| `allowed_regions` | No | Regions to allow via SCP |

### modules/vpc

Creates a VPC with tiered subnets (public, private, isolated).

| Variable | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Name prefix for resources |
| `vpc_cidr` | Yes | VPC CIDR block |
| `az_count` | No | Number of AZs (default: 3) |
| `enable_public_subnets` | No | Create public subnets (default: true) |
| `enable_nat_gateway` | No | Create NAT Gateways (default: true) |
| `single_nat_gateway` | No | Use one NAT for cost savings (default: false) |
| `enable_flow_logs` | No | Enable VPC Flow Logs (default: true) |
| `flow_logs_bucket_arn` | No | S3 bucket ARN for flow logs |

### modules/transit-gateway

Creates Transit Gateway with segmented route tables and centralized egress.

| Variable | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Name prefix |
| `organization_arn` | Yes | Org ARN for RAM sharing |
| `egress_vpc_cidr` | No | CIDR for egress VPC (default: 10.255.0.0/20) |
| `az_count` | No | Number of AZs (default: 3) |

### modules/guardduty

Enables GuardDuty with organization-wide management.

| Variable | Required | Description |
|----------|----------|-------------|
| `security_account_id` | Conditional | Required if `is_delegated_admin_setup = true` |
| `is_delegated_admin_setup` | No | True = designate delegated admin (default: false) |
| `findings_bucket_arn` | No | S3 bucket for findings export |
| `enable_notifications` | No | Create EventBridge rules (default: true) |

### modules/securityhub

Enables Security Hub with compliance standards.

| Variable | Required | Description |
|----------|----------|-------------|
| `security_account_id` | Conditional | Required if `is_delegated_admin_setup = true` |
| `enable_aws_foundational_standard` | No | Enable FSBP (default: true) |
| `enable_cis_standard` | No | Enable CIS benchmark (default: true) |
| `enable_nist_standard` | No | Enable NIST 800-53 (default: false) |
| `enable_cross_region_aggregation` | No | Aggregate findings cross-region (default: true) |

### modules/cloudtrail

Creates an organization-wide CloudTrail.

| Variable | Required | Description |
|----------|----------|-------------|
| `log_bucket_name` | Yes | S3 bucket name for logs |
| `kms_key_arn` | Yes | KMS key for encryption |
| `trail_name` | No | Trail name (default: organization-trail) |
| `enable_insights` | No | Enable CloudTrail Insights (default: true) |

### modules/config

Enables AWS Config with optional organization aggregator.

| Variable | Required | Description |
|----------|----------|-------------|
| `config_bucket_name` | Yes | S3 bucket for Config delivery |
| `is_aggregator` | No | Create org aggregator (default: false) |
| `enable_default_rules` | No | Enable default Config rules (default: true) |
| `include_global_resources` | No | Record global resources (default: true) |

### modules/security-baseline

Applies security hardening to any account.

| Variable | Required | Description |
|----------|----------|-------------|
| `ebs_kms_key_arn` | No | KMS key for EBS encryption |
| `create_support_role` | No | Create AWS Support role (default: true) |
| `create_notification_topic` | No | Create SNS topic (default: true) |
| `trusted_principal_arns` | No | Principals for support role trust |

### modules/iam-identity-center

Configures SSO permission sets and account assignments.

| Variable | Required | Description |
|----------|----------|-------------|
| `account_assignments` | No | List of group/user-to-account-to-permission mappings |

### modules/account-baseline

Combines security-baseline + config for a complete account setup.

| Variable | Required | Description |
|----------|----------|-------------|
| `account_name` | Yes | Account name (used as S3 prefix) |
| `config_bucket_name` | Yes | Centralized Config bucket name |
| `create_support_role` | No | Create AWS Support role (default: true) |
| `enable_default_config_rules` | No | Enable default Config rules (default: true) |
