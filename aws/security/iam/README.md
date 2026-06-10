# 🔐 IAM Architecture

> Enterprise IAM design following least privilege principles with cross-account access patterns.

---

## Architecture

```mermaid
graph TD
    subgraph "Identity"
        IDP[External IdP<br/>Okta / Azure AD]
        SSO[IAM Identity Center]
    end
    
    subgraph "Permission Sets"
        ADMIN[AdministratorAccess<br/>Break-glass only]
        READONLY[ReadOnlyAccess<br/>All teams]
        DEV[DeveloperAccess<br/>Non-prod only]
        SECAUDIT[SecurityAudit<br/>Security team]
    end
    
    subgraph "Target Accounts"
        MGMT[Management]
        SEC[Security]
        PROD[Production]
        NONPROD[Non-Production]
    end
    
    IDP --> SSO
    SSO --> ADMIN --> MGMT
    SSO --> READONLY --> PROD
    SSO --> DEV --> NONPROD
    SSO --> SECAUDIT --> SEC
```

## Key Patterns

| Pattern | Description | Use Case |
|---------|-------------|----------|
| Permission Sets | AWS-managed + inline policies | Human access via SSO |
| Service Roles | Scoped to specific service | EC2, Lambda, ECS task roles |
| Cross-Account Roles | Trust policy + assume role | CI/CD, delegated admin |
| Permission Boundaries | Maximum permissions cap | Developer self-service |
| SCPs | Organization-level deny | Preventive guardrails |

---

➡️ [Back to Security](../) | [Back to AWS](../../)
