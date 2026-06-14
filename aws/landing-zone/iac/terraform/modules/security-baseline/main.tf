# -----------------------------------------------------------------------------
# Security Baseline Module
# Applied to every account to establish a common security posture
# Enables EBS encryption by default, configures password policy,
# creates a support role, and sets up IAM Access Analyzer
# -----------------------------------------------------------------------------

# Default EBS Encryption
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "this" {
  count   = var.ebs_kms_key_arn != "" ? 1 : 0
  key_arn = var.ebs_kms_key_arn
}

# IAM Account Password Policy
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
}

# IAM Access Analyzer (Account-level)
resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "account-analyzer"
  type          = "ACCOUNT"

  tags = var.tags
}

# Block S3 Public Access at account level
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Support Role (for AWS Support access)
resource "aws_iam_role" "support" {
  count = var.create_support_role ? 1 : 0

  name = "AWSSupportAccess"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_principal_arns
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "support" {
  count = var.create_support_role ? 1 : 0

  role       = aws_iam_role.support[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSSupportAccess"
}

# SNS Topic for Security Notifications
resource "aws_sns_topic" "security_notifications" {
  count = var.create_notification_topic ? 1 : 0

  name              = "security-notifications"
  kms_master_key_id = var.sns_kms_key_id

  tags = var.tags
}

resource "aws_sns_topic_policy" "security_notifications" {
  count = var.create_notification_topic ? 1 : 0

  arn = aws_sns_topic.security_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventsPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_notifications[0].arn
      }
    ]
  })
}
