##############
# Storage
##############
output "lakerunner_container_name" {
  value       = azurerm_storage_container.lakerunner.name
  description = "Main container name"
}

output "lakerunner_container_url" {
  value       = "https://${azurerm_storage_account.sa.name}.blob.core.windows.net/${azurerm_storage_container.lakerunner.name}"
  description = "Blob URL for the main container"
}

output "storage_account_name" {
  value       = azurerm_storage_account.sa.name
  description = "Storage account name (global unique)"
}

output "storage_account_access_key" {
  value       = azurerm_storage_account.sa.primary_access_key
  sensitive   = true
  description = "Use with Azure Blob SDK/CLI (no S3 API)"
}

output "event_queue_name" {
  value       = azurerm_storage_queue.notifications.name
  description = "Queue receiving BlobCreated events (db/ excluded)"
}

##############
# Environment
##############
output "location" {
  value       = var.location
  description = "Azure region used"
}

##############
# Networking
##############
output "vnet_name" { value = azurerm_virtual_network.vnet.name }
output "subnet_name" { value = azurerm_subnet.subnet.name }
output "subnet_cidr" { value = azurerm_subnet.subnet.address_prefixes }

##############
# PostgreSQL
##############
output "postgresql_fqdn" {
  value       = var.create_postgresql ? azurerm_postgresql_flexible_server.pg[0].fqdn : null
  description = "PG server FQDN"
}

output "postgresql_connection_string" {
  value       = var.create_postgresql ? "postgresql://${var.pg_admin_user}:${var.pg_admin_password}@${azurerm_postgresql_flexible_server.pg[0].fqdn}:5432/${var.postgresql_database_name}?sslmode=require" : null
  sensitive   = true
  description = "App connection string"
}

##############
# AKS
##############
output "aks_cluster_name" {
  value       = var.enable_aks ? azurerm_kubernetes_cluster.aks[0].name : null
  description = "AKS cluster name (null if disabled)"
}

output "aks_kube_config" {
  value       = var.enable_aks ? azurerm_kubernetes_cluster.aks[0].kube_config_raw : null
  sensitive   = true
  description = "kubeconfig (null if AKS disabled)"
}

##############
# Kafka analog
##############
output "kafka_bootstrap_server" {
  value       = var.enable_kafka ? "${azurerm_eventhub_namespace.ehns[0].name}.servicebus.windows.net:9093" : null
  description = "Kafka-compatible bootstrap (SASL_SSL)"
}
