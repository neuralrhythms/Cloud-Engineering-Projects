# Architecture Overview

## Multi-Account Strategy

This landing zone implements the AWS Security Reference Architecture (SRA) pattern with dedicated accounts for specific functions:

### Account Types

| Account | OU | Purpose |
|---------|-----|---------|
| Management | Root | AWS Organizations administration, billing, SCPs |
| Security Tooling | Security | Delegated admin for GuardDuty, SecurityHub, Config, Inspector |
| Log Archive | Security | Immutable centralized log storage |
| Network | Infrastructure | Transit Gateway, shared VPCs, DNS, firewalls |
| Shared Services | Infrastructure | CI/CD pipelines, shared tooling |
| Workload (Prod) | Workloads/Prod | Production workloads |
| Workload (Non-Prod) | Workloads/Non-Prod | Development, staging workloads |

## Network Architecture

```
                         ┌───────────────────────────────────┐
                         │        Network Account             │
                         │                                    │
                         │    ┌────────────────────────┐      │
                         │    │   Transit Gateway      │      │
                         │    └──────────┬─────────────┘      │
                         │               │                    │
                         │    ┌──────────┼──────────┐         │
                         │    │          │          │         │
                         │    ▼          ▼          ▼         │
                         │ ┌──────┐ ┌──────┐ ┌──────────┐    │
                         │ │Egress│ │Ingress│ │Inspection│    │
                         │ │ VPC  │ │ VPC  │ │   VPC    │    │
                         │ └──────┘ └──────┘ └──────────┘    │
                         │                                    │
                         └───────────────────────────────────┘
                                        │
              ┌─────────────────────────┼─────────────────────────┐
              │                         │                         │
              ▼                         ▼                         ▼
    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
    │  Production VPCs  │    │ Non-Prod VPCs    │    │ Shared Svc VPC   │
    │  (Workload Accts) │    │ (Workload Accts) │    │ (Shared Acct)    │
    └──────────────────┘    └──────────────────┘    └──────────────────┘
```

### Transit Gateway Route Tables

| Route Table | Associations | Propagations | Purpose |
|------------|--------------|--------------|---------|
| Production | Prod VPCs | Shared Services, Egress | Prod isolation |
| Non-Production | Non-Prod VPCs | Shared Services, Egress | Dev/Staging |
| Shared Services | Shared VPC | All workload VPCs | Central tools |
| Edge | Egress VPC, Ingress VPC | All | Internet access |

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Tooling Account                       │
│                    (Delegated Administrator)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐    │
│  │GuardDuty │ │ Security │ │  AWS     │ │    IAM Access    │    │
│  │  Admin   │ │   Hub    │ │ Config   │ │     Analyzer     │    │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────────┬─────────┘    │
│       │             │            │                 │              │
│       └─────────────┴────────────┴─────────────────┘              │
│                              │                                    │
│                    ┌─────────▼──────────┐                         │
│                    │    EventBridge     │                         │
│                    │  (Notifications)   │                         │
│                    └────────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                  ▼
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │ Member Acct  │   │ Member Acct  │   │ Member Acct  │
    │ (Auto-       │   │ (Auto-       │   │ (Auto-       │
    │  enrolled)   │   │  enrolled)   │   │  enrolled)   │
    └──────────────┘   └──────────────┘   └──────────────┘
```

## Logging Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Log Archive Account                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐   │
│  │  CloudTrail     │  │  Config Logs    │  │ VPC Flow Logs  │   │
│  │  S3 Bucket      │  │  S3 Bucket      │  │  S3 Bucket     │   │
│  │  (Object Lock)  │  │  (Object Lock)  │  │  (Object Lock) │   │
│  └─────────────────┘  └─────────────────┘  └────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    KMS CMK                                │    │
│  │            (Encryption for all log buckets)               │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              S3 Lifecycle Policies                         │    │
│  │  Standard → IA (90 days) → Glacier (365 days)            │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                               ▲
                               │ (Logs flow in from all accounts)
            ┌──────────────────┼──────────────────┐
            │                  │                  │
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │ CloudTrail   │   │ AWS Config   │   │  VPC Flow    │
    │ (Org Trail)  │   │ (All Accts)  │   │    Logs      │
    └──────────────┘   └──────────────┘   └──────────────┘
```

## Identity Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Management Account                             │
│                    (IAM Identity Center)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Identity Source: AWS SSO Directory / External IdP (Okta/Azure)  │
│                                                                   │
│  Permission Sets:                                                 │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────────┐   │
│  │ Administrator  │ │  ReadOnly      │ │ SecurityAudit      │   │
│  │ (Emergency)    │ │  (Dev teams)   │ │ (Security team)    │   │
│  └────────────────┘ └────────────────┘ └────────────────────┘   │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────────┐   │
│  │  Developer     │ │  NetworkAdmin  │ │  Billing           │   │
│  │  (App teams)   │ │  (Net team)    │ │  (Finance)         │   │
│  └────────────────┘ └────────────────┘ └────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Management plane** - All API calls recorded in CloudTrail → Log Archive
2. **Network traffic** - VPC Flow Logs → Log Archive (centralized)
3. **Security findings** - GuardDuty/Inspector/Macie → SecurityHub → EventBridge
4. **Configuration** - AWS Config records → Security account (aggregator) + Log Archive (history)
5. **Access** - Users authenticate via Identity Center → assume roles in target accounts
