# ADR-001: Why Amazon EKS

## Status
Accepted

## Date
2025-01-01

## Context

The platform engineering team needed to select a Kubernetes distribution to host containerised application workloads on AWS. The key requirements were:

- Production-grade Kubernetes with SLA-backed availability
- AWS-native integrations (IAM, networking, storage, observability)
- Reduced operational burden on the platform team
- Compatibility with Terraform for infrastructure provisioning
- Support for Helm-based application deployments
- Path to self-service for application teams

The organisation is AWS-primary and has existing AWS expertise and tooling.

---

## Options Considered

### Option 1 — Amazon EKS (Managed Kubernetes)

AWS manages the Kubernetes control plane. The platform team manages worker nodes, add-ons, and cluster configuration.

**Pros:**
- Control plane fully managed by AWS (patched, HA, multi-AZ)
- Native integrations: IAM (IRSA), VPC CNI, EBS/EFS CSI, ALB, CloudWatch
- EKS Managed Add-ons simplify core component upgrades
- EKS Managed Node Groups simplify worker node lifecycle
- Strong Terraform provider support (`hashicorp/aws`)
- AWS SLA: 99.95% monthly uptime for control plane
- Native GuardDuty EKS Protection
- Large community and ecosystem

**Cons:**
- Less control over control plane configuration
- EKS-specific concepts (aws-auth, IRSA, managed add-ons)
- Kubernetes version support limited to AWS-supported releases

### Option 2 — Self-Managed Kubernetes on EC2

Install and manage the full Kubernetes control plane on EC2 instances.

**Pros:**
- Full control over all components and configuration
- Any Kubernetes version supportable

**Cons:**
- Significant operational overhead (etcd backups, control plane HA, certificate management)
- Team responsible for control plane upgrades and security patches
- No AWS SLA for availability
- Much higher total cost of ownership
- Not aligned with AWS-native strategy

### Option 3 — Amazon ECS (Elastic Container Service)

AWS-native container orchestration without Kubernetes.

**Pros:**
- Simpler AWS-native service; less operational complexity
- Native Fargate support (serverless)
- No Kubernetes learning curve

**Cons:**
- Not Kubernetes; limits portability and ecosystem compatibility
- Smaller community and tooling ecosystem than Kubernetes
- Helm not applicable; different deployment model
- Skills transferability limited

### Option 4 — Amazon EKS Anywhere / EKS on Fargate

**EKS Anywhere:** On-premises EKS — not applicable for cloud-only deployment.

**EKS on Fargate:** Serverless pods without managing nodes.

**Pros of Fargate:** No node management.

**Cons of Fargate:** Limited add-on support, no DaemonSets, higher per-pod cost at scale, limited observability tooling compatibility.

---

## Decision

**Amazon EKS with Managed Node Groups** was selected as the Kubernetes platform.

The decision prioritises operational efficiency (managed control plane), AWS-native integration depth, and alignment with the organisation's AWS-primary strategy. The managed control plane eliminates the most complex operational burden while providing a fully compliant, SLA-backed Kubernetes environment.

---

## Consequences

### Positive
- Control plane operations outsourced to AWS; platform team focuses on cluster configuration and workloads
- Native IRSA, VPC CNI, and EBS CSI integrations are best-in-class for AWS workloads
- EKS managed add-ons simplify the upgrade and patching lifecycle
- Kubernetes ecosystem tooling (Helm, kubectl, standard operators) fully compatible
- AWS Well-Architected alignment out of the box

### Negative
- Kubernetes version pinned to AWS-supported releases (typically 3 minor versions)
- EKS-specific abstractions (IRSA, EKS access entries, managed add-ons) require team knowledge
- EKS upgrade required approximately annually (AWS mandates version currency within 14 months)

### Risks
- EKS end-of-support window requires planned upgrade procedures (mitigated by upgrade pipeline)
- Add-on version compatibility requires attention during upgrades (mitigated by upgrade strategy)

---

## References

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [EKS Managed Add-ons](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
- [EKS Upgrade Strategy](../operations/eks-upgrade-strategy.md)
