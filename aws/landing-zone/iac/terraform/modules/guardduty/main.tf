# -----------------------------------------------------------------------------
# GuardDuty Module
# Enables GuardDuty as organization-wide delegated administrator
# Deployed in the Security Tooling account
# -----------------------------------------------------------------------------

# Designate the security account as delegated admin (run in management account)
resource "aws_guardduty_organization_admin_account" "this" {
  count = var.is_delegated_admin_setup ? 1 : 0

  admin_account_id = var.security_account_id
}

# Create the GuardDuty detector in the Security account
resource "aws_guardduty_detector" "this" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
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

  tags = var.tags
}

# Organization configuration - auto-enable for new accounts
resource "aws_guardduty_organization_configuration" "this" {
  count = var.is_delegated_admin_setup ? 0 : 1

  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.this.id

  datasources {
    s3_logs {
      auto_enable = true
    }
    kubernetes {
      audit_logs {
        auto_enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = true
        }
      }
    }
  }
}

# Export findings to S3 in the Log Archive account
resource "aws_guardduty_publishing_destination" "s3" {
  count = var.findings_bucket_arn != "" ? 1 : 0

  detector_id     = aws_guardduty_detector.this.id
  destination_arn = var.findings_bucket_arn
  kms_key_arn     = var.findings_kms_key_arn
}

# EventBridge rule for high-severity findings
resource "aws_cloudwatch_event_rule" "high_severity" {
  count = var.enable_notifications ? 1 : 0

  name        = "guardduty-high-severity-findings"
  description = "Captures high severity GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "sns" {
  count = var.enable_notifications && var.notification_topic_arn != "" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.high_severity[0].name
  target_id = "guardduty-sns"
  arn       = var.notification_topic_arn
}
