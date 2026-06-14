# ADR-002: Why Terraform for Infrastructure as Code

## Status
Accepted

## Date
2025-01-01

## Context

The team required an Infrastructure as Code (IaC) tool to provision and manage all AWS infrastructure: VPC, EKS, IAM, ECR, KMS, CloudWatch, and supporting services. The tool needed to integrate with the CI/CD pipeline and support multiple environments (dev, test, prod) from a single codebase.

---

## Options Considered

### Option 1 — Terraform (HashiCorp)

Declarative IaC tool with a large AWS provider ecosystem.

**Pros:**
- Mature, widely adopted; strong community and module ecosystem
- Comprehensive AWS provider (`hashicorp/aws`) with broad resource coverage
- State management with S3 + DynamoDB locking
- Multi-cloud portability (if needed in future)
- Strong modularisation support
- Extensive CI/CD integration tooling (tfsec, checkov, terraform-docs)
- Team has existing Terraform expertise
- HCL is readable and reviewable in PRs

**Cons:**
- State management complexity (S3 backend, locking, drift)
- Terraform Cloud/Enterprise required for advanced features (we use self-managed S3 backend)
- HashiCorp licence change (BSL from 1.6+); OpenTofu is the OSS fork

### Option 2 — AWS CloudFormation

AWS-native IaC service.

**Pros:**
- Native AWS service; no external tooling required
- Drift detection built in
- Service integration without a separate provider

**Cons:**
- Verbose YAML/JSON syntax; lower readability
- Limited modularisation (nested stacks are complex)
- Slower release cycle for new AWS service support
- Less flexible than Terraform for complex logic
- Harder to write unit tests for
- Not multi-cloud

### Option 3 — AWS CDK (Cloud Development Kit)

IaC using programming languages (TypeScript, Python, Java).

**Pros:**
- Uses familiar programming languages; powerful abstraction
- Strong L2/L3 constructs reduce boilerplate
- Native AWS service support

**Cons:**
- Higher complexity for infrastructure engineers; requires developer mindset
- Generated CloudFormation templates are hard to read/debug
- Less widely adopted in platform engineering teams
- State management via CloudFormation (less flexible than Terraform S3 backend)

### Option 4 — Pulumi

IaC using general-purpose languages; similar to CDK but multi-cloud.

**Pros:**
- Full programming language power
- Multi-cloud

**Cons:**
- Less mature than Terraform for AWS
- Smaller community
- State management via Pulumi Cloud (or self-hosted backend)
- No existing team expertise

---

## Decision

**Terraform** was selected as the IaC tool.

The decision is based on the team's existing expertise, the maturity of the AWS provider, the strong ecosystem of security scanning tools (tfsec, checkov), and the straightforward S3 state backend. The modular structure supports reuse across environments.

Note: HashiCorp's BSL licence change is acknowledged. **OpenTofu** (the OSS fork, maintained by the Linux Foundation) is the planned migration path if licence constraints become an issue. The Terraform/OpenTofu syntax is 100% compatible.

---

## Consequences

### Positive
- Consistent, reviewable infrastructure code across all environments
- Module reuse reduces duplication
- S3 + DynamoDB state backend is robust and auditable
- Strong security scanning integration in CI pipeline
- Team can onboard quickly with existing Terraform knowledge

### Negative
- Terraform state must be carefully managed (S3 versioning + MFA Delete mitigates risk)
- Drift between state and reality requires monitoring (addressed by drift detection pipeline)
- BSL licence change may require migration to OpenTofu in future

### Risks
- State file corruption (mitigated by S3 versioning and DynamoDB locking)
- Terraform version skew across team (mitigated by `.terraform-version` file and pipeline enforcement)

---

## References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [OpenTofu](https://opentofu.org/)
- [Terraform Module Standards](../architecture/terraform-module-standards.md)
