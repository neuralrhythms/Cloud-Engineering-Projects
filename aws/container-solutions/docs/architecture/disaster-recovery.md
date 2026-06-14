# Disaster Recovery Strategy

## Document Information

| Field | Value |
|---|---|
| Document Type | Disaster Recovery Strategy |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This document defines the Disaster Recovery (DR) strategy for the AWS EKS platform. It covers recovery objectives, failure scenarios, recovery procedures, and testing requirements.

---

## 2. Recovery Objectives

| Environment | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) |
|---|---|---|
| Production | 4 hours | 1 hour |
| Test | 24 hours | 24 hours |
| Dev | Best effort | 24 hours |

> RTO and RPO targets must be validated with stakeholders and agreed contractually where required.

---

## 3. DR Strategy Classification

This platform follows an **Infrastructure-as-Code Re-provision** DR strategy:

- AWS infrastructure is fully reproducible from Terraform code in Git
- Kubernetes workloads are reproducible from Helm charts in Git
- Data persistence is handled by the application layer (external to EKS)
- Container images are stored in ECR (regional service; regionally durable)

DR Category: **Backup and Restore / Warm Standby**

---

## 4. Failure Scenarios and Recovery Procedures

### 4.1 EKS Control Plane Failure

**Responsibility:** AWS (managed service)

- EKS control plane is managed by AWS and runs across multiple AZs
- AWS SLA: 99.95% monthly uptime
- Recovery: AWS automatically recovers the control plane

**Platform team actions:**
- Monitor CloudWatch for `APIServerErrors` metric
- Open AWS Support case if recovery exceeds 30 minutes

---

### 4.2 Worker Node AZ Failure

**Scenario:** An entire Availability Zone becomes unavailable.

**Recovery:**
1. Cluster Autoscaler will detect unschedulable pods
2. New nodes will be provisioned in remaining AZs
3. Pods will reschedule onto healthy nodes (within minutes, assuming sufficient capacity in remaining AZs)

**Pre-requisites:**
- Multi-AZ node groups configured
- Topology spread constraints or pod anti-affinity on critical workloads

**Recovery time:** Minutes (automated)

---

### 4.3 Full Cluster Loss (Terraform State Available)

**Scenario:** EKS cluster is accidentally deleted or becomes unrecoverable.

**Recovery Procedure:**

```
Step 1: Verify Terraform state in S3 is intact
Step 2: Run Terraform plan to confirm state vs reality
Step 3: Run Terraform apply to recreate cluster
Step 4: Restore aws-auth ConfigMap / EKS Access Entries
Step 5: Redeploy platform Helm charts (ALB controller, autoscaler, etc.)
Step 6: Redeploy application Helm charts from Git
Step 7: Validate cluster health and application availability
Step 8: Update DNS (if required)
```

**Estimated RTO:** 2–4 hours

---

### 4.4 Terraform State Loss

**Scenario:** Terraform state file in S3 is corrupted or deleted.

**Mitigations:**
- S3 versioning enabled on state bucket
- MFA Delete enabled on state bucket (production)
- Daily S3 replication to secondary bucket (optional)

**Recovery:**
1. Restore from S3 versioned backup
2. Run `terraform import` for resources not recoverable from state
3. Validate state with `terraform plan` (expect no changes after import)

---

### 4.5 AWS Region-Level Failure

**Scenario:** Primary AWS region is unavailable.

**Strategy:** This platform is single-region by default. A full region failure requires a pre-built DR region.

**For organisations requiring cross-region DR:**

| Component | DR Strategy |
|---|---|
| Terraform code | Already in Git; deploy to DR region |
| Container images | ECR replication to DR region |
| Kubernetes manifests | Re-apply from Git |
| Application data | Application team responsibility (RDS read replica, DynamoDB global tables, etc.) |
| DNS | Route 53 health checks + failover routing policy |

**DR Region Activation:**

```
Step 1: Declare a DR event; notify stakeholders
Step 2: Bootstrap Terraform state in DR region
Step 3: Run Terraform apply in DR region
Step 4: Redeploy platform services via Helm
Step 5: Redeploy applications with images from replicated ECR
Step 6: Update Route 53 failover records to DR region
Step 7: Validate DR environment
```

---

### 4.6 CI/CD System (Jenkins) Failure

**Recovery:**
- Jenkins configuration is stored as code (JCasC — Jenkins Configuration as Code)
- Agent images are stored in ECR
- Pipelines defined as Jenkinsfiles in Git
- Jenkins home directory backed up to S3 (daily)

**Recovery Procedure:**
1. Provision new Jenkins instance (EC2 or EKS pod)
2. Restore Jenkins home from S3 backup or apply JCasC
3. Reconnect agents
4. Verify pipelines are accessible

---

## 5. Data Backup Summary

| Component | Backup Method | Frequency | Retention | Recovery Process |
|---|---|---|---|---|
| Terraform state | S3 versioning | Continuous | 90 days | S3 restore |
| ECR images | Regional service (durable) | On push | Per lifecycle policy | N/A |
| Jenkins home | S3 backup | Daily | 30 days | Restore from S3 |
| EKS etcd | AWS managed | Continuous | AWS managed | Cluster restore |
| Application data | Application team | Application-defined | Application-defined | Application-defined |

---

## 6. DR Testing Requirements

DR procedures must be tested regularly:

| Test Type | Frequency | Scope |
|---|---|---|
| Cluster recreation test | Quarterly | Dev environment |
| AZ failover simulation | Semi-annually | Test environment |
| Jenkins recovery test | Semi-annually | Dev Jenkins instance |
| Terraform state restore | Annually | Dev environment |
| Full DR exercise | Annually | Production (off-hours) |

### Test Documentation

Each DR test must produce:
- Test plan (pre-test)
- Test report with actual vs expected RTO/RPO
- Issues log
- Remediation actions

---

## 7. Communication Plan

### Escalation Contacts

| Role | Responsibility | Contact |
|---|---|---|
| Platform Engineering Lead | Technical decision making | — |
| AWS Account Manager | AWS-level issues | — |
| Security Lead | Security incidents | — |
| Service Delivery Manager | Stakeholder communication | — |

### Communication Cadence

| Event | Action |
|---|---|
| Incident detected | Notify Platform Lead immediately |
| DR declared | Notify all stakeholders within 15 minutes |
| Every 30 minutes | Status update to stakeholders |
| Incident resolved | RCA within 48 hours |

---

## 8. Related Documents

- [EKS Upgrade Strategy](../operations/eks-upgrade-strategy.md)
- [Operational Runbooks](../runbooks/)
- [High-Level Design](high-level-design.md)
