# =============================================================================
# Module: security
# Purpose: KMS keys, GuardDuty, Security Hub, CloudTrail, AWS Config
# =============================================================================
# NOTE: Scaffolding placeholder.
# See docs/security/security-design.md for design specifications.
# =============================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# -----------------------------------------------------------------------------
# KMS Keys
# -----------------------------------------------------------------------------
# TODO: aws_kms_key + aws_kms_alias for each purpose:
#   - eks-secrets       (EKS etcd encryption)
#   - ebs               (EBS volume encryption)
#   - ecr               (ECR image encryption)
#   - logs              (CloudWatch Logs encryption)
#   - secrets-manager   (Secrets Manager encryption)
#   - terraform-state   (S3 Terraform state encryption)
#
# All keys:
#   - enable_key_rotation = true
#   - deletion_window_in_days = 30

# -----------------------------------------------------------------------------
# GuardDuty
# -----------------------------------------------------------------------------
# TODO: aws_guardduty_detector
# TODO: aws_guardduty_detector_feature (EKS_AUDIT_LOGS, EKS_RUNTIME_MONITORING, S3_DATA_EVENTS, MALWARE_PROTECTION)

# -----------------------------------------------------------------------------
# Security Hub
# -----------------------------------------------------------------------------
# TODO: aws_securityhub_account
# TODO: aws_securityhub_standards_subscription for:
#   - AWS Foundational Security Best Practices (FSBP)
#   - CIS AWS Foundations Benchmark

# -----------------------------------------------------------------------------
# CloudTrail
# -----------------------------------------------------------------------------
# TODO: aws_cloudtrail (multi-region trail)
# Destination: S3 bucket with KMS encryption
# CloudWatch Logs integration enabled
# Log file validation: enabled

# -----------------------------------------------------------------------------
# AWS Config
# -----------------------------------------------------------------------------
# TODO: aws_config_configuration_recorder
# TODO: aws_config_delivery_channel
# TODO: aws_config_conformance_pack (AWS Security Best Practices)

# -----------------------------------------------------------------------------
# Security Group — EKS Control Plane
# -----------------------------------------------------------------------------
# TODO: aws_security_group (see Network Design for rules)

# -----------------------------------------------------------------------------
# Security Group — EKS Nodes
# -----------------------------------------------------------------------------
# TODO: aws_security_group (see Network Design for rules)

# -----------------------------------------------------------------------------
# Security Group — ALB
# -----------------------------------------------------------------------------
# TODO: aws_security_group (see Network Design for rules)
