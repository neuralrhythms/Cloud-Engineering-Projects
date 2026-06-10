# Key Architecture Decisions

## Decision Summary

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Account Strategy | Multi-account per workload | Blast radius isolation, security boundaries |
| 2 | OU Structure | Function-based OUs | Consistent policy application via SCPs |
| 3 | Network Pattern | Hub-and-spoke (TGW) | Scalable, centralized control, segmentation |
| 4 | Egress Pattern | Centralized NAT | Cost optimization, single inspection point |
| 5 | IaC Tool | Terraform | Multi-cloud support, state management, ecosystem |
| 6 | State Backend | S3 + DynamoDB | Native AWS, encryption, locking |
| 7 | CI/CD | GitHub Actions + OIDC | No long-lived credentials, native integration |
| 8 | Identity | IAM Identity Center | Native AWS SSO, permission sets, external IdP support |
| 9 | Logging | Centralized + Object Lock | Immutability, compliance, single source of truth |
| 10 | Security Services | Delegated admin pattern | Separation of duties, least privilege |

## Detailed Decisions

### ADR-001: Multi-Account Strategy

**Context**: Need to isolate workloads, enforce security boundaries, and manage blast radius.

**Decision**: Each workload environment gets its own AWS account. Shared services (security, logging, networking) get dedicated accounts.

**Consequences**:
- (+) Strong isolation between workloads
- (+) Independent service quotas per account
- (+) Clear cost allocation
- (-) More complex cross-account networking
- (-) Requires automation for account provisioning

### ADR-002: Layered Deployment Model

**Context**: Landing zone has interdependent components that must be deployed in order.

**Decision**: Use numbered layers (00-06) with explicit dependencies. Each layer has its own Terraform state.

**Consequences**:
- (+) Clear deployment order
- (+) Small blast radius per state file
- (+) Independent team ownership of layers
- (-) Cross-layer references require remote state or SSM parameters
- (-) More complex CI/CD pipeline

### ADR-003: Hub-and-Spoke Networking

**Context**: Need connectivity between accounts while maintaining segmentation.

**Decision**: Transit Gateway in Network account, shared via RAM. Separate route tables for prod/non-prod.

**Consequences**:
- (+) Centralized traffic control
- (+) Easy to add new accounts
- (+) Supports inspection VPC pattern
- (-) Single point of failure (mitigated by AWS HA)
- (-) Transit Gateway per-attachment and per-GB costs

### ADR-004: Centralized Egress

**Context**: Workload VPCs need internet access for updates, API calls.

**Decision**: Single egress VPC in Network account with NAT Gateways. All outbound traffic routes through TGW to egress VPC.

**Consequences**:
- (+) Reduced NAT Gateway costs (shared across accounts)
- (+) Single point for network inspection/firewall
- (+) Centralized egress IP management
- (-) Added latency (minimal, same-region)
- (-) Egress VPC becomes critical path

### ADR-005: GitHub OIDC for CI/CD Authentication

**Context**: Need secure authentication from CI/CD to AWS without storing long-lived credentials.

**Decision**: Use GitHub Actions OIDC provider to assume IAM roles directly.

**Consequences**:
- (+) No secret key rotation needed
- (+) Scoped to specific repos/branches
- (+) Audit trail in CloudTrail
- (-) Requires OIDC provider setup per account
- (-) GitHub-specific (but replaceable)
