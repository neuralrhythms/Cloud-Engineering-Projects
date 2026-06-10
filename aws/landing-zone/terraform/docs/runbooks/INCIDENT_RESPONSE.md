# Security Incident Response Runbook

## Overview

This runbook provides guidance for responding to security findings detected by the landing zone security services.

## Severity Classification

| Severity | Source | Example | Response Time |
|----------|--------|---------|--------------|
| Critical | GuardDuty HIGH | Compromised credentials, crypto mining | Immediate (< 1 hour) |
| High | SecurityHub CRITICAL | Public S3 bucket with sensitive data | < 4 hours |
| Medium | GuardDuty MEDIUM | Unusual API activity | < 24 hours |
| Low | Config non-compliant | Missing tags, non-encrypted volume | < 1 week |

## Immediate Actions for Critical Findings

### 1. Isolate the Resource

For compromised EC2 instances:
```bash
# Replace security group with isolation SG (no inbound/outbound)
aws ec2 modify-instance-attribute \
  --instance-id i-xxx \
  --groups sg-isolation
```

For compromised IAM credentials:
```bash
# Deactivate access keys
aws iam update-access-key --access-key-id AKIAXX --status Inactive --user-name xxx

# Revoke all sessions for the role
aws iam put-role-policy --role-name xxx --policy-name RevokeOlderSessions --policy-document file://revoke.json
```

### 2. Preserve Evidence

- Enable VPC Flow Logs if not already enabled
- Take EBS snapshots of affected instances
- Export CloudTrail logs for the time period
- Screenshot Security Hub findings

### 3. Investigate

Check CloudTrail for the affected principal:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=xxx \
  --start-time "2024-01-01T00:00:00Z"
```

### 4. Remediate

- Rotate affected credentials
- Patch vulnerable systems
- Update SCPs/IAM policies to prevent recurrence

### 5. Post-Incident

- Document findings and timeline
- Update detection rules if gap identified
- Conduct lessons learned session

## Contacts

| Role | Team | Escalation |
|------|------|-----------|
| Security On-Call | @security-team | PagerDuty |
| Platform Engineering | @platform-team | Slack #platform-incidents |
| Management | CISO | Email + Phone |
