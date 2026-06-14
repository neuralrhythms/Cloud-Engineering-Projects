# Node Patching Strategy

## Document Information

| Field | Value |
|---|---|
| Document Type | Operations — Node Patching Strategy |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This document defines the monthly patching strategy for EKS worker nodes. It covers both **Managed Node Groups** (primary strategy) and **self-managed EC2 worker nodes** (reference architecture for teams with custom AMI requirements).

---

## 2. Patching Philosophy

| Principle | Description |
|---|---|
| Immutable nodes | Nodes are never patched in-place; they are replaced with new AMI versions |
| Rolling replacement | One node replaced at a time; workloads maintained throughout |
| Pipeline-driven | All patching executed via Jenkins pipeline; no manual actions |
| Monthly cadence | OS patches applied monthly (aligned with AWS AMI release cycle) |
| Zero downtime | PodDisruptionBudgets and rolling updates ensure no downtime |

---

## 3. Patching Strategy — Managed Node Groups

### 3.1 How It Works

AWS releases updated EKS-optimised AMIs regularly. These AMIs include OS patches (security updates, kernel updates) while maintaining compatibility with the EKS cluster version.

Patching = updating the AMI version in the node group → EKS performs rolling node replacement.

### 3.2 Monthly Patching Procedure

#### Step 1: Check for Updated AMI

```bash
# Get latest AMI for EKS version and instance type
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.30/amazon-linux-2/recommended/release_version \
  --query Parameter.Value \
  --output text
```

#### Step 2: Update AMI Version in Terraform

```hcl
# terraform/environments/{env}/terraform.tfvars
eks_node_group_release_version = "1.30.x-20241201"  # Updated monthly
```

#### Step 3: Run Node Group Refresh Pipeline

```bash
# Jenkins pipeline: maintenance-pipelines/node-group-refresh
# Parameters: ENVIRONMENT, NODE_GROUP_NAME
```

Or direct AWS CLI:
```bash
aws eks update-nodegroup-version \
  --cluster-name eks-platform-prod \
  --nodegroup-name general \
  --release-version 1.30.x-20241201 \
  --force
```

#### Step 4: Monitor Rolling Update

```bash
# Watch node group update status
aws eks describe-update \
  --cluster-name eks-platform-prod \
  --nodegroup-name general \
  --update-id {update-id}

# Monitor node status
kubectl get nodes -w

# Monitor pod rescheduling
kubectl get pods --all-namespaces -w
```

#### Step 5: Post-Patch Validation

```bash
# Verify all nodes running new AMI
kubectl get nodes -o wide

# Verify all nodes Ready
kubectl get nodes

# Run smoke test
./scripts/smoke-test.sh prod
```

### 3.3 Patch Cadence for Managed Node Groups

| Environment | Patch Frequency | Timing |
|---|---|---|
| Dev | Monthly | First Monday of month |
| Test | Monthly | Second Monday of month |
| Prod | Monthly | Third Monday of month (during maintenance window) |

Maintenance window (prod): 02:00–06:00 UTC (low traffic period)

---

## 4. Patching Strategy — Self-Managed EC2 Worker Nodes

> This section applies only if the platform uses self-managed EC2-based worker nodes instead of (or alongside) Managed Node Groups.

### 4.1 Overview

Self-managed nodes require the platform team to:
1. Build a new AMI with OS patches applied
2. Update the Launch Template in Auto Scaling Group to use the new AMI
3. Trigger an instance refresh to replace nodes
4. Monitor the rolling replacement

### 4.2 AMI Build Process

Use EC2 Image Builder or Packer to build the EKS worker node AMI:

```
Base: Amazon Linux 2 EKS-optimised AMI
     │
     ▼
Apply OS security patches (yum update)
     │
     ▼
Apply CIS hardening (if required)
     │
     ▼
Install additional tooling (CloudWatch agent, SSM agent, etc.)
     │
     ▼
Run security scan (Inspector, Trivy on OS packages)
     │
     ▼
Publish AMI → Update Launch Template
```

**Packer template location:** `scripts/packer/eks-node-ami.pkr.hcl`

### 4.3 Node Replacement Procedure

#### Step 1: Build New AMI

Trigger AMI build pipeline (manual or scheduled):
```bash
packer build scripts/packer/eks-node-ami.pkr.hcl
```

#### Step 2: Update Launch Template

```hcl
resource "aws_launch_template" "eks_node" {
  image_id = var.eks_node_ami_id  # Updated to new AMI ID
}
```

#### Step 3: Pre-Patch Safety Checks

Before starting instance refresh:
```bash
# Verify all pods are healthy
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Verify PodDisruptionBudgets won't block
kubectl get pdb --all-namespaces

# Verify sufficient node capacity for rolling replace
kubectl get nodes
```

#### Step 4: Drain and Replace Nodes (Rolling)

Option A — AWS Auto Scaling Instance Refresh:
```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name {asg-name} \
  --strategy Rolling \
  --preferences '{
    "MinHealthyPercentage": 80,
    "InstanceWarmup": 120,
    "SkipMatching": false,
    "AutoRollback": true
  }'
```

Option B — Manual Node Drain and Terminate:
```bash
# For each node being replaced:
NODE="ip-10-0-10-100.eu-west-1.compute.internal"

# Cordon node (prevent new pods)
kubectl cordon $NODE

# Drain node (evict pods gracefully)
kubectl drain $NODE \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=300s

# Terminate EC2 instance (ASG will launch replacement)
INSTANCE_ID=$(kubectl get node $NODE -o jsonpath='{.spec.providerID}' | cut -d/ -f5)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Wait for replacement node to be Ready
kubectl wait --for=condition=Ready node -l kubernetes.io/hostname=$NEW_NODE --timeout=300s
```

#### Step 5: Post-Patch Validation

```bash
# Verify all nodes show new AMI
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/{cluster},Values=owned" \
  --query 'Reservations[].Instances[].ImageId'

# Verify all nodes Ready
kubectl get nodes

# Run smoke test
./scripts/smoke-test.sh {env}
```

### 4.4 Handling Pod Disruption Budget Violations

If a node drain fails due to PDB violations:

```bash
# Check which PDB is blocking
kubectl describe pdb -n {namespace} {pdb-name}

# Check which pods are blocking
kubectl get pods -n {namespace} -l {selector}
```

Options:
1. Wait for application to scale up additional replicas
2. Coordinate with application team to temporarily adjust PDB
3. Force drain with `--force` flag (last resort; may cause downtime)

---

## 5. AWS Node Termination Handler (Self-Managed Nodes Only)

For self-managed nodes using Spot instances, the AWS Node Termination Handler DaemonSet must be deployed to handle Spot interruption notices gracefully:

```bash
helm upgrade --install aws-node-termination-handler \
  eks/aws-node-termination-handler \
  --namespace kube-system \
  --set enableSpotInterruptionDraining=true \
  --set enableScheduledEventDraining=true
```

This is **not required** for Managed Node Groups — EKS handles Spot interruptions natively.

---

## 6. Monthly Patching Runbook Summary

```
Week 1 (Mon): Patch Dev
  1. Check latest AMI / build new AMI (if self-managed)
  2. Update Terraform / Launch Template
  3. Run patch pipeline in dev
  4. Validate

Week 2 (Mon): Patch Test
  1. Apply same AMI version as Dev
  2. Run patch pipeline in test
  3. Validate
  4. Run regression tests

Week 3 (Mon, 02:00 UTC): Patch Prod
  1. Notify stakeholders of maintenance window
  2. Apply same AMI version
  3. Run patch pipeline in prod (rolling, one node at a time)
  4. Monitor pod rescheduling
  5. Validate
  6. Notify stakeholders: patching complete

Week 4: Review
  1. Review patch status report
  2. Document any issues encountered
  3. Update runbook if needed
```

---

## 7. Emergency Patching

For critical CVEs (CVSS ≥ 9.0) requiring immediate patching:

1. Assess impact — does the CVE affect EKS worker nodes?
2. Check if AWS has released a patched EKS AMI
3. Trigger emergency patch in dev → test → prod (compressed timeline)
4. Emergency prod patch may skip normal maintenance window with stakeholder approval
5. Document as emergency change with RCA

---

## 8. Related Documents

- [EKS Upgrade Strategy](eks-upgrade-strategy.md)
- [Maintenance Pipeline](../../platform-pipelines/maintenance-pipelines/)
- [Disaster Recovery](../architecture/disaster-recovery.md)
