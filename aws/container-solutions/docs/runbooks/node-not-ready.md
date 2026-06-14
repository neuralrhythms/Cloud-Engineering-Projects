# Runbook: Node NotReady

## Purpose

Diagnose and resolve EKS worker nodes stuck in `NotReady` state.

---

## 1. Identify the Problem

```bash
# List all nodes and their status
kubectl get nodes

# Get details on the NotReady node
kubectl describe node <node-name>

# Look for conditions at the bottom of the describe output
# Common conditions: MemoryPressure, DiskPressure, PIDPressure, NetworkUnavailable
```

---

## 2. Common Causes and Fixes

### Cause A — kubelet not running on the node

**Symptoms:** Node shows `NotReady`; `kubectl describe node` shows `KubeletNotReady`

**Fix:**
```bash
# Get the instance ID
INSTANCE_ID=$(kubectl get node <node-name> \
  -o jsonpath='{.spec.providerID}' | cut -d/ -f5)

# Connect via SSM Session Manager (no SSH key needed)
aws ssm start-session --target $INSTANCE_ID

# On the node — check kubelet status
sudo systemctl status kubelet
sudo journalctl -u kubelet --since "10 minutes ago"

# Restart kubelet if stopped
sudo systemctl restart kubelet
```

---

### Cause B — Disk pressure

**Symptoms:** `conditions: DiskPressure=True`

**Fix:**
```bash
# Check disk usage on the node
kubectl exec -n kube-system $(kubectl get pod -n kube-system \
  -l k8s-app=aws-node -o name | head -1) -- df -h

# Clean up unused images (via SSM on the node)
sudo docker system prune -af   # If using Docker
sudo crictl rmi --prune        # If using containerd
```

**Prevent:** Ensure node disk size is adequate (100GB recommended for production).
Review ECR lifecycle policies to limit pulled image count.

---

### Cause C — Memory pressure

**Symptoms:** `conditions: MemoryPressure=True`; pods being evicted

**Fix:**
```bash
# Check which pods are consuming the most memory
kubectl top pods --all-namespaces --sort-by=memory | head -20

# Check for pods without memory limits (they can consume unbounded memory)
kubectl get pods --all-namespaces -o json | \
  jq '.items[] | select(.spec.containers[].resources.limits.memory == null) | .metadata.name'
```

**Prevent:** Enforce memory limits via LimitRange and ResourceQuota on namespaces.

---

### Cause D — Network plugin issue (VPC CNI)

**Symptoms:** `NetworkUnavailable=True`; pods fail with network errors

**Fix:**
```bash
# Check VPC CNI pod on the affected node
kubectl get pods -n kube-system -l k8s-app=aws-node -o wide | grep <node-name>

# Describe the aws-node pod on that node
kubectl describe pod <aws-node-pod> -n kube-system

# Check VPC CNI logs
kubectl logs <aws-node-pod> -n kube-system -c aws-node

# Restart VPC CNI pod on the node
kubectl delete pod <aws-node-pod> -n kube-system
```

---

### Cause E — Node failed health check (auto-replaced by EKS)

For **Managed Node Groups**, AWS will automatically detect and replace unhealthy nodes.

If the node is not being replaced:
```bash
# Check node group health
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --query 'nodegroup.health'

# Trigger instance replacement manually
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id $INSTANCE_ID \
  --should-decrement-desired-capacity false
```

---

## 3. If Node Cannot Be Recovered

```bash
# Cordon the node to prevent new scheduling
kubectl cordon <node-name>

# Drain all pods off the node
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=120s

# Terminate the EC2 instance (ASG will launch a replacement)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Verify replacement node becomes Ready
kubectl get nodes -w
```

---

## 4. Post-Recovery Checks

```bash
# All nodes Ready
kubectl get nodes

# No pending pods
kubectl get pods --all-namespaces | grep Pending

# Verify autoscaler is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler
```

---

## Related

- [Cluster Health Check](cluster-health-check.md)
- [Node Patching Strategy](../operations/node-patching-strategy.md)
