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
# KMS Customer Managed Key
################################################################################

resource "aws_kms_key" "main" {
  description             = "CMK for ${var.name_prefix} fraud detection platform encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.name_prefix}-key-policy"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowLambdaRoleUsage"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_execution.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowStepFunctionsRoleUsage"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.step_functions.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${local.region}:${local.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cmk"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.name_prefix}-fraud-detection"
  target_key_id = aws_kms_key.main.key_id
}

################################################################################
# Lambda Execution Role
################################################################################

resource "aws_iam_role" "lambda_execution" {
  name = "${var.name_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lambda-execution-role"
  })
}

# DynamoDB permissions
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.name_prefix}-lambda-dynamodb"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable",
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ]
        Resource = [
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.name_prefix}-*",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.name_prefix}-*/index/*",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.name_prefix}-*/stream/*"
        ]
      }
    ]
  })
}

# S3 permissions
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.name_prefix}-lambda-s3"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.name_prefix}-*",
          "arn:aws:s3:::${var.name_prefix}-*/*"
        ]
      }
    ]
  })
}

# Step Functions permissions
resource "aws_iam_role_policy" "lambda_stepfunctions" {
  name = "${var.name_prefix}-lambda-stepfunctions"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:StartSyncExecution",
          "states:DescribeExecution",
          "states:StopExecution"
        ]
        Resource = "arn:aws:states:${local.region}:${local.account_id}:stateMachine:${var.name_prefix}-*"
      }
    ]
  })
}

# Fraud Detector permissions
resource "aws_iam_role_policy" "lambda_fraud_detector" {
  name = "${var.name_prefix}-lambda-frauddetector"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "frauddetector:GetEventPrediction",
          "frauddetector:SendEvent",
          "frauddetector:GetDetectors",
          "frauddetector:GetRules",
          "frauddetector:GetVariables",
          "frauddetector:GetEventTypes",
          "frauddetector:BatchGetVariable"
        ]
        Resource = "*"
      }
    ]
  })
}

# Timestream permissions
resource "aws_iam_role_policy" "lambda_timestream" {
  name = "${var.name_prefix}-lambda-timestream"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "timestream:WriteRecords",
          "timestream:DescribeEndpoints",
          "timestream:Select",
          "timestream:DescribeTable",
          "timestream:DescribeDatabase"
        ]
        Resource = [
          "arn:aws:timestream:${local.region}:${local.account_id}:database/${var.name_prefix}-*",
          "arn:aws:timestream:${local.region}:${local.account_id}:database/${var.name_prefix}-*/table/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "timestream:DescribeEndpoints"
        Resource = "*"
      }
    ]
  })
}

# Neptune permissions
resource "aws_iam_role_policy" "lambda_neptune" {
  name = "${var.name_prefix}-lambda-neptune"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "neptune-db:ReadDataViaQuery",
          "neptune-db:WriteDataViaQuery",
          "neptune-db:DeleteDataViaQuery",
          "neptune-db:connect"
        ]
        Resource = "arn:aws:neptune-db:${local.region}:${local.account_id}:*/*"
      }
    ]
  })
}

# EventBridge permissions
resource "aws_iam_role_policy" "lambda_eventbridge" {
  name = "${var.name_prefix}-lambda-eventbridge"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents",
          "events:PutRule",
          "events:DescribeRule",
          "events:ListRules"
        ]
        Resource = [
          "arn:aws:events:${local.region}:${local.account_id}:event-bus/${var.name_prefix}-*",
          "arn:aws:events:${local.region}:${local.account_id}:rule/${var.name_prefix}-*"
        ]
      }
    ]
  })
}

# CloudWatch Logs permissions
resource "aws_iam_role_policy" "lambda_cloudwatch" {
  name = "${var.name_prefix}-lambda-cloudwatch"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      }
    ]
  })
}

# KMS permissions
resource "aws_iam_role_policy" "lambda_kms" {
  name = "${var.name_prefix}-lambda-kms"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

# VPC Networking permissions
resource "aws_iam_role_policy" "lambda_vpc" {
  name = "${var.name_prefix}-lambda-vpc"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Step Functions Execution Role
################################################################################

resource "aws_iam_role" "step_functions" {
  name = "${var.name_prefix}-stepfunctions-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-stepfunctions-execution-role"
  })
}

resource "aws_iam_role_policy" "step_functions_lambda" {
  name = "${var.name_prefix}-sfn-lambda"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.name_prefix}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_functions_dynamodb" {
  name = "${var.name_prefix}-sfn-dynamodb"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.name_prefix}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_functions_xray" {
  name = "${var.name_prefix}-sfn-xray"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_functions_logs" {
  name = "${var.name_prefix}-sfn-logs"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:CreateLogStream",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}
