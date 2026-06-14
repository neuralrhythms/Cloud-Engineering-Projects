# Module: iam

Provisions IAM roles for the EKS platform: cluster role, node group role, and IRSA roles for platform components (ALB controller, Cluster Autoscaler, External Secrets Operator, Jenkins).

## Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  project           = "eks-platform"
  environment       = "prod"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `project` | Project name | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `oidc_provider_arn` | OIDC provider ARN | `string` | — | yes |
| `oidc_provider_url` | OIDC provider URL | `string` | — | yes |
| `tags` | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `eks_cluster_role_arn` | EKS cluster IAM role ARN |
| `eks_node_role_arn` | Node group IAM role ARN |
| `alb_controller_role_arn` | ALB Controller IRSA role ARN |
| `cluster_autoscaler_role_arn` | Cluster Autoscaler IRSA role ARN |
| `external_secrets_role_arn` | External Secrets Operator IRSA role ARN |
| `jenkins_deploy_role_arn` | Jenkins deployment IAM role ARN |

## IRSA Pattern

Each IRSA role has a trust policy scoped to a specific namespace and service account:

```json
{
  "StringEquals": {
    "{oidc-url}:sub": "system:serviceaccount:{namespace}:{service-account}",
    "{oidc-url}:aud": "sts.amazonaws.com"
  }
}
```

This ensures only the intended pod identity can assume the role.

## Notes

- No static IAM access keys are created by this module
- All roles use short-lived STS tokens via IRSA
- Jenkins role can be trusted by EC2 instance profile or IRSA depending on Jenkins deployment model
