# =============================================================================
# Module: ecr
# Purpose: ECR repositories with scanning, lifecycle policies, and encryption
# =============================================================================
# NOTE: Scaffolding placeholder.
# =============================================================================

locals {
  name_prefix = "${var.project}"
}

# -----------------------------------------------------------------------------
# ECR Repositories
# -----------------------------------------------------------------------------
# TODO: aws_ecr_repository for each repository in var.repositories
#
# resource "aws_ecr_repository" "this" {
#   for_each = toset(var.repositories)
#
#   name                 = "${local.name_prefix}/${each.value}"
#   image_tag_mutability = var.image_tag_mutability
#
#   image_scanning_configuration {
#     scan_on_push = true
#   }
#
#   encryption_configuration {
#     encryption_type = "KMS"
#     kms_key         = var.kms_key_arn
#   }
#
#   tags = merge(var.tags, {
#     Name      = "${local.name_prefix}/${each.value}"
#     ManagedBy = "terraform"
#   })
# }

# -----------------------------------------------------------------------------
# ECR Lifecycle Policy
# -----------------------------------------------------------------------------
# TODO: aws_ecr_lifecycle_policy
# Rule 1: Expire untagged images after 7 days
# Rule 2: Keep last N tagged images

# -----------------------------------------------------------------------------
# ECR Repository Policy (cross-account access, if required)
# -----------------------------------------------------------------------------
# TODO: aws_ecr_repository_policy (optional)
