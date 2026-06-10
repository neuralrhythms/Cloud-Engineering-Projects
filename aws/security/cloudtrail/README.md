# 🔐 AWS CloudTrail - Organization Audit Trail

> Immutable, encrypted audit logging across all accounts and regions.

## Architecture

```mermaid
graph TD
    subgraph "All Accounts (Auto-Enrolled)"
        API[API Calls<br/>Management + Data Events]
    end
    
    subgraph "Management Account"
        TRAIL[Organization Trail<br/>Multi-Region + Insights]
    end
    
    subgraph "Log Archive Account"
        S3[S3 Bucket<br/>Versioned + Object Lock]
        KMS[KMS CMK<br/>Auto-Rotation]
        LIFECYCLE[Lifecycle<br/>Standard → IA → Glacier]
    end
    
    API --> TRAIL
    TRAIL --> S3
    S3 --> KMS
    S3 --> LIFECYCLE
    
    TRAIL --> CW[CloudWatch Logs<br/>Real-time Analysis]
    CW --> METRIC[Metric Filters]
    METRIC --> ALARM[CloudWatch Alarms]
```

## Key Controls

- **Log file validation**: Digest files for tamper detection
- **KMS encryption**: Customer-managed key with restricted policy
- **S3 Object Lock**: WORM compliance (governance mode)
- **Bucket policy**: Deny deletion, require SSL
- **SCP protection**: Deny trail modification in member accounts
- **Multi-region**: Single trail captures all regions

---

➡️ [Back to Security](../) | [Back to AWS](../../)
