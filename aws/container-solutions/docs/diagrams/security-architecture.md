# Diagram: Security Architecture

## Overview

This diagram illustrates the layered security controls across the EKS platform — from AWS account boundary through to container runtime.

---

## Mermaid Source

```mermaid
graph TB
    subgraph Layer1["Layer 1 — AWS Account & IAM"]
        SCPs[AWS Organizations\nService Control Policies]
        IAM[IAM Roles\nLeast Privilege]
        IRSA[IRSA\nPod-level IAM]
        CT[CloudTrail\nAPI Audit Logging]
        CONFIG[AWS Config\nCompliance Rules]
    end

    subgraph Layer2["Layer 2 — Network Security"]
        SG[Security Groups\nDeny by Default]
        NACLs[NACLs\nSubnet Level]
        VPCE[VPC Endpoints\nNo Internet for AWS APIs]
        FLOW[VPC Flow Logs\nAll Traffic]
        ALB_TLS[ALB\nTLS Termination]
    end

    subgraph Layer3["Layer 3 — Kubernetes Security"]
        RBAC[Kubernetes RBAC\nLeast Privilege]
        PSS[Pod Security\nStandards — Restricted]
        NETPOL[Network Policies\nDefault Deny All]
        ADM[Admission\nControl — PSA]
        AUDIT[EKS Audit Logs\n→ CloudWatch]
    end

    subgraph Layer4["Layer 4 — Workload / Container"]
        NONROOT[Run as Non-Root]
        READONLY[Read-Only\nRoot Filesystem]
        NOCAP[Drop ALL\nCapabilities]
        SECCOMP[SeccompProfile\nRuntimeDefault]
        IMGSCAN[Image Scan\nTrivy in CI]
        ECRSCAN[ECR Enhanced\nScanning]
    end

    subgraph Layer5["Layer 5 — Data Protection"]
        KMS[AWS KMS\nCMK Encryption]
        SM[Secrets Manager\nNo Static Secrets]
        ETCD[EKS etcd\nEnvelope Encryption]
        TLS[TLS 1.2+\nIn Transit]
    end

    subgraph Detection["Threat Detection & Response"]
        GD[GuardDuty\nVPC + DNS + EKS + CloudTrail]
        SH[Security Hub\nAggregated Findings]
        SNS[SNS\nAlerts]
        RUNBOOK[Incident\nRunbooks]

        GD --> SH
        SH --> SNS
        SNS --> RUNBOOK
    end

    Layer1 --> Layer2
    Layer2 --> Layer3
    Layer3 --> Layer4
    Layer4 --> Layer5

    Layer1 --> Detection
    Layer2 --> Detection
    Layer3 --> Detection
    Layer4 --> Detection
```

---

## Security Controls by Layer

| Layer | Controls | Tools / Services |
|---|---|---|
| AWS Account | SCPs, IAM, CloudTrail | AWS Organizations, IAM, CloudTrail |
| Network | Security Groups, NACLs, VPC Endpoints, Flow Logs | VPC, AWS Network Firewall (optional) |
| Kubernetes | RBAC, PSS, Network Policies, Admission Control | EKS, Kubernetes built-in |
| Container | Non-root, read-only FS, no capabilities, seccomp | Container runtime, OCI spec |
| Data | KMS, Secrets Manager, TLS | KMS, Secrets Manager, ACM |
| Detection | GuardDuty, Security Hub, CloudTrail | GuardDuty, Security Hub |

---

## IRSA Trust Flow

```mermaid
sequenceDiagram
    participant Pod
    participant SA as ServiceAccount
    participant OIDC as EKS OIDC Provider
    participant STS as AWS STS
    participant IAM as IAM Role
    participant Service as AWS Service

    Pod->>SA: Mount projected service account token
    Pod->>STS: AssumeRoleWithWebIdentity (token)
    STS->>OIDC: Validate token
    OIDC-->>STS: Token valid
    STS-->>Pod: Temporary credentials (1h)
    Pod->>IAM: API call with temp credentials
    IAM->>Service: Authorised API call
```

---

## Rendered Format

To render: [Mermaid Live Editor](https://mermaid.live)
