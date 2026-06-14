# -----------------------------------------------------------------------------
# Production Environment Configuration
# Update these values with your actual account details
# -----------------------------------------------------------------------------

aws_region = "us-east-1"

# Core account emails (use + addressing for unique emails on same domain)
security_account_email        = "aws+security@company.com"
log_archive_account_email     = "aws+logging@company.com"
network_account_email         = "aws+network@company.com"
shared_services_account_email = "aws+shared-services@company.com"

# Region restrictions (uncomment to enforce)
# allowed_regions = ["us-east-1", "us-west-2", "eu-west-1"]

# Workload accounts
workload_accounts = [
  {
    name        = "app1-prod"
    email       = "aws+app1-prod@company.com"
    environment = "production"
    team        = "app-team-1"
    vpc_cidr    = "10.1.0.0/16"
  },
  {
    name        = "app2-prod"
    email       = "aws+app2-prod@company.com"
    environment = "production"
    team        = "app-team-2"
    vpc_cidr    = "10.2.0.0/16"
  },
  {
    name        = "app1-staging"
    email       = "aws+app1-staging@company.com"
    environment = "non-production"
    team        = "app-team-1"
    vpc_cidr    = "10.11.0.0/16"
  },
  {
    name        = "app1-dev"
    email       = "aws+app1-dev@company.com"
    environment = "non-production"
    team        = "app-team-1"
    vpc_cidr    = "10.21.0.0/16"
  },
  {
    name        = "app2-dev"
    email       = "aws+app2-dev@company.com"
    environment = "non-production"
    team        = "app-team-2"
    vpc_cidr    = "10.22.0.0/16"
  }
]

# Networking
egress_vpc_cidr          = "10.255.0.0/20"
shared_services_vpc_cidr = "10.254.0.0/20"
az_count                 = 3

# Security
enable_nist_standard = false
