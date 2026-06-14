# -----------------------------------------------------------------------------
# Development/Testing Configuration
# Reduced costs: single NAT, fewer AZs
# -----------------------------------------------------------------------------

aws_region = "us-east-1"

# Core account emails
security_account_email        = "aws+security-dev@company.com"
log_archive_account_email     = "aws+logging-dev@company.com"
network_account_email         = "aws+network-dev@company.com"
shared_services_account_email = "aws+shared-dev@company.com"

# Workload accounts (minimal for dev)
workload_accounts = [
  {
    name        = "sandbox-dev"
    email       = "aws+sandbox-dev@company.com"
    environment = "non-production"
    team        = "platform"
    vpc_cidr    = "10.100.0.0/16"
  }
]

# Reduced footprint for cost savings
egress_vpc_cidr          = "10.255.0.0/24"
shared_services_vpc_cidr = "10.254.0.0/24"
az_count                 = 2

# Security
enable_nist_standard = false
