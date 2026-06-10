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
# Lambda Function - Fraud Scorer
################################################################################

data "archive_file" "fraud_scorer" {
  type        = "zip"
  output_path = "${path.module}/files/fraud_scorer.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

fraud_detector_client = boto3.client('frauddetector')

def handler(event, context):
    """
    Invokes Amazon Fraud Detector to score the transaction.
    """
    logger.info(f"Fraud Scorer invoked with event: {json.dumps(event)}")

    try:
        response = fraud_detector_client.get_event_prediction(
            detectorId=os.environ['DETECTOR_NAME'],
            eventId=event.get('eventId', 'unknown'),
            eventTypeName=os.environ['EVENT_TYPE_NAME'],
            entities=[{
                'entityType': 'customer',
                'entityId': event.get('userId', 'unknown')
            }],
            eventVariables={
                'ip_address': event.get('ip_address', '0.0.0.0'),
                'user_agent': event.get('user_agent', 'unknown'),
                'email_address': event.get('email_address', 'unknown@example.com')
            },
            eventTimestamp=event.get('timestamp', '2024-01-01T00:00:00Z')
        )

        score = response.get('modelScores', [{}])[0].get('scores', {})
        outcomes = [o.get('name') for o in response.get('ruleResults', [])]

        return {
            'statusCode': 200,
            'eventId': event.get('eventId'),
            'fraudScore': score,
            'outcomes': outcomes,
            'source': 'fraud_detector'
        }
    except Exception as e:
        logger.error(f"Error in fraud scoring: {str(e)}")
        raise
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "fraud_scorer" {
  function_name    = "${var.name_prefix}-fraud-scorer"
  filename         = data.archive_file.fraud_scorer.output_path
  source_code_hash = data.archive_file.fraud_scorer.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.11"
  role             = var.lambda_execution_role
  memory_size      = 512
  timeout          = 30

  environment {
    variables = {
      EVENTS_TABLE     = var.events_table_name
      FINDINGS_TABLE   = var.findings_table_name
      DETECTOR_NAME    = split("/", var.fraud_detector_arn)[1]
      EVENT_TYPE_NAME  = "${var.name_prefix}_ato_check"
      NEPTUNE_ENDPOINT = var.neptune_endpoint
      EVENT_BUS_ARN    = var.event_bus_arn
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-fraud-scorer"
  })
}

################################################################################
# Lambda Function - Rules Evaluator
################################################################################

data "archive_file" "rules_evaluator" {
  type        = "zip"
  output_path = "${path.module}/files/rules_evaluator.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

timestream_query = boto3.client('timestream-query')

def handler(event, context):
    """
    Queries Timestream for historical patterns and evaluates business rules.
    """
    logger.info(f"Rules Evaluator invoked with event: {json.dumps(event)}")

    try:
        user_id = event.get('userId', 'unknown')
        database = os.environ['TIMESTREAM_DATABASE']
        table = os.environ['TIMESTREAM_TABLE']

        query = f"""
            SELECT COUNT(*) as event_count,
                   AVG(measure_value::double) as avg_score
            FROM "{database}"."{table}"
            WHERE userId = '{user_id}'
            AND time > ago(24h)
        """

        response = timestream_query.query(QueryString=query)

        rows = response.get('Rows', [])
        event_count = int(rows[0]['Data'][0]['ScalarValue']) if rows else 0
        avg_score = float(rows[0]['Data'][1]['ScalarValue']) if rows and rows[0]['Data'][1].get('ScalarValue') else 0.0

        velocity_risk = 'HIGH' if event_count > 10 else 'MEDIUM' if event_count > 5 else 'LOW'

        return {
            'statusCode': 200,
            'eventId': event.get('eventId'),
            'velocityRisk': velocity_risk,
            'eventCount24h': event_count,
            'avgScore24h': avg_score,
            'source': 'rules_evaluator'
        }
    except Exception as e:
        logger.error(f"Error in rules evaluation: {str(e)}")
        raise
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "rules_evaluator" {
  function_name    = "${var.name_prefix}-rules-evaluator"
  filename         = data.archive_file.rules_evaluator.output_path
  source_code_hash = data.archive_file.rules_evaluator.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.11"
  role             = var.lambda_execution_role
  memory_size      = 512
  timeout          = 30

  environment {
    variables = {
      EVENTS_TABLE        = var.events_table_name
      FINDINGS_TABLE      = var.findings_table_name
      TIMESTREAM_DATABASE = var.timestream_database
      TIMESTREAM_TABLE    = var.timestream_table
      NEPTUNE_ENDPOINT    = var.neptune_endpoint
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rules-evaluator"
  })
}

################################################################################
# Lambda Function - Result Aggregator
################################################################################

data "archive_file" "result_aggregator" {
  type        = "zip"
  output_path = "${path.module}/files/result_aggregator.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    """
    Aggregates results from parallel checks and writes findings to DynamoDB.
    """
    logger.info(f"Result Aggregator invoked with event: {json.dumps(event)}")

    try:
        findings_table = dynamodb.Table(os.environ['FINDINGS_TABLE'])

        fraud_result = event.get('fraudScore', {})
        rules_result = event.get('rulesEvaluation', {})
        network_result = event.get('networkCheck', {})

        overall_score = calculate_overall_score(fraud_result, rules_result, network_result)
        risk_level = determine_risk_level(overall_score)

        finding = {
            'eventId': event.get('eventId', 'unknown'),
            'detectionType': 'ATO',
            'timestamp': datetime.utcnow().isoformat(),
            'overallScore': int(overall_score),
            'riskLevel': risk_level,
            'fraudDetectorResult': json.dumps(fraud_result),
            'rulesResult': json.dumps(rules_result),
            'networkResult': json.dumps(network_result),
            'decision': risk_level
        }

        findings_table.put_item(Item=finding)

        return {
            'statusCode': 200,
            'eventId': event.get('eventId'),
            'overallScore': overall_score,
            'riskLevel': risk_level,
            'decision': risk_level
        }
    except Exception as e:
        logger.error(f"Error in result aggregation: {str(e)}")
        raise


def calculate_overall_score(fraud_result, rules_result, network_result):
    score = 0
    if fraud_result.get('outcomes'):
        if 'block_transaction' in str(fraud_result['outcomes']):
            score += 400
        elif 'review_transaction' in str(fraud_result['outcomes']):
            score += 200

    velocity = rules_result.get('velocityRisk', 'LOW')
    if velocity == 'HIGH':
        score += 300
    elif velocity == 'MEDIUM':
        score += 150

    if network_result.get('isVpn'):
        score += 100
    if network_result.get('isTor'):
        score += 200

    return min(score, 1000)


def determine_risk_level(score):
    if score > 800:
        return 'BLOCK'
    elif score > 500:
        return 'REVIEW'
    else:
        return 'APPROVE'
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "result_aggregator" {
  function_name    = "${var.name_prefix}-result-aggregator"
  filename         = data.archive_file.result_aggregator.output_path
  source_code_hash = data.archive_file.result_aggregator.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.11"
  role             = var.lambda_execution_role
  memory_size      = 512
  timeout          = 30

  environment {
    variables = {
      EVENTS_TABLE   = var.events_table_name
      FINDINGS_TABLE = var.findings_table_name
      EVENT_BUS_ARN  = var.event_bus_arn
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-result-aggregator"
  })
}

################################################################################
# CloudWatch Log Groups for Lambda
################################################################################

resource "aws_cloudwatch_log_group" "fraud_scorer" {
  name              = "/aws/lambda/${aws_lambda_function.fraud_scorer.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "rules_evaluator" {
  name              = "/aws/lambda/${aws_lambda_function.rules_evaluator.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "result_aggregator" {
  name              = "/aws/lambda/${aws_lambda_function.result_aggregator.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

################################################################################
# Step Functions State Machine - ATO Detection
################################################################################

resource "aws_cloudwatch_log_group" "ato_state_machine" {
  name              = "/aws/states/${var.name_prefix}-ato-detection"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_sfn_state_machine" "ato_detection" {
  name     = "${var.name_prefix}-ato-detection"
  role_arn = var.lambda_execution_role
  type     = "EXPRESS"

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.ato_state_machine.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  definition = jsonencode({
    Comment = "ATO Detection Workflow - Parallel fraud analysis pipeline"
    StartAt = "ParallelFraudChecks"
    States = {
      ParallelFraudChecks = {
        Type = "Parallel"
        Branches = [
          {
            StartAt = "InvokeFraudDetector"
            States = {
              InvokeFraudDetector = {
                Type     = "Task"
                Resource = "arn:aws:states:::lambda:invoke"
                Parameters = {
                  FunctionName = aws_lambda_function.fraud_scorer.arn
                  "Payload.$"  = "$"
                }
                ResultPath = "$.fraudScore"
                End        = true
                Retry = [
                  {
                    ErrorEquals     = ["States.TaskFailed"]
                    IntervalSeconds = 2
                    MaxAttempts     = 3
                    BackoffRate     = 2.0
                  }
                ]
              }
            }
          },
          {
            StartAt = "QueryTimestream"
            States = {
              QueryTimestream = {
                Type     = "Task"
                Resource = "arn:aws:states:::lambda:invoke"
                Parameters = {
                  FunctionName = aws_lambda_function.rules_evaluator.arn
                  "Payload.$"  = "$"
                }
                ResultPath = "$.rulesEvaluation"
                End        = true
                Retry = [
                  {
                    ErrorEquals     = ["States.TaskFailed"]
                    IntervalSeconds = 2
                    MaxAttempts     = 3
                    BackoffRate     = 2.0
                  }
                ]
              }
            }
          },
          {
            StartAt = "CheckWAFNetwork"
            States = {
              CheckWAFNetwork = {
                Type     = "Task"
                Resource = "arn:aws:states:::lambda:invoke"
                Parameters = {
                  FunctionName = aws_lambda_function.result_aggregator.arn
                  "Payload.$"  = "$"
                }
                ResultPath = "$.networkCheck"
                End        = true
                Retry = [
                  {
                    ErrorEquals     = ["States.TaskFailed"]
                    IntervalSeconds = 2
                    MaxAttempts     = 3
                    BackoffRate     = 2.0
                  }
                ]
              }
            }
          }
        ]
        ResultPath = "$.parallelResults"
        Next       = "AggregateResults"
      }
      AggregateResults = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.result_aggregator.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.aggregatedResult"
        Next       = "WriteFindingsToDynamoDB"
      }
      WriteFindingsToDynamoDB = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:putItem"
        Parameters = {
          TableName = var.findings_table_name
          Item = {
            "eventId" = {
              "S.$" = "$.aggregatedResult.Payload.eventId"
            }
            "detectionType" = {
              "S" = "ATO"
            }
            "riskLevel" = {
              "S.$" = "$.aggregatedResult.Payload.riskLevel"
            }
            "overallScore" = {
              "N.$" = "States.Format('{}', $.aggregatedResult.Payload.overallScore)"
            }
          }
        }
        End = true
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
      }
    }
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ato-detection"
  })
}
