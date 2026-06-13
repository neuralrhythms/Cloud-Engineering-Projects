output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS web app service name"
  value       = aws_ecs_service.web_app.name
}

output "ecr_web_app_url" {
  description = "ECR repository URL for web app"
  value       = aws_ecr_repository.web_app.repository_url
}

output "ecr_app_backend_url" {
  description = "ECR repository URL for app backend"
  value       = aws_ecr_repository.app_backend.repository_url
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "sg_alb_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "sg_ecs_web_id" {
  description = "ECS web tier Security Group ID"
  value       = aws_security_group.ecs_web.id
}

output "sg_app_backend_id" {
  description = "EC2/ECS backend Security Group ID"
  value       = aws_security_group.app_backend.id
}

output "sg_mgn_id" {
  description = "MGN replication Security Group ID"
  value       = aws_security_group.mgn.id
}

output "mgn_launch_template_id" {
  description = "MGN rehost EC2 launch template ID"
  value       = aws_launch_template.mgn_rehost.id
}
