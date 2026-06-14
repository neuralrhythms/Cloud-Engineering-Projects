# Network Design

## Document Information

| Field | Value |
|---|---|
| Document Type | Network Design |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This document describes the network architecture for the AWS EKS platform, covering VPC design, subnet strategy, routing, security group configuration, DNS, and connectivity patterns.

---

## 2. Design Principles

- **Private by default** — workloads run in private subnets; no direct internet exposure
- **Least privilege networking** — security groups follow deny-by-default with explicit allow rules
- **Multi-AZ** — all subnets and node groups span three Availability Zones
- **Traffic separation** — public subnets for ingress/egress infrastructure only; private for compute
- **VPC Endpoints** — internal traffic to AWS services avoids NAT Gateway / internet

---

## 3. IP Addressing

### Environment CIDR Allocations

| Environment | VPC CIDR | Notes |
|---|---|---|
| Dev | 10.0.0.0/16 | 65,536 IPs |
| Test | 10.1.0.0/16 | 65,536 IPs |
| Prod | 10.2.0.0/16 | 65,536 IPs |

> CIDRs are chosen to avoid overlap for future VPC peering or Transit Gateway connectivity.

### Subnet Allocation (per environment)

| Subnet | CIDR | AZ | Type | Use |
|---|---|---|---|---|
| Public Subnet A | 10.x.0.0/24 | AZ-a | Public | ALB, NAT Gateway |
| Public Subnet B | 10.x.1.0/24 | AZ-b | Public | ALB, NAT Gateway |
| Public Subnet C | 10.x.2.0/24 | AZ-c | Public | ALB, NAT Gateway |
| Private Subnet A | 10.x.10.0/24 | AZ-a | Private | EKS Nodes |
| Private Subnet B | 10.x.11.0/24 | AZ-b | Private | EKS Nodes |
| Private Subnet C | 10.x.12.0/24 | AZ-c | Private | EKS Nodes |

> Adjust CIDR sizes if workload density requires larger subnets (e.g., /22 for high pod counts with AWS VPC CNI).

---

## 4. Internet Gateway and NAT Gateway

### Internet Gateway

- One Internet Gateway attached per VPC
- Used only by public subnets for ingress (ALB) and NAT Gateway egress

### NAT Gateway

| Environment | NAT Gateway Count | Rationale |
|---|---|---|
| Dev | 1 (in AZ-a only) | Cost saving; acceptable for dev |
| Test | 1 (in AZ-a only) | Cost saving; acceptable for test |
| Prod | 3 (one per AZ) | HA; avoids cross-AZ NAT traffic |

---

## 5. Route Tables

### Public Subnet Route Table

| Destination | Target |
|---|---|
| 10.x.0.0/16 | Local |
| 0.0.0.0/0 | Internet Gateway |

### Private Subnet Route Table (per AZ)

| Destination | Target |
|---|---|
| 10.x.0.0/16 | Local |
| 0.0.0.0/0 | NAT Gateway (in same AZ for prod; AZ-a for dev/test) |
| (service-specific) | VPC Endpoint |

---

## 6. VPC Endpoints

VPC Endpoints reduce reliance on NAT Gateway and improve security by keeping traffic within the AWS network.

| Service | Endpoint Type | Purpose |
|---|---|---|
| Amazon ECR (API) | Interface | Container image pulls |
| Amazon ECR (DKR) | Interface | Container image pulls |
| Amazon S3 | Gateway | Terraform state, ECR layer storage |
| AWS Secrets Manager | Interface | Runtime secrets for pods |
| AWS Systems Manager | Interface | Session Manager, SSM agent |
| Amazon CloudWatch Logs | Interface | Log delivery from nodes and pods |
| AWS KMS | Interface | Key operations for encryption |
| Amazon STS | Interface | IRSA token exchange |

---

## 7. DNS

### VPC DNS Configuration

- `enableDnsHostnames`: true
- `enableDnsSupport`: true

### Route 53

- Optional: Route 53 hosted zones for internal service discovery
- Public hosted zone for external DNS (if using Route 53 as DNS provider)
- Private hosted zone for internal service endpoints

### CoreDNS

- Cluster DNS provided by CoreDNS (EKS managed add-on)
- Default cluster domain: `cluster.local`
- External DNS resolution via VPC DNS resolver (not the EKS add-on)

### External DNS (Optional)

The [External DNS](https://github.com/kubernetes-sigs/external-dns) controller can be deployed to automatically manage Route 53 records from Kubernetes Ingress/Service annotations.

---

## 8. Security Groups

### Security Group Architecture

```
Internet
    │
    ▼
[ALB Security Group]
    │ (outbound to Node SG)
    ▼
[EKS Node Security Group]
    │ (internal communication)
    ▼
[EKS Control Plane Security Group]
```

### ALB Security Group

| Direction | Protocol | Port | Source/Dest | Purpose |
|---|---|---|---|---|
| Inbound | TCP | 443 | 0.0.0.0/0 | HTTPS from internet |
| Inbound | TCP | 80 | 0.0.0.0/0 | HTTP (redirect to HTTPS) |
| Outbound | All | All | EKS Node SG | Traffic to pods |

### EKS Node Security Group

| Direction | Protocol | Port | Source/Dest | Purpose |
|---|---|---|---|---|
| Inbound | All | All | Self | Node-to-node communication |
| Inbound | TCP | 1025-65535 | Control Plane SG | API server to nodes |
| Inbound | TCP | 443 | Control Plane SG | Webhooks |
| Inbound | All | All | ALB SG | Traffic from ALB |
| Outbound | All | All | 0.0.0.0/0 | Outbound (via NAT) |

### EKS Control Plane Security Group

| Direction | Protocol | Port | Source/Dest | Purpose |
|---|---|---|---|---|
| Inbound | TCP | 443 | Node SG | Nodes to API server |
| Outbound | TCP | 1025-65535 | Node SG | API server to kubelets |
| Outbound | TCP | 443 | Node SG | API server to webhooks |

---

## 9. Pod Networking

### AWS VPC CNI

The platform uses the AWS VPC CNI plugin for pod networking:

- Each pod receives a real VPC IP address from the subnet CIDR
- Pods can communicate with other VPC resources natively
- Security Groups for Pods (SGP) is supported for fine-grained network control
- IPv4 is used by default; IPv6 can be enabled if required

### IP Address Planning Considerations

With AWS VPC CNI, each node consumes IPs for both the node itself and all pods scheduled on it. For example:
- m5.xlarge: max 58 pods, consuming up to 58 VPC IPs
- Ensure subnets are sized appropriately for max node count × max pods per node

### Network Policies

Kubernetes Network Policies are enforced using the **AWS Network Policy Controller** (available from EKS 1.25+), or Calico as an alternative. See [kubernetes/network-policies/](../../kubernetes/network-policies/) for policy templates.

---

## 10. VPC Flow Logs

VPC Flow Logs are enabled for all environments:

| Parameter | Value |
|---|---|
| Traffic type | ALL (accept + reject) |
| Destination | CloudWatch Logs |
| Log group | `/aws/vpc/flow-logs/{env}` |
| Retention | 90 days (dev/test), 365 days (prod) |
| Format | Custom (includes vpc-id, az-id, instance-id) |

---

## 11. Connectivity Patterns

### Pattern A — Single VPC (Current Design)

All environments in the same account share no VPC. Each environment has its own VPC. This is the default pattern for this repository.

### Pattern B — VPC Peering (Optional)

If cross-environment connectivity is required (e.g., shared services):

```
Dev VPC ←──── Peering ────→ Shared Services VPC
Test VPC ←─── Peering ────→ Shared Services VPC
Prod VPC ←─── Peering ────→ Shared Services VPC
```

### Pattern C — AWS Transit Gateway (Future)

For large-scale multi-VPC connectivity, AWS Transit Gateway provides a hub-and-spoke model.

---

## 12. Related Documents

- [High-Level Design](high-level-design.md)
- [Low-Level Design](low-level-design.md)
- [Security Design](../security/security-design.md)
