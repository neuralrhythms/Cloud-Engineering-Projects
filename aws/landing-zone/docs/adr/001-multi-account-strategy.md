# ADR-001: Multi-Account Strategy

## Status

Accepted

## Context

We need to design an AWS environment that supports multiple workload teams, enforces security boundaries, and allows independent management of resources per team/environment.

Options considered:
1. **Single account with VPC isolation** - Simple but lacks security boundaries
2. **Multi-account per environment** - One account per env (dev/staging/prod)
3. **Multi-account per workload per environment** - Maximum isolation

## Decision

We adopt option 3: multi-account per workload per environment, aligned with AWS Organizations best practices.

Each workload team gets:
- A production account in the Production OU
- A non-production account in the Non-Production OU

Shared infrastructure (security, logging, networking) runs in dedicated accounts managed by the platform team.

## Consequences

### Positive
- Strong security isolation between workloads and environments
- Independent AWS service quotas per account
- Clear cost attribution via AWS account boundaries
- Teams cannot accidentally impact each other
- SCP enforcement at OU level provides consistent governance

### Negative
- Increased complexity in networking (cross-account connectivity)
- More accounts to manage (mitigated by automation)
- Cross-account IAM requires careful design
- Higher baseline cost (some services have per-account minimums)

### Mitigations
- Transit Gateway provides scalable cross-account networking
- Account vending automation reduces management overhead
- IAM Identity Center provides unified access management
- Security baseline module ensures consistent configuration

## References

- AWS Security Reference Architecture
- AWS Whitepaper: Organizing Your AWS Environment
