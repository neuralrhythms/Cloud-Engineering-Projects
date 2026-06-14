bucket         = "eks-platform-test-terraform-state-REPLACE_WITH_ACCOUNT_ID"
key            = "eks-platform/test/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "eks-platform-test-terraform-locks"
encrypt        = true
kms_key_id     = "alias/eks-platform-test-terraform-state"
