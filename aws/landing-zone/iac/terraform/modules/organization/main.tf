# -----------------------------------------------------------------------------
# AWS Organizations Module
# Creates the organizational unit structure and member accounts
# -----------------------------------------------------------------------------

resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "tagpolicies.tag.amazonaws.com",
    "ram.amazonaws.com",
    "inspector2.amazonaws.com",
    "macie.amazonaws.com",
    "access-analyzer.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]

  feature_set = "ALL"
}

# -----------------------------------------------------------------------------
# Organizational Units
# -----------------------------------------------------------------------------

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads_prod" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "workloads_nonprod" {
  name      = "Non-Production"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "suspended" {
  name      = "Suspended"
  parent_id = aws_organizations_organization.this.roots[0].id
}

# -----------------------------------------------------------------------------
# Core Accounts
# -----------------------------------------------------------------------------

resource "aws_organizations_account" "security" {
  name      = var.security_account_name
  email     = var.security_account_email
  parent_id = aws_organizations_organizational_unit.security.id
  role_name = var.organization_role_name

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "security"
  })
}

resource "aws_organizations_account" "log_archive" {
  name      = var.log_archive_account_name
  email     = var.log_archive_account_email
  parent_id = aws_organizations_organizational_unit.security.id
  role_name = var.organization_role_name

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "logging"
  })
}

resource "aws_organizations_account" "network" {
  name      = var.network_account_name
  email     = var.network_account_email
  parent_id = aws_organizations_organizational_unit.infrastructure.id
  role_name = var.organization_role_name

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "network"
  })
}

resource "aws_organizations_account" "shared_services" {
  name      = var.shared_services_account_name
  email     = var.shared_services_account_email
  parent_id = aws_organizations_organizational_unit.infrastructure.id
  role_name = var.organization_role_name

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "shared-services"
  })
}

# -----------------------------------------------------------------------------
# Workload Accounts
# -----------------------------------------------------------------------------

resource "aws_organizations_account" "workload" {
  for_each = { for acct in var.workload_accounts : acct.name => acct }

  name      = each.value.name
  email     = each.value.email
  parent_id = each.value.environment == "production" ? aws_organizations_organizational_unit.workloads_prod.id : aws_organizations_organizational_unit.workloads_nonprod.id
  role_name = var.organization_role_name

  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, {
    AccountType = "workload"
    Environment = each.value.environment
    Team        = lookup(each.value, "team", "")
  })
}

# -----------------------------------------------------------------------------
# Service Control Policies
# -----------------------------------------------------------------------------

resource "aws_organizations_policy" "deny_leave_org" {
  name        = "deny-leave-organization"
  description = "Prevents member accounts from leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny-leave-org.json")
}

resource "aws_organizations_policy_attachment" "deny_leave_org" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy" "deny_root_usage" {
  name        = "deny-root-user-actions"
  description = "Prevents usage of root user credentials in member accounts"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny-root-usage.json")
}

resource "aws_organizations_policy_attachment" "deny_root_workloads" {
  policy_id = aws_organizations_policy.deny_root_usage.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy" "deny_region" {
  count = var.allowed_regions != null ? 1 : 0

  name        = "deny-unapproved-regions"
  description = "Restricts actions to approved AWS regions only"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnapprovedRegions"
        Effect    = "Deny"
        Action    = "*"
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
          ArnNotLike = {
            "aws:PrincipalARN" = "arn:aws:iam::*:role/${var.organization_role_name}"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "deny_region_workloads" {
  count = var.allowed_regions != null ? 1 : 0

  policy_id = aws_organizations_policy.deny_region[0].id
  target_id = aws_organizations_organizational_unit.workloads.id
}
