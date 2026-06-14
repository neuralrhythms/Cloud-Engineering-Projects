# Low-Level Design (LLD)

## Document Information

| Field | Value |
|---|---|
| Document Type | Low-Level Design |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This Low-Level Design provides detailed technical specifications for the AWS EKS platform. It is intended for engineers implementing or operating the platform and contains configuration parameters, module interfaces, resource naming conventions, and component-level specifications.

---

## 2. Naming Conventions

All resources follow a consistent naming pattern:

```
{project}-{environment}-{component}-{suffix}
```

Examples:

| Resource | Name Pattern | Example |
|---|---|---|
| VPC | `{project}-{env}-vpc` | `eks-platform-prod-vpc` |
| EKS Cluster | `{project}-{env}-eks` | `eks-platform-prod-eks` |
| Node Group | `{project}-{env}-ng-{type}` | `eks-platform-prod-ng-general` |
| ECR Repository | `{project}/{app-name}` | `eks-platform/my-app` |
| IAM Role | `{project}-{env}-{component}-role` | `eks-platform-prod-eks-node-role` |
| KMS Key Alias | `alias/{project}-{env}-{purpose}` | `alias/eks-platform-prod-eks-secrets` |
| Security Group | `{project}-{env}-{component}-sg` | `eks-platform-prod-eks-nodes-sg` |

---

## 3. VPC Specification

| Parameter | Dev | Test | Prod |
|---|---|---|---|
| CIDR Block | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| Public Subnets | 3 x /24 | 3 x /24 | 3 x /24 |
| Private Subnets | 3 x /24 | 3 x /24 | 3 x /24 |
| NAT Gateways | 1 | 1 | 3 (one per AZ) |
| VPC Flow Logs | Enabled | Enabled | Enabled |
| DNS Hostnames | Enabled | Enabled | Enabled |
| DNS Resolution | Enabled | Enabled | Enabled |

### Subnet Tags (Required for EKS)

Public subnets must be tagged:
```
kubernetes.io/role/elb = 1
kubernetes.io/cluster/{cluster-name} = shared
```

Private subnets must be tagged:
```
kubernetes.io/role/internal-elb = 1
kubernetes.io/cluster/{cluster-name} = shared
```

---

## 4. EKS Cluster Specification

| Parameter | Dev | Test | Prod |
|---|---|---|---|
| Kubernetes Version | 1.30 | 1.30 | 1.30 |
| API Endpoint Access | Public + Private | Public + Private | Private only |
| Control Plane Logs | All types | All types | All types |
| Secrets Encryption | KMS | KMS | KMS |
| OIDC Provider | Enabled | Enabled | Enabled |
| Pod Identity | Enabled | Enabled | Enabled |

### Control Plane Log Types

- `api`
- `audit`
- `authenticator`
- `controllerManager`
- `scheduler`

---

## 5. Managed Node Group Specification

### General Purpose Node Group

| Parameter | Dev | Test | Prod |
|---|---|---|---|
| Instance Type | t3.medium | m5.large | m5.xlarge |
| Capacity Type | SPOT | ON_DEMAND | ON_DEMAND |
| Min Size | 1 | 2 | 3 |
| Max Size | 5 | 10 | 20 |
| Desired Size | 2 | 3 | 5 |
| AMI Type | AL2_x86_64 | AL2_x86_64 | AL2_x86_64 |
| Disk Size (GB) | 50 | 100 | 100 |
| Max Unavailable | 1 | 1 | 1 |

### Node Group Labels

```yaml
node.kubernetes.io/workload-type: general
environment: dev|test|prod
platform: eks
```

### Node Group Taints (Production)

```yaml
# No taints on general node group
# Example for dedicated workload node group:
# workload=critical:NoSchedule
```

---

## 6. IAM Roles Specification

### EKS Cluster Role

```
Name:    {project}-{env}-eks-cluster-role
Trusted: eks.amazonaws.com
Policies:
  - AmazonEKSClusterPolicy
```

### EKS Node Group Role

```
Name:    {project}-{env}-eks-node-role
Trusted: ec2.amazonaws.com
Policies:
  - AmazonEKSWorkerNodePolicy
  - AmazonEKS_CNI_Policy
  - AmazonEC2ContainerRegistryReadOnly
  - AmazonSSMManagedInstanceCore       # For Session Manager access
```

### AWS Load Balancer Controller Role (IRSA)

```
Name:    {project}-{env}-alb-controller-role
Trusted: OIDC Provider (federated)
Condition: sts:AssumeRoleWithWebIdentity
Subject: system:serviceaccount:kube-system:aws-load-balancer-controller
Policies:
  - AWSLoadBalancerControllerIAMPolicy  (custom managed policy)
```

### Cluster Autoscaler Role (IRSA)

```
Name:    {project}-{env}-cluster-autoscaler-role
Trusted: OIDC Provider (federated)
Condition: sts:AssumeRoleWithWebIdentity
Subject: system:serviceaccount:kube-system:cluster-autoscaler
Policies:
  - ClusterAutoscalerPolicy  (custom managed policy)
```

---

## 7. KMS Keys Specification

| Key Alias | Purpose | Key Type |
|---|---|---|
| `alias/{project}-{env}-eks-secrets` | EKS etcd encryption | Symmetric |
| `alias/{project}-{env}-ebs` | EBS volume encryption | Symmetric |
| `alias/{project}-{env}-ecr` | ECR image encryption | Symmetric |
| `alias/{project}-{env}-logs` | CloudWatch Logs encryption | Symmetric |
| `alias/{project}-{env}-secrets-manager` | Secrets Manager encryption | Symmetric |

All keys:
- Multi-region: disabled (single-region per environment)
- Key rotation: enabled (annual)
- Key policy: restricts access to specific IAM roles

---

## 8. Security Groups Specification

### EKS Control Plane Security Group

| Rule | Type | Port | Source |
|---|---|---|---|
| Allow HTTPS from nodes | Inbound | 443 | Node SG |
| Allow all to nodes | Outbound | all | Node SG |

### EKS Node Security Group

| Rule | Type | Port | Source |
|---|---|---|---|
| Allow all node-to-node | Inbound | all | Self |
| Allow from control plane | Inbound | 1025-65535 | Control Plane SG |
| Allow HTTPS from control plane | Inbound | 443 | Control Plane SG |
| Allow all outbound | Outbound | all | 0.0.0.0/0 |

### ALB Security Group

| Rule | Type | Port | Source |
|---|---|---|---|
| Allow HTTPS from internet | Inbound | 443 | 0.0.0.0/0 |
| Allow HTTP from internet | Inbound | 80 | 0.0.0.0/0 |
| Allow all to nodes | Outbound | all | Node SG |

---

## 9. ECR Repository Specification

| Parameter | Value |
|---|---|
| Image scanning | Scan on push |
| Image tag mutability | IMMUTABLE (prod) / MUTABLE (dev/test) |
| Encryption | KMS (CMK) |
| Lifecycle policy | Expire untagged after 7 days; keep last 10 tagged |
| Cross-account access | Via resource-based policy |

---

## 10. EKS Add-ons Version Matrix

| Add-on | Managed By | Version Policy |
|---|---|---|
| vpc-cni | EKS Managed Add-on | Latest compatible with EKS version |
| coredns | EKS Managed Add-on | Latest compatible with EKS version |
| kube-proxy | EKS Managed Add-on | Latest compatible with EKS version |
| aws-ebs-csi-driver | EKS Managed Add-on | Latest compatible with EKS version |
| aws-load-balancer-controller | Helm (self-managed) | Pinned version, upgrades via pipeline |
| cluster-autoscaler | Helm (self-managed) | Pinned version, must match EKS version |
| metrics-server | Helm (self-managed) | Latest stable |
| aws-cloudwatch-agent | EKS Managed Add-on | Latest compatible with EKS version |

---

## 11. Terraform State Configuration

| Environment | Backend | State Key |
|---|---|---|
| Dev | S3 + DynamoDB | `eks-platform/dev/terraform.tfstate` |
| Test | S3 + DynamoDB | `eks-platform/test/terraform.tfstate` |
| Prod | S3 + DynamoDB | `eks-platform/prod/terraform.tfstate` |

State bucket naming: `{project}-{env}-terraform-state-{account-id}`
Lock table naming: `{project}-{env}-terraform-locks`

---

## 12. Related Documents

- [High-Level Design](high-level-design.md)
- [Network Design](network-design.md)
- [EKS Platform Design](eks-platform-design.md)
- [Terraform Module Standards](terraform-module-standards.md)
