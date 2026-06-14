# Terraform S3 Backend Configuration — Production Environment
# Usage: terraform init -backend-config=backend.hcl

bucket         = "eks-platform-prod-terraform-state-REPLACE_WITH_ACCOUNT_ID"
key            = "eks-platform/prod/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "eks-platform-prod-terraform-locks"
encrypt        = true
kms_key_id     = "alias/eks-platform-prod-terraform-state"
