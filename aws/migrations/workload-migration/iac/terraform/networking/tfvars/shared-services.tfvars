# Shared Services Account — VPC Configuration
account_name               = "shared-services"
environment                = "shared"
vpc_cidr                   = "10.1.0.0/16"
create_igw                 = false
create_nat_gateway         = false
create_interface_endpoints = true

transit_gateway_id = "tgw-REPLACE_WITH_REAL_TGW_ID"
flow_logs_s3_arn   = "arn:aws:s3:::s3-vpcflowlogs-REPLACE_WITH_LOG_ARCHIVE_ACCOUNT_ID"

tgw_subnets = [
  { name = "snet-tgw-a", cidr = "10.1.0.0/28", az = "ap-southeast-2a" },
  { name = "snet-tgw-b", cidr = "10.1.0.16/28", az = "ap-southeast-2b" },
  { name = "snet-tgw-c", cidr = "10.1.0.32/28", az = "ap-southeast-2c" }
]

public_subnets = []

app_subnets = [
  { name = "snet-ad-a",       cidr = "10.1.1.0/27",  az = "ap-southeast-2a" },
  { name = "snet-ad-b",       cidr = "10.1.1.32/27", az = "ap-southeast-2b" },
  { name = "snet-transfer-a", cidr = "10.1.2.0/27",  az = "ap-southeast-2a" },
  { name = "snet-transfer-b", cidr = "10.1.2.32/27", az = "ap-southeast-2b" },
  { name = "snet-tools-a",    cidr = "10.1.3.0/26",  az = "ap-southeast-2a" },
  { name = "snet-tools-b",    cidr = "10.1.3.64/26", az = "ap-southeast-2b" }
]

data_subnets = []
