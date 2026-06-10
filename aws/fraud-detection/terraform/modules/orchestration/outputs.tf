output "ato_state_machine_arn" {
  description = "ARN of the ATO detection Step Functions state machine"
  value       = aws_sfn_state_machine.ato_detection.arn
}

output "fraud_scorer_function_arn" {
  description = "ARN of the fraud scorer Lambda function"
  value       = aws_lambda_function.fraud_scorer.arn
}

output "rules_evaluator_function_arn" {
  description = "ARN of the rules evaluator Lambda function"
  value       = aws_lambda_function.rules_evaluator.arn
}
