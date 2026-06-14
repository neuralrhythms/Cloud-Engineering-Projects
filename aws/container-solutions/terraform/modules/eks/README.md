# Module: eks

Provisions the Amazon EKS cluster, OIDC provider, managed node groups, managed add-ons, and EKS access entries.

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  project            = "eks-platform"
  environment        = "prod"
  cluster_name       = "eks-platform-prod-eks"
  kubernetes_version = "1.30"
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.private_subnet_ids
  kms_key_arn        = module.security.kms_key_arns["eks-secrets"]

  endpoint_private_access = true
  endpoint_public_access  = false

  cluster_role_arn        = module.iam.eks_cluster_role_arn
  node_role_arn           = module.iam.eks_node_role_arn
  platform_admin_role_arn = var.platform_admin_role_arn

  node_groups = {
    general = {
      instance_types  = ["m5.xlarge"]
      capacity_type   = "ON_DEMAND"
      min_size        = 3
      max_size        = 20
      desired_size    = 5
      disk_size       = 100
      max_unavailable = 1
      labels          = { "node.kubernetes.io/workload-type" = "general" }
      taints          = []
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `project` | Project name | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `cluster_name` | EKS cluster name | `string` | — | yes |
| `kubernetes_version` | Kubernetes version | `string` | `1.30` | no |
| `vpc_id` | VPC ID | `string` | — | yes |
| `subnet_ids` | Private subnet IDs for nodes | `list(string)` | — | yes |
| `kms_key_arn` | KMS key ARN for etcd encryption | `string` | — | yes |
| `endpoint_private_access` | Enable private API endpoint | `bool` | `true` | no |
| `endpoint_public_access` | Enable public API endpoint | `bool` | `false` | no |
| `cluster_role_arn` | EKS cluster IAM role ARN | `string` | — | yes |
| `node_role_arn` | Node group IAM role ARN | `string` | — | yes |
| `node_groups` | Map of node group configs | `map(object)` | see variables.tf | no |
| `platform_admin_role_arn` | IAM role ARN for cluster admins | `string` | — | yes |
| `log_retention_days` | CloudWatch log retention | `number` | `90` | no |
| `tags` | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | EKS cluster name |
| `cluster_arn` | EKS cluster ARN |
| `cluster_endpoint` | API server endpoint |
| `cluster_certificate_authority_data` | CA data (sensitive) |
| `cluster_version` | Kubernetes version |
| `oidc_provider_arn` | OIDC provider ARN (for IRSA) |
| `oidc_provider_url` | OIDC provider URL (for IRSA) |
| `node_group_arns` | Map of node group ARNs |
| `cluster_security_group_id` | Cluster security group ID |

## Notes

- All control plane log types are enabled by default
- OIDC provider is required for IRSA — always enabled
- EKS Access Entries (not `aws-auth` ConfigMap) are used for IAM → RBAC mapping
- Node group `release_version` drives AMI selection — update monthly for patching
