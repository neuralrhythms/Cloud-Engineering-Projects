# Runbook: Security Incident Response

## Purpose

Procedure for responding to security incidents on the EKS platform, including GuardDuty findings, suspected breaches, and container escapes.

---

## Severity Classification

| Severity | Examples | Response Time |
|---|---|---|
| Critical | Active breach, data exfiltration confirmed | 15 minutes |
| High | GuardDuty High finding, suspected credential compromise | 1 hour |
| Medium | Security misconfiguration, policy violation | 24 hours |
| Low | Informational finding | 1 week |

---

## 1. Initial Response

### 1.1 Confirm the Incident

```bash
# Check GuardDuty findings
aws guardduty list-findings \
  --detector-id {detector-id} \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7}}}'

# Get finding details
aws guardduty get-findings \
  --detector-id {detector-id} \
  --finding-ids {finding-id}

# Check Security Hub
aws securityhub get-findings \
  --filters '{"SeverityLabel":[{"Value":"HIGH","Comparison":"EQUALS"}]}'
```

### 1.2 Notify the Team

- Notify Platform Engineering Lead
- Notify Security Lead
- Open incident channel (Slack/Teams: `#incident-{date}`)
- Begin incident log

---

## 2. Containment

### 2.1 Isolate Suspicious Pod

```bash
# Apply network isolation policy to suspected pod
# (Deny all ingress and egress)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-suspected-pod
  namespace: {namespace}
spec:
  podSelector:
    matchLabels:
      {label-selector}
  policyTypes:
    - Ingress
    - Egress
EOF

# Optionally delete the pod if compromise confirmed
kubectl delete pod {pod-name} -n {namespace}
```

### 2.2 Revoke Compromised Credentials

If IRSA credentials are compromised:
```bash
# Deny the specific IAM role
aws iam put-role-policy \
  --role-name {compromised-role} \
  --policy-name emergency-deny \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'
```

### 2.3 Block Suspicious IP

```bash
# Add deny rule to security group
aws ec2 authorize-security-group-ingress \
  --group-id {sg-id} \
  --protocol all \
  --source {suspicious-ip}/32
# Note: Security Group rules are ALLOW rules; use Network ACL for DENY
aws ec2 create-network-acl-entry \
  --network-acl-id {nacl-id} \
  --rule-number 1 \
  --protocol -1 \
  --rule-action deny \
  --cidr-block {suspicious-ip}/32 \
  --ingress
```

---

## 3. Investigation

### 3.1 Collect Evidence

```bash
# Pod logs (capture before deletion)
kubectl logs {pod-name} -n {namespace} > /tmp/pod-{name}-logs.txt

# Pod describe (shows events, mounts, env vars)
kubectl describe pod {pod-name} -n {namespace} > /tmp/pod-{name}-describe.txt

# Container processes
kubectl exec {pod-name} -n {namespace} -- ps aux

# Container network connections
kubectl exec {pod-name} -n {namespace} -- netstat -tulpn
```

### 3.2 CloudTrail Investigation

```bash
# Find API calls from suspected IAM role (last 24 hours)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue={role-name} \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
  --query 'Events[*].{Time:EventTime,Event:EventName,User:Username,IP:Resources}'
```

### 3.3 VPC Flow Log Investigation

Query in CloudWatch Logs Insights:
```
fields @timestamp, srcAddr, dstAddr, dstPort, action, bytes
| filter srcAddr like "10.2.10."
| filter action = "REJECT"
| sort @timestamp desc
| limit 100
```

### 3.4 EKS Audit Log Investigation

```bash
# Query EKS audit logs in CloudWatch Logs Insights
# Log group: /aws/eks/{cluster}/cluster

fields @timestamp, verb, objectRef.resource, user.username, sourceIPs.0
| filter @logStream = "kube-apiserver-audit"
| filter user.username like "suspicious-user"
| sort @timestamp desc
| limit 50
```

---

## 4. Eradication

- Remove malicious code or compromised containers
- Rotate all potentially exposed credentials
- Re-deploy affected workloads from clean images
- Apply security patches if vulnerability exploited
- Remove any backdoors or persistence mechanisms

---

## 5. Recovery

- Re-enable isolated resources after investigation completes
- Validate all systems operational
- Confirm no residual access by threat actor
- Resume normal operations

---

## 6. Post-Incident

### 6.1 Root Cause Analysis

RCA document must include:
- Timeline of events
- Root cause identification
- Impact assessment
- Immediate containment actions taken
- Remediation actions completed
- Preventive measures to avoid recurrence

### 6.2 Remediation Actions

Typical actions:
- Patch CVE that enabled the incident
- Tighten IAM policies
- Add network policy to prevent lateral movement
- Add CloudWatch Alarm for early detection
- Update this runbook with lessons learned

---

## Related

- [Security Design](../security/security-design.md)
- [Cluster Health Check](cluster-health-check.md)
- [GuardDuty Documentation](https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html)
