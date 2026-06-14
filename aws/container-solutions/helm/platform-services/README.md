# Platform Services Helm Charts

This directory contains Helm chart configurations for platform-level components deployed into the EKS cluster.

These are **not application charts** — they are infrastructure components managed by the Platform Engineering team.

## Components

| Component | Chart Source | Namespace | Purpose |
|---|---|---|---|
| `aws-load-balancer-controller` | `eks/aws-load-balancer-controller` | `kube-system` | Provisions ALB/NLB from Ingress/Service resources |
| `cluster-autoscaler` | `autoscaler/cluster-autoscaler` | `kube-system` | Scales node groups based on pending pods |
| `metrics-server` | `metrics-server/metrics-server` | `kube-system` | CPU/memory metrics for HPA |
| `external-secrets` | `external-secrets/external-secrets` | `platform-system` | Syncs secrets from AWS Secrets Manager |

## Deployment

Platform services are deployed via the infrastructure CD pipeline, not the application pipeline.

### AWS Load Balancer Controller

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --values aws-load-balancer-controller/values.yaml \
  --values aws-load-balancer-controller/values-{env}.yaml
```

### Cluster Autoscaler

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --values cluster-autoscaler/values.yaml \
  --values cluster-autoscaler/values-{env}.yaml
```

### External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace platform-system \
  --create-namespace \
  --values external-secrets/values.yaml
```

## Version Pinning

All platform service chart versions are pinned. Never use `--devel` or floating versions in production.

Version pins are maintained in each component's `values.yaml` and updated via the upgrade pipeline.
