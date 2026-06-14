# Cost Optimization Guide

## Document Information

| Field | Value |
|---|---|
| Document Type | Cost Optimization Guide |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This guide provides cost optimization strategies for the AWS EKS platform. It covers compute, networking, storage, and operational practices aligned with the AWS Well-Architected Cost Optimization pillar.

---

## 2. Compute Optimization

### 2.1 Spot Instances for Non-Production

| Environment | Instance Strategy | Estimated Saving |
|---|---|---|
| Dev | 100% Spot | ~70% vs On-Demand |
| Test | 100% Spot | ~70% vs On-Demand |
| Prod | On-Demand (general) + Spot (batch/stateless) | ~30–50% on mixed |

Spot configuration in Managed Node Groups:
```hcl
capacity_type = "SPOT"
instance_types = ["m5.large", "m5.xlarge", "m4.large", "m4.xlarge"]
# Multiple instance types improve Spot availability
```

Use the AWS Node Termination Handler to gracefully handle Spot interruptions.

### 2.2 Right-Sizing

- Use Container Insights and CloudWatch metrics to identify over-provisioned pods
- Review CPU/memory utilisation weekly for production workloads
- Set Kubernetes resource requests accurately — these drive scheduling and autoscaling decisions
- Use Vertical Pod Autoscaler (VPA) in recommendation mode to suggest right-sized requests

### 2.3 Cluster Autoscaler

- Configure scale-down delay appropriately (`--scale-down-delay-after-add=10m`)
- Enable `--balance-similar-node-groups` to prevent uneven scaling
- Review autoscaler logs for scale-up/down patterns to identify inefficiencies

### 2.4 Instance Type Selection

| Workload Type | Recommended Instance | Reason |
|---|---|---|
| General purpose | m5.xlarge, m6i.xlarge | Balanced CPU/memory |
| Memory intensive | r5.large, r6i.large | Higher memory ratio |
| Compute intensive | c5.xlarge, c6i.xlarge | Higher CPU ratio |
| Cost-conscious | t3.large (dev/test) | Burstable; cheaper |

---

## 3. Networking Optimization

### 3.1 NAT Gateway

NAT Gateway charges per GB of data processed:

| Strategy | Application |
|---|---|
| Single NAT per environment (non-prod) | Dev/Test — acceptable; saves ~2x NAT cost |
| One NAT per AZ (prod) | Prod — necessary for HA; cross-AZ NAT avoided |
| VPC Endpoints | Eliminate NAT charges for AWS service traffic |

High-value VPC Endpoints to implement:
- S3 (Gateway — free)
- ECR API + DKR (Interface)
- Secrets Manager (Interface)
- CloudWatch Logs (Interface)
- SSM (Interface)

### 3.2 Data Transfer

- Keep EKS nodes in the same AZ as their primary data sources
- Use pod topology spread to distribute pods across AZs, reducing cross-AZ traffic
- Enable CloudWatch Logs agent log compression

---

## 4. Storage Optimization

### 4.1 ECR Lifecycle Policies

Implement lifecycle policies to remove unused images:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Remove untagged images after 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Keep last 20 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": { "type": "expire" }
    }
  ]
}
```

### 4.2 CloudWatch Logs Retention

Set appropriate log retention periods:

| Log Group | Dev | Test | Prod |
|---|---|---|---|
| EKS control plane logs | 7 days | 30 days | 90 days |
| Application logs | 7 days | 30 days | 90 days |
| VPC flow logs | 7 days | 30 days | 365 days |

### 4.3 EBS Volumes

- Delete EBS volumes when node groups are deleted (default for managed node groups)
- Use gp3 (not gp2) for better cost-performance ratio
- Enable EBS volume encryption with KMS (minimal performance impact)

---

## 5. Operational Cost Reduction

### 5.1 Jenkins Cost

- Use dynamic Jenkins agents (Kubernetes plugin) — agents terminate after use
- Schedule non-prod EKS clusters to scale to zero overnight (Cluster Autoscaler)
- Consider AWS Fargate for Jenkins agents (serverless; pay per job duration)

### 5.2 Development Environment Scheduling

Automate dev/test cluster scale-down outside business hours:

```bash
# Scale to zero (morning scale-up handled by Cluster Autoscaler)
# Runs via Lambda or Systems Manager Automation

aws eks update-nodegroup-config \
  --cluster-name eks-platform-dev \
  --nodegroup-name general \
  --scaling-config minSize=0,maxSize=5,desiredSize=0
```

### 5.3 Removing Idle Resources

Implement tagging policies to identify and review idle resources:
- Unused ECR repositories (no pushes in 90 days)
- Old EBS snapshots
- Unused Elastic IPs
- CloudWatch Log groups with zero ingestion

---

## 6. Cost Visibility

### 6.1 AWS Cost Allocation Tags

All resources must include cost allocation tags:
- `Project`
- `Environment`
- `Team`
- `CostCentre`

Enable these tags in AWS Cost Explorer for cost breakdown.

### 6.2 AWS Cost Explorer

Recommended Cost Explorer views:
- Monthly cost by environment tag
- Monthly cost by service
- Cost trend by team/project
- Savings Plans and Reserved Instance coverage

### 6.3 AWS Budgets

Create budget alerts for each environment:

| Environment | Monthly Budget | Alert Threshold |
|---|---|---|
| Dev | £500 | 80% |
| Test | £500 | 80% |
| Prod | £5,000 | 80% |

---

## 7. Savings Plans and Reserved Instances

For production On-Demand instances:

| Option | Commitment | Saving |
|---|---|---|
| Compute Savings Plan | 1 year, no upfront | ~20–40% |
| EC2 Instance Savings Plan | 1 year, no upfront | ~30–40% |
| Reserved Instances | 1 year, no upfront | ~30–40% |

Recommendation: After 3 months of production usage, analyse On-Demand spend and purchase appropriate Savings Plans.

---

## 8. Well-Architected Cost Optimization Checklist

- [ ] Spot instances used for dev/test node groups
- [ ] Cluster Autoscaler enabled and tuned
- [ ] Resource requests/limits set on all pods
- [ ] ECR lifecycle policies implemented
- [ ] VPC Endpoints deployed for high-traffic AWS services
- [ ] CloudWatch log retention policies set
- [ ] Cost allocation tags applied to all resources
- [ ] AWS Budgets configured with alerts
- [ ] Monthly cost review process established
- [ ] Dev/test environment scale-down schedule implemented

---

## 9. Related Documents

- [Low-Level Design](low-level-design.md)
- [EKS Platform Design](eks-platform-design.md)
- [Well-Architected Assessment](well-architected-assessment.md)
