# Diagram: Application CI/CD Pipeline

## Overview

This diagram shows the full application delivery pipeline — from Git commit through build, test, container scan, ECR push, and Helm deployment across environments.

---

## Mermaid Source

```mermaid
flowchart TB
    GIT[("Git Repository\nApplication Code")]

    subgraph BUILD["Stage 1: Build & Test"]
        direction LR
        B1[Checkout]
        B2[Build\nApplication]
        B3[Unit Tests]
        B4{Tests\nPassed?}
        B5[Publish\nTest Report]
        B6[❌ Fail Pipeline]

        B1 --> B2 --> B3 --> B4
        B4 -->|Yes| B5
        B4 -->|No| B6
    end

    subgraph CONTAINER["Stage 2: Container Build & Scan"]
        direction LR
        CB1[Build Container\nImage\nkaniko/docker]
        CB2[Trivy Scan\nHIGH/CRITICAL CVEs]
        CB3{Vulnerabilities\nFound?}
        CB4[Fail — Block\nDeployment]
        CB5[Publish\nScan Report]

        CB1 --> CB2 --> CB3
        CB3 -->|Yes| CB4
        CB3 -->|No| CB5
    end

    subgraph ECR["Stage 3: Push to ECR"]
        direction LR
        ECR1[aws ecr\nget-login-password]
        ECR2[docker push\nimage:git-sha-build]
        ECR3[Tag as latest\nmain branch only]
        ECR4[ECR Enhanced\nScanning continues]

        ECR1 --> ECR2 --> ECR3 --> ECR4
    end

    subgraph DEVDEPLOY["Stage 4: Deploy to Dev (Auto)"]
        direction LR
        DD1[helm upgrade\n--install]
        DD2[Wait for\nRollout]
        DD3[Health Check]
        DD4{Healthy?}
        DD5[✅ Dev OK]
        DD6[❌ Auto Rollback]

        DD1 --> DD2 --> DD3 --> DD4
        DD4 -->|Yes| DD5
        DD4 -->|No| DD6
    end

    subgraph TESTDEPLOY["Stage 5: Deploy to Test (Auto)"]
        direction LR
        TD1[helm upgrade\n--install]
        TD2[Integration Tests]
        TD3{Tests\nPassed?}
        TD4[✅ Test OK]
        TD5[❌ Fail + Alert]

        TD1 --> TD2 --> TD3
        TD3 -->|Yes| TD4
        TD3 -->|No| TD5
    end

    subgraph PRODAPPROVE["Stage 6: Production Gate"]
        direction LR
        PA1[Helm Diff\nPreview Changes]
        PA2[Manual Approval\nRequired]
        PA3{Approved?}
        PA4[Proceed to\nProduction]
        PA5[Abort]

        PA1 --> PA2 --> PA3
        PA3 -->|Yes| PA4
        PA3 -->|No| PA5
    end

    subgraph PRODDEPLOY["Stage 7: Deploy to Production"]
        direction LR
        PD1[helm upgrade\n--atomic --timeout 10m]
        PD2[Smoke Test]
        PD3{Healthy?}
        PD4[✅ Production\nDeployment Complete]
        PD5[❌ Auto Rollback\nPagerDuty Alert]

        PD1 --> PD2 --> PD3
        PD3 -->|Yes| PD4
        PD3 -->|No| PD5
    end

    GIT --> BUILD
    BUILD --> CONTAINER
    CONTAINER --> ECR
    ECR --> DEVDEPLOY
    DEVDEPLOY --> TESTDEPLOY
    TESTDEPLOY --> PRODAPPROVE
    PRODAPPROVE --> PRODDEPLOY
```

---

## Image Tagging Strategy

| Tag Format | Example | Used For |
|---|---|---|
| `{git-sha}-{build-number}` | `abc1234-42` | All deployed versions |
| `latest` | `latest` | Convenience; main branch only |
| `v{semver}` | `v1.2.3` | Release tags (optional) |

Images are **immutable** in production ECR (IMMUTABLE tag mutability setting).

---

## Deployment Commands Reference

### Dev / Test

```bash
helm upgrade --install my-app ./helm/my-app \
  --namespace team-dev \
  --values helm/my-app/values.yaml \
  --values helm/environments/dev/my-app.yaml \
  --set image.tag=${IMAGE_TAG} \
  --wait --timeout 5m
```

### Production

```bash
helm upgrade --install my-app ./helm/my-app \
  --namespace team-prod \
  --values helm/my-app/values.yaml \
  --values helm/environments/prod/my-app.yaml \
  --set image.tag=${IMAGE_TAG} \
  --atomic --timeout 10m \
  --cleanup-on-fail
```

---

## Rendered Format

To render: [Mermaid Live Editor](https://mermaid.live)
