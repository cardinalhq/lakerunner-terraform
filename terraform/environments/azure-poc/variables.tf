#####################
# Environment & Naming
#####################
variable "installation_id" {
  description = "3-10 chars, lowercase/number; used in names"
  type        = string
  default     = "poc"
}

variable "environment" {
  type    = string
  default = "poc"
}

variable "labels" {
  description = "Tags/labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

#####################
# Storage
#####################
variable "storage_account_basename" {
  description = "Base name for the Storage Account (suffix added for global uniqueness)"
  type        = string
  default     = "lakerunnerpoc"
}

#####################
# Networking
#####################
variable "address_space" {
  type    = list(string)
  default = ["10.42.0.0/16"]
}

variable "subnet_cidr" {
  type    = list(string)
  default = ["10.42.1.0/24"]
}

#####################
# VM (optional convenience VM)
#####################
variable "create_vm" {
  type    = bool
  default = false
}

variable "vm_name" {
  type    = string
  default = "lakerunner-poc-vm"
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "admin_username" {
  type    = string
  default = "lakerunner"
}

variable "ssh_public_key" {
  description = "SSH public key for the VM admin account"
  type        = string
}

#####################
# PostgreSQL
#####################
variable "create_postgresql" {
  type    = bool
  default = true
}

variable "pg_admin_user" {
  type    = string
  default = "lakerunner"
}

variable "pg_admin_password" {
  type      = string
  sensitive = true
}

variable "postgresql_database_name" {
  type    = string
  default = "lakerunner"
}

variable "postgresql_version" {
  type    = string
  default = "16"
}

variable "postgresql_sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgresql_storage_mb" {
  type    = number
  default = 32768
}

#####################
# AKS (GKE analog)
#####################
variable "enable_aks" {
  type    = bool
  default = false
}

variable "aks_cluster_name" {
  type    = string
  default = "lakerunner-poc-aks"
}

variable "aks_dns_prefix" {
  type    = string
  default = "lakerunner-poc"
}

variable "aks_node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "aks_user_node_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "aks_node_os_disk_gb" {
  type    = number
  default = 60
}

variable "aks_enable_autoscaling" {
  type    = bool
  default = true
}

variable "aks_min_count" {
  type    = number
  default = 1
}

variable "aks_max_count" {
  type    = number
  default = 3
}

variable "aks_use_spot" {
  type    = bool
  default = false
}

variable "aks_spot_max_price" {
  type    = number
  default = -1
}

variable "aks_kubernetes_version" {
  type    = string
  default = ""
}

variable "aks_network_plugin" {
  description = "azure (CNI) or kubenet"
  type        = string
  default     = "azure"
}

variable "aks_network_policy" {
  type    = string
  default = "azure"
}

variable "aks_private_cluster_enabled" {
  type    = bool
  default = false
}

variable "aks_enable_workload_identity" {
  type    = bool
  default = true
}

#####################
# Eventing (Pub/Sub analog)
#####################
variable "event_exclude_prefixes" {
  description = "Blob path prefixes to exclude from notifications (e.g. [\"db/\"])"
  type        = list(string)
  default     = ["db/"]
}

#####################
# Kafka analog
#####################
variable "enable_kafka" {
  type    = bool
  default = false
}

variable "eventhub_sku" {
  type    = string
  default = "Standard"
}

variable "eventhub_capacity" {
  type    = number
  default = 1
}
