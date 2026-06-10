# 🔐 Amazon GuardDuty - Organization-Wide Threat Detection

> Centralized threat detection across all AWS accounts with automated response.

## Architecture

```mermaid
graph LR
    subgraph "All Member Accounts"
        VPC_FL[VPC Flow Logs]
        DNS_L[DNS Logs]
        CT_E[CloudTrail Events]
        K8S[EKS Audit Logs]
    end
    
    subgraph "Security Account (Delegated Admin)"
        GD[GuardDuty Detector]
        GD --> FINDINGS[Findings]
    end
    
    subgraph "Response"
        EB[EventBridge]
        SNS[SNS - PagerDuty]
        LAMBDA[Lambda - Auto Remediate]
        SH[Security Hub]
    end
    
    VPC_FL --> GD
    DNS_L --> GD
    CT_E --> GD
    K8S --> GD
    
    FINDINGS --> EB
    EB --> SNS
    EB --> LAMBDA
    FINDINGS --> SH
```

## Finding Severity Response

| Severity | Action | SLA |
|----------|--------|-----|
| Critical (8-10) | PagerDuty alert + auto-isolate | Immediate |
| High (7-8.9) | Slack alert + investigation | < 4 hours |
| Medium (4-6.9) | Ticket creation | < 24 hours |
| Low (1-3.9) | Weekly review | 1 week |

---

➡️ [Back to Security](../) | [Back to AWS](../../)
