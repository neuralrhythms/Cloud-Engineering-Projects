variable "project" {
  description = "Project name used as a prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster (must be an AWS-supported version)"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for EKS worker nodes"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for EKS etcd secret encryption"
  type        = string
}

variable "endpoint_private_access" {
  description = "Enable private endpoint access to the EKS API server"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public endpoint access to the EKS API server (disabled in production)"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS API endpoint (if enabled)"
  type        = list(string)
  default     = []
}

variable "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS cluster"
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the IAM role for EKS managed node groups"
  type        = string
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types  = list(string)
    capacity_type   = string # ON_DEMAND or SPOT
    min_size        = number
    max_size        = number
    desired_size    = number
    disk_size       = number
    max_unavailable = number
    labels          = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {
    general = {
      instance_types  = ["m5.xlarge"]
      capacity_type   = "ON_DEMAND"
      min_size        = 3
      max_size        = 20
      desired_size    = 5
      disk_size       = 100
      max_unavailable = 1
      labels = {
        "node.kubernetes.io/workload-type" = "general"
      }
      taints = []
    }
  }
}

variable "eks_addons" {
  description = "Map of EKS managed add-on configurations"
  type = map(object({
    addon_version     = string
    resolve_conflicts = string
  }))
  default = {}
}

variable "platform_admin_role_arn" {
  description = "ARN of the IAM role for platform administrators (EKS Access Entry)"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for EKS control plane logs"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
