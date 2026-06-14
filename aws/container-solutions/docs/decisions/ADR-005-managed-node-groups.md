# ADR-005: Why EKS Managed Node Groups

## Status
Accepted

## Date
2025-01-01

## Context

Worker node compute for the EKS cluster can be provided in three ways: EKS Managed Node Groups, self-managed EC2 Auto Scaling Groups, or AWS Fargate. The platform team needed to select the primary compute strategy, balancing operational burden, lifecycle management, and flexibility.

---

## Options Considered

### Option 1 — EKS Managed Node Groups

AWS manages the EC2 instances within Auto Scaling Groups on behalf of the platform team.

**Pros:**
- Node provisioning and registration handled by AWS
- OS patching via AMI update: simply update the AMI version, EKS performs rolling replacement
- EKS-optimised AMI maintained and patched by AWS
- Rolling update support without manual drain/terminate scripting
- Native integration with EKS console and API
- Spot instance support without Node Termination Handler setup
- Node group health monitoring by EKS; automatic replacement of unhealthy nodes
- Supports node group update via Terraform (AMI version change triggers rolling update)

**Cons:**
- Limited control over exact EC2 launch configuration vs self-managed
- Cannot use fully custom AMIs without limitations
- Cannot set all Auto Scaling Group lifecycle hook configurations

### Option 2 — Self-Managed EC2 Auto Scaling Groups

Platform team manages EC2 instances, AMIs, and node registration.

**Pros:**
- Full control over launch template, AMI, and lifecycle hooks
- Custom AMI (e.g., CIS hardened, specific kernel version)
- Any EC2 configuration supportable

**Cons:**
- Platform team responsible for OS patching (coordinated AMI rebuild + rolling replace)
- Manual node drain/terminate scripting for updates
- AWS Node Termination Handler DaemonSet required for Spot interruption handling
- EKS node registration bootstrap scripting required
- Higher operational overhead; more failure modes

### Option 3 — AWS Fargate

Serverless pod execution; no node management.

**Pros:**
- Zero node management
- Pay per pod (no idle node cost)
- Nodes are isolated per pod (strong isolation)

**Cons:**
- DaemonSets not supported (eliminates many platform tools: CloudWatch Agent, node exporters)
- Limited pod configuration (no privileged containers, no hostNetwork)
- Higher per-pod cost at scale
- Storage limited to ephemeral + EFS (no EBS)
- Not suitable as primary compute for a general-purpose platform

---

## Decision

**EKS Managed Node Groups** were selected as the primary compute strategy.

The decision balances reduced operational burden with sufficient control for a general-purpose platform. Managed Node Groups handle the most complex lifecycle operations (OS patching via AMI updates, rolling node replacement, Spot interruption) natively, allowing the platform team to focus on higher-value activities.

Self-managed nodes are documented as a reference architecture for teams with specific requirements (custom AMI, CIS hardening, GPU workloads). See [Node Patching Strategy](../operations/node-patching-strategy.md) for the patching procedure applicable to self-managed nodes.

---

## Consequences

### Positive
- Node patching simplified to AMI version update in Terraform + pipeline execution
- EKS handles rolling update without custom drain scripts
- Spot instance support works natively without additional DaemonSets
- Reduced operational toil; platform team focuses on workloads not node plumbing

### Negative
- Less control over node configuration than self-managed approach
- Custom AMI support is possible but more limited than self-managed
- Node group update can take time for large clusters (mitigated by pipeline tooling)

### Risks
- AMI update availability: AWS releases updated EKS-optimised AMIs regularly; platform team must track and apply (mitigated by upgrade pipeline)
- Breaking change in EKS-optimised AMI (rare; mitigated by testing in dev first)

---

## References

- [EKS Managed Node Groups Documentation](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [EKS Upgrade Strategy](../operations/eks-upgrade-strategy.md)
- [Node Patching Strategy](../operations/node-patching-strategy.md)
