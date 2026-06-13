output "rds_mssql_endpoint" {
  description = "RDS SQL Server endpoint"
  value       = aws_db_instance.mssql.address
}

output "rds_mssql_port" {
  description = "RDS SQL Server port"
  value       = aws_db_instance.mssql.port
}

output "rds_mssql_arn" {
  description = "RDS SQL Server instance ARN"
  value       = aws_db_instance.mssql.arn
}

output "aurora_cluster_endpoint" {
  description = "Aurora MySQL writer endpoint"
  value       = aws_rds_cluster.aurora_mysql.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora MySQL reader endpoint"
  value       = aws_rds_cluster.aurora_mysql.reader_endpoint
}

output "aurora_cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.aurora_mysql.arn
}

output "dms_replication_instance_arn" {
  description = "DMS replication instance ARN"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "secret_rds_mssql_arn" {
  description = "Secrets Manager ARN for RDS SQL Server credentials"
  value       = aws_secretsmanager_secret.rds_mssql.arn
}

output "secret_aurora_mysql_arn" {
  description = "Secrets Manager ARN for Aurora MySQL credentials"
  value       = aws_secretsmanager_secret.aurora_mysql.arn
}

output "sg_rds_mssql_id" {
  description = "Security Group ID for RDS SQL Server"
  value       = aws_security_group.rds_mssql.id
}

output "sg_aurora_mysql_id" {
  description = "Security Group ID for Aurora MySQL"
  value       = aws_security_group.aurora_mysql.id
}

output "sg_dms_id" {
  description = "Security Group ID for DMS replication instance"
  value       = aws_security_group.dms.id
}
