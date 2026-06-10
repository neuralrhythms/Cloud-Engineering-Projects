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
# Lambda Function - Event Ingester
################################################################################

data "archive_file" "event_ingester" {
  type        = "zip"
  output_path = "${path.module}/files/event_ingester.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os
import uuid
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
sfn_client = boto3.client('stepfunctions')

REQUIRED_FIELDS = ['userId', 'ip_address', 'user_agent', 'email_address']

def handler(event, context):
    """
    Validates incoming fraud check request, stores in DynamoDB,
    and starts the Step Functions workflow.
    """
    logger.info(f"Event Ingester invoked")

    try:
        body = json.loads(event.get('body', '{}'))

        # Validate required fields
        missing_fields = [f for f in REQUIRED_FIELDS if f not in body]
        if missing_fields:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Missing required fields',
                    'missing': missing_fields
                })
            }

        # Generate event ID and timestamp
        event_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()

        # Store event in DynamoDB
        table = dynamodb.Table(os.environ['EVENTS_TABLE'])
        item = {
            'eventId': event_id,
            'timestamp': timestamp,
            'userId': body['userId'],
            'ip_address': body['ip_address'],
            'user_agent': body['user_agent'],
            'email_address': body['email_address'],
            'status': 'PROCESSING',
            'source': event.get('resource', '/unknown'),
            'requestContext': {
                'sourceIp': event.get('requestContext', {}).get('identity', {}).get('sourceIp', 'unknown')
            }
        }
        table.put_item(Item=item)

        # Start Step Functions execution
        sfn_input = {
            'eventId': event_id,
            'timestamp': timestamp,
            'userId': body['userId'],
            'ip_address': body['ip_address'],
            'user_agent': body['user_agent'],
            'email_address': body['email_address']
        }

        sfn_response = sfn_client.start_sync_execution(
            stateMachineArn=os.environ['STATE_MACHINE_ARN'],
            name=f"ato-{event_id}",
            input=json.dumps(sfn_input)
        )

        result = json.loads(sfn_response.get('output', '{}'))

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'eventId': event_id,
                'status': 'COMPLETED',
                'result': result
            })
        }
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "event_ingester" {
  function_name    = "${var.name_prefix}-event-ingester"
  filename         = data.archive_file.event_ingester.output_path
  source_code_hash = data.archive_file.event_ingester.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.11"
  role             = var.lambda_execution_role
  memory_size      = 512
  timeout          = 30

  environment {
    variables = {
      EVENTS_TABLE      = var.events_table_name
      STATE_MACHINE_ARN = var.state_machine_arn
    }
  }

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-event-ingester"
  })
}

resource "aws_cloudwatch_log_group" "event_ingester" {
  name              = "/aws/lambda/${aws_lambda_function.event_ingester.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

################################################################################
# API Gateway REST API
################################################################################

resource "aws_api_gateway_rest_api" "fraud_api" {
  name        = "${var.name_prefix}-fraud-api"
  description = "Banking Fraud Detection API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-fraud-api"
  })
}

################################################################################
# API Gateway Resources
################################################################################

# /fraudcheck
resource "aws_api_gateway_resource" "fraudcheck" {
  rest_api_id = aws_api_gateway_rest_api.fraud_api.id
  parent_id   = aws_api_gateway_rest_api.fraud_api.root_resource_id
  path_part   = "fraudcheck"
}

# /fraudcheck/ato
resource "aws_api_gateway_resource" "ato" {
  rest_api_id = aws_api_gateway_rest_api.fraud_api.id
  parent_id   = aws_api_gateway_resource.fraudcheck.id
  path_part   = "ato"
}

# /fraudcheck/aml
resource "aws_api_gateway_resource" "aml" {
  rest_api_id = aws_api_gateway_rest_api.fraud_api.id
  parent_id   = aws_api_gateway_resource.fraudcheck.id
  path_part   = "aml"
}

################################################################################
# API Gateway Methods & Integrations - ATO
################################################################################

resource "aws_api_gateway_method" "ato_post" {
  rest_api_id   = aws_api_gateway_rest_api.fraud_api.id
  resource_id   = aws_api_gateway_resource.ato.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "ato_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.fraud_api.id
  resource_id             = aws_api_gateway_resource.ato.id
  http_method             = aws_api_gateway_method.ato_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.event_ingester.invoke_arn
}

################################################################################
# API Gateway Methods & Integrations - AML
################################################################################

resource "aws_api_gateway_method" "aml_post" {
  rest_api_id   = aws_api_gateway_rest_api.fraud_api.id
  resource_id   = aws_api_gateway_resource.aml.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "aml_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.fraud_api.id
  resource_id             = aws_api_gateway_resource.aml.id
  http_method             = aws_api_gateway_method.aml_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.event_ingester.invoke_arn
}

################################################################################
# API Gateway Deployment & Stage
################################################################################

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.fraud_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.fraudcheck.id,
      aws_api_gateway_resource.ato.id,
      aws_api_gateway_resource.aml.id,
      aws_api_gateway_method.ato_post.id,
      aws_api_gateway_method.aml_post.id,
      aws_api_gateway_integration.ato_lambda.id,
      aws_api_gateway_integration.aml_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.fraud_api.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
  }

  xray_tracing_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-fraud-api-${var.environment}"
  })
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.fraud_api.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = true
    throttling_burst_limit = 500
    throttling_rate_limit  = 1000
  }
}

################################################################################
# CloudWatch Log Group for API Gateway
################################################################################

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}-fraud-api"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

################################################################################
# Lambda Permission for API Gateway
################################################################################

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_ingester.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.fraud_api.execution_arn}/*/*"
}

################################################################################
# API Gateway Account (for CloudWatch logging)
################################################################################

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.name_prefix}-api-gateway-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
