output "kms_key_arn" {
  description = "ARN of the KMS Customer Managed Key"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID of the KMS Customer Managed Key"
  value       = aws_kms_key.main.key_id
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution IAM role"
  value       = aws_iam_role.lambda_execution.arn
}

output "step_functions_role_arn" {
  description = "ARN of the Step Functions execution IAM role"
  value       = aws_iam_role.step_functions.arn
}
