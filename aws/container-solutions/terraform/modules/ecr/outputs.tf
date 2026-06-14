output "repository_urls" {
  description = "Map of repository name to repository URL"
  value       = {} # TODO: replace with { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repository name to repository ARN"
  value       = {} # TODO: replace with { for k, v in aws_ecr_repository.this : k => v.arn }
}

output "registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = null # TODO: replace with values(aws_ecr_repository.this)[0].registry_id
}
