# Module: networking

Provisions the VPC, public and private subnets, NAT gateways, route tables, VPC endpoints, and VPC flow logs for the EKS platform.

## Usage

```hcl
module "networking" {
  source = "../../modules/networking"

  project              = "eks-platform"
  environment          = "prod"
  vpc_cidr             = "10.2.0.0/16"
  availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnet_cidrs  = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
  private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
  single_nat_gateway   = false
  cluster_name         = "eks-platform-prod-eks"
  enable_vpc_endpoints = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `project` | Project name prefix | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `vpc_cidr` | VPC CIDR block | `string` | `10.0.0.0/16` | no |
| `availability_zones` | List of AZs | `list(string)` | — | yes |
| `public_subnet_cidrs` | Public subnet CIDRs | `list(string)` | — | yes |
| `private_subnet_cidrs` | Private subnet CIDRs | `list(string)` | — | yes |
| `single_nat_gateway` | Use one NAT GW (dev/test cost saving) | `bool` | `false` | no |
| `cluster_name` | EKS cluster name for subnet tags | `string` | — | yes |
| `enable_vpc_endpoints` | Enable VPC Interface Endpoints | `bool` | `true` | no |
| `flow_log_retention_days` | VPC flow log retention (days) | `number` | `90` | no |
| `tags` | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR block |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `nat_gateway_ids` | List of NAT Gateway IDs |
| `internet_gateway_id` | Internet Gateway ID |

## Notes

- Public subnets are tagged for EKS ALB discovery (`kubernetes.io/role/elb=1`)
- Private subnets are tagged for EKS internal load balancers (`kubernetes.io/role/internal-elb=1`)
- In production, set `single_nat_gateway = false` to place one NAT Gateway per AZ
- VPC Endpoints reduce NAT Gateway data processing costs for ECR, S3, Secrets Manager traffic
