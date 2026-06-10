################################################################################
# Timestream Database
################################################################################

resource "aws_timestreamwrite_database" "fraud_events" {
  database_name = "${var.name_prefix}-fraud-events"
  kms_key_id    = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-fraud-events-db"
  })
}

################################################################################
# Timestream Table
################################################################################

resource "aws_timestreamwrite_table" "fraud_events" {
  database_name = aws_timestreamwrite_database.fraud_events.database_name
  table_name    = "${var.name_prefix}-fraud-events"

  retention_properties {
    memory_store_retention_period_in_hours  = 24
    magnetic_store_retention_period_in_days = 365
  }

  magnetic_store_write_properties {
    enable_magnetic_store_writes = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-fraud-events-table"
  })
}
