output "database_name" {
  description = "Name of the Timestream database"
  value       = aws_timestreamwrite_database.fraud_events.database_name
}

output "table_name" {
  description = "Name of the Timestream table"
  value       = aws_timestreamwrite_table.fraud_events.table_name
}

output "table_arn" {
  description = "ARN of the Timestream table"
  value       = aws_timestreamwrite_table.fraud_events.arn
}
