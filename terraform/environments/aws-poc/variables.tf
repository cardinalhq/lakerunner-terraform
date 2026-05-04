#####################
# Environment & naming
#####################
variable "installation_id" {
  description = "Unique identifier for this installation (3-10 chars, lowercase + digits, must start with a letter)"
  type        = string
  default     = "poc"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.installation_id))
    error_message = "Installation ID must be 3-10 characters, start with a letter, then letters and numbers only."
  }
}

variable "region" {
  description = "AWS region for POC resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "poc"
}

variable "tags" {
  description = "Additional tags applied to all resources"
  type        = map(string)
  default     = {}
}

#####################
# Networking
#####################
variable "vpc_cidr" {
  description = "CIDR block for the dedicated POC VPC"
  type        = string
  default     = "10.0.0.0/16"
}

#####################
# PostgreSQL (RDS)
#####################
variable "create_postgresql" {
  description = "Create an RDS Postgres instance for Lakerunner"
  type        = bool
  default     = true
}

variable "postgresql_engine_version" {
  description = "Postgres engine major version"
  type        = string
  default     = "18"
}

variable "postgresql_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"
}

variable "postgresql_allocated_storage" {
  description = "Allocated storage (GB) for the RDS instance"
  type        = number
  default     = 20
}

variable "postgresql_database_name" {
  description = "Initial database name (created by RDS itself)"
  type        = string
  default     = "lakerunner"
}

variable "postgresql_configdb_name" {
  description = "Second database for Lakerunner configdb (created via the postgresql provider)"
  type        = string
  default     = "config"
}

variable "postgresql_username" {
  description = "Postgres master username"
  type        = string
  default     = "lakerunner"
}

variable "postgresql_password" {
  description = "Postgres master password (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgresql_allowed_cidr" {
  description = "External CIDRs allowed to reach RDS on 5432. Defaults to 0.0.0.0/0 for POC ease; tighten for any real use."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

#####################
# EKS
#####################
variable "enable_eks" {
  description = "Provision an EKS cluster + node group + IRSA role for Lakerunner"
  type        = bool
  default     = true
}

variable "eks_kubernetes_version" {
  description = "EKS control plane Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "eks_node_min" {
  description = "Minimum nodes in the managed node group"
  type        = number
  default     = 1
}

variable "eks_node_max" {
  description = "Maximum nodes in the managed node group"
  type        = number
  default     = 10
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "eks_node_use_spot" {
  description = "Use SPOT capacity for the managed node group"
  type        = bool
  default     = true
}

variable "eks_node_disk_size" {
  description = "EBS volume size (GB) for nodes"
  type        = number
  default     = 50
}
