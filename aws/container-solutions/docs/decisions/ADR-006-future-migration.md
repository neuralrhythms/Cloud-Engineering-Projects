# ADR-006: Future Migration Considerations

## Status
Proposed

## Date
2025-01-01

## Context

This ADR documents anticipated future evolution of the platform. While the current architecture is production-ready, the technology landscape evolves rapidly. This record captures known migration paths and triggers that would cause the platform team to revisit current decisions.

---

## Migration 1 — Terraform → OpenTofu

### Trigger
HashiCorp's Business Source Licence (BSL) introduced in Terraform 1.6+ restricts certain commercial use cases. If the organisation's usage model is affected by BSL terms, migration to OpenTofu is required.

### Effort
- OpenTofu is a 100% compatible fork of Terraform (maintained by the Linux Foundation)
- Migration requires: replace `terraform` binary with `tofu`; update CI pipeline scripts
- No module or state migration required

### Timeline
- Evaluate annually or if licence constraints are raised
- Migration can be completed in a single sprint

---

## Migration 2 — Jenkins → GitHub Actions (Application Pipelines)

### Trigger
- Organisation adopts GitHub as primary development platform
- Team wants to reduce Jenkins operational overhead for simpler application pipelines
- New engineering hires prefer GitHub Actions

### Effort
- Application pipeline Jenkinsfiles → GitHub Actions YAML workflows
- Self-hosted GitHub Actions runners required for VPC-internal deployments (EKS access)
- Platform/infrastructure pipelines may remain on Jenkins (complex approval flows)

### Considerations
- GitHub Actions supports Helm deployments natively via `aws-actions` and `helm`
- OIDC-based AWS authentication eliminates need for stored IAM access keys
- Cost: GitHub-hosted runners have per-minute pricing; self-hosted runners are infrastructure cost

---

## Migration 3 — Push-based CI/CD → GitOps (ArgoCD)

### Trigger
- Team wants continuous reconciliation and drift detection for Kubernetes workloads
- Scaling to many teams where per-team pipelines become maintenance burden
- Desire for Kubernetes-native deployment model

### Effort
- Deploy ArgoCD as a platform component (Helm chart available)
- Create ArgoCD Application resources pointing at existing Helm charts in Git
- Existing Helm chart structure is fully compatible with ArgoCD — no chart changes required
- Jenkins application deployment stages replaced by ArgoCD sync
- Jenkins infrastructure pipeline unaffected

### Considerations
- ArgoCD provides strong deployment visibility via UI
- GitOps model requires discipline: all Kubernetes changes via Git (no `kubectl apply` by hand)
- Image updater (ArgoCD Image Updater) or Flux can automate image tag updates

---

## Migration 4 — CloudWatch → Prometheus + Grafana

### Trigger
- Need for richer Kubernetes-native dashboards
- Multi-cluster observability requirements
- Team preference for OSS tooling

### Effort
- Deploy `kube-prometheus-stack` Helm chart (Prometheus + Grafana + Alertmanager)
- CloudWatch remains for AWS-layer metrics and logs (VPC Flow Logs, CloudTrail, EKS control plane)
- Prometheus scrapes kube-state-metrics and node-exporter for Kubernetes-level metrics
- Federation or remote write to Amazon Managed Prometheus (AMP) for hosted option

### Considerations
- CloudWatch and Prometheus complement each other; not a replacement decision
- Amazon Managed Prometheus (AMP) + Amazon Managed Grafana (AMG) is a managed Prometheus/Grafana stack if operational overhead of self-hosted is a concern

---

## Migration 5 — EKS Managed Nodes → Karpenter

### Trigger
- Need for faster node provisioning (Cluster Autoscaler can take 3–5 minutes; Karpenter ~30–60 seconds)
- Desire for more flexible instance selection (automatic right-sizing)
- Cost optimisation through bin-packing and Spot diversification

### Effort
- Deploy Karpenter Helm chart as replacement for Cluster Autoscaler
- Define `NodePool` and `EC2NodeClass` resources (replacing node group configuration)
- Migrate node groups to be managed by Karpenter gradually
- Cluster Autoscaler and Karpenter can coexist during migration

### Considerations
- Karpenter is now a CNCF project; broadly recommended by AWS
- Managed Node Groups can be retained alongside Karpenter-managed nodes
- Spot diversification is built into Karpenter (better than Cluster Autoscaler)

---

## Migration 6 — Multi-Account Architecture

### Trigger
- Organisation grows and requires strict environment isolation
- Compliance requirements (e.g., PCI DSS, HIPAA) mandate account separation
- Cost attribution by business unit requires account-level separation

### Effort
- Adopt AWS Control Tower or AWS Landing Zone Accelerator
- Separate Terraform state per account
- Cross-account ECR access policies
- AWS Transit Gateway for inter-account connectivity (if required)
- Identity Centre (SSO) for cross-account access

---

## References

- [OpenTofu](https://opentofu.org/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Karpenter](https://karpenter.sh/)
- [Amazon Managed Prometheus](https://aws.amazon.com/prometheus/)
- [ADR-001](ADR-001-eks-platform-choice.md)
- [ADR-002](ADR-002-terraform-iac.md)
