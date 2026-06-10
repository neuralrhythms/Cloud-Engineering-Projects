# 🌐 Hybrid Connectivity

> Secure connectivity between AWS and on-premises data centers using VPN and Direct Connect.

---

## Architecture

```mermaid
graph LR
    subgraph "On-Premises"
        DC[Data Center]
        CGW[Customer Gateway]
    end
    
    subgraph "AWS Network Account"
        VGW[Virtual Private Gateway]
        DX[Direct Connect]
        VPN[Site-to-Site VPN<br/>Backup Path]
        TGW[Transit Gateway]
    end
    
    subgraph "AWS Workloads"
        VPC1[Production VPCs]
        VPC2[Non-Prod VPCs]
    end
    
    DC --> CGW
    CGW -->|Primary: 1 Gbps| DX --> TGW
    CGW -->|Backup: IPSec| VPN --> TGW
    TGW --> VPC1
    TGW --> VPC2
```

## Connectivity Options

| Option | Bandwidth | Latency | Encryption | Cost |
|--------|-----------|---------|-----------|------|
| Direct Connect | 1-100 Gbps | Low (dedicated) | MACsec | $$$$ |
| Site-to-Site VPN | Up to 1.25 Gbps | Variable | IPSec | $ |
| DX + VPN (encrypted) | 1-100 Gbps | Low | IPSec over DX | $$$$$ |

---

➡️ [Back to Networking](../) | [Back to AWS](../../)
