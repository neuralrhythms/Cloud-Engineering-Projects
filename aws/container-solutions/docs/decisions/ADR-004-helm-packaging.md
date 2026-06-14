# ADR-004: Why Helm for Kubernetes Packaging

## Status
Accepted

## Date
2025-01-01

## Context

Application teams need a standardised way to package, version, and deploy Kubernetes applications across multiple environments (dev, test, prod). The packaging system must support per-environment configuration overrides, rollback, and integration with the CI/CD pipeline.

---

## Options Considered

### Option 1 — Helm

The de-facto Kubernetes package manager.

**Pros:**
- Industry standard; widely adopted
- Powerful templating with environment-specific value overrides
- Release management (upgrade, rollback, history)
- Large chart repository ecosystem for platform components
- `helm diff` plugin for change preview
- `--atomic` flag for automatic rollback on failure
- Helm OCI registry support for chart storage in ECR
- Supports Helm hooks for pre/post deployment jobs

**Cons:**
- Go template syntax can be complex and hard to debug
- Templating pitfalls (e.g., type coercion, indentation)
- Helm releases stored as Kubernetes secrets (can clutter)

### Option 2 — Kustomize

Kubernetes-native configuration management without templating.

**Pros:**
- Built into `kubectl apply -k`
- No templating language; uses overlays and patches
- Simpler mental model for basic use cases
- No external tool required

**Cons:**
- Less powerful for complex parameterisation across many environments
- No release management (no upgrade/rollback lifecycle)
- No chart ecosystem for third-party tools
- Less CI/CD integration maturity than Helm

### Option 3 — Raw Kubernetes Manifests + envsubst

Simple environment variable substitution in YAML files.

**Pros:**
- Maximum simplicity; no additional tools

**Cons:**
- No release management
- Environment differences require manual file duplication or complex scripting
- No rollback mechanism
- Does not scale beyond simple applications

### Option 4 — ArgoCD (GitOps operator) with Helm

Helm rendered by ArgoCD in-cluster from Git.

**Pros:**
- GitOps continuous delivery
- Automatic drift detection and reconciliation
- Strong UI for deployment visibility

**Cons:**
- ArgoCD is an additional platform component to operate
- Requires shift in mental model (pull-based vs push-based CD)
- More complex initial setup
- Not selected at this stage; potential future evolution

---

## Decision

**Helm** was selected as the Kubernetes packaging and deployment tool.

Helm is the most widely adopted solution, provides release lifecycle management, supports value overrides for multi-environment deployments, and has a large ecosystem of pre-built charts for platform components.

The push-based Helm deployment model (via Jenkins) is well-suited to the current team's operational model. A future migration to GitOps (ArgoCD) is a natural evolution path — Helm charts work with ArgoCD without modification.

---

## Consequences

### Positive
- Standard packaging across all application teams reduces onboarding friction
- Helm release lifecycle (upgrade, rollback, history) simplifies deployment operations
- Large ecosystem of ready-to-use charts for platform add-ons
- `--atomic` flag provides automatic rollback on failed deployments
- Helm diff enables transparent change review in production approval gates

### Negative
- Go templates require learning curve for chart authors
- Helm templating errors can be obscure (mitigated by CI linting)
- Helm release state in cluster secrets requires occasional pruning

### Risks
- Overly complex Helm charts become maintenance burden (mitigated by standards and linting)
- Chart value schema drift across environments (mitigated by values.schema.json validation)

---

## Future Consideration

ArgoCD is the natural evolution for teams wanting a GitOps model. The Helm chart structure used in this platform is fully compatible with ArgoCD — migration would involve deploying ArgoCD and pointing it at the same Helm charts in Git.

---

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Deployment Standards](../architecture/helm-deployment-standards.md)
- [Helm Charts](../../helm/)
