# =============================================================================
# Environment: prod
# Purpose: Root module for production environment
# Production has stricter settings: private API endpoint, multi-AZ NAT,
# immutable ECR images, longer log retention, On-Demand nodes.
# =============================================================================

terraform {
  backend "s3" {
    # Backend config provided via backend.hcl at init time
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "aws-eks-platform"
    }
  }
}

locals {
  project      = var.project
  environment  = var.environment
  cluster_name = "${var.project}-${var.environment}-eks"
}

module "security" {
  source = "../../modules/security"

  project                   = local.project
  environment               = local.environment
  vpc_id                    = module.networking.vpc_id
  enable_guardduty          = true
  enable_security_hub       = true
  enable_config             = true
  cloudtrail_s3_bucket_name = "${local.project}-${local.environment}-cloudtrail-${var.aws_account_id}"

  tags = var.tags
}

module "networking" {
  source = "../../modules/networking"

  project              = local.project
  environment          = local.environment
  vpc_cidr             = "10.2.0.0/16"
  availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnet_cidrs  = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
  private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
  single_nat_gateway   = false  # One NAT per AZ for prod HA
  cluster_name         = local.cluster_name
  enable_vpc_endpoints = true
  flow_log_retention_days = 365

  tags = var.tags
}

module "iam" {
  source = "../../modules/iam"

  project           = local.project
  environment       = local.environment
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  tags = var.tags
}

module "ecr" {
  source = "../../modules/ecr"

  project              = local.project
  repositories         = var.ecr_repositories
  image_tag_mutability = "IMMUTABLE"  # Immutable in prod
  kms_key_arn          = module.security.kms_key_arns["ecr"]

  tags = var.tags
}

module "eks" {
  source = "../../modules/eks"

  project            = local.project
  environment        = local.environment
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_subnet_ids
  kms_key_arn        = module.security.kms_key_arns["eks-secrets"]

  endpoint_private_access = true   # Private only in prod
  endpoint_public_access  = false
  public_access_cidrs     = []

  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_node_role_arn

  node_groups = {
    general = {
      instance_types  = ["m5.xlarge", "m5.2xlarge"]
      capacity_type   = "ON_DEMAND"
      min_size        = 3
      max_size        = 20
      desired_size    = 5
      disk_size       = 100
      max_unavailable = 1
      labels = {
        "node.kubernetes.io/workload-type" = "general"
        "environment"                      = "prod"
      }
      taints = []
    }
  }

  platform_admin_role_arn = var.platform_admin_role_arn
  log_retention_days      = 90

  tags = var.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  project               = local.project
  environment           = local.environment
  cluster_name          = local.cluster_name
  kms_key_arn           = module.security.kms_key_arns["logs"]
  log_retention_days    = 90
  alert_email_addresses = var.alert_email_addresses

  tags = var.tags
}
