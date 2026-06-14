# Runbook: Cluster Health Check

## Purpose

Routine health check procedure for the EKS cluster. Run daily or when investigating platform issues.

---

## 1. Node Health

```bash
# All nodes should be in Ready state
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-2-10-xxx.compute...    Ready    <none>   5d    v1.30.x

# Describe any node in NotReady state
kubectl describe node {node-name}

# Check node conditions
kubectl get nodes -o json | jq '.items[].status.conditions'
```

---

## 2. System Pod Health

```bash
# All kube-system pods should be Running
kubectl get pods -n kube-system

# All platform pods should be Running
kubectl get pods -n platform-system

# Check for any pods in CrashLoopBackOff or Error state
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
```

---

## 3. EKS Control Plane

```bash
# Check EKS cluster status
aws eks describe-cluster \
  --name {cluster-name} \
  --query 'cluster.status'
# Expected: ACTIVE

# Check EKS add-on status
aws eks list-addons --cluster-name {cluster-name}
aws eks describe-addon --cluster-name {cluster-name} --addon-name vpc-cni
# Expected: ACTIVE
```

---

## 4. Cluster Autoscaler

```bash
# Check autoscaler pod
kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler

# Check autoscaler logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler --tail=50

# Check for scale-up events
kubectl get events -n kube-system | grep -i scale
```

---

## 5. Ingress / Load Balancer

```bash
# Check ALB controller pod
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# List all Ingresses
kubectl get ingress --all-namespaces
```

---

## 6. Resource Utilisation

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage (top consumers)
kubectl top pods --all-namespaces --sort-by=cpu | head -20
kubectl top pods --all-namespaces --sort-by=memory | head -20
```

---

## 7. Recent Events

```bash
# Cluster-wide warning events
kubectl get events --all-namespaces --field-selector type=Warning

# Recent events (last hour)
kubectl get events --all-namespaces \
  --sort-by='.lastTimestamp' | tail -30
```

---

## 8. CloudWatch Health

Check CloudWatch Container Insights dashboard in the AWS console:
- Node CPU utilisation < 80%
- Node memory utilisation < 85%
- No pending pods > 0 for > 10 minutes
- No active alarms

---

## Health Check Pass Criteria

| Check | Expected | Action if Failed |
|---|---|---|
| All nodes Ready | ✅ | See [Node NotReady runbook](node-not-ready.md) |
| No CrashLoopBackOff pods | ✅ | Investigate pod logs |
| EKS cluster ACTIVE | ✅ | Contact AWS Support |
| All add-ons ACTIVE | ✅ | Re-deploy add-on |
| Autoscaler pod Running | ✅ | Redeploy autoscaler |
| No Warning events (critical) | ✅ | Investigate event details |
