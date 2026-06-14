# Helm Deployment Standards

## Document Information

| Field | Value |
|---|---|
| Document Type | Engineering Standards |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This document defines standards for creating, managing, and deploying Helm charts within the EKS platform. All application teams deploying to EKS must follow these standards.

---

## 2. Chart Structure

Every Helm chart must follow this standard structure:

```
{chart-name}/
├── Chart.yaml            # Chart metadata
├── values.yaml           # Default values
├── values.schema.json    # (Recommended) JSON Schema for values validation
├── .helmignore           # Files to exclude from packaging
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── serviceaccount.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── configmap.yaml    # (if required)
│   ├── secret.yaml       # (if required — prefer External Secrets)
│   ├── networkpolicy.yaml
│   ├── NOTES.txt
│   └── _helpers.tpl      # Template helpers
└── README.md
```

---

## 3. Chart.yaml Requirements

```yaml
apiVersion: v2
name: my-app
description: A Helm chart for My Application
type: application
version: 1.0.0           # Chart version (semantic versioning)
appVersion: "1.0.0"      # Application version (matches container image tag)
maintainers:
  - name: Platform Engineering
    email: platform@example.com
keywords:
  - myapp
```

---

## 4. values.yaml Standards

### Required Top-Level Keys

```yaml
# values.yaml

# -- Replica count (overridden by HPA in production)
replicaCount: 2

image:
  # -- Container image repository
  repository: "123456789012.dkr.ecr.eu-west-1.amazonaws.com/my-app"
  # -- Container image pull policy
  pullPolicy: IfNotPresent
  # -- Container image tag (overridden by CI/CD pipeline)
  tag: "latest"

serviceAccount:
  # -- Create a service account
  create: true
  # -- Annotations on the service account (e.g., for IRSA)
  annotations: {}
  # -- Service account name override
  name: ""

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: false
  className: "alb"
  annotations: {}
  hosts: []
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 1

livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5

# -- Pod-level security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
  seccompProfile:
    type: RuntimeDefault

# -- Container-level security context
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

# -- Environment variables
env: {}

# -- Node selector
nodeSelector: {}

# -- Tolerations
tolerations: []

# -- Affinity rules
affinity: {}

# -- Topology spread constraints
topologySpreadConstraints: []
```

---

## 5. Environment-Specific Values

Per-environment overrides are stored in:

```
helm/environments/
├── dev/
│   └── {chart-name}.yaml
├── test/
│   └── {chart-name}.yaml
└── prod/
    └── {chart-name}.yaml
```

Example `helm/environments/prod/my-app.yaml`:

```yaml
replicaCount: 5

image:
  tag: "abc123f-42"   # Set by CI/CD pipeline

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20

ingress:
  enabled: true
  hosts:
    - host: my-app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - my-app.example.com

resources:
  limits:
    cpu: "2"
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: my-app
```

---

## 6. Deployment Template Standards

### Required Template Labels

All templates must include the standard Kubernetes recommended labels:

```yaml
labels:
  {{- include "my-app.labels" . | nindent 4 }}

# In _helpers.tpl:
{{- define "my-app.labels" -}}
helm.sh/chart: {{ include "my-app.chart" . }}
{{ include "my-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "my-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### Security Context Requirements

All Deployments must include pod and container security contexts (see `values.yaml` defaults above):

- `runAsNonRoot: true`
- `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`
- `capabilities.drop: [ALL]`
- `seccompProfile.type: RuntimeDefault`

### Resource Limits

Every container must define both requests and limits. Charts without resource definitions will fail validation in the CI pipeline.

---

## 7. PodDisruptionBudget

Every production deployment must have a PodDisruptionBudget:

```yaml
# templates/pdb.yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "my-app.fullname" . }}
spec:
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  selector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
{{- end }}
```

---

## 8. Helm Deployment Command Standards

### Dev / Test (Auto Deploy)

```bash
helm upgrade --install {release-name} ./helm/{chart-name} \
  --namespace {namespace} \
  --create-namespace \
  --values helm/{chart-name}/values.yaml \
  --values helm/environments/{env}/{chart-name}.yaml \
  --set image.tag={image-tag} \
  --wait \
  --timeout 5m
```

### Production (Atomic with Rollback)

```bash
helm upgrade --install {release-name} ./helm/{chart-name} \
  --namespace {namespace} \
  --values helm/{chart-name}/values.yaml \
  --values helm/environments/prod/{chart-name}.yaml \
  --set image.tag={image-tag} \
  --atomic \
  --timeout 10m \
  --cleanup-on-fail
```

### Rollback

```bash
helm rollback {release-name} {revision} \
  --namespace {namespace} \
  --wait
```

---

## 9. Helm Diff for Change Preview

Before deploying, use the Helm diff plugin to preview changes:

```bash
helm diff upgrade {release-name} ./helm/{chart-name} \
  --namespace {namespace} \
  --values helm/{chart-name}/values.yaml \
  --values helm/environments/prod/{chart-name}.yaml \
  --set image.tag={new-image-tag}
```

Include diff output in the Jenkins pipeline approval step.

---

## 10. Chart Versioning

- Chart `version` in `Chart.yaml` follows semantic versioning
- `appVersion` tracks the application release version
- Charts are versioned independently of the application
- Chart version is bumped:
  - **Patch**: bug fix in templates, no new features
  - **Minor**: new optional feature added (backward compatible)
  - **Major**: breaking change in values or template structure

---

## 11. Linting and Validation

All charts must pass:

```bash
helm lint ./helm/{chart-name}
helm lint ./helm/{chart-name} --values helm/environments/prod/{chart-name}.yaml
helm template ./helm/{chart-name} | kubectl apply --dry-run=client -f -
```

CI pipeline runs these checks on every PR.

---

## 12. Related Documents

- [EKS Platform Design](eks-platform-design.md)
- [CI/CD Design](cicd-design.md)
- [Helm Charts](../../helm/)
