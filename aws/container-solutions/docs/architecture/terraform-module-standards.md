# Terraform Module Standards

## Document Information

| Field | Value |
|---|---|
| Document Type | Engineering Standards |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This document defines the standards and conventions for writing, structuring, and consuming Terraform modules in the EKS platform repository. All contributors must follow these standards.

---

## 2. Module Structure

Every Terraform module must follow this directory structure:

```
modules/{module-name}/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── versions.tf       # Required providers and Terraform version constraints
├── locals.tf         # Local value computations (if needed)
├── data.tf           # Data source declarations (if needed)
└── README.md         # Module documentation
```

Optional files:

```
├── iam.tf            # IAM-related resources (can be separate for clarity)
├── security.tf       # Security group resources
└── examples/         # Usage examples
    └── basic/
        ├── main.tf
        └── README.md
```

---

## 3. File Conventions

### `versions.tf`

Always pin provider and Terraform versions:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}
```

### `variables.tf`

All variables must have:
- `description` attribute
- `type` constraint
- `default` only where appropriate (never for required inputs)
- Validation blocks for constrained inputs

```hcl
variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "eks_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}
```

### `outputs.tf`

All outputs must have:
- `description` attribute
- `sensitive = true` for sensitive values (passwords, keys, ARNs of sensitive resources)

```hcl
output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate data for EKS cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}
```

---

## 4. Naming Conventions

### Resources

Use descriptive names that include the module context:

```hcl
# Good
resource "aws_vpc" "main" { ... }
resource "aws_eks_cluster" "this" { ... }
resource "aws_iam_role" "eks_cluster" { ... }

# Avoid — generic names cause confusion with multiple instances
resource "aws_vpc" "vpc" { ... }
resource "aws_eks_cluster" "cluster" { ... }
```

### Variables and Outputs

- Use `snake_case` for all variable and output names
- Prefix with component name for clarity in complex modules

```hcl
variable "vpc_cidr_block" { ... }
variable "eks_cluster_name" { ... }
output "eks_cluster_arn" { ... }
```

---

## 5. Tagging Standards

All AWS resources must include the following tags:

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCentre  = var.cost_centre
    Repository  = "aws-eks-platform"
  }
}
```

Resources must merge module-specific tags with common tags:

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}
```

---

## 6. Module Composition

### Environment Root Modules

Each environment (`dev`, `test`, `prod`) has its own root module under `terraform/environments/{env}/`. These root modules compose the reusable modules:

```hcl
# terraform/environments/prod/main.tf

module "networking" {
  source = "../../modules/networking"

  project     = local.project
  environment = local.environment
  vpc_cidr    = "10.2.0.0/16"
  azs         = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

module "eks" {
  source = "../../modules/eks"

  project        = local.project
  environment    = local.environment
  cluster_name   = "${local.project}-${local.environment}-eks"
  eks_version    = "1.30"
  vpc_id         = module.networking.vpc_id
  subnet_ids     = module.networking.private_subnet_ids
}
```

### Module Interdependencies

Modules communicate exclusively through **outputs and variables** — never via `data` sources that reach into another module's state.

---

## 7. State Management

### Backend Configuration

Each environment uses a separate state file with S3 + DynamoDB locking:

```hcl
# terraform/environments/prod/backend.hcl
bucket         = "eks-platform-prod-terraform-state-123456789012"
key            = "eks-platform/prod/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "eks-platform-prod-terraform-locks"
encrypt        = true
kms_key_id     = "alias/eks-platform-prod-terraform-state"
```

### State Bucket Requirements

- Versioning: enabled
- Server-side encryption: KMS (CMK)
- Block public access: all settings enabled
- MFA Delete: enabled (production)
- Replication: enabled to secondary region (production)

---

## 8. Security Requirements

- Never hardcode secrets, passwords, or access keys in Terraform code
- Use AWS Secrets Manager data sources for sensitive values
- All resources containing data must have KMS encryption enabled
- IAM policies must follow least-privilege (no `*` actions without justification)
- Every IAM policy with wildcards must include a comment explaining the rationale

---

## 9. Code Quality

### Pre-commit Hooks

Mandatory pre-commit hooks (configured in `.pre-commit-config.yaml`):

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint
      - id: terraform_tfsec
      - id: checkov
```

### CI Checks (Pipeline)

Every PR must pass:
- `terraform fmt -check`
- `terraform validate`
- `tfsec .`
- `checkov -d . --framework terraform`

### Code Review Requirements

- All changes require at least one peer review
- Security-related changes require Platform Lead review
- Production changes require Platform Lead sign-off

---

## 10. Documentation

Every module's `README.md` must include:

- **Purpose** — what the module provisions
- **Usage example** — minimal working example
- **Inputs table** — all variables with types, descriptions, defaults
- **Outputs table** — all outputs with descriptions
- **Notes** — known limitations, considerations

Use [terraform-docs](https://terraform-docs.io/) to auto-generate input/output tables:

```bash
terraform-docs markdown table . > README.md
```

---

## 11. Versioning

Modules in this repository do not have independent versioning (they are consumed by environments within the same repository). If modules are extracted to a separate registry in future:

- Use semantic versioning (`major.minor.patch`)
- Tag releases in Git (`v1.0.0`)
- Pin module source with `?ref=v1.0.0`

---

## 12. Related Documents

- [Low-Level Design](low-level-design.md)
- [Terraform Module Structure](../../terraform/modules/)
- [CI/CD Design](cicd-design.md)
