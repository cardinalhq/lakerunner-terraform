variable "project_id" {
  description = "The GCP project ID for your POC environment"
  type        = string
}

variable "installation_id" {
  description = "Unique identifier for this installation (allows multiple POCs in same project)"
  type        = string
  default     = "poc"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.installation_id))
    error_message = "Installation ID must be 3-10 characters, start with a letter, then letters and numbers only."
  }
}

variable "region" {
  description = "GCP region for POC resources (choose closest to you)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for POC resources"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "poc"
}

variable "labels" {
  description = "Labels to apply to all taggable resources"
  type        = map(string)
  default     = {}
}

# Network Configuration - now using dedicated VPC
# Note: vpc_name and subnet_name are now created dynamically

# Kubernetes Configuration
variable "enable_gke" {
  description = "Enable GKE cluster for container workloads"
  type        = bool
  default     = true
}

variable "gke_min_nodes" {
  description = "Minimum number of nodes in the GKE node pool"
  type        = number
  default     = 1
}

variable "gke_max_nodes" {
  description = "Maximum number of nodes in the GKE node pool"
  type        = number
  default     = 10
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "gke_use_spot" {
  description = "Use spot instances for GKE nodes"
  type        = bool
  default     = true
}

variable "gke_disk_size_gb" {
  description = "Disk size in GB for GKE nodes"
  type        = number
  default     = 50
}

# PostgreSQL Configuration
variable "create_postgresql" {
  description = "Create new PostgreSQL instance (true) or use existing (false)"
  type        = bool
  default     = true
}

variable "postgresql_instance_name" {
  description = "PostgreSQL instance name - used for new instance creation or existing instance reference"
  type        = string
  default     = ""
}

variable "postgresql_database_name" {
  description = "PostgreSQL database name for Lakerunner"
  type        = string
  default     = "lakerunner"
}

variable "postgresql_configdb_name" {
  description = "PostgreSQL configdb database name for Lakerunner"
  type        = string
  default     = "config"
}

variable "postgresql_user" {
  description = "PostgreSQL username for Lakerunner"
  type        = string
  default     = "lakerunner"
}

variable "postgresql_password" {
  description = "PostgreSQL password for Lakerunner (leave empty for auto-generation)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgresql_machine_type" {
  description = "PostgreSQL machine type"
  type        = string
  default     = "db-custom-1-3840"
}

variable "postgresql_disk_size_gb" {
  description = "PostgreSQL disk size in GB"
  type        = number
  default     = 10
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_17"
}

variable "postgresql_edition" {
  description = "PostgreSQL edition (ENTERPRISE or ENTERPRISE_PLUS)"
  type        = string
  default     = "ENTERPRISE"
}