# Diagram: EKS Platform Architecture

## Overview

This diagram shows the Kubernetes platform architecture inside the EKS cluster — namespaces, platform components, application workloads, ingress, autoscaling, and secrets management.

---

## Mermaid Source

```mermaid
graph TB
    subgraph EKS["Amazon EKS Cluster"]

        subgraph KubeSystem["Namespace: kube-system"]
            ALBCTRL[AWS Load Balancer\nController]
            CA[Cluster\nAutoscaler]
            VPCCNI[VPC CNI\nPlugin]
            COREDNS[CoreDNS]
            KPROXY[kube-proxy]
        end

        subgraph PlatformSystem["Namespace: platform-system"]
            ESO[External Secrets\nOperator]
            MS[Metrics\nServer]
            CWA[CloudWatch\nAgent]
        end

        subgraph Monitoring["Namespace: monitoring"]
            CWINSIGHTS[Container\nInsights]
        end

        subgraph AppNS["Namespace: team-prod"]
            subgraph App1["Application: payments-api"]
                DEP1[Deployment\n3 replicas]
                SVC1[Service\nClusterIP]
                ING1[Ingress\nALB]
                SA1[ServiceAccount\n+ IRSA]
                HPA1[HPA\nCPU 70%]
                PDB1[PodDisruptionBudget\nminAvailable: 1]
            end
        end

        subgraph SecretFlow["Secrets Flow"]
            KSEC[Kubernetes\nSecret\nauto-synced]
        end

    end

    subgraph AWS["AWS Services"]
        ALB_AWS[Application\nLoad Balancer]
        SM_AWS[Secrets\nManager]
        CW_AWS[CloudWatch]
        IAMIRSA[IAM Role\nIRSA]
        ECR_AWS[Amazon ECR]
        ASG[Auto Scaling\nGroup]
    end

    ALB_AWS --> ING1
    ING1 --> SVC1
    SVC1 --> DEP1
    ALBCTRL --> ALB_AWS
    CA --> ASG
    ESO --> SM_AWS
    SM_AWS --> KSEC
    KSEC --> DEP1
    SA1 --> IAMIRSA
    DEP1 --> SA1
    CWA --> CW_AWS
    CWINSIGHTS --> CW_AWS
    HPA1 --> DEP1
    DEP1 --> ECR_AWS
```

---

## Component Descriptions

| Component | Namespace | Purpose |
|---|---|---|
| AWS Load Balancer Controller | kube-system | Provisions ALB/NLB from Ingress/Service resources |
| Cluster Autoscaler | kube-system | Scales node groups based on pending pods |
| VPC CNI | kube-system | Pod networking with VPC-native IPs |
| CoreDNS | kube-system | Cluster DNS resolution |
| External Secrets Operator | platform-system | Syncs secrets from AWS Secrets Manager |
| Metrics Server | platform-system | Provides CPU/memory metrics for HPA |
| CloudWatch Agent | platform-system | Ships logs and metrics to CloudWatch |
| Container Insights | monitoring | Enhanced node/pod metrics in CloudWatch |

---

## Rendered Format

To render this diagram:
- [Mermaid Live Editor](https://mermaid.live)
- GitHub (native Mermaid rendering in `.md` files)
