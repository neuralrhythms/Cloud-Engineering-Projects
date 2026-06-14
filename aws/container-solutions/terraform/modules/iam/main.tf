# =============================================================================
# Module: iam
# Purpose: IAM roles for EKS cluster, node groups, and IRSA-based components
# =============================================================================
# NOTE: Scaffolding placeholder.
# See docs/security/security-design.md for IAM role specifications.
# =============================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# -----------------------------------------------------------------------------
# EKS Cluster IAM Role
# -----------------------------------------------------------------------------
# TODO: aws_iam_role + aws_iam_role_policy_attachment
# Policies: AmazonEKSClusterPolicy

# -----------------------------------------------------------------------------
# EKS Node Group IAM Role
# -----------------------------------------------------------------------------
# TODO: aws_iam_role + aws_iam_role_policy_attachment
# Policies:
#   - AmazonEKSWorkerNodePolicy
#   - AmazonEKS_CNI_Policy
#   - AmazonEC2ContainerRegistryReadOnly
#   - AmazonSSMManagedInstanceCore

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller IRSA Role
# -----------------------------------------------------------------------------
# TODO: aws_iam_role (federated trust → OIDC provider)
# Condition: system:serviceaccount:kube-system:aws-load-balancer-controller
# Policy: Custom AWSLoadBalancerControllerIAMPolicy

# -----------------------------------------------------------------------------
# Cluster Autoscaler IRSA Role
# -----------------------------------------------------------------------------
# TODO: aws_iam_role (federated trust → OIDC provider)
# Condition: system:serviceaccount:kube-system:cluster-autoscaler
# Policy: Custom ClusterAutoscalerPolicy

# -----------------------------------------------------------------------------
# External Secrets Operator IRSA Role
# -----------------------------------------------------------------------------
# TODO: aws_iam_role (federated trust → OIDC provider)
# Condition: system:serviceaccount:platform-system:external-secrets
# Policy: SecretsManager read (scoped to project/environment prefix)

# -----------------------------------------------------------------------------
# Jenkins Deploy Role
# -----------------------------------------------------------------------------
# TODO: aws_iam_role (trusted by Jenkins EC2 instance or EKS OIDC)
# Permissions:
#   - ECR: GetAuthorizationToken, BatchGetImage, PutImage
#   - EKS: DescribeCluster
#   - SecretsManager: GetSecretValue (scoped)
