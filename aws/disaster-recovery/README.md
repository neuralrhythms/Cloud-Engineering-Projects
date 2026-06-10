# 🔄 Disaster Recovery

> Cross-region architectures ensuring business continuity and data durability across AWS environments.

---

## Overview

Enterprise disaster recovery implementations covering multiple strategies from backup-and-restore to active-active multi-region architectures.

## DR Strategies Comparison

| Strategy | RPO | RTO | Cost | Complexity |
|----------|-----|-----|------|-----------|
| Backup & Restore | Hours | Hours | $ | Low |
| Pilot Light | Minutes | 30-60 min | $$ | Medium |
| Warm Standby | Minutes | 10-30 min | $$$ | Medium-High |
| Active-Active | Zero | Zero | $$$$ | High |

## Architecture: Warm Standby

```mermaid
graph LR
    subgraph "Primary Region (us-east-1)"
        ALB1[Application Load Balancer]
        ASG1[Auto Scaling Group<br/>Full Capacity]
        RDS1[(RDS Primary<br/>Multi-AZ)]
        S3_1[S3 Bucket]
    end
    
    subgraph "DR Region (us-west-2)"
        ALB2[Application Load Balancer]
        ASG2[Auto Scaling Group<br/>Reduced Capacity]
        RDS2[(RDS Read Replica<br/>Cross-Region)]
        S3_2[S3 Bucket<br/>CRR Enabled]
    end
    
    R53[Route 53<br/>Health Checks + Failover]
    
    R53 -->|Active| ALB1
    R53 -.->|Standby| ALB2
    
    RDS1 -->|Async Replication| RDS2
    S3_1 -->|Cross-Region Replication| S3_2
    ALB1 --> ASG1 --> RDS1
    ALB2 --> ASG2 --> RDS2
```

## Architecture: Active-Active Multi-Region

```mermaid
graph TD
    subgraph "Global"
        GDB[(DynamoDB Global Table)]
        R53[Route 53 Latency Routing]
        CF[CloudFront]
    end
    
    subgraph "Region A (us-east-1)"
        ALB_A[ALB]
        ECS_A[ECS Service]
        CACHE_A[ElastiCache]
    end
    
    subgraph "Region B (eu-west-1)"
        ALB_B[ALB]
        ECS_B[ECS Service]
        CACHE_B[ElastiCache]
    end
    
    CF --> R53
    R53 --> ALB_A
    R53 --> ALB_B
    ALB_A --> ECS_A --> GDB
    ALB_B --> ECS_B --> GDB
    ECS_A --> CACHE_A
    ECS_B --> CACHE_B
```

## Key Components

### Route 53 Health Checks and Failover

- Active health checks on primary endpoints
- Automatic DNS failover when primary fails
- Configurable TTL for fast propagation

### Data Replication

| Data Store | Replication Method | Lag |
|-----------|-------------------|-----|
| RDS | Cross-region read replica | Seconds |
| DynamoDB | Global Tables | Milliseconds |
| S3 | Cross-Region Replication (CRR) | Minutes |
| ElastiCache | Global Datastore | Sub-second |
| EFS | Cross-Region Replication | Minutes |

### AWS Backup

- Centralized backup policies across accounts
- Cross-region copy rules for critical workloads
- Point-in-time recovery for databases
- Vault lock for compliance (WORM)

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| DR region selection | us-west-2 | Geographic diversity, full service availability |
| RDS replication | Cross-region read replica | Async with minimal performance impact on primary |
| Failover automation | Route 53 health checks | Native integration, no custom logic needed |
| Infrastructure DR | Terraform + CI/CD | Rebuild from code rather than replicate infrastructure |

## Testing Strategy

| Test Type | Frequency | Scope |
|-----------|-----------|-------|
| Backup restore validation | Weekly (automated) | Individual resources |
| Component failover | Monthly | Single service failover |
| Full DR exercise | Quarterly | Complete region failover |
| Chaos engineering | Ongoing | Random failure injection |

---

➡️ [Back to AWS Projects](../) | [Back to Portfolio](../../)
