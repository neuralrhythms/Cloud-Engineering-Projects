# 🤖 LLM Application Hosting

> Production model serving patterns for large language models on AWS.

## Architecture

```mermaid
graph TD
    subgraph "API Layer"
        ALB[Application Load Balancer]
        APIGW[API Gateway]
    end
    
    subgraph "Compute Options"
        ECS[ECS Fargate<br/>Container-based]
        SM[SageMaker Endpoint<br/>Real-time Inference]
        BEDROCK[Bedrock<br/>Serverless]
    end
    
    subgraph "Supporting Services"
        CACHE[ElastiCache<br/>Response Cache]
        QUEUE[SQS<br/>Async Processing]
        ASG[Auto Scaling<br/>Based on Queue Depth]
    end
    
    ALB --> ECS
    APIGW --> SM
    APIGW --> BEDROCK
    ECS --> CACHE
    APIGW --> QUEUE --> ECS
    ECS --> ASG
```

## Hosting Options Comparison

| Option | Latency | Cost Model | Scaling | Use Case |
|--------|---------|-----------|---------|----------|
| Bedrock | Medium | Per-token | Automatic | General LLM access |
| SageMaker RT | Low | Per-instance-hour | Manual/Auto | Custom models |
| ECS + vLLM | Low | Per-container-hour | Task-based | Self-hosted open models |
| SageMaker Async | High | Per-request | Queue-based | Batch processing |

---

➡️ [Back to AI Workloads](../) | [Back to AWS](../../)
