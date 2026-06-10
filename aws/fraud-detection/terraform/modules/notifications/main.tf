################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

################################################################################
# SNS Topic for Fraud Alerts
################################################################################

resource "aws_sns_topic" "fraud_alerts" {
  name = "${var.name_prefix}-fraud-alerts"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-fraud-alerts"
  })
}

################################################################################
# SNS Topic Policy - Allow EventBridge to publish
################################################################################

resource "aws_sns_topic_policy" "fraud_alerts" {
  arn = aws_sns_topic.fraud_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name_prefix}-fraud-alerts-policy"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.fraud_alerts.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:events:${local.region}:${local.account_id}:rule/${var.name_prefix}-*"
          }
        }
      },
      {
        Sid    = "AllowAccountManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = [
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:AddPermission",
          "sns:RemovePermission",
          "sns:DeleteTopic",
          "sns:Subscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:Publish"
        ]
        Resource = aws_sns_topic.fraud_alerts.arn
      }
    ]
  })
}

################################################################################
# Email Subscription (conditional)
################################################################################

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.fraud_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

################################################################################
# SMS Subscription (conditional)
################################################################################

resource "aws_sns_topic_subscription" "sms" {
  count     = var.notification_phone != "" ? 1 : 0
  topic_arn = aws_sns_topic.fraud_alerts.arn
  protocol  = "sms"
  endpoint  = var.notification_phone
}

################################################################################
# EventBridge Rule - High Risk to SNS
################################################################################

resource "aws_cloudwatch_event_rule" "high_risk_to_sns" {
  name           = "${var.name_prefix}-high-risk-notify"
  description    = "Routes high-risk fraud events to SNS for notifications"
  event_bus_name = var.event_bus_name

  event_pattern = jsonencode({
    source      = ["fraud-detection-platform"]
    detail-type = ["FraudFinding.BLOCK"]
    detail = {
      overallScore = [{
        numeric = [">", 800]
      }]
    }
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-high-risk-notify"
  })
}

resource "aws_cloudwatch_event_target" "high_risk_sns" {
  rule           = aws_cloudwatch_event_rule.high_risk_to_sns.name
  event_bus_name = var.event_bus_name
  target_id      = "send-to-sns"
  arn            = aws_sns_topic.fraud_alerts.arn

  input_transformer {
    input_paths = {
      eventId   = "$.detail.eventId"
      riskLevel = "$.detail.riskLevel"
      score     = "$.detail.overallScore"
      timestamp = "$.detail.timestamp"
    }
    input_template = "\"HIGH RISK FRAUD ALERT: Event <eventId> scored <score>/1000 (Risk: <riskLevel>) at <timestamp>. Immediate investigation required.\""
  }
}
