# =============================================================================
# Environment: dev
# Purpose: Root module for dev environment — composes all platform modules
# =============================================================================

terraform {
  backend "s3" {
    # Backend config provided via backend.hcl at init time
    # terraform init -backend-config=backend.hcl
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
  project     = var.project
  environment = var.environment
  cluster_name = "${var.project}-${var.environment}-eks"
}

# -----------------------------------------------------------------------------
# Security (KMS, GuardDuty, Security Hub, CloudTrail, Security Groups)
# -----------------------------------------------------------------------------
module "security" {
  source = "../../modules/security"

  project                  = local.project
  environment              = local.environment
  vpc_id                   = module.networking.vpc_id
  enable_guardduty         = true
  enable_security_hub      = true
  enable_config            = false  # Cost saving in dev
  cloudtrail_s3_bucket_name = "${local.project}-${local.environment}-cloudtrail-${var.aws_account_id}"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Networking (VPC, Subnets, NAT, VPC Endpoints)
# -----------------------------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  project              = local.project
  environment          = local.environment
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  single_nat_gateway   = true  # Cost saving in dev
  cluster_name         = local.cluster_name
  enable_vpc_endpoints = true
  flow_log_retention_days = 7  # Shorter retention in dev

  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM (Cluster role, node role, IRSA roles)
# -----------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  project           = local.project
  environment       = local.environment
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  tags = var.tags
}

# -----------------------------------------------------------------------------
# ECR (Container registries)
# -----------------------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  project              = local.project
  repositories         = var.ecr_repositories
  image_tag_mutability = "MUTABLE"  # Mutable in dev for easier testing
  kms_key_arn          = module.security.kms_key_arns["ecr"]

  tags = var.tags
}

# -----------------------------------------------------------------------------
# EKS (Cluster, Node Groups, Add-ons)
# -----------------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  project            = local.project
  environment        = local.environment
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_subnet_ids
  kms_key_arn        = module.security.kms_key_arns["eks-secrets"]

  endpoint_private_access = false  # Public+private in dev for ease of access
  endpoint_public_access  = true
  public_access_cidrs     = var.allowed_public_cidrs

  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_node_role_arn

  node_groups = {
    general = {
      instance_types  = ["t3.medium", "t3.large"]
      capacity_type   = "SPOT"  # Spot in dev for cost saving
      min_size        = 1
      max_size        = 5
      desired_size    = 2
      disk_size       = 50
      max_unavailable = 1
      labels = {
        "node.kubernetes.io/workload-type" = "general"
        "environment"                      = "dev"
      }
      taints = []
    }
  }

  platform_admin_role_arn = var.platform_admin_role_arn
  log_retention_days      = 30

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Monitoring (CloudWatch, Alarms, Dashboards)
# -----------------------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"

  project            = local.project
  environment        = local.environment
  cluster_name       = local.cluster_name
  kms_key_arn        = module.security.kms_key_arns["logs"]
  log_retention_days = 30
  alert_email_addresses = var.alert_email_addresses

  tags = var.tags
}
