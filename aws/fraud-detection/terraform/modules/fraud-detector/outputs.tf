output "detector_name" {
  description = "Name of the Fraud Detector"
  value       = aws_frauddetector_detector.ato_detector.name
}

output "detector_arn" {
  description = "ARN of the Fraud Detector"
  value       = aws_frauddetector_detector.ato_detector.arn
}

output "event_type_name" {
  description = "Name of the Fraud Detector event type"
  value       = aws_frauddetector_event_type.ato_check.name
}
