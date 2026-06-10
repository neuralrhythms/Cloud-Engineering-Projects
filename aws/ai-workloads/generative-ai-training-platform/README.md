# 🤖 Generative AI Training Platform

> Cost-efficient static website hosting platform for AI/ML learning content with CDN delivery and GitHub integration.

---

## Overview

A serverless platform for hosting generative AI training materials, tutorials, and interactive content. Built with a focus on cost efficiency, global performance, and automated content deployment.

## Architecture

```mermaid
graph LR
    subgraph "Content Pipeline"
        GH[GitHub Repository<br/>Markdown + Code]
        GA[GitHub Actions<br/>Build & Deploy]
    end
    
    subgraph "AWS Infrastructure"
        S3[S3 Bucket<br/>Static Assets]
        CF[CloudFront<br/>Global CDN]
        ACM[ACM Certificate<br/>TLS 1.3]
        R53[Route 53<br/>Custom Domain]
        LAMBDA_E[Lambda@Edge<br/>Auth + Redirects]
    end
    
    subgraph "AI Content Generation"
        BEDROCK[Amazon Bedrock<br/>Content Generation]
        LAMBDA[Lambda<br/>Content Processor]
    end
    
    GH --> GA --> S3
    R53 --> CF --> S3
    CF --> LAMBDA_E
    CF --> ACM
    BEDROCK --> LAMBDA --> S3
```

## Features

| Feature | Implementation |
|---------|---------------|
| Static site hosting | S3 + CloudFront Origin Access Control |
| Custom domain + HTTPS | Route 53 + ACM certificate |
| Global performance | CloudFront edge locations worldwide |
| Automated deployment | GitHub Actions → S3 sync |
| AI content generation | Bedrock Claude → Lambda → S3 |
| Access control | Lambda@Edge for basic auth |
| Cost optimization | S3 Intelligent-Tiering, CF caching |

## Cost Breakdown

| Component | Monthly Cost |
|-----------|-------------|
| S3 storage (10 GB) | ~$0.23 |
| CloudFront (100 GB transfer) | ~$8.50 |
| Route 53 hosted zone | $0.50 |
| Lambda@Edge invocations | ~$0.10 |
| **Total** | **~$10/month** |

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hosting | S3 + CloudFront | Lowest cost, highest availability (11 9s durability) |
| Build tool | Hugo / Next.js static export | Fast builds, markdown-friendly |
| Deployment | GitHub Actions | Native Git integration, free tier |
| AI content | Bedrock Claude | Serverless, pay-per-token, no infrastructure |
| CDN | CloudFront | AWS-native, OAC for S3, global edge network |

---

➡️ [Back to AI Workloads](../) | [Back to AWS](../../)
