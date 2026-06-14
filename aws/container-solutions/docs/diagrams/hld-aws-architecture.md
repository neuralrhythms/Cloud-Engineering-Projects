# Diagram: High-Level AWS Architecture

## Overview

This diagram shows the top-level AWS architecture for the EKS platform — VPC layout, EKS cluster, load balancing, CI/CD, ECR, and supporting AWS services.

---

## Mermaid Source

```mermaid
graph TB
    subgraph Internet["☁️ Internet"]
        USER[👤 Users]
        DEV[👨‍💻 Developers]
    end

    subgraph AWS["AWS Cloud (eu-west-1)"]

        R53[Route 53\nDNS]

        subgraph VPC["VPC 10.x.0.0/16"]

            subgraph PublicSubnets["Public Subnets (AZ-a, AZ-b, AZ-c)"]
                ALB[Application\nLoad Balancer]
                NAT[NAT\nGateway]
                IGW[Internet\nGateway]
            end

            subgraph PrivateSubnets["Private Subnets (AZ-a, AZ-b, AZ-c)"]

                subgraph EKS["Amazon EKS Cluster"]
                    CP[EKS Control\nPlane\n(AWS Managed)]

                    subgraph NG["Managed Node Groups"]
                        N1[Node AZ-a\nm5.xlarge]
                        N2[Node AZ-b\nm5.xlarge]
                        N3[Node AZ-c\nm5.xlarge]
                    end

                    subgraph Pods["Application Pods"]
                        P1[App Pod]
                        P2[App Pod]
                        P3[App Pod]
                    end
                end

                JENKINS[Jenkins\nCI/CD\n(EC2 or EKS)]
            end

        end

        ECR[Amazon ECR\nContainer Registry]
        SM[Secrets Manager]
        KMS[AWS KMS]
        CW[CloudWatch\nLogs + Metrics]
        GD[GuardDuty]
        SH[Security Hub]
        CT[CloudTrail]

    end

    USER --> R53
    R53 --> ALB
    ALB --> Pods
    DEV --> JENKINS
    JENKINS --> ECR
    JENKINS --> EKS
    ECR --> Pods
    Pods --> SM
    KMS --> ECR
    KMS --> SM
    EKS --> CW
    EKS --> GD
    CP --> CW
    CT --> CW
    GD --> SH
    PrivateSubnets --> NAT
    NAT --> IGW
    IGW --> Internet
```

---

## Diagram Notes

- All EKS worker nodes run in private subnets
- ALB is the only internet-facing entry point for user traffic
- Jenkins may run on EC2 or as a pod within EKS (both patterns supported)
- ECR is a regional AWS service; accessed via VPC Endpoint
- KMS provides envelope encryption for ECR, Secrets Manager, EBS, and EKS etcd
- GuardDuty aggregates findings into Security Hub

---

## Rendered Format

To render this diagram, use one of:
- [Mermaid Live Editor](https://mermaid.live)
- VS Code with the Mermaid Preview extension
- GitHub (renders `.md` Mermaid blocks natively)
