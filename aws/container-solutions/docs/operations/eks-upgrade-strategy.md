# EKS Upgrade Strategy

## Document Information

| Field | Value |
|---|---|
| Document Type | Operations — Upgrade Strategy |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This document defines the strategy and procedure for upgrading the Amazon EKS platform — covering Kubernetes version upgrades mandated by AWS, EKS add-on upgrades, and Managed Node Group updates.

---

## 2. AWS EKS Version Policy

AWS supports EKS clusters on a fixed number of Kubernetes minor versions (typically 3–4 at any time). Key policy points:

- AWS provides support for each minor version for **14 months** after release
- AWS automatically upgrades clusters that fall out of support (**auto-upgrade notice provided**)
- Upgrade path: sequential minor versions only (e.g., 1.28 → 1.29 → 1.30; cannot skip)
- Kubernetes releases a new minor version approximately every 4 months
- **Target:** Keep EKS clusters within N-1 of the latest supported version

### Version Support Timeline (Example)

| Kubernetes Version | EKS GA | EKS End of Support |
|---|---|---|
| 1.28 | 2023-09 | ~2024-11 |
| 1.29 | 2024-01 | ~2025-03 |
| 1.30 | 2024-05 | ~2025-07 |
| 1.31 | 2024-09 | ~2025-11 |

> Always check [AWS EKS Kubernetes Versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) for current support windows.

---

## 3. Upgrade Principles

| Principle | Description |
|---|---|
| Dev first | All upgrades validated in dev before test; test before prod |
| Sequential | Only one minor version per upgrade cycle |
| Pipeline-driven | All upgrades executed via Jenkins pipeline; no manual changes |
| Documented | Pre-upgrade checklist completed; upgrade notes recorded |
| Tested | Post-upgrade validation suite executed after each environment |
| Reversible (partial) | Control plane upgrade is not reversible; node groups can be rolled back |

---

## 4. Pre-Upgrade Checklist

Complete before every upgrade:

- [ ] Check AWS EKS release notes for the target version
- [ ] Check deprecation notices (Kubernetes API removals)
- [ ] Review EKS add-on compatibility matrix for the target version
- [ ] Check Helm chart compatibility for cluster-autoscaler, ALB controller, external-secrets
- [ ] Verify application workloads use only non-deprecated Kubernetes APIs
- [ ] Run `kubectl convert` or `pluto` to detect deprecated API usage
- [ ] Confirm DR procedure is documented and tested
- [ ] Schedule maintenance window for test and prod upgrades
- [ ] Notify application teams of upcoming upgrade and impact

### API Deprecation Check

```bash
# Install pluto
brew install FairwindsOps/tap/pluto

# Check deprecated APIs in cluster
pluto detect-all-in-cluster

# Check deprecated APIs in Helm releases
pluto detect-helm -owide
```

---

## 5. Upgrade Procedure

### 5.1 Environment Sequence

```
Dev → Test → Prod
(minimum 24 hours between each environment)
```

### 5.2 Step-by-Step Upgrade

#### Step 1: Update EKS Version in Terraform

```hcl
# terraform/environments/{env}/terraform.tfvars
eks_version = "1.30"  # Update to target version
```

#### Step 2: Run Terraform CI Pipeline

```bash
# Validate the change passes CI checks
terraform plan
```

#### Step 3: Upgrade Control Plane (via Terraform Apply)

The `aws_eks_cluster` resource update triggers the control plane upgrade. EKS upgrades the control plane with zero worker node impact.

**Duration:** 10–20 minutes per environment.

#### Step 4: Update EKS Managed Add-ons

After the control plane is upgraded, update each add-on to the compatible version:

```hcl
# terraform/modules/eks/addons.tf
resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = aws_eks_cluster.this.name
  addon_name        = "vpc-cni"
  addon_version     = "v1.18.x-eksbuild.1"  # Compatible with target EKS version
  resolve_conflicts = "OVERWRITE"
}
```

Check compatible versions:
```bash
aws eks describe-addon-versions \
  --kubernetes-version 1.30 \
  --addon-name vpc-cni \
  --query 'addons[].addonVersions[].addonVersion'
```

#### Step 5: Update Managed Node Groups

Node groups must be updated to run the new EKS-optimised AMI for the target Kubernetes version.

Option A — Terraform (AMI version update):
```hcl
resource "aws_eks_node_group" "general" {
  release_version = "1.30.x-20241109"  # Updated AMI version
  
  update_config {
    max_unavailable = 1
  }
}
```

Option B — AWS CLI (direct update):
```bash
aws eks update-nodegroup-version \
  --cluster-name eks-platform-dev \
  --nodegroup-name general \
  --kubernetes-version 1.30
```

**Process:** EKS cordons and drains one node at a time, launches replacement with new AMI, waits for it to be Ready, then proceeds to the next node. `max_unavailable = 1` ensures only one node is replaced at a time.

**Duration:** Depends on node count (typically 5–10 minutes per node).

#### Step 6: Update Platform Helm Charts

After nodes are updated, update Helm chart versions for platform components:

```bash
# Update cluster-autoscaler (must match EKS version)
helm upgrade cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=eks-platform-{env} \
  --set image.tag=v1.30.x

# Update AWS Load Balancer Controller
helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --version 1.8.x
```

#### Step 7: Post-Upgrade Validation

Run the post-upgrade validation suite:

```bash
# All nodes Ready
kubectl get nodes

# All system pods Running
kubectl get pods -n kube-system

# All platform pods Running
kubectl get pods -n platform-system

# EKS add-on status
aws eks list-addons --cluster-name {cluster}
aws eks describe-addon --cluster-name {cluster} --addon-name vpc-cni

# Application smoke test
./scripts/smoke-test.sh {env}
```

---

## 6. Upgrade Pipeline (Jenkins)

The EKS upgrade is executed via the dedicated upgrade pipeline:

```
platform-pipelines/upgrade-pipelines/eks-upgrade/Jenkinsfile
```

### Pipeline Parameters

| Parameter | Description | Example |
|---|---|---|
| `TARGET_VERSION` | Target Kubernetes version | `1.30` |
| `ENVIRONMENT` | Target environment | `dev` |
| `DRY_RUN` | Plan only; no apply | `true/false` |

### Pipeline Stages

1. Pre-upgrade health check
2. API deprecation scan (`pluto`)
3. Terraform plan (control plane version update)
4. Manual approval (test + prod)
5. Terraform apply (control plane upgrade)
6. Wait for control plane ready
7. Update managed add-ons (Terraform)
8. Update node groups (Terraform / rolling)
9. Update platform Helm charts
10. Post-upgrade validation
11. Notify on success/failure

---

## 7. Rollback Considerations

| Component | Rollback Possible? | Method |
|---|---|---|
| EKS Control Plane | **No** — cannot downgrade K8s version | Plan carefully; test in dev first |
| EKS Add-ons | Yes | Revert `addon_version` in Terraform |
| Node Groups | Yes | Revert `release_version` in Terraform (rolling) |
| Platform Helm Charts | Yes | `helm rollback {release} {revision}` |

---

## 8. Upgrade Schedule

| Activity | Frequency | Lead Time |
|---|---|---|
| Monitor AWS EKS release announcements | Monthly | — |
| Dev environment upgrade | Per minor version | Within 30 days of GA |
| Test environment upgrade | Per minor version | Within 60 days of GA |
| Prod environment upgrade | Per minor version | Within 90 days of GA |
| Verify version support status | Quarterly | — |

---

## 9. Related Documents

- [Node Patching Strategy](node-patching-strategy.md)
- [Upgrade Pipeline Jenkinsfile](../../platform-pipelines/upgrade-pipelines/)
- [Disaster Recovery](../architecture/disaster-recovery.md)
