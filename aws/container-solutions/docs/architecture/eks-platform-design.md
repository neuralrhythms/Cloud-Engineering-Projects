# EKS Platform Design

## Document Information

| Field | Value |
|---|---|
| Document Type | EKS Platform Design |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This document describes the Kubernetes platform design on Amazon EKS — covering cluster configuration, add-ons, namespace strategy, RBAC model, secrets management, pod security, and platform component architecture.

---

## 2. EKS Cluster Configuration

### Control Plane

| Parameter | Value |
|---|---|
| Kubernetes version | 1.30 (pinned; upgraded via pipeline) |
| API endpoint | Private (prod) / Public+Private (dev/test) |
| Control plane logs | api, audit, authenticator, controllerManager, scheduler |
| Envelope encryption | Enabled (KMS CMK for etcd secrets) |
| OIDC provider | Enabled (required for IRSA) |
| EKS Pod Identity | Enabled |

### EKS Managed Add-ons

| Add-on | Version Strategy | Configuration |
|---|---|---|
| `vpc-cni` | Latest compatible | Enable network policy support |
| `coredns` | Latest compatible | Default configuration |
| `kube-proxy` | Latest compatible | Default configuration |
| `aws-ebs-csi-driver` | Latest compatible | KMS encryption enabled |
| `amazon-cloudwatch-observability` | Latest compatible | Container Insights enabled |

---

## 3. Managed Node Groups vs EC2 Worker Nodes

### 3.1 Managed Node Groups (Recommended)

This platform uses **EKS Managed Node Groups** as the primary compute strategy.

**Advantages:**

| Feature | Managed Node Group | Self-Managed EC2 |
|---|---|---|
| OS patching | AWS-managed (AMI updates) | Manual or custom automation |
| Node replacement | Rolling update via API | Custom drain/replace scripts |
| Autoscaling integration | Native EKS/ASG integration | Manual ASG configuration |
| Node health monitoring | AWS monitors and replaces | Manual health checks |
| Spot instance support | Native | Manual interruption handling |
| Lifecycle management | AWS handles | Custom automation required |

### 3.2 Self-Managed EC2 Nodes (Reference Architecture)

For specialised use cases (custom AMIs, specific kernel versions, GPU workloads), self-managed EC2-based worker nodes may be used.

**Key differences from Managed Node Groups:**
- Node AMI must be built and maintained by platform team (e.g., using EC2 Image Builder or Packer)
- Spot interruption handling requires custom DaemonSet (e.g., AWS Node Termination Handler)
- OS-level patching must be coordinated with workload drain procedures
- Instance refresh must be triggered manually or via pipeline

> Self-managed nodes are not the default for this platform. They are documented here for reference. See [Node Patching Strategy](../operations/node-patching-strategy.md) for patching procedures if self-managed nodes are in use.

---

## 4. Namespace Strategy

### Platform Namespaces

| Namespace | Purpose | Access |
|---|---|---|
| `kube-system` | Kubernetes system components | Platform team only |
| `kube-public` | Public cluster info | Read-only for all |
| `kube-node-lease` | Node heartbeats | System only |
| `platform-system` | Platform add-ons (autoscaler, ALB controller) | Platform team only |
| `monitoring` | CloudWatch agent, metrics-server | Platform team only |
| `ingress-nginx` | (Optional) NGINX ingress controller | Platform team only |
| `cert-manager` | TLS certificate management | Platform team only |

### Application Namespaces

Application teams are allocated dedicated namespaces following the pattern:

```
{team-name}-{environment}
```

Examples:
- `payments-dev`
- `payments-prod`
- `orders-prod`
- `auth-prod`

Each application namespace is provisioned via Terraform (or GitOps process) with:
- Resource quotas
- LimitRange defaults
- Network policies (deny-all default + explicit allows)
- RBAC bindings

---

## 5. RBAC Model

### Cluster-Level Roles

| Role | Bound To | Permissions |
|---|---|---|
| `cluster-admin` | Platform Engineering team IAM role | Full cluster access |
| `platform-ops` | Platform ops IAM role | Read/write platform namespaces |
| `view` | Dev team IAM roles | Read-only cluster-wide |

### Namespace-Level Roles

| Role | Bound To | Permissions |
|---|---|---|
| `app-developer` | Team IAM role | Full access within team namespace |
| `app-readonly` | Team viewer IAM role | Read-only within team namespace |
| `app-deployer` | Jenkins service account | Deploy, rollout, scale in team namespace |

### aws-auth ConfigMap

The `aws-auth` ConfigMap maps IAM roles/users to Kubernetes RBAC:

```yaml
# kubernetes/rbac/aws-auth-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::ACCOUNT_ID:role/eks-platform-prod-eks-node-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::ACCOUNT_ID:role/platform-engineering-role
      username: platform-admin
      groups:
        - system:masters
    - rolearn: arn:aws:iam::ACCOUNT_ID:role/jenkins-deploy-role
      username: jenkins
      groups:
        - app-deployers
```

> Note: EKS Access Entries (introduced in EKS 1.28) are the preferred approach over `aws-auth` ConfigMap for new clusters. This platform adopts Access Entries.

---

## 6. Pod Security Standards

Kubernetes Pod Security Standards (PSS) are enforced at the namespace level:

| Namespace Type | PSS Level | Enforcement Mode |
|---|---|---|
| `kube-system` | Privileged | Enforce |
| `platform-system` | Baseline | Enforce |
| Application namespaces | Restricted | Warn + Audit (Enforce planned) |

PSS labels applied to namespaces:
```yaml
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/warn: restricted
pod-security.kubernetes.io/audit: restricted
```

---

## 7. Secrets Management

### Design

Secrets are managed through a layered approach:

```
AWS Secrets Manager / Parameter Store
          │
          ▼
  Kubernetes External Secrets Operator
  (or AWS Secrets and Config Provider / ASCP)
          │
          ▼
  Kubernetes Secret (auto-synced)
          │
          ▼
     Pod (mounted as env var or volume)
```

### Implementation Options

| Option | Description | Preferred For |
|---|---|---|
| **External Secrets Operator** | Syncs AWS Secrets Manager/SSM into K8s Secrets | Application workloads |
| **AWS ASCP (CSI Driver)** | Mounts secrets directly as files via CSI | Certificates, high-sensitivity secrets |
| **Native K8s Secrets** | Base64-encoded; encrypted at rest via KMS | Simple config (not recommended for sensitive data) |

### IRSA for Secret Access

Each application's service account has an associated IAM role granting read access to its specific secrets only:

```
Pod → ServiceAccount → IRSA IAM Role → Secrets Manager policy (scoped by name/prefix)
```

---

## 8. Cluster Autoscaler

### Configuration

| Parameter | Value |
|---|---|
| Deployed via | Helm chart (`cluster-autoscaler`) |
| Namespace | `kube-system` |
| IRSA | Enabled (dedicated IAM role) |
| Scale down delay | 10 minutes |
| Scale down utilisation threshold | 50% |
| Skip nodes with system pods | true |
| Balance similar node groups | true |
| Expander | least-waste |

### Cluster Autoscaler IAM Policy

The Cluster Autoscaler requires permissions to:
- Describe Auto Scaling groups
- Modify desired capacity
- Terminate instances

Policy is defined in `terraform/modules/iam/cluster-autoscaler-policy.tf`.

---

## 9. Ingress Architecture

### AWS Load Balancer Controller

- Manages ALB (Application Load Balancer) via Kubernetes Ingress resources
- Manages NLB (Network Load Balancer) via Kubernetes Service (type: LoadBalancer)
- Deployed as Helm chart in `kube-system`
- IRSA enabled for ALB/NLB provisioning

### Ingress Class

```yaml
# Annotation for ALB ingress
kubernetes.io/ingress.class: alb
# or using IngressClass resource
ingressClassName: alb
```

### TLS Termination

- TLS terminated at the ALB using ACM certificates
- Traffic from ALB to pods can be HTTP (within VPC) or HTTPS (end-to-end)
- ACM certificates provisioned via Terraform (`aws_acm_certificate` resource)

---

## 10. Horizontal Pod Autoscaler (HPA)

Application teams are encouraged to define HPA on all production workloads:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

Metrics Server is deployed as a platform component to provide CPU/memory metrics to HPA.

---

## 11. Resource Management

### Namespace ResourceQuota (Template)

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
    services: "20"
    persistentvolumeclaims: "10"
```

### LimitRange (Template)

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
spec:
  limits:
    - type: Container
      default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      max:
        cpu: "4"
        memory: 8Gi
```

---

## 12. Related Documents

- [RBAC Manifests](../../kubernetes/rbac/)
- [Network Policies](../../kubernetes/network-policies/)
- [Helm Standards](helm-deployment-standards.md)
- [EKS Upgrade Strategy](../operations/eks-upgrade-strategy.md)
