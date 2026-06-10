################################################################################
# Custom EventBridge Event Bus
################################################################################

resource "aws_cloudwatch_event_bus" "fraud_events" {
  name = "${var.name_prefix}-fraud-events"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-fraud-events"
  })
}

################################################################################
# Lambda Function - DynamoDB Stream to EventBridge Publisher
################################################################################

data "archive_file" "stream_publisher" {
  type        = "zip"
  output_path = "${path.module}/files/stream_publisher.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

eventbridge = boto3.client('events')

def handler(event, context):
    """
    Processes DynamoDB Streams records from findings table
    and publishes events to EventBridge.
    """
    logger.info(f"Stream publisher invoked with {len(event.get('Records', []))} records")

    event_bus_name = os.environ['EVENT_BUS_NAME']
    entries = []

    for record in event.get('Records', []):
        if record['eventName'] not in ['INSERT', 'MODIFY']:
            continue

        new_image = record.get('dynamodb', {}).get('NewImage', {})

        event_id = new_image.get('eventId', {}).get('S', 'unknown')
        detection_type = new_image.get('detectionType', {}).get('S', 'unknown')
        risk_level = new_image.get('riskLevel', {}).get('S', 'unknown')
        overall_score = int(new_image.get('overallScore', {}).get('N', '0'))

        detail = {
            'eventId': event_id,
            'detectionType': detection_type,
            'riskLevel': risk_level,
            'overallScore': overall_score,
            'timestamp': datetime.utcnow().isoformat()
        }

        entry = {
            'Source': 'fraud-detection-platform',
            'DetailType': f'FraudFinding.{risk_level}',
            'Detail': json.dumps(detail),
            'EventBusName': event_bus_name
        }
        entries.append(entry)

    if entries:
        # EventBridge PutEvents supports max 10 entries per call
        for i in range(0, len(entries), 10):
            batch = entries[i:i+10]
            response = eventbridge.put_events(Entries=batch)
            failed = response.get('FailedEntryCount', 0)
            if failed > 0:
                logger.error(f"Failed to publish {failed} events")

    return {
        'statusCode': 200,
        'processedRecords': len(entries)
    }
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "stream_publisher" {
  function_name    = "${var.name_prefix}-stream-publisher"
  filename         = data.archive_file.stream_publisher.output_path
  source_code_hash = data.archive_file.stream_publisher.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.11"
  role             = var.lambda_execution_role
  memory_size      = 256
  timeout          = 60

  environment {
    variables = {
      EVENT_BUS_NAME = aws_cloudwatch_event_bus.fraud_events.name
    }
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-stream-publisher"
  })
}

resource "aws_cloudwatch_log_group" "stream_publisher" {
  name              = "/aws/lambda/${aws_lambda_function.stream_publisher.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

################################################################################
# DynamoDB Stream Event Source Mapping
################################################################################

resource "aws_lambda_event_source_mapping" "findings_stream" {
  event_source_arn  = var.findings_table_stream_arn
  function_name     = aws_lambda_function.stream_publisher.arn
  starting_position = "LATEST"
  batch_size        = 10

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT", "MODIFY"]
      })
    }
  }
}

################################################################################
# EventBridge Rules
################################################################################

# High-risk events rule (score > 800)
resource "aws_cloudwatch_event_rule" "high_risk" {
  name           = "${var.name_prefix}-high-risk-fraud"
  description    = "Captures high-risk fraud events with score > 800"
  event_bus_name = aws_cloudwatch_event_bus.fraud_events.name

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
    Name = "${var.name_prefix}-high-risk-fraud"
  })
}

# Medium-risk events rule (score 500-800)
resource "aws_cloudwatch_event_rule" "medium_risk" {
  name           = "${var.name_prefix}-medium-risk-fraud"
  description    = "Captures medium-risk fraud events with score 500-800"
  event_bus_name = aws_cloudwatch_event_bus.fraud_events.name

  event_pattern = jsonencode({
    source      = ["fraud-detection-platform"]
    detail-type = ["FraudFinding.REVIEW"]
    detail = {
      overallScore = [{
        numeric = [">=", 500, "<=", 800]
      }]
    }
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-medium-risk-fraud"
  })
}

################################################################################
# CloudWatch Log Group as Default Target
################################################################################

resource "aws_cloudwatch_log_group" "event_bus_logs" {
  name              = "/aws/events/${var.name_prefix}-fraud-events"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "high_risk_logs" {
  rule           = aws_cloudwatch_event_rule.high_risk.name
  event_bus_name = aws_cloudwatch_event_bus.fraud_events.name
  target_id      = "high-risk-cloudwatch"
  arn            = aws_cloudwatch_log_group.event_bus_logs.arn
}

resource "aws_cloudwatch_event_target" "medium_risk_logs" {
  rule           = aws_cloudwatch_event_rule.medium_risk.name
  event_bus_name = aws_cloudwatch_event_bus.fraud_events.name
  target_id      = "medium-risk-cloudwatch"
  arn            = aws_cloudwatch_log_group.event_bus_logs.arn
}

################################################################################
# CloudWatch Logs Resource Policy for EventBridge
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_cloudwatch_log_resource_policy" "event_bus" {
  policy_name = "${var.name_prefix}-eventbridge-logs"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "delivery.logs.amazonaws.com"]
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.event_bus_logs.arn}:*"
      }
    ]
  })
}
