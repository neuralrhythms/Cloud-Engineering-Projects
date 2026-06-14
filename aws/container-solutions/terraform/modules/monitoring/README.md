# Module: monitoring

Provisions CloudWatch log groups, SNS alert topics, CloudWatch alarms, and a CloudWatch dashboard for the EKS cluster.

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project               = "eks-platform"
  environment           = "prod"
  cluster_name          = "eks-platform-prod-eks"
  kms_key_arn           = module.security.kms_key_arns["logs"]
  log_retention_days    = 90
  alert_email_addresses = ["platform-team@example.com"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `project` | Project name | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `cluster_name` | EKS cluster name | `string` | — | yes |
| `kms_key_arn` | KMS key ARN for log encryption | `string` | — | yes |
| `log_retention_days` | Log retention period in days | `number` | `90` | no |
| `alert_email_addresses` | Email addresses for alarm notifications | `list(string)` | `[]` | no |
| `tags` | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `sns_alert_topic_arn` | SNS topic ARN for cluster alerts |
| `cloudwatch_log_group_names` | Map of purpose → log group name |

## Log Groups Created

| Log Group | Source |
|---|---|
| `/aws/eks/{cluster}/cluster` | EKS control plane |
| `/aws/containerinsights/{cluster}/performance` | Container Insights metrics |
| `/aws/containerinsights/{cluster}/application` | Application container logs |
| `/aws/containerinsights/{cluster}/host` | Node system logs |
| `/aws/vpc/flow-logs/{env}` | VPC flow logs |

## Alarms Created

- Node CPU utilisation > 80% (5 min)
- Node memory utilisation > 85% (5 min)
- Pod restart count > 5 (5 min)
- Pending pod count > 0 (10 min)
- EKS API server 5xx errors > 10 (5 min)

## Notes

- All log groups are encrypted with the provided KMS key
- SNS email subscriptions require manual confirmation after apply
- See `docs/diagrams/observability-architecture.md` for the full observability design
