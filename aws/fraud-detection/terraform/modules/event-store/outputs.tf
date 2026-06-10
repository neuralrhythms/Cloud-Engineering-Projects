output "events_table_name" {
  description = "Name of the fraud events DynamoDB table"
  value       = aws_dynamodb_table.fraud_events.name
}

output "events_table_arn" {
  description = "ARN of the fraud events DynamoDB table"
  value       = aws_dynamodb_table.fraud_events.arn
}

output "findings_table_name" {
  description = "Name of the fraud findings DynamoDB table"
  value       = aws_dynamodb_table.fraud_findings.name
}

output "findings_table_arn" {
  description = "ARN of the fraud findings DynamoDB table"
  value       = aws_dynamodb_table.fraud_findings.arn
}

output "findings_table_stream_arn" {
  description = "Stream ARN of the fraud findings DynamoDB table"
  value       = aws_dynamodb_table.fraud_findings.stream_arn
}

output "data_bucket_name" {
  description = "Name of the training data S3 bucket"
  value       = aws_s3_bucket.training_data.id
}

output "data_bucket_arn" {
  description = "ARN of the training data S3 bucket"
  value       = aws_s3_bucket.training_data.arn
}
