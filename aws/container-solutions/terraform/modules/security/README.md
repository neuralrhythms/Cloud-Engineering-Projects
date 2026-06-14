# Module: security

Provisions KMS keys, security groups, GuardDuty, Security Hub, CloudTrail, and AWS Config for the EKS platform.

## Usage

```hcl
module "security" {
  source = "../../modules/security"

  project                   = "eks-platform"
  environment               = "prod"
  vpc_id                    = module.networking.vpc_id
  enable_guardduty          = true
  enable_security_hub       = true
  enable_config             = true
  cloudtrail_s3_bucket_name = "eks-platform-prod-cloudtrail-123456789012"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `project` | Project name | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `vpc_id` | VPC ID for security groups | `string` | — | yes |
| `enable_guardduty` | Enable Amazon GuardDuty | `bool` | `true` | no |
| `enable_security_hub` | Enable AWS Security Hub | `bool` | `true` | no |
| `enable_config` | Enable AWS Config | `bool` | `true` | no |
| `cloudtrail_s3_bucket_name` | S3 bucket for CloudTrail logs | `string` | — | yes |
| `tags` | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `kms_key_arns` | Map of purpose → KMS key ARN |
| `eks_control_plane_sg_id` | EKS control plane security group ID |
| `eks_nodes_sg_id` | EKS node security group ID |
| `alb_sg_id` | ALB security group ID |
| `guardduty_detector_id` | GuardDuty detector ID |

## KMS Keys Created

| Alias | Purpose |
|---|---|
| `eks-secrets` | EKS etcd secret encryption |
| `ebs` | EBS volume encryption |
| `ecr` | ECR image encryption |
| `logs` | CloudWatch Logs encryption |
| `secrets-manager` | Secrets Manager encryption |
| `terraform-state` | Terraform S3 state encryption |

## Notes

- All KMS keys have automatic annual rotation enabled
- GuardDuty EKS protection (audit log analysis) is enabled by default
- Security Hub standards: AWS FSBP and CIS AWS Foundations Benchmark
- `enable_config = false` is acceptable for dev to reduce cost
