# ADR-002: Terraform Layered Architecture

## Status

Accepted

## Context

The landing zone has interdependent components that must be deployed in a specific order. We need a way to organize Terraform code that:
- Minimizes blast radius of changes
- Allows independent team ownership
- Makes dependencies explicit
- Supports gradual rollout

Options considered:
1. **Single state file** - Simple but high blast radius, slow plans
2. **Per-account state files** - Good isolation but doesn't capture shared resources
3. **Layered architecture** - Ordered layers with dependency flow

## Decision

We adopt a layered architecture with numbered layers (00-06). Each layer:
- Has its own Terraform state file
- Deploys to specific accounts
- Has explicit dependencies on lower layers
- Can be owned by different teams

Layers:
- 00: Bootstrap (state backend)
- 01: Organization (OUs, accounts, SCPs)
- 02: Security (GuardDuty, SecurityHub, Config)
- 03: Logging (CloudTrail, log buckets)
- 04: Networking (TGW, VPCs)
- 05: Identity (SSO, permission sets)
- 06: Workloads (account baselines, VPCs)

## Consequences

### Positive
- Small blast radius per deployment
- Clear dependency order
- Teams can own specific layers
- Faster plan/apply times per layer
- Independent CI/CD pipelines possible

### Negative
- Cross-layer data sharing requires remote state or SSM parameters
- More complex CI/CD (must handle layer ordering)
- More Terraform init/plan/apply cycles

### Mitigations
- SSM Parameter Store for cross-layer references (account IDs, resource IDs)
- CI/CD matrix strategy with sequential execution
- Helper scripts for multi-layer deployments

## References

- HashiCorp: Terraform Recommended Practices
- Gruntwork: Infrastructure Live
