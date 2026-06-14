# Security Design

## Document Information

| Field | Value |
|---|---|
| Document Type | Security Design |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering / Security |

---

## 1. Purpose

This document describes the security architecture of the AWS EKS platform. It covers identity and access management, network security, data protection, threat detection, and compliance controls.

---

## 2. Security Principles

| Principle | Description |
|---|---|
| Least Privilege | Every identity (IAM role, Kubernetes service account) receives only the minimum permissions required |
| Defence in Depth | Multiple security controls at each layer (network, identity, runtime, data) |
| Zero Trust | No implicit trust; every request is authenticated and authorised |
| Encryption Everywhere | Data encrypted at rest and in transit using KMS-managed keys |
| Immutable Infrastructure | Nodes are replaced rather than modified; drift is prevented by IaC |
| Audit Everything | All API calls, network flows, and cluster actions are logged |
| Shift Left | Security scanning occurs in CI pipeline before deployment |

---

## 3. Identity and Access Management

### 3.1 AWS IAM

All IAM roles follow least-privilege:

| Role | Assigned To | Key Permissions |
|---|---|---|
| `eks-cluster-role` | EKS control plane | `AmazonEKSClusterPolicy` |
| `eks-node-role` | Managed Node Group instances | Worker node policies + SSM |
| `alb-controller-role` | ALB Controller ServiceAccount (IRSA) | ELB management permissions |
| `cluster-autoscaler-role` | Cluster Autoscaler ServiceAccount (IRSA) | ASG read/modify |
| `jenkins-deploy-role` | Jenkins EC2/pod | ECR push, EKS describe, Secrets read |
| `external-secrets-role` | External Secrets Operator ServiceAccount | SecretsManager GetSecretValue |

### 3.2 IAM Roles for Service Accounts (IRSA)

IRSA allows Kubernetes pods to assume IAM roles without static credentials:

```
Pod → ServiceAccount → OIDC Provider → IAM Role → AWS API
```

Configuration:
1. EKS OIDC provider enabled on cluster
2. IAM role trust policy scoped to specific namespace and service account name
3. ServiceAccount annotated with IAM role ARN

```yaml
# ServiceAccount annotation
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/my-app-role
```

Trust policy condition:
```json
{
  "StringEquals": {
    "oidc.eks.eu-west-1.amazonaws.com/id/OIDC_ID:sub":
      "system:serviceaccount:my-namespace:my-service-account",
    "oidc.eks.eu-west-1.amazonaws.com/id/OIDC_ID:aud":
      "sts.amazonaws.com"
  }
}
```

### 3.3 No Long-Lived Credentials

- No IAM access keys stored in Jenkins, Kubernetes secrets, or application code
- Jenkins uses EC2 instance profile or EKS IRSA for AWS API access
- Application pods use IRSA for AWS service access
- All credentials are short-lived tokens (IRSA tokens expire in 1 hour by default)

---

## 4. Kubernetes RBAC

### 4.1 RBAC Model

See [EKS Platform Design — RBAC](../architecture/eks-platform-design.md#5-rbac-model) for full role definitions.

### 4.2 Principle of Least Privilege in RBAC

- Cluster-admin binding is tightly restricted (Platform Engineering team only)
- Application teams have namespace-scoped access only
- Read-only roles used for monitoring and audit tooling
- No default service accounts used for workloads (dedicated service accounts per app)

### 4.3 EKS Access Entries

EKS 1.28+ uses Access Entries (replacing `aws-auth` ConfigMap) for cleaner, API-driven RBAC:

```hcl
resource "aws_eks_access_entry" "platform_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.platform_admin.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "platform_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.platform_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
```

---

## 5. Network Security

### 5.1 Network Segmentation

- Worker nodes run in private subnets with no direct internet access
- Inbound internet traffic only through ALB in public subnets
- Outbound internet through NAT Gateway
- VPC Endpoints for AWS service traffic (avoids internet path)

### 5.2 Security Groups

See [Network Design — Security Groups](../architecture/network-design.md#8-security-groups) for detailed rules.

### 5.3 Kubernetes Network Policies

Default deny-all policy applied to all application namespaces:

```yaml
# kubernetes/network-policies/default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Explicit allow policies added per application:

```yaml
# Allow ingress from ALB to application pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-from-alb
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: my-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: TCP
          port: 8080
```

### 5.4 TLS

- All external traffic uses TLS 1.2+ terminated at ALB (ACM certificate)
- Internal service-to-service traffic uses mTLS where required (future: service mesh)
- EKS API endpoint uses TLS (AWS-managed certificate)

---

## 6. Data Protection

### 6.1 Encryption at Rest

| Data | Encryption | Key |
|---|---|---|
| EKS etcd secrets | AWS-managed encryption + KMS CMK envelope | `alias/{project}-{env}-eks-secrets` |
| EBS volumes (node root) | EBS encryption | `alias/{project}-{env}-ebs` |
| ECR images | KMS encryption | `alias/{project}-{env}-ecr` |
| S3 (Terraform state) | SSE-KMS | `alias/{project}-{env}-terraform-state` |
| CloudWatch Logs | KMS encryption | `alias/{project}-{env}-logs` |
| Secrets Manager | KMS encryption | `alias/{project}-{env}-secrets-manager` |

### 6.2 Encryption in Transit

| Connection | Protocol | Certificate |
|---|---|---|
| Client to ALB | TLS 1.2+ | ACM certificate |
| ALB to pods | HTTP (within VPC) or HTTPS | Optional: ACM |
| Pod to AWS services | TLS (VPC Endpoint) | AWS-managed |
| EKS API access | TLS | AWS-managed |
| Node to control plane | TLS | EKS-managed |

### 6.3 Secrets Management

All application secrets stored in AWS Secrets Manager:
- No secrets in Kubernetes YAML files or Helm values
- External Secrets Operator syncs secrets from Secrets Manager to Kubernetes Secrets
- Kubernetes Secrets encrypted at rest via KMS (etcd envelope encryption)
- Secret access audited via CloudTrail

---

## 7. Container Security

### 7.1 Image Scanning

```
CI Pipeline: Build Image
      │
      ▼
Trivy Scan (HIGH/CRITICAL → fail build)
      │
      ▼
Push to ECR
      │
      ▼
ECR Enhanced Scanning (continuous, post-push)
```

### 7.2 Image Signing (Future)

AWS Signer or Cosign for image signing and verification at admission time.

### 7.3 Pod Security Standards

| Namespace | Level | Enforcement |
|---|---|---|
| `kube-system` | Privileged | Enforce |
| `platform-system` | Baseline | Enforce |
| Application namespaces | Restricted | Enforce (gradually rolled out) |

Required security context for all application containers:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
  seccompProfile:
    type: RuntimeDefault
```

### 7.4 Admission Control

- Kubernetes built-in Pod Security Admission controller (PSA) for Pod Security Standards
- Future: OPA Gatekeeper or Kyverno for custom policy enforcement

---

## 8. Threat Detection and Response

### 8.1 Amazon GuardDuty

Enabled with EKS protection:

| Data Source | What It Detects |
|---|---|
| VPC Flow Logs | Unexpected network connections, port scanning |
| DNS Logs | C2 communication, DNS exfiltration |
| CloudTrail | Unusual API calls, credential abuse |
| EKS Audit Logs | Container escape attempts, privilege escalation |
| Malware Protection | Malware on EBS volumes |

Findings are sent to:
- AWS Security Hub (aggregation)
- SNS → Slack/PagerDuty (High/Critical severity)

### 8.2 AWS Security Hub

Standards enabled:
- AWS Foundational Security Best Practices
- CIS AWS Foundations Benchmark
- (Optional) PCI DSS

### 8.3 AWS CloudTrail

- Enabled in all environments
- Multi-region trail for comprehensive coverage
- S3 destination with KMS encryption and MFA Delete
- CloudWatch Logs integration for real-time alerting
- Data events: S3 (read/write), Lambda, EKS API calls

### 8.4 VPC Flow Logs

- All traffic (ACCEPT + REJECT) logged
- Stored in CloudWatch Logs with 365-day retention (prod)
- Analysed by GuardDuty and available for ad-hoc investigation

---

## 9. Compliance and Audit

### 9.1 AWS Config

- Enabled in all environments
- Configuration recorder captures all resource changes
- Conformance packs: AWS Security Best Practices, CIS Level 1

### 9.2 Audit Logging Coverage

| Layer | Log Source | Destination |
|---|---|---|
| AWS API | CloudTrail | S3 + CloudWatch Logs |
| Network | VPC Flow Logs | CloudWatch Logs |
| Kubernetes | EKS Audit Logs | CloudWatch Logs |
| Application | Application logs (stdout/stderr) | CloudWatch Logs |
| Container | Container runtime logs | CloudWatch Logs |

### 9.3 Log Retention

| Log Type | Dev | Test | Prod |
|---|---|---|---|
| CloudTrail | 90 days | 90 days | 365 days |
| VPC Flow Logs | 30 days | 30 days | 365 days |
| EKS Audit Logs | 30 days | 30 days | 90 days |
| Application Logs | 7 days | 30 days | 90 days |

---

## 10. Security Scanning in CI/CD

| Stage | Tool | What It Scans |
|---|---|---|
| Pre-commit | `git-secrets`, `detect-secrets` | Hardcoded secrets in code |
| Terraform CI | `tfsec`, `checkov` | IaC misconfigurations |
| Container build | `trivy` | Container image CVEs |
| Dependency scan | `trivy` / `snyk` | Application dependency CVEs |
| Helm lint | `helm lint`, `polaris` | Kubernetes manifest best practices |

---

## 11. Incident Response

### Security Incident Runbook Location

See [docs/runbooks/security-incident-response.md](../runbooks/security-incident-response.md)

### Severity Classification

| Severity | Description | Response Time |
|---|---|---|
| Critical | Active breach, data exfiltration | 15 minutes |
| High | Suspected breach, GuardDuty High finding | 1 hour |
| Medium | Security misconfiguration, policy violation | 24 hours |
| Low | Informational finding, best practice deviation | 1 week |

---

## 12. Related Documents

- [Network Design](../architecture/network-design.md)
- [EKS Platform Design](../architecture/eks-platform-design.md)
- [Security Incident Response Runbook](../runbooks/security-incident-response.md)
- [Well-Architected Assessment](../architecture/well-architected-assessment.md)
