# 🏔️ Terraform

> Multi-cloud Infrastructure as Code with reusable, versioned modules.

---

## Module Library

### AWS Modules

| Module | Description |
|--------|-------------|
| [aws/vpc](aws/) | VPC with public, private, isolated subnets |
| [aws/transit-gateway](aws/) | TGW with route table segmentation |
| [aws/organization](aws/) | AWS Organizations with OUs and SCPs |
| [aws/security-baseline](aws/) | Account-level security hardening |
| [aws/guardduty](aws/) | Organization-wide threat detection |
| [aws/cloudtrail](aws/) | Organization audit trail |

### Azure Modules

| Module | Description |
|--------|-------------|
| [azure/vnet](azure/) | Virtual Network with subnet tiers |
| [azure/aks](azure/) | Managed Kubernetes cluster |
| [azure/sql](azure/) | Azure SQL with geo-replication |

### GCP Modules

| Module | Description |
|--------|-------------|
| [gcp/vpc](gcp/) | VPC with shared VPC support |
| [gcp/gke](gcp/) | GKE cluster with node pools |

## Standards

- All modules pinned to >= Terraform 1.6
- Provider versions pinned with `~>` constraints
- Every module includes: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`
- All variables have descriptions and type constraints
- All outputs have descriptions
- Default tags applied via provider `default_tags`

---

➡️ [Back to Portfolio](../)
