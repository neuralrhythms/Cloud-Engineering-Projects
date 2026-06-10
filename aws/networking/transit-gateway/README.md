# 🌐 Transit Gateway - Hub and Spoke Network

> Centralized network architecture connecting multiple AWS accounts with traffic segmentation and centralized egress.

---

## Architecture

```mermaid
graph TD
    INET[Internet] --> IGW[IGW]
    IGW --> NAT[NAT GW x3 AZs]
    NAT --> EG_VPC[Egress VPC]
    EG_VPC --> TGW[Transit Gateway]
    
    TGW --> |Production RT| PROD1[Prod VPC 1<br/>10.1.0.0/16]
    TGW --> |Production RT| PROD2[Prod VPC 2<br/>10.2.0.0/16]
    TGW --> |Non-Prod RT| DEV1[Dev VPC 1<br/>10.11.0.0/16]
    TGW --> |Shared RT| SHARED[Shared Services VPC<br/>10.254.0.0/20]
    TGW --> |Edge RT| VPN[Site-to-Site VPN]
    
    VPN --> DC[On-Premises Data Center]
```

## Route Table Segmentation

| Route Table | Associated VPCs | Can Reach | Cannot Reach |
|------------|-----------------|-----------|--------------|
| Production | Prod workloads | Shared Services, Egress | Non-Production |
| Non-Production | Dev, Staging | Shared Services, Egress | Production |
| Shared Services | Shared VPC | All workloads | Direct internet |
| Edge | Egress VPC, VPN | All (routes to workloads) | N/A |

## Key Design Decisions

- **Centralized NAT**: Shared egress reduces cost and provides single inspection point
- **Route table isolation**: Production and non-production cannot communicate
- **RAM sharing**: TGW shared with entire organization via Resource Access Manager
- **Auto-accept**: New VPC attachments automatically accepted

---

➡️ [Back to Networking](../) | [Back to AWS](../../)
