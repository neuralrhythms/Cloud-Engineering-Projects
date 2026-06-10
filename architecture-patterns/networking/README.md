# 📐 Networking Patterns

> Hub-spoke, mesh, and hybrid connectivity architectures.

---

## Hub-and-Spoke (Transit Gateway)

```mermaid
graph TD
    HUB[Transit Gateway<br/>Central Hub] --> SPOKE1[Prod VPC 1]
    HUB --> SPOKE2[Prod VPC 2]
    HUB --> SPOKE3[Dev VPC]
    HUB --> SHARED[Shared Services]
    HUB --> EGRESS[Egress VPC<br/>NAT + Firewall]
    HUB --> ONPREM[On-Premises<br/>VPN / DX]
    
    EGRESS --> INET[Internet]
```

| Pros | Cons |
|------|------|
| ✅ Centralized management | ❌ TGW per-attachment cost |
| ✅ Scalable (5000 attachments) | ❌ Single regional resource |
| ✅ Route table segmentation | ❌ Bandwidth limits per attachment |
| ✅ Supports VPN and DX | ❌ Additional hop latency (minimal) |

## Use Cases

| Pattern | When to Use |
|---------|-------------|
| Hub-Spoke (TGW) | 5+ VPCs, centralized control, multi-account |
| VPC Peering | 2-4 VPCs, simple connectivity, low cost |
| PrivateLink | Service-to-service access without full VPC connectivity |
| Shared VPC (RAM) | Teams in same account needing controlled subnets |
| Transit Gateway peering | Multi-region hub-spoke |

---

➡️ [Back to Patterns](../) | [Back to Portfolio](../../)
