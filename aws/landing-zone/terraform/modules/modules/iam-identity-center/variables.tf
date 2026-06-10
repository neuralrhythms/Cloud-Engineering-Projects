# -----------------------------------------------------------------------------
# IAM Identity Center Module - Variables
# -----------------------------------------------------------------------------

variable "account_assignments" {
  description = "List of account assignments (map groups/users to accounts with permission sets)"
  type = list(object({
    principal_name   = string
    principal_id     = string
    principal_type   = string # GROUP or USER
    account_id       = string
    permission_set   = string
  }))
  default = []
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "landing-zone"
    ManagedBy = "terraform"
    Layer     = "identity"
  }
}
