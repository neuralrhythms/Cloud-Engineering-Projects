# 🚀 Workload Migration

> Multi-account workload migration using AWS Migration Hub, Application Migration Service, and replatforming strategies.

---

## Overview

Large-scale application migration from legacy infrastructure to AWS Landing Zone accounts, following the AWS Migration Acceleration Program (MAP) methodology.

## Migration Strategy (7 Rs)

```mermaid
graph TD
    ASSESS[Assess Portfolio] --> DECISION{Migration Strategy}
    DECISION --> REHOST[Rehost - Lift & Shift]
    DECISION --> REPLATFORM[Replatform - Lift & Optimize]
    DECISION --> REFACTOR[Refactor - Re-architect]
    DECISION --> RETIRE[Retire - Decommission]
    DECISION --> RETAIN[Retain - Keep On-Prem]
    
    REHOST --> MGN[Application Migration Service]
    REPLATFORM --> DMS[DMS + Managed Services]
    REFACTOR --> CONTAINERS[ECS/EKS + Serverless]
```

## Services Used

| Service | Purpose |
|---------|---------|
| Migration Hub | Central tracking and orchestration |
| Application Migration Service | Server replication (rehost) |
| DMS | Database migration |
| CloudEndure | Block-level replication |
| Transfer Family | File transfer automation |

---

➡️ [Back to Migrations](../) | [Back to AWS](../../)
