# -----------------------------------------------------------------------------
# IAM Identity Center (AWS SSO) Module
# Configures permission sets and account assignments
# Deployed in the Management Account
# -----------------------------------------------------------------------------

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# -----------------------------------------------------------------------------
# Permission Sets
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_permission_set" "admin" {
  name             = "AdministratorAccess"
  description      = "Full administrator access - use for break-glass only"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT1H"
  relay_state      = ""

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}

resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "ReadOnlyAccess"
  description      = "Read-only access to all AWS services"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
}

resource "aws_ssoadmin_permission_set" "security_audit" {
  name             = "SecurityAudit"
  description      = "Security audit access for security team"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "security_audit" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
  permission_set_arn = aws_ssoadmin_permission_set.security_audit.arn
}

resource "aws_ssoadmin_permission_set" "developer" {
  name             = "DeveloperAccess"
  description      = "Developer access to non-production workload accounts"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "developer_poweruser" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn
}

# Deny IAM and Organizations modifications for developers
resource "aws_ssoadmin_permission_set_inline_policy" "developer_deny" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMAndOrgChanges"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "organizations:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_ssoadmin_permission_set" "network_admin" {
  name             = "NetworkAdministrator"
  description      = "Network administration access"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "network_admin" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/NetworkAdministrator"
  permission_set_arn = aws_ssoadmin_permission_set.network_admin.arn
}

resource "aws_ssoadmin_permission_set" "billing" {
  name             = "BillingAccess"
  description      = "Billing and cost management access"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"

  tags = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "billing" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/Billing"
  permission_set_arn = aws_ssoadmin_permission_set.billing.arn
}

# -----------------------------------------------------------------------------
# Account Assignments (configurable via variable)
# -----------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = { for assignment in var.account_assignments : "${assignment.principal_name}-${assignment.account_id}-${assignment.permission_set}" => assignment }

  instance_arn       = local.sso_instance_arn
  permission_set_arn = lookup(local.permission_set_arns, each.value.permission_set, "")

  principal_id   = each.value.principal_id
  principal_type = each.value.principal_type
  target_id      = each.value.account_id
  target_type    = "AWS_ACCOUNT"
}

locals {
  permission_set_arns = {
    "AdministratorAccess"    = aws_ssoadmin_permission_set.admin.arn
    "ReadOnlyAccess"         = aws_ssoadmin_permission_set.readonly.arn
    "SecurityAudit"          = aws_ssoadmin_permission_set.security_audit.arn
    "DeveloperAccess"        = aws_ssoadmin_permission_set.developer.arn
    "NetworkAdministrator"   = aws_ssoadmin_permission_set.network_admin.arn
    "BillingAccess"          = aws_ssoadmin_permission_set.billing.arn
  }
}
