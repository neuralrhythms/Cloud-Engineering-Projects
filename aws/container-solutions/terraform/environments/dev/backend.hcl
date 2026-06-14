# Terraform S3 Backend Configuration — Dev Environment
# Usage: terraform init -backend-config=backend.hcl

bucket         = "eks-platform-dev-terraform-state-REPLACE_WITH_ACCOUNT_ID"
key            = "eks-platform/dev/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "eks-platform-dev-terraform-locks"
encrypt        = true
kms_key_id     = "alias/eks-platform-dev-terraform-state"
