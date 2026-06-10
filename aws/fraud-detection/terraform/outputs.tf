# -----------------------------------------------------------------------------
# Root Outputs
# -----------------------------------------------------------------------------

output "api_endpoint" {
  description = "FraudCheck API endpoint URL"
  value       = module.api_ingestion.api_endpoint
}

output "api_id" {
  description = "API Gateway REST API ID"
  value       = module.api_ingestion.api_id
}

output "events_table_name" {
  description = "DynamoDB fraud events table name"
  value       = module.event_store.events_table_name
}

output "findings_table_name" {
  description = "DynamoDB fraud findings table name"
  value       = module.event_store.findings_table_name
}

output "data_bucket_name" {
  description = "S3 bucket for training data"
  value       = module.event_store.data_bucket_name
}

output "fraud_detector_name" {
  description = "Amazon Fraud Detector detector name"
  value       = module.fraud_detector.detector_name
}

output "step_function_arn" {
  description = "ARN of the ATO detection Step Function"
  value       = module.orchestration.ato_state_machine_arn
}

output "event_bus_name" {
  description = "EventBridge fraud event bus name"
  value       = module.event_bus.event_bus_name
}

output "neptune_endpoint" {
  description = "Neptune cluster endpoint (if enabled)"
  value       = var.enable_neptune ? module.neptune[0].cluster_endpoint : ""
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint (if enabled)"
  value       = var.enable_opensearch ? module.analytics[0].opensearch_endpoint : ""
}
