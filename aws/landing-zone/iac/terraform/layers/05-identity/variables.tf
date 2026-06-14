# -----------------------------------------------------------------------------
# Layer 05: Identity - Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_assignments" {
  description = "List of account assignments mapping groups/users to accounts with permission sets"
  type = list(object({
    principal_name   = string
    principal_id     = string
    principal_type   = string
    account_id       = string
    permission_set   = string
  }))
  default = []
}
