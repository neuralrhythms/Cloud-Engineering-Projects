# Production Workload Account — VPC Configuration
account_name               = "workload-prod"
environment                = "prod"
vpc_cidr                   = "10.2.0.0/16"
create_igw                 = true
create_nat_gateway         = true
create_interface_endpoints = true

# TGW ID — set after network-hub TGW is deployed
transit_gateway_id = "tgw-REPLACE_WITH_REAL_TGW_ID"

# Flow logs — Log Archive account S3 bucket ARN
flow_logs_s3_arn = "arn:aws:s3:::s3-vpcflowlogs-REPLACE_WITH_LOG_ARCHIVE_ACCOUNT_ID"

tgw_subnets = [
  { name = "snet-tgw-a", cidr = "10.2.0.0/28", az = "ap-southeast-2a" },
  { name = "snet-tgw-b", cidr = "10.2.0.16/28", az = "ap-southeast-2b" },
  { name = "snet-tgw-c", cidr = "10.2.0.32/28", az = "ap-southeast-2c" }
]

public_subnets = [
  { name = "snet-public-a", cidr = "10.2.1.0/26", az = "ap-southeast-2a" },
  { name = "snet-public-b", cidr = "10.2.1.64/26", az = "ap-southeast-2b" },
  { name = "snet-public-c", cidr = "10.2.1.128/26", az = "ap-southeast-2c" }
]

app_subnets = [
  { name = "snet-app-a", cidr = "10.2.2.0/25", az = "ap-southeast-2a" },
  { name = "snet-app-b", cidr = "10.2.2.128/25", az = "ap-southeast-2b" },
  { name = "snet-app-c", cidr = "10.2.3.0/25", az = "ap-southeast-2c" }
]

data_subnets = [
  { name = "snet-data-a", cidr = "10.2.4.0/26", az = "ap-southeast-2a" },
  { name = "snet-data-b", cidr = "10.2.4.64/26", az = "ap-southeast-2b" },
  { name = "snet-data-c", cidr = "10.2.4.128/26", az = "ap-southeast-2c" }
]
