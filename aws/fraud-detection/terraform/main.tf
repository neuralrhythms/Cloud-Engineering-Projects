# -----------------------------------------------------------------------------
# Banking Fraud Detection Platform - Main Configuration
# Orchestrates all modules for the complete fraud detection solution
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Networking - VPC, Subnets, Security Groups, VPC Endpoints
# -----------------------------------------------------------------------------

module "networking" {
  source = "./modules/networking"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  aws_region  = var.aws_region
  tags        = local.common_tags
}

# -----------------------------------------------------------------------------
# Security - KMS Keys, IAM Roles
# -----------------------------------------------------------------------------

module "security" {
  source = "./modules/security"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# -----------------------------------------------------------------------------
# Event Store - DynamoDB Tables + S3 Buckets
# -----------------------------------------------------------------------------

module "event_store" {
  source = "./modules/event-store"

  name_prefix = local.name_prefix
  kms_key_arn = module.security.kms_key_arn
  tags        = local.common_tags
}

# -----------------------------------------------------------------------------
# Amazon Fraud Detector - ML-based ATO Detection
# -----------------------------------------------------------------------------

module "fraud_detector" {
  source = "./modules/fraud-detector"

  name_prefix     = local.name_prefix
  data_bucket_arn = module.event_store.data_bucket_arn
  tags            = local.common_tags
}

# -----------------------------------------------------------------------------
# Amazon Timestream - Business Rules Engine
# -----------------------------------------------------------------------------

module "timestream" {
  source = "./modules/timestream"

  name_prefix = local.name_prefix
  kms_key_arn = module.security.kms_key_arn
  tags        = local.common_tags
}

# -----------------------------------------------------------------------------
# Amazon Neptune - Graph Database for AML Detection
# -----------------------------------------------------------------------------

module "neptune" {
  source = "./modules/neptune"
  count  = var.enable_neptune ? 1 : 0

  name_prefix    = local.name_prefix
  instance_class = var.neptune_instance_class
  subnet_ids     = module.networking.private_subnet_ids
  vpc_id         = module.networking.vpc_id
  kms_key_arn    = module.security.kms_key_arn
  tags           = local.common_tags
}

# -----------------------------------------------------------------------------
# Orchestration - Step Functions + Lambda Functions
# -----------------------------------------------------------------------------

module "orchestration" {
  source = "./modules/orchestration"

  name_prefix             = local.name_prefix
  events_table_name       = module.event_store.events_table_name
  findings_table_name     = module.event_store.findings_table_name
  events_table_arn        = module.event_store.events_table_arn
  findings_table_arn      = module.event_store.findings_table_arn
  fraud_detector_arn      = module.fraud_detector.detector_arn
  timestream_database     = module.timestream.database_name
  timestream_table        = module.timestream.table_name
  neptune_endpoint        = var.enable_neptune ? module.neptune[0].cluster_endpoint : ""
  event_bus_arn           = module.event_bus.event_bus_arn
  subnet_ids              = module.networking.private_subnet_ids
  security_group_ids      = [module.networking.lambda_security_group_id]
  kms_key_arn             = module.security.kms_key_arn
  lambda_execution_role   = module.security.lambda_execution_role_arn
  tags                    = local.common_tags
}

# -----------------------------------------------------------------------------
# API Ingestion - API Gateway + Lambda
# -----------------------------------------------------------------------------

module "api_ingestion" {
  source = "./modules/api-ingestion"

  name_prefix            = local.name_prefix
  environment            = var.environment
  state_machine_arn      = module.orchestration.ato_state_machine_arn
  events_table_name      = module.event_store.events_table_name
  events_table_arn       = module.event_store.events_table_arn
  lambda_execution_role  = module.security.lambda_execution_role_arn
  kms_key_arn            = module.security.kms_key_arn
  tags                   = local.common_tags
}

# -----------------------------------------------------------------------------
# WAF - Web Application Firewall for API Protection
# -----------------------------------------------------------------------------

module "waf" {
  source = "./modules/waf"
  count  = var.enable_waf ? 1 : 0

  name_prefix = local.name_prefix
  api_arn     = module.api_ingestion.api_stage_arn
  tags        = local.common_tags
}

# -----------------------------------------------------------------------------
# Event Bus - EventBridge + DynamoDB Streams
# -----------------------------------------------------------------------------

module "event_bus" {
  source = "./modules/event-bus"

  name_prefix              = local.name_prefix
  findings_table_stream_arn = module.event_store.findings_table_stream_arn
  lambda_execution_role    = module.security.lambda_execution_role_arn
  kms_key_arn              = module.security.kms_key_arn
  tags                     = local.common_tags
}

# -----------------------------------------------------------------------------
# Notifications - Pinpoint + SNS
# -----------------------------------------------------------------------------

module "notifications" {
  source = "./modules/notifications"

  name_prefix        = local.name_prefix
  event_bus_name     = module.event_bus.event_bus_name
  notification_email = var.notification_email
  notification_phone = var.notification_phone
  tags               = local.common_tags
}

# -----------------------------------------------------------------------------
# Analytics - OpenSearch + QuickSight Data Source
# -----------------------------------------------------------------------------

module "analytics" {
  source = "./modules/analytics"
  count  = var.enable_opensearch ? 1 : 0

  name_prefix    = local.name_prefix
  instance_type  = var.opensearch_instance_type
  instance_count = var.opensearch_instance_count
  subnet_ids     = module.networking.private_subnet_ids
  vpc_id         = module.networking.vpc_id
  kms_key_arn    = module.security.kms_key_arn
  tags           = local.common_tags
}
