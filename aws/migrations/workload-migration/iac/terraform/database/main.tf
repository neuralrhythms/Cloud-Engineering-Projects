################################################################################
# Database — RDS for SQL Server (Multi-AZ) + Aurora Serverless v2 (MySQL)
# Reference framework for VMware → AWS Cloud Native Migration
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      TerraformManaged = "true"
      Environment      = var.environment
      Owner            = var.owner_tag
      CostCentre       = var.cost_centre
      Application      = "database"
      MigrationWave    = "wave-2"
    }
  }
}

################################################################################
# DB Subnet Groups
################################################################################

resource "aws_db_subnet_group" "rds" {
  name        = "dbsng-rds-${var.environment}"
  description = "Subnet group for RDS SQL Server"
  subnet_ids  = var.data_subnet_ids

  tags = { Name = "dbsng-rds-${var.environment}" }
}

resource "aws_rds_cluster_parameter_group" "aurora_mysql" {
  name        = "pg-aurora-mysql-${var.environment}"
  family      = "aurora-mysql8.0"
  description = "Aurora MySQL 8.0 parameter group — migration framework"

  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }

  parameter {
    name  = "server_audit_logging"
    value = "1"
  }

  parameter {
    name  = "server_audit_events"
    value = "CONNECT,QUERY_DDL,QUERY_DML"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "time_zone"
    value = "UTC"
  }

  tags = { Name = "pg-aurora-mysql-${var.environment}" }
}

resource "aws_db_parameter_group" "rds_mssql" {
  name        = "pg-rds-mssql-${var.environment}"
  family      = "sqlserver-se-15.0"
  description = "RDS SQL Server 2019 SE parameter group — migration framework"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = { Name = "pg-rds-mssql-${var.environment}" }
}

################################################################################
# Secrets Manager — Database Credentials
################################################################################

resource "random_password" "rds_mssql" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.<>?"
}

resource "random_password" "aurora_mysql" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.<>?"
}

resource "aws_secretsmanager_secret" "rds_mssql" {
  name        = "/${var.environment}/database/rds-mssql/admin"
  description = "RDS SQL Server admin credentials"
  kms_key_id  = var.kms_key_secrets_arn

  tags = { Name = "secret-rds-mssql-admin-${var.environment}" }
}

resource "aws_secretsmanager_secret_version" "rds_mssql" {
  secret_id = aws_secretsmanager_secret.rds_mssql.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.rds_mssql.result
    engine   = "sqlserver"
    host     = aws_db_instance.mssql.address
    port     = 1433
    dbname   = "master"
  })
}

resource "aws_secretsmanager_secret" "aurora_mysql" {
  name        = "/${var.environment}/database/aurora-mysql/admin"
  description = "Aurora MySQL admin credentials"
  kms_key_id  = var.kms_key_secrets_arn

  tags = { Name = "secret-aurora-mysql-admin-${var.environment}" }
}

resource "aws_secretsmanager_secret_version" "aurora_mysql" {
  secret_id = aws_secretsmanager_secret.aurora_mysql.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.aurora_mysql.result
    engine   = "aurora-mysql"
    host     = aws_rds_cluster.aurora_mysql.endpoint
    port     = 3306
    dbname   = "main"
  })
}

################################################################################
# Security Groups
################################################################################

resource "aws_security_group" "rds_mssql" {
  name        = "sg-${var.environment}-data-rds-mssql"
  description = "Allow SQL Server access from application and DMS tiers"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SQL Server from application tier"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = var.app_security_group_ids
  }

  ingress {
    description     = "SQL Server from DMS replication instance"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [aws_security_group.dms.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "sg-${var.environment}-data-rds-mssql" }
}

resource "aws_security_group" "aurora_mysql" {
  name        = "sg-${var.environment}-data-aurora"
  description = "Allow MySQL access from application and DMS tiers"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from application tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.app_security_group_ids
  }

  ingress {
    description     = "MySQL from DMS replication instance"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.dms.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "sg-${var.environment}-data-aurora" }
}

resource "aws_security_group" "dms" {
  name        = "sg-${var.environment}-dms"
  description = "Security group for DMS replication instance"
  vpc_id      = var.vpc_id

  egress {
    description = "SQL Server to RDS target"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "MySQL to Aurora target"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "SQL Server source in SDDC"
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = var.sddc_db_cidrs
  }

  egress {
    description = "MySQL source in SDDC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.sddc_db_cidrs
  }

  tags = { Name = "sg-${var.environment}-dms" }
}

################################################################################
# RDS for SQL Server (Multi-AZ)
################################################################################

resource "aws_db_instance" "mssql" {
  identifier     = "rds-mssql-${var.environment}"
  engine         = "sqlserver-se"
  engine_version = var.mssql_engine_version
  instance_class = var.mssql_instance_class
  license_model  = var.mssql_license_model # "license-included" or "bring-your-own-license"

  username = "admin"
  password = random_password.rds_mssql.result

  storage_type          = "gp3"
  allocated_storage     = var.mssql_allocated_storage_gb
  max_allocated_storage = var.mssql_max_allocated_storage_gb
  storage_encrypted     = true
  kms_key_id            = var.kms_key_rds_mssql_arn

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds_mssql.id]

  parameter_group_name = aws_db_parameter_group.rds_mssql.name
  option_group_name    = var.mssql_option_group_name # Pre-created with SQLSERVER_BACKUP_RESTORE

  backup_retention_period   = 7
  backup_window             = "01:00-02:00"
  maintenance_window        = "sun:02:00-sun:03:00"
  auto_minor_version_upgrade = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "rds-mssql-${var.environment}-final-snapshot"

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_rds_mssql_arn
  performance_insights_retention_period = 7

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  enabled_cloudwatch_logs_exports = ["error", "agent"]

  tags = {
    Name          = "rds-mssql-${var.environment}"
    BackupPolicy  = "daily-7d"
    PatchGroup    = "windows-${var.environment}"
  }
}

################################################################################
# Aurora Serverless v2 (MySQL-compatible)
################################################################################

resource "aws_db_subnet_group" "aurora" {
  name        = "dbsng-aurora-${var.environment}"
  description = "Subnet group for Aurora MySQL Serverless v2"
  subnet_ids  = var.data_subnet_ids

  tags = { Name = "dbsng-aurora-${var.environment}" }
}

resource "aws_rds_cluster" "aurora_mysql" {
  cluster_identifier      = "aurora-mysql-${var.environment}"
  engine                  = "aurora-mysql"
  engine_mode             = "provisioned" # Serverless v2 uses provisioned engine_mode
  engine_version          = var.aurora_mysql_engine_version
  database_name           = "main"
  master_username         = "admin"
  master_password         = random_password.aurora_mysql.result

  storage_encrypted = true
  kms_key_id        = var.kms_key_aurora_mysql_arn

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora_mysql.id]

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_mysql.name

  backup_retention_period      = 7
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "sun:03:00-sun:04:00"

  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "aurora-mysql-${var.environment}-final-snapshot"
  apply_immediately           = false

  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_acu
    max_capacity = var.aurora_max_acu
  }

  tags = {
    Name         = "aurora-mysql-${var.environment}"
    BackupPolicy = "daily-7d"
  }
}

resource "aws_rds_cluster_instance" "aurora_writer" {
  identifier         = "aurora-mysql-${var.environment}-writer"
  cluster_identifier = aws_rds_cluster.aurora_mysql.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_mysql.engine
  engine_version     = aws_rds_cluster.aurora_mysql.engine_version

  db_subnet_group_name = aws_db_subnet_group.aurora.name

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn
  auto_minor_version_upgrade   = true

  tags = {
    Name = "aurora-mysql-${var.environment}-writer"
    Role = "writer"
  }
}

resource "aws_rds_cluster_instance" "aurora_reader" {
  identifier         = "aurora-mysql-${var.environment}-reader"
  cluster_identifier = aws_rds_cluster.aurora_mysql.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_mysql.engine
  engine_version     = aws_rds_cluster.aurora_mysql.engine_version

  db_subnet_group_name = aws_db_subnet_group.aurora.name

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn

  tags = {
    Name = "aurora-mysql-${var.environment}-reader"
    Role = "reader"
  }
}

################################################################################
# DMS Replication Instance
################################################################################

resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "dms-sng-${var.environment}"
  replication_subnet_group_description = "DMS replication instance subnet group"
  subnet_ids                           = var.data_subnet_ids

  tags = { Name = "dms-sng-${var.environment}" }
}

resource "aws_dms_replication_instance" "main" {
  replication_instance_id    = "dms-rep-${var.environment}"
  replication_instance_class = var.dms_instance_class
  allocated_storage          = 200
  multi_az                   = true
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  tags = {
    Name          = "dms-rep-${var.environment}"
    MigrationWave = "wave-2"
  }
}

# DMS Source Endpoint — MS SQL Server (SDDC)
resource "aws_dms_endpoint" "src_mssql" {
  endpoint_id   = "ep-src-mssql-${var.environment}"
  endpoint_type = "source"
  engine_name   = "sqlserver"

  server_name = var.sddc_mssql_host
  port        = 1433
  username    = var.sddc_mssql_username
  password    = var.sddc_mssql_password
  database_name = var.sddc_mssql_database

  ssl_mode = "require"

  tags = { Name = "ep-src-mssql-${var.environment}" }
}

# DMS Source Endpoint — MySQL (SDDC)
resource "aws_dms_endpoint" "src_mysql" {
  endpoint_id   = "ep-src-mysql-${var.environment}"
  endpoint_type = "source"
  engine_name   = "mysql"

  server_name   = var.sddc_mysql_host
  port          = 3306
  username      = var.sddc_mysql_username
  password      = var.sddc_mysql_password
  database_name = var.sddc_mysql_database

  ssl_mode = "require"

  tags = { Name = "ep-src-mysql-${var.environment}" }
}

# DMS Target Endpoint — RDS SQL Server
resource "aws_dms_endpoint" "tgt_rds_mssql" {
  endpoint_id   = "ep-tgt-rds-mssql-${var.environment}"
  endpoint_type = "target"
  engine_name   = "sqlserver"

  server_name   = aws_db_instance.mssql.address
  port          = 1433
  username      = "admin"
  password      = random_password.rds_mssql.result
  database_name = "master"

  ssl_mode = "require"

  tags = { Name = "ep-tgt-rds-mssql-${var.environment}" }
}

# DMS Target Endpoint — Aurora MySQL
resource "aws_dms_endpoint" "tgt_aurora_mysql" {
  endpoint_id   = "ep-tgt-aurora-mysql-${var.environment}"
  endpoint_type = "target"
  engine_name   = "aurora"

  server_name   = aws_rds_cluster.aurora_mysql.endpoint
  port          = 3306
  username      = "admin"
  password      = random_password.aurora_mysql.result
  database_name = "main"

  ssl_mode = "require"

  tags = { Name = "ep-tgt-aurora-mysql-${var.environment}" }
}

# DMS Replication Task — SQL Server Full Load
resource "aws_dms_replication_task" "mssql_fullload" {
  replication_task_id      = "task-mssql-fullload-${var.environment}"
  migration_type           = "full-load"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.src_mssql.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.tgt_rds_mssql.endpoint_arn
  table_mappings           = file("${path.module}/dms-table-mappings/mssql-all-tables.json")

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema              = ""
      SupportLobs               = true
      FullLobMode               = false
      LobChunkSize              = 64
      LimitedSizeLobMode        = true
      LobMaxSize                = 32768
    }
    FullLoadSettings = {
      TargetTablePrepMode       = "DO_NOTHING"
      CreatePkAfterFullLoad     = false
      StopTaskCachedChangesApplied = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks       = 8
      TransactionConsistencyTimeout = 600
      CommitRate                = 50000
    }
    Logging = {
      EnableLogging = true
    }
  })

  tags = { Name = "task-mssql-fullload-${var.environment}" }
}

# DMS Replication Task — MySQL Full Load
resource "aws_dms_replication_task" "mysql_fullload" {
  replication_task_id      = "task-mysql-fullload-${var.environment}"
  migration_type           = "full-load"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.src_mysql.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.tgt_aurora_mysql.endpoint_arn
  table_mappings           = file("${path.module}/dms-table-mappings/mysql-all-tables.json")

  replication_task_settings = jsonencode({
    TargetMetadata = {
      SupportLobs        = true
      FullLobMode        = false
      LimitedSizeLobMode = true
      LobMaxSize         = 32768
    }
    FullLoadSettings = {
      TargetTablePrepMode   = "DO_NOTHING"
      MaxFullLoadSubTasks   = 8
      CommitRate            = 50000
    }
    Logging = {
      EnableLogging = true
    }
  })

  tags = { Name = "task-mysql-fullload-${var.environment}" }
}

################################################################################
# IAM — RDS Enhanced Monitoring Role
################################################################################

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "role-rds-enhanced-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

################################################################################
# CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "alarm-rds-mssql-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS SQL Server CPU > 80% for 10 minutes"
  alarm_actions       = [var.sns_ops_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.mssql.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "alarm-rds-mssql-storage-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 21474836480 # 20 GB in bytes
  alarm_description   = "RDS SQL Server free storage < 20 GB"
  alarm_actions       = [var.sns_ops_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.mssql.id
  }
}

resource "aws_cloudwatch_metric_alarm" "aurora_acu" {
  alarm_name          = "alarm-aurora-acu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.aurora_max_acu * 0.875
  alarm_description   = "Aurora Serverless v2 ACU > 87.5% of maximum"
  alarm_actions       = [var.sns_ops_topic_arn]

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora_mysql.cluster_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "dms_lag" {
  alarm_name          = "alarm-dms-replication-lag-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CDCLatencySource"
  namespace           = "AWS/DMS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 300
  alarm_description   = "DMS CDC source latency > 300 seconds"
  alarm_actions       = [var.sns_ops_topic_arn]

  dimensions = {
    ReplicationInstanceIdentifier = aws_dms_replication_instance.main.replication_instance_id
  }
}
