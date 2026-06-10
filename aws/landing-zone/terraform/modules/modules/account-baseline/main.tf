# -----------------------------------------------------------------------------
# Account Baseline Module
# Applies standard security and compliance configuration to any account
# Combines security baseline, Config, and VPC Flow Logs
# -----------------------------------------------------------------------------

module "security_baseline" {
  source = "../security-baseline"

  ebs_kms_key_arn            = var.ebs_kms_key_arn
  create_support_role        = var.create_support_role
  trusted_principal_arns     = var.trusted_principal_arns
  create_notification_topic  = var.create_notification_topic

  tags = var.tags
}

module "config" {
  source = "../config"

  config_bucket_name       = var.config_bucket_name
  s3_key_prefix            = "config/${var.account_name}"
  include_global_resources = var.include_global_resources
  enable_default_rules     = var.enable_default_config_rules

  tags = var.tags
}
