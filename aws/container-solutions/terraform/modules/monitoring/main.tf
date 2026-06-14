# =============================================================================
# Module: monitoring
# Purpose: CloudWatch dashboards, alarms, SNS topics, log groups
# =============================================================================
# NOTE: Scaffolding placeholder.
# See docs/diagrams/observability-architecture.md
# =============================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# -----------------------------------------------------------------------------
# SNS Topic for Alerts
# -----------------------------------------------------------------------------
# TODO: aws_sns_topic (cluster-alerts)
# TODO: aws_sns_topic_subscription (Slack/PagerDuty webhook via Lambda)

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------
# TODO: aws_cloudwatch_log_group for:
#   - /aws/eks/{cluster}/cluster              (EKS control plane)
#   - /aws/containerinsights/{cluster}/...   (Container Insights)
#   - /aws/vpc/flow-logs/{env}               (VPC Flow Logs)
# All with KMS encryption and var.log_retention_days

# -----------------------------------------------------------------------------
# CloudWatch Alarms — Node Level
# -----------------------------------------------------------------------------
# TODO: aws_cloudwatch_metric_alarm for:
#   - node_cpu_utilization > 80% for 5 min
#   - node_memory_utilization > 85% for 5 min

# -----------------------------------------------------------------------------
# CloudWatch Alarms — Pod Level
# -----------------------------------------------------------------------------
# TODO: aws_cloudwatch_metric_alarm for:
#   - pod_number_of_container_restarts > 5 in 5 min
#   - number of pending pods > 0 for 10 min

# -----------------------------------------------------------------------------
# CloudWatch Alarms — EKS API
# -----------------------------------------------------------------------------
# TODO: aws_cloudwatch_metric_alarm for apiserver 5xx errors

# -----------------------------------------------------------------------------
# CloudWatch Dashboard — Cluster Overview
# -----------------------------------------------------------------------------
# TODO: aws_cloudwatch_dashboard (cluster overview with Container Insights widgets)
