# Contributing Guide

## Overview

This guide covers standards for contributing to the AWS EKS Platform repository. All changes must follow these standards before merging.

---

## Branching Strategy

| Branch | Purpose |
|---|---|
| `main` | Production-ready code; protected; deployments triggered from here |
| `feature/{description}` | New features or platform components |
| `fix/{description}` | Bug fixes |
| `chore/{description}` | Maintenance — dependency updates, refactoring |
| `docs/{description}` | Documentation only changes |

Branch naming examples:
- `feature/add-rds-module`
- `fix/alb-security-group-rules`
- `chore/upgrade-eks-1-31`
- `docs/update-runbook-node-patching`

---

## Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`

Examples:
```
feat(eks): add dedicated node group for ML workloads
fix(networking): correct private subnet CIDR in test environment
docs(runbooks): add node not ready troubleshooting steps
chore(deps): pin terraform aws provider to 5.31.0
```

---

## Pull Request Standards

### Before Opening a PR

- [ ] All pre-commit hooks pass locally
- [ ] `terraform fmt -check -recursive terraform/` passes
- [ ] `terraform validate` passes for affected environments
- [ ] `tfsec` and `checkov` scans pass (or exceptions documented)
- [ ] `helm lint` passes for any modified charts
- [ ] Documentation updated for any design changes
- [ ] No secrets, account IDs, or sensitive values in the diff

### PR Title

Keep under 72 characters. Use the same format as commit messages:
```
feat(iam): add IRSA role for external secrets operator
```

### PR Description

Use the PR template (`.github/PULL_REQUEST_TEMPLATE.md`).

### Review Requirements

| Change Type | Required Approvals |
|---|---|
| Documentation only | 1 peer review |
| Terraform (dev/test) | 1 Platform Engineer |
| Terraform (prod) | 1 Platform Lead |
| Security changes | 1 Platform Lead + Security review |
| EKS version upgrade | 1 Platform Lead |

---

## Pre-commit Setup

Install pre-commit hooks before making changes:

```bash
pip install pre-commit
pre-commit install
```

The `.pre-commit-config.yaml` runs: `terraform fmt`, `terraform validate`, `tfsec`, `checkov`, `helm lint`, and secret scanning.

---

## Terraform Standards

See [Terraform Module Standards](../docs/architecture/terraform-module-standards.md).

Key rules:
- All variables must have `description` and `type`
- All resources must include `common_tags`
- Never use `count` for resources that have unique identities — use `for_each`
- No hardcoded account IDs, region names, or ARNs in module code

---

## Helm Standards

See [Helm Deployment Standards](../docs/architecture/helm-deployment-standards.md).

Key rules:
- All charts must pass `helm lint`
- All production-deployed containers must have resource limits
- Security context must be set on all containers
- PodDisruptionBudget required for all production deployments

---

## Questions

Open a GitHub Issue or reach out in the `#platform-engineering` Slack channel.
