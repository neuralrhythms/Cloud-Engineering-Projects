# 📐 Observability Pattern

> Comprehensive monitoring, logging, and distributed tracing for cloud-native applications.

---

## Three Pillars

```mermaid
graph TD
    subgraph "Metrics"
        CW[CloudWatch Metrics]
        CUSTOM[Custom Metrics<br/>EMF / StatsD]
        DASH[Dashboards<br/>Real-time Visibility]
    end
    
    subgraph "Logs"
        CW_LOGS[CloudWatch Logs]
        S3_LOGS[S3 Archive<br/>Long-term Retention]
        OPENSEARCH[OpenSearch<br/>Full-text Search]
    end
    
    subgraph "Traces"
        XRAY[X-Ray<br/>Distributed Tracing]
        SERVICE_MAP[Service Map<br/>Dependency Visualization]
    end
    
    subgraph "Alerting"
        ALARMS[CloudWatch Alarms]
        SNS[SNS → PagerDuty]
        COMPOSITE[Composite Alarms]
    end
    
    CW --> DASH
    CW --> ALARMS --> SNS
    CW_LOGS --> OPENSEARCH
    XRAY --> SERVICE_MAP
```

## Best Practices

1. **Structured logging** — JSON format with correlation IDs
2. **Custom metrics** — business KPIs, not just infrastructure
3. **Distributed tracing** — trace requests across service boundaries
4. **Alerting on symptoms, not causes** — alert on error rates, not CPU
5. **Dashboards per audience** — executive, SRE, developer views

---

➡️ [Back to Patterns](../) | [Back to Portfolio](../../)
