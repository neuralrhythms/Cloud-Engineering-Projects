output "kms_key_arns" {
  description = "Map of KMS key purpose to ARN"
  value       = {} # TODO: replace with key ARN map
}

output "eks_control_plane_sg_id" {
  description = "Security Group ID for EKS control plane"
  value       = null # TODO: replace with aws_security_group.eks_control_plane.id
}

output "eks_nodes_sg_id" {
  description = "Security Group ID for EKS worker nodes"
  value       = null # TODO: replace with aws_security_group.eks_nodes.id
}

output "alb_sg_id" {
  description = "Security Group ID for the Application Load Balancer"
  value       = null # TODO: replace with aws_security_group.alb.id
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = null # TODO: replace with aws_guardduty_detector.this.id
}
