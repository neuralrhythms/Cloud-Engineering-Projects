# Module: ecr

Provisions Amazon ECR repositories with image scanning, lifecycle policies, KMS encryption, and optional cross-account access.

## Usage

```hcl
module "ecr" {
  source = "../../modules/ecr"

  project              = "eks-platform"
  repositories         = ["sample-app", "api-gateway"]
  image_tag_mutability = "IMMUTABLE"
  kms_key_arn          = module.security.kms_key_arns["ecr"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `project` | Project name prefix for repo names | `string` | — | yes |
| `repositories` | List of repository names | `list(string)` | `["sample-app"]` | no |
| `image_tag_mutability` | `IMMUTABLE` (prod) or `MUTABLE` (dev/test) | `string` | `IMMUTABLE` | no |
| `kms_key_arn` | KMS key ARN for image encryption | `string` | — | yes |
| `untagged_image_retention_days` | Days before untagged images expire | `number` | `7` | no |
| `tagged_image_retention_count` | Number of tagged images to retain | `number` | `20` | no |
| `cross_account_arns` | IAM ARNs for cross-account pull access | `list(string)` | `[]` | no |
| `tags` | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `repository_urls` | Map of repo name → repository URL |
| `repository_arns` | Map of repo name → repository ARN |
| `registry_id` | ECR registry ID (AWS account ID) |

## Notes

- Scan on push is enabled for all repositories
- Use `IMMUTABLE` tag mutability in production to prevent image overwrites
- Lifecycle policies prevent unbounded storage growth
- Repository names follow the pattern: `{project}/{repo-name}`
