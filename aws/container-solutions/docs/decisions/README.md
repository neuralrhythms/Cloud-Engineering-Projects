# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for the AWS EKS platform.

ADRs document significant technical decisions: the context, the options considered, the decision made, and the consequences.

---

## ADR Index

| ADR | Title | Status | Date |
|---|---|---|---|
| [ADR-001](ADR-001-eks-platform-choice.md) | Why Amazon EKS | Accepted | 2025 |
| [ADR-002](ADR-002-terraform-iac.md) | Why Terraform for IaC | Accepted | 2025 |
| [ADR-003](ADR-003-jenkins-cicd.md) | Why Jenkins for CI/CD | Accepted | 2025 |
| [ADR-004](ADR-004-helm-packaging.md) | Why Helm for Kubernetes Packaging | Accepted | 2025 |
| [ADR-005](ADR-005-managed-node-groups.md) | Why EKS Managed Node Groups | Accepted | 2025 |
| [ADR-006](ADR-006-future-migration.md) | Future Migration Considerations | Proposed | 2025 |

---

## ADR Status Definitions

| Status | Meaning |
|---|---|
| Proposed | Under discussion; not yet agreed |
| Accepted | Decision made and in effect |
| Deprecated | Was accepted; superseded by newer decision |
| Superseded | Replaced by a newer ADR (reference noted) |

---

## How to Create a New ADR

1. Copy the template below into a new file: `ADR-{NNN}-{short-title}.md`
2. Fill in all sections
3. Set status to `Proposed`
4. Open a PR for team review
5. Once agreed, set status to `Accepted` and merge

### ADR Template

```markdown
# ADR-{NNN}: {Title}

## Status
Proposed | Accepted | Deprecated | Superseded by ADR-{NNN}

## Date
YYYY-MM-DD

## Context
[What is the situation that requires a decision?]

## Decision
[What was decided?]

## Options Considered
[What alternatives were evaluated?]

## Consequences
### Positive
[What improves as a result of this decision?]

### Negative
[What are the trade-offs or downsides?]

### Risks
[What could go wrong?]

## References
[Links to relevant documents, RFCs, blog posts, etc.]
```
