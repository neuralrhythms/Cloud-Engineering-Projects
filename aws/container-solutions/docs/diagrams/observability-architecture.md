# Diagram: Observability Architecture

## Overview

This diagram shows the observability stack built on AWS-native services — CloudWatch Logs, Metrics, Container Insights, Alarms, and Dashboards — with placeholders for future Prometheus/Grafana integration.

---

## Mermaid Source

```mermaid
graph TB
    subgraph Sources["Data Sources"]
        direction LR
        EKSLOGS[EKS Control\nPlane Logs]
        APPLOGS[Application\nContainer Logs\nstdout/stderr]
        NODELOGS[Node System\nLogs]
        VPCFLOW[VPC Flow\nLogs]
        CTLOGS[CloudTrail\nLogs]
        KUBEMETRICS[kube-state-metrics\n+ Metrics Server]
        NODEEXPORTER[Node Metrics\nfrom CloudWatch Agent]
    end

    subgraph Collection["Collection Layer"]
        direction LR
        CWA[CloudWatch Agent\n(DaemonSet)]
        FLUENTBIT[Fluent Bit\n(optional — future)]
    end

    subgraph Storage["Storage & Processing"]
        direction TB
        CWLOGS[CloudWatch Logs\nLog Groups]
        CWMETRICS[CloudWatch\nMetrics]
        CI[Container\nInsights]
    end

    subgraph Visibility["Visibility Layer"]
        direction LR
        CWDASH[CloudWatch\nDashboards]
        CWALARMS[CloudWatch\nAlarms]
        INSIGHTSQ[CloudWatch\nLogs Insights\nQueries]
    end

    subgraph Alerting["Alerting & Notification"]
        direction LR
        SNS[Amazon SNS]
        SLACK[Slack /\nMS Teams]
        PD[PagerDuty\n(on-call)]
        EMAIL[Email\nNotifications]
    end

    subgraph Future["Future: OSS Observability Stack"]
        direction LR
        PROM[Prometheus\n(placeholder)]
        GRAFANA[Grafana\n(placeholder)]
        JAEGER[AWS X-Ray /\nJaeger (placeholder)]
        NOTE["💡 Can be added alongside\nCloudWatch without replacing it"]
    end

    EKSLOGS --> CWLOGS
    APPLOGS --> CWA
    NODELOGS --> CWA
    CWA --> CWLOGS
    CWA --> CWMETRICS
    CWA --> CI
    VPCFLOW --> CWLOGS
    CTLOGS --> CWLOGS
    KUBEMETRICS --> CWMETRICS
    NODEEXPORTER --> CWMETRICS

    CWLOGS --> CWDASH
    CWLOGS --> INSIGHTSQ
    CWMETRICS --> CWDASH
    CWMETRICS --> CWALARMS
    CI --> CWDASH
    CI --> CWALARMS

    CWALARMS --> SNS
    SNS --> SLACK
    SNS --> PD
    SNS --> EMAIL

    CWMETRICS -.->|future| PROM
    PROM -.-> GRAFANA
    CWLOGS -.->|future| JAEGER
```

---

## CloudWatch Log Groups

| Log Group | Source | Retention |
|---|---|---|
| `/aws/eks/{cluster}/cluster` | EKS control plane | 90 days (prod) |
| `/aws/containerinsights/{cluster}/performance` | Container Insights | 30 days |
| `/aws/containerinsights/{cluster}/application` | Application containers | 30–90 days |
| `/aws/containerinsights/{cluster}/host` | Node system logs | 30 days |
| `/aws/vpc/flow-logs/{env}` | VPC Flow Logs | 365 days (prod) |
| `/aws/cloudtrail/{env}` | CloudTrail | 365 days (prod) |

---

## CloudWatch Alarms (Recommended)

| Alarm | Metric | Threshold | Action |
|---|---|---|---|
| High CPU on nodes | `node_cpu_utilization` | > 80% for 5 min | SNS → Slack |
| High memory on nodes | `node_memory_utilization` | > 85% for 5 min | SNS → Slack |
| Pending pods | `pending_pod_count` | > 0 for 10 min | SNS → Slack |
| Pod crash loop | `pod_number_of_container_restarts` | > 5 in 5 min | SNS → PagerDuty |
| API server errors | `apiserver_request_total (5xx)` | > 10 in 5 min | SNS → PagerDuty |
| Node group scaling | `ASG desired capacity` change | Any change | SNS → Slack |
| GuardDuty High finding | Security Hub | Severity ≥ 7 | SNS → PagerDuty |

---

## Container Insights Dashboard Panels

- Cluster CPU utilisation (%)
- Cluster memory utilisation (%)
- Node CPU / memory breakdown by AZ
- Pod count by namespace
- Container restart count
- Network I/O
- Disk I/O

---

## Future Prometheus/Grafana Integration Notes

When adding Prometheus:
- Deploy using `kube-prometheus-stack` Helm chart
- Federate CloudWatch metrics via `yet-another-cloudwatch-exporter`
- CloudWatch Logs remain as-is; Loki can supplement for log querying
- Grafana can sit alongside CloudWatch Dashboards

This adds rich K8s-native dashboards without replacing the CloudWatch foundation.

---

## Rendered Format

To render: [Mermaid Live Editor](https://mermaid.live)
