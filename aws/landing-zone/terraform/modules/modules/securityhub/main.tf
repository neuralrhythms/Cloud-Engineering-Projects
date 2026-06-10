# -----------------------------------------------------------------------------
# Security Hub Module
# Enables Security Hub as organization-wide delegated administrator
# Deployed in the Security Tooling account
# -----------------------------------------------------------------------------

# Designate the security account as delegated admin (run in management account)
resource "aws_securityhub_organization_admin_account" "this" {
  count = var.is_delegated_admin_setup ? 1 : 0

  admin_account_id = var.security_account_id
}

# Enable Security Hub in the Security account
resource "aws_securityhub_account" "this" {}

# Organization configuration - auto-enable for new accounts
resource "aws_securityhub_organization_configuration" "this" {
  count = var.is_delegated_admin_setup ? 0 : 1

  auto_enable           = true
  auto_enable_standards = "DEFAULT"

  depends_on = [aws_securityhub_account.this]
}

# Enable security standards
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  count = var.enable_aws_foundational_standard ? 1 : 0

  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "cis" {
  count = var.enable_cis_standard ? 1 : 0

  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "nist" {
  count = var.enable_nist_standard ? 1 : 0

  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"

  depends_on = [aws_securityhub_account.this]
}

# Finding aggregator for multi-region
resource "aws_securityhub_finding_aggregator" "this" {
  count = var.enable_cross_region_aggregation ? 1 : 0

  linking_mode = "ALL_REGIONS"

  depends_on = [aws_securityhub_account.this]
}

# EventBridge rule for critical findings
resource "aws_cloudwatch_event_rule" "critical_findings" {
  count = var.enable_notifications ? 1 : 0

  name        = "securityhub-critical-findings"
  description = "Captures critical and high severity Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "critical_sns" {
  count = var.enable_notifications && var.notification_topic_arn != "" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.critical_findings[0].name
  target_id = "securityhub-sns"
  arn       = var.notification_topic_arn
}

# Data sources
data "aws_region" "current" {}
