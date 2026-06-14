output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = null # TODO: replace with aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = null # TODO: replace with aws_iam_role.eks_node.arn
}

output "alb_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = null # TODO: replace with aws_iam_role.alb_controller.arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IRSA role"
  value       = null # TODO: replace with aws_iam_role.cluster_autoscaler.arn
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets Operator IRSA role"
  value       = null # TODO: replace with aws_iam_role.external_secrets.arn
}

output "jenkins_deploy_role_arn" {
  description = "ARN of the Jenkins deployment role"
  value       = null # TODO: replace with aws_iam_role.jenkins_deploy.arn
}
