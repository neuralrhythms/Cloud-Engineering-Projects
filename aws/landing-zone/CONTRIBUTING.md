# Contributing to AWS Landing Zone

## Development Workflow

1. Create a feature branch from `main`
2. Make your changes following the coding standards below
3. Run `terraform fmt -recursive` and `terraform validate`
4. Submit a pull request using the PR template
5. Wait for CI checks to pass and obtain required reviews
6. Merge via squash merge

## Coding Standards

### Terraform

- Use `terraform fmt` for consistent formatting
- Pin all provider and module versions
- Use meaningful resource names with consistent prefixes
- Include descriptions for all variables and outputs
- Use `locals` to reduce repetition
- Tag all resources with mandatory tags (see tagging policy)

### Naming Conventions

| Resource | Convention | Example |
|----------|-----------|---------|
| Files | lowercase with hyphens | `main.tf`, `variables.tf` |
| Resources | snake_case | `aws_vpc.main` |
| Variables | snake_case | `vpc_cidr_block` |
| Outputs | snake_case | `vpc_id` |
| Modules | kebab-case directories | `modules/transit-gateway/` |

### File Structure per Module

```
modules/example-module/
├── main.tf          # Primary resource definitions
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Provider and terraform version constraints
├── data.tf          # Data sources (if needed)
├── locals.tf        # Local values (if needed)
└── README.md        # Module documentation
```

### Required Tags

All resources must include:

```hcl
tags = {
  Project     = "landing-zone"
  Environment = var.environment
  ManagedBy   = "terraform"
  Layer       = "organization|security|logging|networking|identity|workload"
}
```

## Pull Request Process

1. Fill out the PR template completely
2. Ensure all CI checks pass
3. Obtain approvals from CODEOWNERS
4. Production changes require additional security team approval
5. Squash merge to maintain clean history

## Security Considerations

- Never commit secrets or credentials
- Use AWS Secrets Manager or SSM Parameter Store for sensitive values
- Review SCP changes carefully - they can lock out accounts
- Test changes in sandbox/non-prod before production
- Follow the principle of least privilege in all IAM policies
