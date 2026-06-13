################################################################################
# Security — KMS, Security Hub, GuardDuty, CloudTrail, Config, IAM Roles
# Reference framework for VMware → AWS Cloud Native Migration
# Deploy per account; Security Hub/GuardDuty enable via delegated admin in
# security-tooling account
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      TerraformManaged = "true"
      Environment      = var.environment
      Owner            = var.owner_tag
      CostCentre       = var.cost_centre
    }
  }
}

################################################################################
# KMS Customer Managed Keys
################################################################################

resource "aws_kms_key" "rds_mssql" {
  description             = "CMK for RDS SQL Server encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_rds.json

  tags = { Name = "key-rds-mssql-${var.environment}" }
}

resource "aws_kms_alias" "rds_mssql" {
  name          = "alias/rds-mssql-${var.environment}"
  target_key_id = aws_kms_key.rds_mssql.key_id
}

resource "aws_kms_key" "aurora_mysql" {
  description             = "CMK for Aurora MySQL encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_rds.json

  tags = { Name = "key-aurora-mysql-${var.environment}" }
}

resource "aws_kms_alias" "aurora_mysql" {
  name          = "alias/aurora-mysql-${var.environment}"
  target_key_id = aws_kms_key.aurora_mysql.key_id
}

resource "aws_kms_key" "ebs" {
  description             = "CMK for EBS volume encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_ebs.json

  tags = { Name = "key-ebs-${var.environment}" }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/ebs-${var.environment}"
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_kms_key" "secrets" {
  description             = "CMK for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_secrets.json

  tags = { Name = "key-secrets-${var.environment}" }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/secrets-${var.environment}"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_kms_key" "terraform_state" {
  count                   = var.is_shared_services ? 1 : 0
  description             = "CMK for Terraform state S3 bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = { Name = "key-terraform-state" }
}

resource "aws_kms_alias" "terraform_state" {
  count         = var.is_shared_services ? 1 : 0
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform_state[0].key_id
}

################################################################################
# Enable EBS Encryption by Default
################################################################################

resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "default" {
  key_arn = aws_kms_key.ebs.arn
}

################################################################################
# GuardDuty (per account)
################################################################################

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false # Enable if EKS is added
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = { Name = "guardduty-${var.environment}" }
}

################################################################################
# Security Hub (per account)
################################################################################

resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
}

################################################################################
# CloudTrail (organisation trail managed from management account)
# Per-account trail for local account events
################################################################################

resource "aws_cloudtrail" "account_trail" {
  count                         = var.is_management_account ? 0 : 1
  name                          = "trail-${var.account_name}"
  s3_bucket_name                = var.cloudtrail_s3_bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.cloudtrail_kms_key_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = { Name = "trail-${var.account_name}" }
}

################################################################################
# AWS Config
################################################################################

resource "aws_config_configuration_recorder" "main" {
  name     = "config-recorder-${var.account_name}"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "config-delivery-${var.account_name}"
  s3_bucket_name = var.config_s3_bucket
  s3_key_prefix  = var.account_name

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# Mandatory Config Rules
resource "aws_config_config_rule" "required_tags" {
  name        = "required-tags"
  description = "Checks that required tags are present on all resources"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key   = "Environment"
    tag2Key   = "Owner"
    tag3Key   = "CostCentre"
    tag4Key   = "Application"
    tag5Key   = "MigrationWave"
  })

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "encrypted_volumes" {
  name        = "encrypted-volumes"
  description = "Checks that EBS volumes are encrypted"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "rds_storage_encrypted" {
  name        = "rds-storage-encrypted"
  description = "Checks that RDS instances are encrypted at rest"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "s3_bucket_public_access_prohibited" {
  name        = "s3-bucket-public-access-prohibited"
  description = "Checks that S3 buckets block public access"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_ACCESS_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name        = "cloud-trail-enabled"
  description = "Checks that CloudTrail is enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

################################################################################
# IAM — EC2 Instance Profile for Rehosted Workloads
################################################################################

resource "aws_iam_role" "ec2_workload" {
  name = "role-ec2-workload-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_workload.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2_workload.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "ec2_secrets" {
  name = "policy-ec2-secrets-access"
  role = aws_iam_role.ec2_workload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:/${var.environment}/*"
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [
          aws_kms_key.secrets.arn,
          aws_kms_key.ebs.arn
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_workload" {
  name = "profile-ec2-workload-${var.environment}"
  role = aws_iam_role.ec2_workload.name
}

################################################################################
# IAM — ECS Task Execution Role
################################################################################

resource "aws_iam_role" "ecs_task_execution" {
  name = "role-ecs-task-exec-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_exec_secrets" {
  name = "policy-ecs-task-exec-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsForECS"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:/${var.environment}/*"
      },
      {
        Sid    = "AllowKMSForECS"
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}

################################################################################
# IAM — Config Service Role
################################################################################

resource "aws_iam_role" "config" {
  name = "role-config-${var.account_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

################################################################################
# Terraform State Resources (shared-services account only)
################################################################################

resource "aws_s3_bucket" "terraform_state" {
  count  = var.is_shared_services ? 1 : 0
  bucket = "s3-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = { Name = "s3-tfstate", Purpose = "terraform-state" }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.is_shared_services ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.is_shared_services ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.is_shared_services ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  count        = var.is_shared_services ? 1 : 0
  name         = "ddb-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform_state[0].arn
  }

  tags = { Name = "ddb-terraform-state-lock" }
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_rds" {
  statement {
    sid     = "AllowRootFull"
    actions = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid = "AllowRDSService"
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:CreateGrant", "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "kms_ebs" {
  statement {
    sid     = "AllowRootFull"
    actions = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid = "AllowEC2Service"
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:CreateGrant", "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "kms_secrets" {
  statement {
    sid     = "AllowRootFull"
    actions = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid = "AllowSecretsManager"
    actions = [
      "kms:Decrypt", "kms:GenerateDataKey*", "kms:CreateGrant", "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["secretsmanager.amazonaws.com"]
    }
  }
}
