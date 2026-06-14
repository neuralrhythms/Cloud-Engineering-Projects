# Architecture Diagrams

All diagrams are authored in [Mermaid](https://mermaid.js.org/) and stored as Markdown files. GitHub renders Mermaid blocks natively in `.md` files.

## Diagram Index

| Diagram | File | Description |
|---|---|---|
| High-Level AWS Architecture | [hld-aws-architecture.md](hld-aws-architecture.md) | Top-level view of VPC, EKS, ALB, CI/CD, and AWS services |
| EKS Platform Architecture | [eks-platform-architecture.md](eks-platform-architecture.md) | Kubernetes platform components and namespace layout |
| Infrastructure CI/CD Pipeline | [infrastructure-cicd-pipeline.md](infrastructure-cicd-pipeline.md) | Terraform lifecycle pipelines (CI, CD, drift, upgrade) |
| Application CI/CD Pipeline | [application-cicd-pipeline.md](application-cicd-pipeline.md) | App build, scan, ECR push, and Helm deploy flow |
| Security Architecture | [security-architecture.md](security-architecture.md) | Layered security controls from AWS account to container runtime |
| Observability Architecture | [observability-architecture.md](observability-architecture.md) | CloudWatch log/metric collection, alarms, dashboards |

## How to Render

**GitHub:** Push to GitHub — Mermaid blocks render automatically in Markdown preview.

**Local (VS Code):** Install the [Markdown Preview Mermaid Support](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-mermaid) extension.

**Online:** Paste diagram source into [mermaid.live](https://mermaid.live).

**Export to PNG/SVG:** Use the Mermaid CLI:
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i hld-aws-architecture.md -o hld-aws-architecture.png
```
