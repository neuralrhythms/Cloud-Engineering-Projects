output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = null # TODO: replace with aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = null # TODO: replace with aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = null # TODO: replace with aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  sensitive   = true
  value       = null # TODO: replace with aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = null # TODO: replace with aws_eks_cluster.this.version
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (used for IRSA)"
  value       = null # TODO: replace with aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (used for IRSA trust policies)"
  value       = null # TODO: replace with aws_iam_openid_connect_provider.this.url
}

output "node_group_arns" {
  description = "Map of node group names to ARNs"
  value       = {} # TODO: replace with { for k, v in aws_eks_node_group.this : k => v.arn }
}

output "cluster_security_group_id" {
  description = "ID of the EKS cluster security group"
  value       = null # TODO: replace with aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
