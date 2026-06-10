# Organization Module

Creates and manages the AWS Organizations structure including OUs, accounts, and SCPs.

## Usage

```hcl
module "organization" {
  source = "../../modules/organization"

  security_account_email        = "aws+security@company.com"
  log_archive_account_email     = "aws+logging@company.com"
  network_account_email         = "aws+network@company.com"
  shared_services_account_email = "aws+shared@company.com"

  allowed_regions = ["us-east-1", "us-west-2", "eu-west-1"]

  workload_accounts = [
    {
      name        = "app1-prod"
      email       = "aws+app1-prod@company.com"
      environment = "production"
      team        = "app-team-1"
    },
    {
      name        = "app1-dev"
      email       = "aws+app1-dev@company.com"
      environment = "non-production"
      team        = "app-team-1"
    }
  ]
}
```

## Resources Created

- AWS Organization with all features enabled
- Organizational Units: Security, Infrastructure, Workloads (Prod/Non-Prod), Sandbox, Suspended
- Core accounts: Security, Log Archive, Network, Shared Services
- Workload accounts (configurable)
- Service Control Policies: Deny leave org, Deny root usage, Region restriction

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| security_account_email | Email for Security account | string | yes |
| log_archive_account_email | Email for Log Archive account | string | yes |
| network_account_email | Email for Network account | string | yes |
| shared_services_account_email | Email for Shared Services account | string | yes |
| workload_accounts | List of workload accounts to create | list(object) | no |
| allowed_regions | AWS regions to allow (null = no restriction) | list(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| organization_id | AWS Organization ID |
| security_ou_id | Security OU ID |
| workloads_prod_ou_id | Production OU ID |
| security_account_id | Security account ID |
| log_archive_account_id | Log Archive account ID |
| network_account_id | Network account ID |
