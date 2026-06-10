# 🔐 KMS Encryption Strategy

> Multi-account key management with cross-account sharing, automatic rotation, and key policies.

## Key Hierarchy

```mermaid
graph TD
    subgraph "Log Archive Account"
        LOG_KEY[Logging KMS Key<br/>CloudTrail, Config, Flow Logs]
    end
    
    subgraph "Security Account"
        SEC_KEY[Security KMS Key<br/>GuardDuty Findings]
    end
    
    subgraph "Workload Accounts"
        EBS_KEY[EBS Default Key<br/>Volume Encryption]
        RDS_KEY[RDS Key<br/>Database Encryption]
        S3_KEY[S3 Key<br/>Object Encryption]
    end
    
    subgraph "Management Account"
        STATE_KEY[Terraform State Key]
    end
    
    LOG_KEY -->|Policy: Allow CloudTrail| CT[CloudTrail Service]
    LOG_KEY -->|Policy: Allow Config| CFG[Config Service]
    EBS_KEY -->|Default Encryption| EC2[EC2 Instances]
```

## Best Practices Implemented

- Automatic key rotation (annual)
- Separate keys per account and purpose
- Key policies with explicit principal grants
- Alias-based key references (not ARN)
- CloudTrail logging of all key usage
- Deletion protection (30-day window)

---

➡️ [Back to Security](../) | [Back to AWS](../../)
