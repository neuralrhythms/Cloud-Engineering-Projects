# Architecture Decision Record Catalog

**Document:** 06 — ADR Catalog  
**Programme:** XYZ Corporation AWS Cloud Transformation  
**Version:** 1.0  
**Status:** Approved for Programme Use  
**Related Documents:** [01 Target Architecture Overview](01-target-architecture-overview.md) · [02 Security & Governance Design](02-security-governance-design.md) · [03 Platform & IaC Design](03-platform-iac-design.md) · [04 Reliability & DR Design](04-reliability-dr-design.md) · [05 FinOps Design](05-finops-design.md)

---

## Table of Contents

1. [ADR Summary Table](#adr-summary-table)
2. [ADR-001: IaC Tooling Selection](#adr-001-iac-tooling-selection)
3. [ADR-002: Multi-Account Governance](#adr-002-multi-account-governance)
4. [ADR-003: Identity and Access Management Strategy](#adr-003-identity-and-access-management-strategy)
5. [ADR-004: Centralised Security Tooling](#adr-004-centralised-security-tooling)
6. [ADR-005: Secrets Management Strategy](#adr-005-secrets-management-strategy)
7. [ADR-006: DR Strategy and Workload Tiering](#adr-006-dr-strategy-and-workload-tiering)
8. [ADR-007: FinOps Tooling and Reporting](#adr-007-finops-tooling-and-reporting)

---

## ADR Summary Table

| ADR # | Title | Status | WAF Pillar(s) Affected |
|---|---|---|---|
| ADR-001 | IaC Tooling Selection | Accepted | Operational Excellence |
| ADR-002 | Multi-Account Governance | Accepted | Operational Excellence, Security, Reliability |
| ADR-003 | Identity and Access Management Strategy | Accepted | Security |
| ADR-004 | Centralised Security Tooling | Accepted | Security |
| ADR-005 | Secrets Management Strategy | Accepted | Security, Operational Excellence |
| ADR-006 | DR Strategy and Workload Tiering | Accepted | Reliability |
| ADR-007 | FinOps Tooling and Reporting | Accepted | Cost Optimisation, Sustainability |

---

## ADR-001: IaC Tooling Selection

### Title

IaC Tooling Selection

### Status

Accepted

### Date

Phase 0 (Foundation & Discovery)

### Context

XYZ Corporation's AWS estate was built organically through manual console operations over multiple years. IaC coverage is below 15%. As the transformation programme scales to 20+ accounts and 2,000+ workloads, a consistent, governed IaC tooling choice is required to enable the GitOps CI/CD model and reach the ≥80% IaC coverage target. The absence of a single mandated tool has resulted in fragmented provisioning approaches across teams, making automated policy enforcement and drift detection impractical at scale.

### Decision

Adopt Terraform as the primary IaC tool for multi-account infrastructure provisioning. AWS CloudFormation StackSets are retained for use cases tightly coupled to AWS Control Tower Customisations (CfCT) where CloudFormation is the native format required by the service.

### Rationale

1. **Multi-provider and multi-account** — Terraform manages AWS, on-premises, and SaaS resources under a single declarative model, meeting the requirement for a unified provisioning surface across a heterogeneous estate.
2. **State management maturity** — S3 backend with DynamoDB state locking is a proven enterprise-scale pattern, providing concurrent-access safety and disaster recovery for infrastructure state.
3. **Module ecosystem** — the Terraform Registry provides extensive AWS community and official modules; the Cloud Centre of Excellence (CCoE) builds on top of these rather than constructing modules from scratch, accelerating delivery.
4. **Team skill availability** — Terraform is the dominant IaC tool in the market; hiring and training pipelines are significantly larger than for AWS CDK or CloudFormation, reducing time-to-competency for the programme team.

### Alternatives Considered

1. **AWS CloudFormation exclusively** — deep native AWS integration and no external toolchain dependency, but lacks multi-provider capability; StackSet scalability limits at large account counts create operational overhead; remote state management is less mature than the S3 + DynamoDB pattern.
2. **AWS Cloud Development Kit (CDK)** — imperative programming model with higher abstraction allowing reuse of general-purpose languages; however, the talent pool is smaller, state management is more complex (CDK synthesises to CloudFormation stacks), and the approach is less well-suited to the programme team's existing skill composition.
3. **Pulumi** — supports general-purpose languages and multi-provider provisioning; however, the ecosystem is smaller, enterprise adoption in EMEA is limited, and available talent is materially less than Terraform, increasing programme delivery risk.

### Trade-offs

1. **Terraform state security** — state files may contain sensitive resource attributes; mitigated by S3 server-side encryption (KMS), strict bucket access policies, and access logging delivered to the Log Archive Account.
2. **BSL licence (Terraform v1.6+)** — HashiCorp's Business Source Licence introduces a contractual consideration for commercial use at scale; OpenTofu (the open-source fork) is a viable alternative if BSL terms become a material concern and will be evaluated at Phase 2 checkpoint.
3. **Drift detection model** — Terraform's drift detection is reactive (scheduled `terraform plan` comparisons) rather than real-time; mitigated by AWS Config continuous evaluation providing a complementary real-time configuration change record.
4. **HCL learning curve** — teams new to Terraform require onboarding to HashiCorp Configuration Language; mitigated by CCoE-led enablement sessions and the module library abstracting raw HCL for most consumers.

### Consequences

- The CCoE owns and maintains the Terraform module library, covering the domains defined in the Platform & IaC Design (networking, compute, security, storage, observability, account baseline).
- All new infrastructure provisioning in Workloads-Prod and Workloads-NonProd OUs is delivered via Terraform modules or Service Catalog products backed by Terraform.
- Direct console resource creation in production accounts is deprecated via SCP from Phase 1 onwards.
- CloudFormation StackSets remain in use exclusively for Control Tower Customisations (CfCT); no new CloudFormation stacks are introduced outside the CfCT scope.

---

## ADR-002: Multi-Account Governance

### Title

Multi-Account Governance

### Status

Accepted

### Date

Phase 0 (Foundation & Discovery)

### Context

XYZ Corporation operates 20+ AWS accounts with no unified governance model. Accounts were created ad hoc, have no consistent SCP structure, and lack centralised security visibility. Root credentials are not universally protected and there is no Account Factory pattern — new accounts are provisioned manually without baseline security controls pre-applied. A governance anchor is required to enforce consistent policy-as-code guardrails, enable centralised compliance posture visibility, and support the phased onboarding of all existing accounts alongside the vending of future accounts.

### Decision

Deploy AWS Control Tower as the governance anchor for the entire XYZ Corporation AWS estate. Organise all accounts into a five-OU hierarchy: Security OU, Infrastructure OU, Workloads-Prod OU, Workloads-NonProd OU, and Sandbox OU. Use Control Tower Account Factory for all future account vending. Deliver organisation-wide baseline configuration customisations — including Config rules, CloudTrail configuration, and default VPC deletion — via Control Tower Customisations for Control Tower (CfCT). Apply the SCP guardrail set defined in the Security & Governance Design at the appropriate OU and root levels.

### Rationale

The minimum blast radius principle drives the five-OU structure: production and non-production workloads are separated by OU-level SCP boundaries, not account-level policies alone, ensuring that a compromised or misconfigured non-production account cannot affect production workloads. Control Tower provides a managed landing zone with pre-validated guardrails, eliminating the significant custom development effort required to replicate its guardrail library, compliance dashboard, and Account Factory in a custom AWS Organizations structure. Account Factory with CfCT ensures every new account is enrolled with baseline security controls applied before any workloads are deployed, closing the gap where accounts were previously created without governance controls in place.

### Alternatives Considered

1. **Custom AWS Organizations structure without Control Tower** — provides maximum flexibility in OU design and SCP structure, but requires significant custom development to replicate Control Tower's guardrail library, compliance dashboard, Account Factory automation, and enrolment workflow; creates high ongoing operational overhead for the CCoE to maintain a bespoke landing zone solution.
2. **AWS Landing Zone Accelerator (LZA)** — more prescriptive and faster to deploy than a fully custom solution; however, LZA is CloudFormation-native and would introduce complexity alongside the Terraform-primary toolchain decision (ADR-001). Control Tower's managed service model reduces the operational burden on the CCoE compared to managing LZA stack updates.

### Trade-offs

1. **Control Tower constraints** — Control Tower enforces specific landing zone patterns that limit certain customisations, including management account email domain requirements and restrictions on management account resource creation; these constraints are acceptable given the programme scope.
2. **Account enrolment sequencing** — existing accounts must be enrolled in Control Tower in a specific sequence to avoid guardrail conflicts; this requires a phased enrolment plan and per-account remediation of any pre-existing non-compliant configuration before enrolment.
3. **Control Tower version lag** — new AWS service features or SCP patterns may not be immediately available via Control Tower-managed guardrails; the CCoE monitors Control Tower release notes and applies updates as part of the quarterly governance review cadence.

### Consequences

- All 20+ existing accounts are enrolled in Control Tower during Phase 0, with a sequenced enrolment plan addressing pre-existing non-compliant configuration.
- New accounts are vended exclusively via Account Factory from Phase 0 onwards; manual account creation is prohibited by SCP.
- The five-OU structure governs SCP inheritance for the lifetime of the programme; changes to the OU hierarchy require CCoE approval and impact assessment.
- Sandbox OU accounts are subject to time-bounded vending and automatic decommissioning after the defined active period.
- Control Tower becomes a critical dependency; the CCoE team includes at least one practitioner with Control Tower operational expertise.

---

## ADR-003: Identity and Access Management Strategy

### Title

Identity and Access Management Strategy

### Status

Accepted

### Date

Phase 0 (Foundation & Discovery)

### Context

Per-account IAM users with long-lived credentials are the current human access model across XYZ Corporation's AWS estate. Long-lived access keys are widespread, root MFA is not universally enforced, and there is no centralised access governance. Joiner-mover-leaver processes are manually executed per account, creating significant risk of stale or over-privileged access. This posture is a critical Security pillar gap and the primary contributor to the 1.5/5 Security WAF baseline score. The programme requires a centralised, auditable, credential-free human access model before any production workload migration or security remediation can be considered complete.

### Decision

Adopt AWS IAM Identity Center (formerly AWS SSO) as the sole mechanism for human access to all AWS accounts. Federate IAM Identity Center with an external Identity Provider (IdP) — Azure Active Directory or Okta — via SAML 2.0 for authentication and SCIM for automated user and group lifecycle management. Define permission sets aligned to least-privilege job roles (ReadOnly, Developer, PlatformEngineer, SecurityAnalyst, BillingAdmin). Remove all per-account IAM users with console access and rotate or remove all human-associated long-lived IAM access keys during Phase 0 and Phase 1.

### Rationale

1. **Centralised identity governance** — a single identity plane across all 20+ accounts eliminates the per-account IAM user sprawl that makes joiner-mover-leaver processes operationally intensive and error-prone.
2. **No long-lived credentials** — IAM Identity Center issues temporary credentials per-session; no static access keys are distributed to human identities, removing the primary credential theft attack vector.
3. **IdP as system of record** — user lifecycle events (provisioning, role changes, off-boarding) are managed in the existing corporate IdP via SCIM, reducing duplicate identity management processes and ensuring access is removed promptly when employees leave.
4. **Least-privilege permission sets** — role-aligned permission sets reduce the blast radius of compromised identities and provide a consistent, reviewable access model across all accounts.

### Alternatives Considered

1. **Centralised IAM users in a jump account with cross-account roles** — simplifies tooling and avoids IdP federation dependency; however, it still requires per-account IAM role management, does not eliminate long-lived credentials for the jump account users themselves, and does not integrate with the corporate IdP for automated lifecycle management.
2. **Per-account IAM users with shared password policies** — this is the current state; rejected because it does not scale across 20+ accounts, creates material joiner-mover-leaver risk, cannot enforce consistent MFA policy across all accounts, and requires manual access reviews that are not operationally sustainable.

### Trade-offs

1. **IdP availability dependency** — if the external IdP experiences an outage, human access to AWS via IAM Identity Center is interrupted. Mitigated by: (a) maintaining a documented break-glass procedure using the Management Account root credential protected by a hardware MFA token, and (b) a CCoE break-glass IAM user in the Management Account only, whose credentials are stored in a physical secure facility.
2. **Permission set proliferation** — as the organisation grows, the number of permission sets may grow unbounded. Mitigated by defining a minimal, role-aligned set from the outset and requiring CCoE approval for any new permission sets via a formal change request.
3. **SCIM provisioning latency** — group membership changes in the IdP may take minutes to propagate to IAM Identity Center via SCIM; this latency is acceptable for non-emergency access changes. Emergency access uses the break-glass procedure.

### Consequences

- All long-lived IAM access keys associated with human identities are rotated or removed during Phase 0 and Phase 1.
- The SCP denying IAM user creation with console access is applied organisation-wide from Phase 1; the Management Account is the sole exception, limited to the break-glass IAM user.
- Machine identities (EC2 Instance Profiles, Lambda execution roles, ECS task roles) are unaffected by this decision and continue to use IAM roles without requiring IAM Identity Center.
- CI/CD pipelines use OIDC-based role assumption rather than long-lived access keys, eliminating static credential storage in pipeline configuration.
- IAM Access Analyzer is enabled organisation-wide from Phase 0 to detect unintended public or cross-account resource access and to validate that the IAM Identity Center permission sets do not grant unintended access paths.

---

## ADR-004: Centralised Security Tooling

### Title

Centralised Security Tooling

### Status

Accepted

### Date

Phase 1 (Security & Governance)

### Context

XYZ Corporation has no centralised security posture management, no unified findings aggregation, and no automated threat detection across its AWS estate. Security findings are siloed per account where any detection tooling exists at all. There is no systematic vulnerability scanning of compute workloads, no centralised WAF enforcement, and no automated response capability. The transformation programme targets a Security Hub score of ≥85% across AWS Foundational Security Best Practices controls and a Mean Time to Detect (MTTD) for HIGH and CRITICAL severity events of under one hour. These targets cannot be achieved without a unified, organisation-wide security tooling architecture.

### Decision

Deploy AWS Security Hub in aggregator mode with the Audit Account as the delegated administrator, serving as the unified security findings platform across the organisation. Enable Amazon GuardDuty organisation-wide via delegated administration from the Audit Account. Enable AWS Inspector v2 for continuous vulnerability scanning of EC2 instances, Lambda functions, and Amazon ECR container images. Deploy AWS Firewall Manager with the Audit Account as administrator for centralised WAF rule deployment to all public-facing Application Load Balancers and CloudFront distributions. Configure AWS Audit Manager with applicable compliance frameworks for continuous, automated evidence collection.

### Rationale

1. **Unified findings surface** — Security Hub aggregates findings from GuardDuty, Inspector v2, Amazon Macie, Firewall Manager, and AWS Config into a single, prioritised findings view, eliminating the per-account security review burden and enabling the automated response pipeline.
2. **Automated enrolment** — delegated administration via AWS Organizations enrols all member accounts automatically at vending time via Account Factory, ensuring no account is ever outside the security monitoring perimeter.
3. **Native integration** — all five services integrate natively with AWS Organizations, requiring no per-account manual configuration and no third-party connector development or maintenance.
4. **Automated response pipeline** — Security Hub findings trigger an EventBridge rule that fans out via Amazon SNS to email, PagerDuty/OpsGenie, Lambda remediation functions, and ITSM ticket creation, achieving the MTTD target without requiring a full SIEM deployment at programme Phase 1.

### Alternatives Considered

1. **Third-party SIEM as primary platform (e.g., Splunk, Microsoft Sentinel)** — provides richer cross-event correlation, advanced threat hunting, and unified log analysis; however, it requires full log ingestion pipelines from all accounts, significant SIEM configuration effort, and ongoing platform licensing cost. The native AWS toolchain achieves the programme's MTTD target and Security Hub score target at lower cost and complexity for Phase 1; SIEM integration is defined as a future capability boundary in the Security & Governance Design.
2. **Amazon GuardDuty alone, without Security Hub** — GuardDuty provides excellent ML-based threat detection but lacks unified findings management across multiple detection sources, compliance benchmark scoring, Config rule integration, and the structured findings format required by the automated response pipeline. Security Hub is the necessary aggregation layer.

### Trade-offs

1. **No full SIEM correlation** — the native toolchain does not provide cross-event correlation rules or advanced threat hunting capabilities available in full SIEM platforms. This is an accepted gap for Phase 1; the SIEM integration boundary is defined in the Security & Governance Design to allow a SIEM to be added at Phase 2 or later without re-architecting the logging pipeline.
2. **AWS Systems Manager Agent dependency** — Inspector v2 EC2 scanning requires the AWS Systems Manager Agent to be installed and reporting on all EC2 instances. Mitigated by the Golden AMI pipeline (Platform & IaC Design) pre-installing SSM Agent on all standard base images.
3. **AWS WAF count mode transition** — Firewall Manager WAF rules are initially deployed in count (monitoring) mode to avoid false-positive blocking of legitimate traffic. Transitioning to block mode requires a tuning period and stakeholder approval; this creates a window where WAF rules are not enforcing, only observing.

### Consequences

- Security Hub, GuardDuty, Inspector v2, Firewall Manager, and Audit Manager are all enabled organisation-wide during Phase 1.
- The Audit Account is the delegated administrator for all five services; the Security OU enforces SCP controls preventing member accounts from disabling or opting out of these services.
- The automated response pipeline (EventBridge rule → SNS topic → Lambda remediation functions) is deployed in the Audit Account and maintained by the CCoE security team.
- The SIEM integration boundary (S3 export or Kinesis Data Firehose stream from the Log Archive Account) is defined and documented but SIEM procurement and deployment are deferred to Phase 2 or beyond.
- Audit Manager compliance framework selection (PCI-DSS, HIPAA, SOC 2) is finalised during Phase 0 discovery; evidence collection begins at Phase 1 enablement.

---

## ADR-005: Secrets Management Strategy

### Title

Secrets Management Strategy

### Status

Accepted

### Date

Phase 1 (Security & Governance)

### Context

Application secrets — including database credentials, API keys, and OAuth tokens — are currently hard-coded in source code repositories or stored in plaintext EC2 instance user data and environment variables across XYZ Corporation's AWS estate. This practice is a primary contributor to the Security pillar baseline score of 1.5/5. Hard-coded and plaintext secrets create credential theft risk, are not rotated on any defined cycle, and leave no audit trail of access. All secrets must be migrated to a managed, auditable secrets service before production workloads can be considered compliant with the programme's security baseline.

### Decision

Standardise on AWS Secrets Manager for all dynamic secrets requiring automatic rotation, including database credentials, API keys, and OAuth tokens. Use AWS Systems Manager Parameter Store (SecureString tier) for static configuration values that do not require rotation, such as feature flags, non-sensitive connection strings, and application configuration parameters. Applications retrieve secrets at runtime via the Secrets Manager SDK or Parameter Store API; secrets are never stored in source code, environment variable plaintext, or EC2 instance user data.

### Rationale

1. **Rotation capability** — Secrets Manager provides native automatic rotation for Amazon RDS, Amazon Redshift, and Amazon DocumentDB via built-in rotation Lambda functions, eliminating the manual rotation processes that are the primary cause of long-lived credential exposure in the current state.
2. **Cost optimisation** — Parameter Store SecureString has a significantly lower per-parameter cost than Secrets Manager for high-volume static configuration values; using both services in their optimal use cases minimises cost while retaining full security properties (KMS encryption, CloudTrail audit trail) for all stored values.
3. **Immutable audit trail** — both services integrate with AWS CloudTrail, providing an immutable record of every secret read, write, rotation, and deletion event, satisfying audit and compliance evidence requirements.

### Alternatives Considered

1. **HashiCorp Vault** — provides richer secrets management capabilities including dynamic secrets for non-AWS services, PKI management, and SSH certificate management; however, it introduces significant operational overhead for high-availability deployment, upgrade management, and licence cost. These capabilities are out of scope for the current programme phase; Vault may be evaluated in a future phase if dynamic secrets for non-AWS services become a requirement.
2. **Application-level KMS envelope encryption** — adds encryption-at-rest to secrets stored in application configuration but does not solve the credential distribution and rotation problem. Secrets are still stored somewhere accessible to the application, just encrypted; the fundamental exposure of hard-coded or configuration-file-stored credentials is not addressed.

### Trade-offs

1. **Migration effort** — Phase 1 requires a comprehensive secrets inventory across source repositories, CI/CD variable stores, EC2 instance user data, and environment variables across all 20+ accounts. This is a significant discovery and migration effort requiring tooling (IAM Access Analyzer, Amazon CodeGuru Reviewer, and custom repository scanning) and per-application migration coordination.
2. **Cost at scale** — Secrets Manager charges per secret per month; for organisations with thousands of secrets, the recurring cost can be material. Mitigated by the two-service strategy: using Parameter Store for static values and reserving Secrets Manager only for secrets with rotation requirements, optimising the cost profile while retaining appropriate service capability.
3. **Cross-account access complexity** — accessing Secrets Manager secrets from workloads in a different account requires explicit resource-based policies on the secret and appropriate IAM permissions on the calling role; this adds configuration complexity for workloads that span multiple accounts, requiring documentation and module-level support in the Terraform module library.

### Consequences

- All hard-coded and plaintext secrets across source repositories, CI/CD configuration, and EC2 instance user data are inventoried and revoked during Phase 1. Replacement secrets are provisioned in Secrets Manager or Parameter Store and applications are updated to retrieve secrets at runtime.
- IAM Access Analyzer and Amazon CodeGuru Reviewer (where applicable to the technology stack) are used to detect new hard-coded credential patterns introduced in code reviews from Phase 1 onwards, providing a continuous prevention control.
- The Terraform module library includes a Secrets Manager module and a Parameter Store module with standardised KMS encryption and resource-based policy patterns to simplify cross-account secret access.
- Rotation schedules for all Secrets Manager-managed secrets are configured at migration time; rotation failure alarms are configured in Amazon CloudWatch to alert the owning team.

---

## ADR-006: DR Strategy and Workload Tiering

### Title

DR Strategy and Workload Tiering

### Status

Accepted

### Date

Phase 0 (Foundation & Discovery) — tiering model; Phase 3 (Reliability & DR) — implementation

### Context

No XYZ Corporation workloads have documented Recovery Time Objective (RTO) or Recovery Point Objective (RPO) targets. There is no consistent DR pattern across the estate — some workloads use multi-AZ deployments by default, others are single-AZ with no standby, and there is no chaos engineering practice to validate that DR mechanisms actually function. The Reliability WAF pillar baseline score is 2.0/5, and the programme target is 3.5/5. The programme must achieve 100% Tier 1 workload DR-validated status — meaning all critical workloads have both a documented and a tested DR capability — within the programme lifecycle. Without a tiering framework, applying consistent DR investment across 2,000+ workloads of varying business criticality would be either prohibitively expensive (if the most costly DR patterns are applied universally) or operationally incoherent (if DR patterns are chosen ad hoc).

### Decision

Define a four-tier workload classification model based on business criticality, ranging from Tier 1 (Mission Critical) through Tier 4 (Standard), with explicit RTO and RPO targets per tier. Require multi-AZ deployment as the minimum resilience pattern for Tier 1 and Tier 2 workloads. Apply multi-region active-passive DR for Tier 1 workloads that meet defined trigger criteria (revenue impact, regulatory requirement, or reputational risk assessment). Mandate AWS Fault Injection Simulator (FIS) validation for all Tier 1 workloads before DR-validated status is formally granted.

| Tier | Label | RTO | RPO |
|---|---|---|---|
| Tier 1 | Mission Critical | ≤ 1 hour | ≤ 15 minutes |
| Tier 2 | Business Critical | ≤ 4 hours | ≤ 1 hour |
| Tier 3 | Standard | ≤ 24 hours | ≤ 4 hours |
| Tier 4 | Non-Critical | ≤ 72 hours | ≤ 24 hours |

### Rationale

Risk-proportionate investment is the governing principle: the four-tier model ensures that the most costly DR patterns — multi-region active-passive with real-time data replication — are applied only to workloads where the business impact of extended outage justifies the cost. Tier 4 workloads do not require standby environments; backup and restore from AWS Backup is sufficient and cost-effective. Mandatory AWS FIS validation provides objective, evidence-based DR assurance rather than relying on theoretical architecture reviews. The tiering register created during Phase 0 gives the programme a factual basis for DR investment prioritisation rather than deferring the conversation to individual application owners.

### Alternatives Considered

1. **Single DR standard for all workloads** — applying multi-AZ to all 2,000+ workloads regardless of criticality would represent significant over-investment for Tier 3 and Tier 4 workloads; the associated standby infrastructure cost and operational complexity would be cost-prohibitive and would not deliver proportionate business value.
2. **Two-tier model (critical / non-critical)** — simpler governance overhead, but lacks the granularity to distinguish Tier 2 (4-hour RTO, multi-AZ required) from Tier 3 (24-hour RTO, backup and restore sufficient) workloads. Both tiers would require the same DR investment despite materially different business impact profiles, resulting in either over-investment in Tier 3 workloads or under-investment in Tier 2 workloads.

### Trade-offs

1. **Tiering governance overhead** — maintaining a formal tiering register and conducting an annual review cycle adds governance overhead; mitigated by embedding the tiering review in the existing FinOps quarterly cadence, where multi-region DR cost impact is already visible through the CUDOS dashboard.
2. **Tier assignment subjectivity** — application owners may over-classify workloads as Tier 1 to receive higher DR investment; mitigated by CCoE arbitration using the cost visibility that the FinOps cadence provides (multi-region DR has a measurable and visible cost differential) and a formal business impact assessment template.
3. **FIS experiment risk** — chaos engineering experiments on production workloads carry inherent risk of inadvertent customer impact. Mitigated by mandatory stop conditions, defined blast radius controls, off-peak execution windows, and the CCoE approval gate process defined in the Reliability & DR Design.

### Consequences

- A tiering register is produced for all 40+ business applications during Phase 0. The register records the tier assignment, RTO/RPO targets, DR pattern requirement, and FIS validation status for each workload.
- Tier 1 workloads are identified and their multi-region DR trigger criteria assessed during Phase 0 to inform the Phase 3 DR implementation scope and budget.
- DR pattern implementation (multi-AZ configuration, AWS Backup policies, Route 53 health checks, cross-region replication) follows the tiering register sequencing in Phases 2 and 3.
- All Tier 1 workloads must pass the defined FIS experiment suite — covering instance termination, AZ failure simulation, and network latency injection — before the programme formally declares Reliability phase completion.
- The tiering register is a living document reviewed annually and updated following any material change to a workload's business criticality, technical architecture, or regulatory status.

---

## ADR-007: FinOps Tooling and Reporting

### Title

FinOps Tooling and Reporting

### Status

Accepted

### Date

Phase 0 (Foundation & Discovery)

### Context

XYZ Corporation has no cost visibility beyond the AWS Billing console, no resource tagging strategy, no automated anomaly detection, and no FinOps operating cadence. The Cost Optimisation WAF pillar baseline is 1.0/5, the lowest of all six pillars. The absence of structured cost visibility means there is no mechanism to detect unexpected spend, attribute costs to business units, or make data-driven commitment purchasing decisions. The programme targets a 25–40% reduction in annual AWS costs and a tagging compliance rate of ≥95% across the estate. Achieving these targets requires a structured cost data architecture, a purpose-built visibility layer, and an operating cadence that embeds cost accountability across engineering and finance stakeholders.

### Decision

Adopt AWS Cost and Usage Reports (CUR) exported to a dedicated analytics account in Parquet format as the primary cost data source, with hourly granularity and resource-level attribution enabled. Deploy the CUDOS (Cost and Usage Dashboard Operations Solution) QuickSight dashboard on top of CUR for executive and team-level cost visibility. Use AWS Cost Anomaly Detection for proactive spend monitoring, configured with monitors at the organisation level, per-linked-account, and per-service. Integrate AWS Compute Optimizer organisation-wide to provide rightsizing recommendations for EC2, Auto Scaling Groups, RDS, Lambda, and Amazon ECS workloads as part of the monthly FinOps operating cadence.

### Rationale

1. **CUR data fidelity** — CUR is the most granular and comprehensive cost data source available in AWS; Parquet format with hourly granularity enables efficient Athena-based cost analysis and supports anomaly detection at the individual resource level, which is not possible with Cost Explorer's aggregated view.
2. **CUDOS operational efficiency** — CUDOS is an AWS-maintained, regularly updated QuickSight solution purpose-built for FinOps reporting; it provides account-level, service-level, and tag-based cost views without requiring custom dashboard development by the CCoE team, reducing time-to-value.
3. **ML-based anomaly detection** — Cost Anomaly Detection uses machine learning baseline modelling to detect unusual spend patterns without requiring the CCoE to manually configure per-service thresholds across 20+ accounts and dozens of services; this capability scales automatically as the estate grows.
4. **Native toolchain cost-effectiveness** — the native AWS toolchain achieves the programme's cost visibility and optimisation targets without requiring a third-party FinOps platform licence at Phase 0–2, avoiding an additional vendor dependency and recurring licence cost during the programme's foundational phases.

### Alternatives Considered

1. **Third-party FinOps platforms (e.g., CloudHealth, Apptio Cloudability, Spot.io)** — these platforms provide richer capabilities for commitment optimisation, reserved instance marketplace management, and showback/chargeback reporting; however, they add platform licence cost, require exporting billing data to a third-party service, and introduce a vendor dependency for a core financial governance function. Deferred for evaluation at Phase 2 checkpoint if the native toolchain proves insufficient for commitment optimisation at scale.
2. **Manual AWS Cost Explorer reporting** — viable for initial cost visibility across a small number of accounts but does not scale to 20+ accounts; lacks the automated anomaly detection, Athena-based ad-hoc query capability, and structured tag-based attribution model required to achieve the programme's ≥95% tagging compliance and 25–40% cost reduction targets.

### Trade-offs

1. **CUDOS deployment effort** — CUDOS requires Amazon QuickSight Enterprise Edition and a one-time deployment effort to configure the CUR S3 bucket, AWS Glue crawler, Athena workgroup, and QuickSight data source. This is a known, well-documented deployment procedure but requires dedicated CCoE effort at Phase 1.
2. **QuickSight Enterprise Edition licensing** — QuickSight Enterprise Edition per-user licensing adds a recurring cost. Mitigated by limiting CUDOS reader access to the FinOps team, Engineering leads, and Finance business partners rather than all account owners; direct cost attribution data is surfaced to application teams via automated SNS alerts and the monthly cost summary rather than direct dashboard access.
3. **Athena query cost on CUR data** — high-volume ad-hoc Athena queries on unpartitioned CUR data can accumulate material query scan costs. Mitigated by configuring AWS Glue partitions on the CUR S3 prefix (by year and month) and setting Athena workgroup query scan limits to bound per-query cost.

### Consequences

- CUR is enabled in the Management Account and delivered to the dedicated analytics account in Parquet format from Phase 0; the data pipeline (S3 → Glue crawler → Athena → QuickSight) is deployed and operational by the end of Phase 0.
- CUDOS is deployed and accessible to the FinOps team and Engineering leads from Phase 1, coinciding with the launch of the FinOps operating cadence.
- Cost Anomaly Detection monitors are activated at organisation level and per-linked-account from Phase 1; anomaly alerts are delivered via SNS to cost-owner distribution lists.
- AWS Compute Optimizer is enabled organisation-wide from Phase 2; rightsizing recommendations are incorporated into the monthly FinOps operating cadence and tracked in the commitment planning register.
- The FinOps operating cadence — weekly team-level cost reviews, monthly executive cost summaries, and quarterly commitment planning and Savings Plan / Reserved Instance adjustment cycles — is launched from Phase 1 alongside the CUDOS rollout.
- Third-party FinOps platform evaluation is scheduled for the Phase 2 checkpoint review if native toolchain capabilities prove insufficient for commitment optimisation complexity at scale.

---

*End of ADR Catalog*
