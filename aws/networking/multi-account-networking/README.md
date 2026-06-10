# 🌐 Multi-Account Networking

> Scalable network architecture using RAM, IPAM, and shared resources across AWS accounts.

---

## Architecture

```mermaid
graph TD
    subgraph "Network Account (Central)"
        IPAM[VPC IPAM<br/>CIDR Allocation]
        TGW[Transit Gateway]
        RAM[Resource Access Manager]
        DNS[Route 53 Resolver<br/>Centralized DNS]
    end
    
    RAM -->|Share TGW| ORG[Organization]
    RAM -->|Share Subnets| TEAMS[Workload Accounts]
    IPAM -->|Allocate CIDRs| VPCs[VPCs Across Accounts]
    DNS -->|Resolve| VPCs
    
    subgraph "Workload Account A"
        VPC_A[VPC - Allocated CIDR]
    end
    
    subgraph "Workload Account B"
        VPC_B[VPC - Allocated CIDR]
    end
    
    TGW --> VPC_A
    TGW --> VPC_B
```

## Key Components

| Component | Purpose | Benefit |
|-----------|---------|---------|
| VPC IPAM | Centralized CIDR management | No IP conflicts, automated allocation |
| RAM | Share TGW and subnets | Workloads attach without network team intervention |
| Route 53 Resolver | Centralized DNS resolution | Consistent name resolution across accounts |
| Network Firewall | Centralized traffic inspection | Single pane for security monitoring |

---

➡️ [Back to Networking](../) | [Back to AWS](../../)
