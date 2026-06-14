# ADR-003: Why Jenkins for CI/CD

## Status
Accepted

## Date
2025-01-01

## Context

The platform required a CI/CD system capable of running both infrastructure pipelines (Terraform) and application delivery pipelines (build, test, scan, deploy). The system needed to support complex multi-stage pipelines with manual approval gates, parameterised builds, and tight AWS integration.

---

## Options Considered

### Option 1 — Jenkins (Self-Hosted)

Open-source, self-hosted CI/CD platform with a large plugin ecosystem.

**Pros:**
- Highly flexible; Jenkinsfiles are code stored in Git
- Self-hosted: data stays within the AWS account; no external SaaS
- Large plugin ecosystem (Kubernetes plugin, AWS plugins, credentials)
- Well understood by the existing team
- Runs on EKS or EC2; can use dynamic Kubernetes-based agents
- No per-seat or per-minute licensing cost (beyond infrastructure)
- Supports complex pipeline logic (parallel stages, approvals, parameters)

**Cons:**
- Requires operational effort to maintain Jenkins master
- Plugin management and upgrades require attention
- Jenkins UI is dated compared to modern CI/CD tools
- Initial setup complexity

### Option 2 — GitHub Actions

Cloud-hosted CI/CD integrated with GitHub.

**Pros:**
- Zero operational overhead (fully managed)
- Native GitHub integration (PRs, commits, status checks)
- Modern YAML-based pipeline syntax
- Large marketplace of actions
- GitHub-hosted or self-hosted runners

**Cons:**
- Tighter coupling to GitHub (reduces portability)
- Self-hosted runners required for VPC-internal deployments (adds operational overhead)
- Less flexibility for complex orchestration than Jenkinsfiles
- Per-minute billing for hosted runners

### Option 3 — AWS CodePipeline + CodeBuild

AWS-native CI/CD services.

**Pros:**
- Native AWS services; tight IAM integration
- No infrastructure to manage
- Native CodeCommit / GitHub integration

**Cons:**
- Limited pipeline flexibility compared to Jenkinsfiles
- CodeBuild is not a full CI system (no native test reporting, limited plugin ecosystem)
- Tightly coupled to AWS; not portable
- UI less capable than Jenkins or GitHub Actions
- Complex multi-stage pipelines are verbose to define

### Option 4 — GitLab CI/CD

Integrated CI/CD within GitLab.

**Pros:**
- Fully integrated with GitLab source control
- Modern YAML pipeline syntax
- Self-hosted or SaaS options

**Cons:**
- Organisation currently uses GitHub; would require migration
- Self-hosted GitLab adds operational complexity

---

## Decision

**Jenkins** was selected as the CI/CD platform.

The primary drivers were the existing team expertise, the requirement for self-hosted pipelines within the AWS account (security and data residency), and the flexibility of Jenkinsfiles for complex multi-stage infrastructure and application pipelines.

---

## Consequences

### Positive
- Full control over pipeline execution environment
- All pipeline credentials remain within AWS (no external SaaS)
- Jenkinsfiles stored in Git alongside application/infrastructure code
- Dynamic Kubernetes agents enable resource-efficient pipeline execution
- Complex approval gates and parameterised builds are straightforward

### Negative
- Platform team must maintain Jenkins master (updates, backups, plugins)
- Jenkins home directory requires persistent storage (EBS or EFS)
- Plugin compatibility requires ongoing attention during Jenkins upgrades

### Risks
- Jenkins master unavailability blocks all deployments (mitigated by recovery runbook and JCasC)
- Plugin vulnerabilities (mitigated by regular Jenkins and plugin updates)

---

## Future Consideration

If the organisation adopts GitHub Actions for application pipelines (where simpler pipelines suffice), a hybrid model can be considered:
- GitHub Actions for application build/test (stateless, GitHub-native)
- Jenkins for infrastructure pipelines (stateful, complex approvals)

---

## References

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [CI/CD Design](../architecture/cicd-design.md)
