# Customization Guide

How to adapt this landing zone framework for your organization's specific needs.

## Table of Contents

1. [Framework Philosophy](#framework-philosophy)
2. [Customizing the OU Structure](#customizing-the-ou-structure)
3. [Customizing Network Architecture](#customizing-network-architecture)
4. [Customizing Security Controls](#customizing-security-controls)
5. [Adding New Modules](#adding-new-modules)
6. [Multi-Region Deployment](#multi-region-deployment)
7. [Integration with Existing Infrastructure](#integration-with-existing-infrastructure)
8. [Scaling Considerations](#scaling-considerations)

---

## Framework Philosophy

This framework is designed as a **starting point**, not a one-size-fits-all solution. Key design choices to be aware of:

| Default Choice | Alternative | When to Change |
|---------------|-------------|---------------|
| Single primary region | Multi-region active-active | Global workloads, DR requirements |
| Centralized egress | Distributed NAT per account | Strict isolation needs, latency sensitivity |
| 3 AZs | 2 AZs | Cost optimization for non-prod |
| TGW hub-and-spoke | VPC Peering | Very few accounts (<5), simple connectivity |
| S3 for flow logs | CloudWatch Logs | Real-time analysis needed |
| KMS CMK encryption | AWS-managed keys | Lower complexity, less control |
| IAM Identity Center | SAML Federation | Legacy IdP integration |

---

## Customizing the OU Structure

### Adding a New OU

Edit `modules/organization/main.tf`:

```hcl
resource "aws_organizations_organizational_unit" "data_platform" {
  name      = "Data Platform"
  parent_id = aws_organizations_organization.this.roots[0].id
}
```

### Nesting OUs

```hcl
resource "aws_organizations_organizational_unit" "data_prod" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.data_platform.id
}
```

### Removing Default OUs

If you don't need the Sandbox or Suspended OUs, remove them from the module and update outputs. Note that removing an OU requires all accounts within it to be moved first.

### Alternative OU Structures

**By Business Unit:**
```
Root
├── Finance OU
│   ├── Finance-Prod
│   └── Finance-NonProd
├── Engineering OU
│   ├── Eng-Prod
│   └── Eng-NonProd
└── Marketing OU
```

**By Compliance:**
```
Root
├── PCI-Compliant OU (strict SCPs)
├── HIPAA-Compliant OU (strict SCPs)
├── Standard OU (normal SCPs)
└── Sandbox OU (permissive)
```

---

## Customizing Network Architecture

### Distributed Egress (Instead of Centralized)

If you prefer each account to have its own NAT Gateway:

```hcl
# In modules/vpc/variables.tf - already supported
module "workload_vpc" {
  source = "../../modules/vpc"

  name               = "app1-prod"
  vpc_cidr           = "10.1.0.0/16"
  enable_nat_gateway = true       # Enable local NAT
  single_nat_gateway = false      # HA across AZs (or true for cost savings)
}
```

Then don't create the egress VPC in Layer 04 and remove the default route to TGW.

### VPC Peering (Instead of TGW)

For small environments with <5 VPCs, peering may be simpler and cheaper:

```hcl
resource "aws_vpc_peering_connection" "prod_to_shared" {
  vpc_id        = module.prod_vpc.vpc_id
  peer_vpc_id   = module.shared_vpc.vpc_id
  peer_owner_id = var.shared_services_account_id
  auto_accept   = false

  tags = { Name = "prod-to-shared" }
}

# Accepter in the shared services account
resource "aws_vpc_peering_connection_accepter" "shared" {
  provider                  = aws.shared_services
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_to_shared.id
  auto_accept               = true
}
```

### Adding an Inspection VPC (Network Firewall)

For east-west traffic inspection:

```hcl
resource "aws_vpc" "inspection" {
  cidr_block = "10.253.0.0/20"
  tags       = { Name = "inspection-vpc" }
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "landing-zone-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.inspection.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.inspection_fw
    content {
      subnet_id = subnet_mapping.value.id
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "landing-zone-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.block_domains.arn
    }
  }
}
```

Route all TGW traffic through the inspection VPC before reaching egress.

### Adding Direct Connect

```hcl
# Direct Connect Gateway
resource "aws_dx_gateway" "this" {
  name            = "landing-zone-dxgw"
  amazon_side_asn = "64512"
}

# Associate with Transit Gateway
resource "aws_dx_gateway_association" "tgw" {
  dx_gateway_id         = aws_dx_gateway.this.id
  associated_gateway_id = module.transit_gateway.transit_gateway_id

  allowed_prefixes = [
    "10.0.0.0/8"  # All internal ranges
  ]
}
```

---

## Customizing Security Controls

### Adjusting SCP Strictness

**More permissive** (for sandbox accounts):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LimitSandboxSpend",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEquals": {
          "ec2:InstanceType": ["t3.micro", "t3.small", "t3.medium"]
        }
      }
    }
  ]
}
```

**More restrictive** (for PCI/HIPAA):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedActions",
      "Effect": "Deny",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyNonIMDSv2",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEquals": {
          "ec2:MetadataHttpTokens": "required"
        }
      }
    }
  ]
}
```

### Adding Additional Security Services

**Amazon Inspector** (vulnerability scanning):
```hcl
resource "aws_inspector2_organization_configuration" "this" {
  auto_enable {
    ec2    = true
    ecr    = true
    lambda = true
  }
}
```

**Amazon Macie** (sensitive data discovery):
```hcl
resource "aws_macie2_account" "this" {}

resource "aws_macie2_organization_admin_account" "this" {
  admin_account_id = var.security_account_id
}
```

### Custom Config Rules

Create organization-wide custom rules:

```hcl
resource "aws_config_organization_managed_rule" "ec2_imdsv2" {
  name            = "ec2-imdsv2-required"
  rule_identifier = "EC2_IMDSV2_CHECK"
  
  input_parameters = jsonencode({})
}

resource "aws_config_organization_managed_rule" "rds_encrypted" {
  name            = "rds-storage-encrypted"
  rule_identifier = "RDS_STORAGE_ENCRYPTED"
}
```

---

## Adding New Modules

### Module Template

```bash
mkdir modules/new-module
```

Create these files:

```
modules/new-module/
├── main.tf          # Resources
├── variables.tf     # Inputs
├── outputs.tf       # Outputs
├── versions.tf      # Provider constraints
├── data.tf          # Data sources (optional)
├── locals.tf        # Local values (optional)
└── README.md        # Documentation
```

### versions.tf (standard)

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

### Integrating the Module

1. Create the module in `modules/`
2. Call it from the appropriate layer in `layers/`
3. Add variables to the layer's `variables.tf`
4. Export outputs needed by other layers
5. Update CODEOWNERS for the new module path
6. Document in this guide

---

## Multi-Region Deployment

### Strategy 1: Security Hub Aggregation Only

Deploy workloads in multiple regions but aggregate security findings to one region:

```hcl
# Already configured in the securityhub module
resource "aws_securityhub_finding_aggregator" "this" {
  linking_mode = "ALL_REGIONS"
}
```

### Strategy 2: Full Multi-Region Landing Zone

For workloads deployed across regions, replicate networking per region:

```hcl
# Primary region
module "tgw_primary" {
  source = "../../modules/transit-gateway"
  providers = { aws = aws.us_east_1 }
  name = "landing-zone-use1"
  # ...
}

# Secondary region
module "tgw_secondary" {
  source = "../../modules/transit-gateway"
  providers = { aws = aws.eu_west_1 }
  name = "landing-zone-euw1"
  # ...
}

# Inter-region peering
resource "aws_ec2_transit_gateway_peering_attachment" "cross_region" {
  provider                = aws.us_east_1
  peer_region             = "eu-west-1"
  peer_transit_gateway_id = module.tgw_secondary.transit_gateway_id
  transit_gateway_id      = module.tgw_primary.transit_gateway_id
}
```

### Strategy 3: Active-Passive DR

Deploy infrastructure in DR region but keep it idle:

```hcl
# Cross-region S3 replication for critical data
resource "aws_s3_bucket_replication_configuration" "cloudtrail_dr" {
  bucket = aws_s3_bucket.cloudtrail.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "cloudtrail-replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.cloudtrail_dr.arn
      storage_class = "STANDARD_IA"
    }
  }
}
```

---

## Integration with Existing Infrastructure

### Importing Existing AWS Organization

If you already have an Organization:

```bash
terraform import module.organization.aws_organizations_organization.this o-xxxxxxxxxx
terraform import module.organization.aws_organizations_organizational_unit.security ou-xxxx-xxxxxxxx
```

### Importing Existing Accounts

```bash
terraform import 'module.organization.aws_organizations_account.workload["app1-prod"]' 123456789012
```

### Coexisting with Control Tower

If Control Tower is already deployed:

1. **Don't recreate the organization** — import existing resources
2. **Respect CT-managed OUs** — don't modify OUs that CT manages
3. **Use CT landing zone as foundation** — layer Terraform on top
4. **Avoid conflicts** — don't manage resources CT manages (like the org trail)

```hcl
# Reference existing Control Tower resources via data sources
data "aws_organizations_organization" "existing" {}
data "aws_organizations_organizational_units" "root" {
  parent_id = data.aws_organizations_organization.existing.roots[0].id
}
```

### Migrating from CloudFormation StackSets

1. Export current StackSet resources
2. Write equivalent Terraform configs
3. Import resources one by one: `terraform import aws_guardduty_detector.this <id>`
4. Verify with `terraform plan` (should show no changes)
5. Delete StackSet instances once Terraform manages the resources

---

## Scaling Considerations

### 50+ Accounts

- Consider splitting `06-workloads` into per-team or per-BU state files
- Use Terragrunt for DRY configurations across many accounts
- Implement account factory automation (Lambda + Step Functions)

### 100+ Accounts

- Move to a multi-repo strategy (separate repos per team/domain)
- Implement a module registry (Terraform Cloud private registry or S3-backed)
- Use account tagging + AWS Organizations APIs for dynamic targeting
- Consider Control Tower Account Factory for Terraform (AFT)

### Performance

- Large organizations: each `terraform plan` queries all resources in state
- Keep state files small (< 200 resources per state)
- Use `-target` sparingly for urgent fixes only
- Consider `-parallelism=20` for faster plans (default is 10)

### Module Versioning

When the module library grows, version them independently:

```hcl
# Pin module versions with Git tags
module "vpc" {
  source = "git::https://github.com/your-org/terraform-modules.git//modules/vpc?ref=v2.1.0"
}
```

Or use a private Terraform registry for enterprise governance.
