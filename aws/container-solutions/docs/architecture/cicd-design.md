# CI/CD Design

## Document Information

| Field | Value |
|---|---|
| Document Type | CI/CD Design |
| Status | Draft |
| Version | 1.0 |
| Last Updated | 2025 |
| Author | Platform Engineering |

---

## 1. Purpose

This document describes the CI/CD architecture for the AWS EKS platform. There are two completely separate pipeline families:

1. **Platform Pipelines** — infrastructure lifecycle, EKS upgrades, node patching
2. **Application Pipelines** — application build, container scan, ECR push, Helm deploy

---

## 2. CI/CD Principles

- **Everything as code** — all pipelines defined as Jenkinsfiles in version control
- **Separate concerns** — infrastructure and application pipelines are independent
- **Immutable artefacts** — container images are built once and promoted through environments
- **Manual gates** — Terraform apply and production deployments require human approval
- **Least privilege** — Jenkins uses IAM roles scoped to minimum required permissions
- **Auditability** — all pipeline runs logged; artefacts version-tagged

---

## 3. Jenkins Architecture

### Jenkins Deployment Options

| Option | Description | Recommended For |
|---|---|---|
| EC2-based Jenkins | Jenkins master on EC2, agents on EC2 | Simplest setup; teams already using EC2 |
| EKS-based Jenkins | Jenkins on Kubernetes using Kubernetes plugin | Dynamic agents; better resource utilisation |

### Jenkins on EKS (Recommended)

```
Jenkins Master (Pod in EKS)
    │
    ├── Kubernetes Plugin
    │        │
    │        └── Dynamic Agent Pods (spun up per job)
    │              ├── Terraform agent image
    │              ├── Docker/Kaniko build agent image
    │              └── Helm/kubectl agent image
    │
    └── Persistent Volume (EFS or EBS) for Jenkins home
```

### Agent Images

| Agent Type | Base Image | Tools |
|---|---|---|
| `terraform-agent` | `hashicorp/terraform:1.6` | terraform, aws-cli, tfsec, checkov |
| `build-agent` | `docker:24` or `gcr.io/kaniko-project/executor` | docker/kaniko, aws-cli |
| `deploy-agent` | `bitnami/kubectl:1.30` | kubectl, helm, aws-cli |

---

## 4. Pipeline 1 — Infrastructure Lifecycle Pipeline

### 4.1 Purpose

Manages the full lifecycle of AWS infrastructure provisioned by Terraform:
- Validation, security scanning, planning, applying
- EKS version upgrades
- Managed Node Group updates
- Drift detection
- Platform maintenance

### 4.2 Pipeline Flow

```
┌─────────┐    ┌───────────┐    ┌──────────────┐    ┌──────────┐    ┌─────────────┐    ┌──────────────┐
│  Git    │───▶│ Validate  │───▶│ Security     │───▶│ Terraform│───▶│  Manual     │───▶│  Terraform   │
│  Push   │    │ (fmt/lint)│    │ Scan         │    │ Plan     │    │  Approval   │    │  Apply       │
└─────────┘    └───────────┘    └──────────────┘    └──────────┘    └─────────────┘    └──────────────┘
                                 (tfsec/checkov)                     (prod only)
```

### 4.3 Stage Definitions

#### Stage: Checkout
- Clone the Git repository
- Set build metadata (commit SHA, branch, timestamp)

#### Stage: Terraform Format & Validate
```
terraform fmt -check -recursive
terraform validate
```

#### Stage: Security Scan
```
tfsec .
checkov -d . --framework terraform
```
- Fail on HIGH/CRITICAL findings
- Produce scan report as build artefact

#### Stage: Terraform Init
```
terraform init -backend-config=environments/{env}/backend.hcl
```

#### Stage: Terraform Plan
```
terraform plan -var-file=environments/{env}/terraform.tfvars -out=tfplan
```
- Plan output archived as build artefact
- Summarise add/change/destroy counts in build description

#### Stage: Manual Approval (Production Only)
- Jenkins `input` step
- Shows Terraform plan summary
- Requires approval from `platform-leads` group

#### Stage: Terraform Apply
```
terraform apply tfplan
```
- Only runs after approval for prod
- Auto-applies for dev/test

#### Stage: Post-Apply Validation
- `kubectl get nodes`
- Smoke test of cluster health endpoints
- Notify Slack/Teams on success or failure

### 4.4 Drift Detection Pipeline

Runs on a scheduled basis (e.g., daily):
```
terraform plan -detailed-exitcode
```
- Exit code 2 = drift detected
- Raises an alert (SNS/Slack) with drift summary

---

## 5. Pipeline 2 — Application Delivery Pipeline

### 5.1 Purpose

Builds, scans, and deploys application container images through environments.

### 5.2 Pipeline Flow

```
┌───────┐  ┌──────┐  ┌─────────┐  ┌──────────────┐  ┌──────────┐  ┌──────────────┐  ┌──────────┐
│  Git  │─▶│Build │─▶│ Unit    │─▶│  Container   │─▶│ Push to  │─▶│    Helm      │─▶│  Smoke   │
│  Push │  │ App  │  │  Test   │  │  Scan (Trivy)│  │   ECR    │  │   Deploy     │  │  Test    │
└───────┘  └──────┘  └─────────┘  └──────────────┘  └──────────┘  └──────────────┘  └──────────┘
```

### 5.3 Stage Definitions

#### Stage: Checkout
- Clone application repository
- Set image tag = `{git-short-sha}-{build-number}`

#### Stage: Build Application
- Language-specific build (Maven, Gradle, npm, etc.)
- Unit tests run as part of build

#### Stage: Unit Tests
- Run unit test suite
- Publish JUnit test results
- Fail pipeline on test failures

#### Stage: Build Container Image
- Build using Dockerfile in application repository
- Tag with: `{ECR_REPO_URI}:{image-tag}`
- Use Kaniko for in-cluster builds (no Docker socket required)

#### Stage: Container Vulnerability Scan
```
trivy image --exit-code 1 --severity HIGH,CRITICAL {image}
```
- Fail on HIGH/CRITICAL CVEs
- Produce scan report as build artefact
- Optionally publish to Security Hub

#### Stage: Push to ECR
```
aws ecr get-login-password | docker login --username AWS --password-stdin {ecr-uri}
docker push {ECR_REPO_URI}:{image-tag}
```
- Tag image as `latest` only for main/trunk branch

#### Stage: Helm Package (Optional)
- Package Helm chart with updated image tag
- Push chart to chart repository (e.g., S3 or OCI registry)

#### Stage: Deploy to Dev (Auto)
```
helm upgrade --install {app-name} ./helm/sample-app \
  --namespace {team}-dev \
  --set image.tag={image-tag} \
  --values helm/environments/dev/{app-name}.yaml
```

#### Stage: Deploy to Test (Auto or Manual)
- Similar to dev deployment
- Optionally trigger integration/e2e test suite

#### Stage: Manual Approval — Production
- Shows diff of changes (Helm diff plugin)
- Requires approval from application team lead

#### Stage: Deploy to Prod
```
helm upgrade --install {app-name} ./helm/sample-app \
  --namespace {team}-prod \
  --set image.tag={image-tag} \
  --values helm/environments/prod/{app-name}.yaml \
  --atomic \
  --timeout 5m
```
- `--atomic` rolls back automatically on failure

#### Stage: Smoke Test
- HTTP health check against deployed service
- Verify pod readiness
- Notify on failure with rollback instructions

---

## 6. EKS Upgrade Pipeline

See [EKS Upgrade Strategy](../operations/eks-upgrade-strategy.md) for full procedure.

Pipeline stages:
1. Pre-upgrade health check
2. Update EKS control plane version (Terraform)
3. Update EKS managed add-ons
4. Update Managed Node Groups (rolling)
5. Post-upgrade validation
6. Update platform Helm charts (cluster-autoscaler, ALB controller)

---

## 7. Maintenance Pipelines

### Node Group Refresh Pipeline

Triggers a rolling refresh of Managed Node Group instances (e.g., after AMI update):
```
aws eks update-nodegroup-version \
  --cluster-name {cluster} \
  --nodegroup-name {ng-name} \
  --force
```

### Terraform Drift Detection Pipeline

Scheduled daily; runs `terraform plan` and reports drift.

### Certificate Rotation Pipeline

Rotates EKS cluster certificates (annual or on-demand).

---

## 8. Pipeline Security

| Control | Implementation |
|---|---|
| Credentials | Stored in Jenkins Credential Store (backed by Secrets Manager) |
| IAM Roles | Jenkins agent uses IAM role via instance profile or IRSA |
| Branch protection | Only `main` branch can trigger prod deployments |
| Approval gates | Manual approval required for prod in both pipeline families |
| Secret scanning | Pre-commit hooks and pipeline scan for secrets in code |
| Image provenance | Image tags include commit SHA for full traceability |

---

## 9. Pipeline Folder Structure

```
platform-pipelines/
├── terraform-ci/
│   └── Jenkinsfile             # Validate + scan (PR check)
├── terraform-cd/
│   └── Jenkinsfile             # Full plan + apply pipeline
├── upgrade-pipelines/
│   ├── eks-upgrade/Jenkinsfile
│   └── node-group-refresh/Jenkinsfile
└── maintenance-pipelines/
    ├── drift-detection/Jenkinsfile
    └── certificate-rotation/Jenkinsfile

application-pipelines/
├── build/
│   └── Jenkinsfile             # Build + test + scan + push
├── release/
│   └── Jenkinsfile             # Helm package + publish
└── deployment/
    └── Jenkinsfile             # Helm deploy (per environment)
```

---

## 10. Related Documents

- [Platform Pipeline Jenkinsfiles](../../platform-pipelines/)
- [Application Pipeline Jenkinsfiles](../../application-pipelines/)
- [EKS Upgrade Strategy](../operations/eks-upgrade-strategy.md)
- [Node Patching Strategy](../operations/node-patching-strategy.md)
