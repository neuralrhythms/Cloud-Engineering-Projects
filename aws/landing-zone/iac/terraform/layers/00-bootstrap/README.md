# Layer 00: Bootstrap

Creates the Terraform state backend infrastructure and CI/CD authentication.

## What This Creates

- S3 bucket for Terraform state (versioned, encrypted)
- DynamoDB table for state locking
- KMS key for state encryption
- GitHub OIDC provider for CI/CD authentication (optional)

## Prerequisites

- AWS CLI configured with Management Account admin credentials
- This layer starts with local state and should be migrated to S3 after initial apply

## Usage

```bash
# First run: local state
terraform init
terraform apply

# After successful apply, uncomment the S3 backend in main.tf and migrate:
terraform init -migrate-state
```

## Important

- This layer uses `prevent_destroy` lifecycle rules
- The state bucket name includes the AWS account ID for uniqueness
- After migration, the local state file can be safely deleted
