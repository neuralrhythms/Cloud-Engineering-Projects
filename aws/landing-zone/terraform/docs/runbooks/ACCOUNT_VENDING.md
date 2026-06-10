# Account Vending Runbook

## Overview

This runbook describes the process for creating and onboarding new AWS accounts into the landing zone.

## Prerequisites

- Access to the Management Account with Organizations permissions
- Terraform state access for `01-organization` layer
- Network team coordination for CIDR allocation

## Process

### Step 1: Define Account Parameters

Add the new account to `layers/01-organization/accounts.tf`:

```hcl
module "new_workload_account" {
  source = "../../modules/organization"
  
  account_name  = "workload-app-prod"
  account_email = "aws+workload-app-prod@company.com"
  ou_id         = module.organization.workloads_prod_ou_id
  
  tags = {
    Team        = "app-team"
    CostCenter  = "CC-1234"
    Environment = "production"
  }
}
```

### Step 2: Plan and Apply Organization Changes

```bash
cd layers/01-organization
terraform plan
terraform apply
```

### Step 3: Deploy Account Baseline

Add the account to `layers/06-workloads/`:

```hcl
module "app_prod_baseline" {
  source = "../../modules/account-baseline"
  
  account_id  = module.new_workload_account.account_id
  environment = "production"
  vpc_cidr    = "10.1.0.0/16"  # Coordinate with network team
}
```

### Step 4: Network Integration

The network team will:
1. Create TGW attachment for the new VPC
2. Add routes to appropriate route tables
3. Update security group rules as needed

### Step 5: Identity Access

Configure IAM Identity Center access:
1. Assign appropriate permission sets
2. Map user groups to the new account

## Checklist

- [ ] Account created in AWS Organizations
- [ ] Placed in correct OU
- [ ] Security baseline deployed (GuardDuty, Config, SecurityHub enrolled)
- [ ] CloudTrail logging confirmed
- [ ] VPC created and attached to Transit Gateway
- [ ] IAM Identity Center access configured
- [ ] Cost allocation tags applied
- [ ] Account documented in inventory
