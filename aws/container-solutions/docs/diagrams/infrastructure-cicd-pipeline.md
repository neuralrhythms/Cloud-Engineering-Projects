# Diagram: Infrastructure CI/CD Pipeline

## Overview

This diagram shows the full infrastructure lifecycle pipeline — from Git commit to Terraform apply, including security scanning and manual approval gates.

---

## Mermaid Source

```mermaid
flowchart LR
    GIT[("Git Repository\nmain / feature branch")]

    subgraph CI["Pipeline 1: Terraform CI (PR Check)"]
        direction TB
        C1[Checkout]
        C2[Terraform\nfmt -check]
        C3[Terraform\nvalidate]
        C4[tfsec\nSecurity Scan]
        C5[checkov\nCompliance Scan]
        C6[Terraform\nInit + Plan\n(no apply)]
        C7{All checks\npassed?}
        C8[✅ PR Approved\nfor Merge]
        C9[❌ Fail — Block\nPR Merge]

        C1 --> C2 --> C3 --> C4 --> C5 --> C6 --> C7
        C7 -->|Yes| C8
        C7 -->|No| C9
    end

    subgraph CD["Pipeline 2: Terraform CD (Deploy)"]
        direction TB
        D1[Checkout\nmain branch]
        D2[Terraform Init\nbackend config]
        D3[Terraform Plan\n-out=tfplan]
        D4{Environment?}
        D5[Auto Apply\ndev / test]
        D6[Manual Approval\nRequired — prod]
        D7[Terraform Apply]
        D8[Post-Apply\nValidation]
        D9[Notify\nSlack / Teams]
        D10[❌ Rollback\nAlert on Failure]

        D1 --> D2 --> D3 --> D4
        D4 -->|dev/test| D5 --> D7
        D4 -->|prod| D6 --> D7
        D7 --> D8 --> D9
        D7 -->|failure| D10
    end

    subgraph DRIFT["Pipeline 3: Drift Detection (Scheduled)"]
        direction TB
        DR1[Scheduled\nDaily Trigger]
        DR2[Terraform Plan\n-detailed-exitcode]
        DR3{Exit Code 2?\nDrift Detected}
        DR4[Alert\nSlack / SNS]
        DR5[✅ No Drift]

        DR1 --> DR2 --> DR3
        DR3 -->|Yes| DR4
        DR3 -->|No| DR5
    end

    GIT -->|PR opened| CI
    GIT -->|Merge to main| CD
    DRIFT

    subgraph UPGRADE["Pipeline 4: EKS Upgrade"]
        direction TB
        U1[Trigger: Manual\nor Scheduled]
        U2[Pre-upgrade\nHealth Check]
        U3[Update Control\nPlane Version]
        U4[Update Managed\nAdd-ons]
        U5[Update Node\nGroups — Rolling]
        U6[Update Platform\nHelm Charts]
        U7[Post-upgrade\nValidation]

        U1 --> U2 --> U3 --> U4 --> U5 --> U6 --> U7
    end
```

---

## Pipeline Triggers

| Pipeline | Trigger | Environments |
|---|---|---|
| Terraform CI | Pull Request opened/updated | All |
| Terraform CD | Merge to `main` branch | dev → test → prod |
| Drift Detection | Scheduled (daily, 06:00 UTC) | All |
| EKS Upgrade | Manual trigger (with version parameter) | All (sequential) |

---

## Approval Requirements

| Stage | Dev | Test | Prod |
|---|---|---|---|
| Terraform Apply | Auto | Auto | Manual approval |
| EKS Control Plane Upgrade | Auto | Manual | Manual |
| Node Group Update | Auto | Manual | Manual |

---

## Rendered Format

To render: [Mermaid Live Editor](https://mermaid.live)
