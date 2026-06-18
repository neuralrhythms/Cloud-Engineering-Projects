# XYZ Corporation — AWS Cloud Transformation
## Architectural Design Suite: Master Index

**Programme:** XYZ Corporation AWS Cloud Transformation  
**Version:** 1.0  
**Status:** Approved for Programme Use  
**Scope:** Six architectural design documents covering all six domains of the transformation programme  
**Out of Scope:** Terraform code, CloudFormation templates, runbook step-by-step instructions, CI/CD pipeline configuration files, application re-architecture

---

## Programme Context

XYZ Corporation operates **2,000+ workloads** across **20+ AWS accounts** supporting **40+ business applications**. The estate was built organically through manual console operations, resulting in a current aggregate AWS Well-Architected Framework (WAF) maturity of approximately **1.4/5**.

The transformation programme targets a WAF aggregate maturity of **≥3.3/5** across all six pillars — Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimisation, and Sustainability — within a **12–18 month programme**.

### WAF Maturity Summary

| WAF Pillar | Current Score | Target Score |
|---|---|---|
| Operational Excellence | 1.5 / 5 | 3.5 / 5 |
| Security | 1.5 / 5 | 4.0 / 5 |
| Reliability | 2.0 / 5 | 3.5 / 5 |
| Performance Efficiency | 1.5 / 5 | 3.0 / 5 |
| Cost Optimisation | 1.0 / 5 | 3.5 / 5 |
| Sustainability | 1.0 / 5 | 2.5 / 5 |
| **Aggregate** | **~1.4 / 5** | **≥ 3.3 / 5** |

---

## Document Inventory

| # | Filename | Title | Sections | Status | WAF Pillars Covered |
|---|---|---|---|---|---|
| 00 | [00-master-index.md](00-master-index.md) | Master Index (this document) | — | Approved for Programme Use | All |
| 01 | [01-target-architecture-overview.md](01-target-architecture-overview.md) | Target Architecture Overview | 9 | Approved for Programme Use | All |
| 02 | [02-security-governance-design.md](02-security-governance-design.md) | Security & Governance Design | 10 | Approved for Programme Use | Security, Operational Excellence |
| 03 | [03-platform-iac-design.md](03-platform-iac-design.md) | Platform & IaC Design | 10 | Approved for Programme Use | Operational Excellence, Security |
| 04 | [04-reliability-dr-design.md](04-reliability-dr-design.md) | Reliability & DR Design | 9 | Approved for Programme Use | Reliability, Operational Excellence |
| 05 | [05-finops-design.md](05-finops-design.md) | FinOps Design | 11 | Approved for Programme Use | Cost Optimisation, Sustainability |
| 06 | [06-adr-catalog.md](06-adr-catalog.md) | Architecture Decision Record Catalog | 7 ADRs + summary table | Approved for Programme Use | All |

---

## Phased Roadmap Summary

The transformation is structured into five phases (Phase 0 through Phase 4). Each phase builds on the previous, and the architectural design documents describe capabilities introduced in their respective phases. No calendar dates are specified; phases represent logical sequencing of delivery.

| Phase | Name | Key Capabilities | Primary Documents |
|---|---|---|---|
| **Phase 0** | Foundation & Discovery | AWS Control Tower baseline deployment; removal of long-lived IAM access keys; enforcement of MFA on root account credentials; full resource and workload discovery inventory across all 20+ accounts | 01, 02 |
| **Phase 1** | Security & Governance | IAM Identity Center rollout (replacing per-account IAM users); SCP guardrail set activation; Security Hub aggregator mode; Amazon GuardDuty organisation-wide; AWS Secrets Manager migration for hard-coded credentials | 02, 06 |
| **Phase 2** | Platform & IaC | Terraform module library published by CCoE; GitOps CI/CD pipelines for infrastructure delivery; AWS Service Catalog portfolios; Golden AMI pipeline via AWS Image Builder; IaC coverage target ≥80% | 03, 06 |
| **Phase 3** | Reliability & DR | Workload tiering and RTO/RPO assignment; AWS Backup organisation-wide policies; AWS Fault Injection Simulator chaos testing for Tier 1 workloads; DR validation sign-off | 04, 06 |
| **Phase 4** | FinOps & Optimisation | CUR/CUDOS cost visibility platform; AWS Savings Plans and Compute Optimizer rightsizing; non-production environment scheduling; FinOps operating cadence established; Sustainability baseline via Customer Carbon Footprint Tool | 05, 06 |

---

## How to Use This Suite

### Document Relationships

The six design documents are intended to be read together as a coherent suite. They share a common set of cross-cutting standards (see [Cross-Cutting Design Standards](#cross-cutting-design-standards) below) and cross-reference each other at key integration points.

```
01-target-architecture-overview.md
        │
        ├── provides the account topology and OU structure consumed by ALL other documents
        │
        ├── 02-security-governance-design.md
        │       └── defines security controls referenced by Platform (03), Reliability (04), and FinOps (05)
        │
        ├── 03-platform-iac-design.md
        │       └── defines IaC/CI/CD patterns and CCoE model; references security baseline from (02)
        │
        ├── 04-reliability-dr-design.md
        │       └── references workload tiering; references observability tools from (03)
        │
        ├── 05-finops-design.md
        │       └── references tagging enforcement from (02 SCPs); references scheduling from (03 Service Catalog)
        │
        └── 06-adr-catalog.md
                └── documents the decisions that underpin all five preceding documents
```

### Recommended Reading Order

1. **Start with `01-target-architecture-overview.md`** — establishes the multi-account topology, OU hierarchy, and WAF pillar mapping that all other documents assume.
2. **Read `02-security-governance-design.md`** — the security baseline is a foundational dependency for platform, reliability, and FinOps designs.
3. **Read `03-platform-iac-design.md`** — the IaC and CI/CD model governs how all infrastructure described in documents 04 and 05 is provisioned.
4. **Read `04-reliability-dr-design.md`** and **`05-finops-design.md`** in either order — they are peers at this level, each building on documents 01–03.
5. **Reference `06-adr-catalog.md`** when you need to understand the rationale and trade-offs behind any significant technology decision made during the programme.

### Audience Guide

| Audience | Recommended Documents |
|---|---|
| Programme Sponsor / Executive Stakeholders | 00 (this document), 01 (sections 1.2–1.5) |
| Principal / Senior Cloud Architects | All documents |
| Security Architects | 01, 02, 06 (ADR-003, ADR-004, ADR-005) |
| Platform / DevOps Engineers | 01, 03, 06 (ADR-001, ADR-002) |
| Reliability / SRE Engineers | 01, 03, 04, 06 (ADR-006) |
| FinOps Practitioners / Finance | 01, 05, 06 (ADR-007) |
| Compliance / Audit Teams | 02, 06 |

---

## WAF Pillar Coverage Matrix

| WAF Pillar | 01 Target Arch | 02 Security | 03 Platform | 04 Reliability | 05 FinOps | 06 ADR Catalog |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Operational Excellence | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Security | ✓ | ✓ | ✓ | — | — | ✓ |
| Reliability | ✓ | — | ✓ | ✓ | — | ✓ |
| Performance Efficiency | ✓ | — | ✓ | ✓ | ✓ | — |
| Cost Optimisation | — | — | ✓ | — | ✓ | ✓ |
| Sustainability | — | — | — | — | ✓ | — |

---

## Cross-Cutting Design Standards

All six documents in this suite conform to the following standards, in accordance with Requirement 7:

1. **AWS nomenclature** — AWS service names and terminology follow AWS documentation exactly (e.g., "IAM Identity Center", "AWS Fault Injection Simulator", "Amazon GuardDuty").
2. **Architecture diagrams** — all diagrams are rendered as Mermaid or PlantUML code blocks using standard architecture conventions.
3. **No implementation detail** — no Terraform HCL, CloudFormation YAML, runbook step-by-step instructions, or CI/CD pipeline configuration files appear in any document.
4. **Phase references** — sequencing is described using Phase 0 through Phase 4 labels; no calendar dates or project milestones are specified.
5. **All six WAF pillars** — each pillar is addressed substantively in at least one design document (see coverage matrix above).
6. **External dependencies** — where a design depends on an external system (IdP, SIEM, ITSM), the document identifies the dependency and defines the integration boundary without prescribing the external system's internal design.
7. **Third-party gaps** — where a required control cannot be achieved with native AWS services alone, the document identifies the gap and recommends a category of tooling without endorsing a specific vendor.

---

## Cross-References Note

Each document in this suite references the others at key integration points. The cross-references use relative Markdown links where the filename is known. Readers are encouraged to follow these links when a referenced design decision or service dependency is described in another document.

Key cross-reference patterns:
- The **Security design (02)** is referenced by all other documents when describing security controls applied to a service (e.g., encryption, IAM roles, tagging enforcement via SCPs).
- The **Target Architecture Overview (01)** OU and account topology is assumed as given in documents 02–06; it is not repeated.
- The **ADR Catalog (06)** is referenced whenever a significant technology decision is mentioned in documents 01–05, allowing readers to trace the rationale without re-litigating the decision.

---

*Document generated as part of the XYZ Corporation AWS Cloud Transformation programme. Version 1.0 — subject to review and update as programme phases progress.*
