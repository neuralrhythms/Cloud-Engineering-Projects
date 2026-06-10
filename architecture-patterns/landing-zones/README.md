# 📐 Landing Zone Patterns

> Multi-account governance patterns for enterprise cloud adoption.

---

## Landing Zone Architecture

```mermaid
graph TD
    ROOT[Organization Root] --> SEC_OU[Security OU<br/>Mandatory]
    ROOT --> INFRA_OU[Infrastructure OU<br/>Shared Services]
    ROOT --> WORK_OU[Workloads OU<br/>Business Applications]
    ROOT --> SAND_OU[Sandbox OU<br/>Experimentation]
    ROOT --> SUSP_OU[Suspended OU<br/>Decommissioned]
    
    SEC_OU --> SECURITY[Security Account<br/>Delegated Admin]
    SEC_OU --> LOGGING[Log Archive<br/>Immutable Logs]
    
    INFRA_OU --> NETWORK[Network Account<br/>Transit Gateway]
    INFRA_OU --> SHARED[Shared Services<br/>CI/CD, DNS]
    
    WORK_OU --> PROD[Production OU]
    WORK_OU --> NONPROD[Non-Production OU]
```

## Key Principles

| Principle | Implementation |
|-----------|---------------|
| Account per workload | Blast radius isolation |
| OU-based governance | SCPs applied at OU level |
| Centralized security | Delegated admin pattern |
| Immutable logging | Object Lock, SCP protection |
| Automated provisioning | Account vending machine |
| Least privilege | Identity Center + Permission Sets |

## Best Practices

1. **Minimize management account usage** — delegate everything
2. **Security baseline applied automatically** — every new account gets GuardDuty, Config, CloudTrail
3. **Network as shared service** — centralize TGW, DNS, egress
4. **Test SCPs in sandbox first** — never deploy restrictive SCPs to production without testing
5. **Infrastructure as Code everything** — reproducible, auditable, version-controlled

---

➡️ [Back to Patterns](../) | [Back to Portfolio](../../)
