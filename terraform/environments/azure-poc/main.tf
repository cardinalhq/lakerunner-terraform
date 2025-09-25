locals {
  common_tags = merge(var.labels, {
    "lakerunner-id" = var.installation_id,
    "environment"   = var.environment,
    "managed-by"    = "terraform"
  })

  rg_name     = "lr-${var.installation_id}-rg"
  vnet_name   = "lr-${var.installation_id}-vnet"
  subnet_name = "lr-${var.installation_id}-subnet"
}

######################################
# Resource Group
######################################
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

######################################
# Storage (GCS bucket analog)
######################################
resource "random_string" "sa" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "sa" {
  name                     = substr(lower(replace("${var.storage_account_basename}${random_string.sa.result}", "/[^0-9a-z]/", "")), 0, 24)
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags

  blob_properties {
    versioning_enabled = false
  }

  timeouts { create = "60m" }
}

resource "azurerm_storage_container" "lakerunner" {
  name                  = "lakerunner"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

# 30-day auto-cleanup like GCS lifecycle
resource "azurerm_storage_management_policy" "cleanup" {
  storage_account_id = azurerm_storage_account.sa.id

  rule {
    name    = "poc-delete-30d"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_creation_greater_than = 30
      }
    }
  }
}

######################################
# Eventing: BlobCreated → Storage Queue
# (GCS Notification → Pub/Sub analog; excludes db/ by default)
######################################
resource "azurerm_storage_queue" "notifications" {
  name                 = "lr-${var.installation_id}-notifications"
  storage_account_name = azurerm_storage_account.sa.name
}

resource "azurerm_eventgrid_system_topic" "blob_topic" {
  name                   = "lr-${var.installation_id}-blob-topic"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  source_arm_resource_id = azurerm_storage_account.sa.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  tags                   = local.common_tags
}

resource "azurerm_eventgrid_system_topic_event_subscription" "blob_created" {
  name                = "lr-${var.installation_id}-sub"
  system_topic        = azurerm_eventgrid_system_topic.blob_topic.name
  resource_group_name = azurerm_resource_group.rg.name

  included_event_types = ["Microsoft.Storage.BlobCreated"]

  # Limit to the "lakerunner" container
  subject_filter {
    subject_begins_with = "/blobServices/default/containers/${azurerm_storage_container.lakerunner.name}/blobs/"
  }

  # Exclude prefixes like db/
  dynamic "advanced_filter" {
    for_each = var.event_exclude_prefixes
    content {
      string_not_begins_with {
        key    = "subject"
        values = ["/blobServices/default/containers/${azurerm_storage_container.lakerunner.name}/blobs/${advanced_filter.value}"]
      }
    }
  }

  storage_queue_endpoint {
    storage_account_id = azurerm_storage_account.sa.id
    queue_name         = azurerm_storage_queue.notifications.name
  }

  depends_on = [azurerm_storage_container.lakerunner]
}

######################################
# Networking (VPC analog)
######################################
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = var.address_space
  tags                = local.common_tags
}

resource "azurerm_subnet" "subnet" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_cidr
}

# NAT for outbound internet (Cloud NAT analog)
resource "azurerm_public_ip" "nat" {
  name                = "lr-${var.installation_id}-natpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway" "ngw" {
  name                = "lr-${var.installation_id}-nat"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.ngw.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "subnet_nat" {
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.ngw.id
}

# NSG (firewall rules analog)
resource "azurerm_network_security_group" "nsg" {
  name                = "lr-${var.installation_id}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # mimic broad internal allow from GCP POC
  security_rule {
    name                       = "allow-internal"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = concat(var.subnet_cidr, ["10.4.0.0/14", "10.8.0.0/20"])
    destination_address_prefix = "*"
  }

  # SSH
  security_rule {
    name                       = "allow-ssh"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "sga" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

######################################
# Convenience VM (optional)
######################################
resource "azurerm_public_ip" "vm" {
  count               = var.create_vm ? 1 : 0
  name                = "${var.vm_name}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vm" {
  count               = var.create_vm ? 1 : 0
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[0].id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  count                     = var.create_vm ? 1 : 0
  network_interface_id      = azurerm_network_interface.vm[0].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  count                           = var.create_vm ? 1 : 0
  name                            = var.vm_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  network_interface_ids           = [azurerm_network_interface.vm[0].id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = local.common_tags
}

######################################
# PostgreSQL Flexible Server (Cloud SQL analog)
######################################
resource "azurerm_postgresql_flexible_server" "pg" {
  count                         = var.create_postgresql ? 1 : 0
  name                          = "lr-${var.installation_id}-pg"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = var.postgresql_version
  sku_name                      = var.postgresql_sku_name
  storage_mb                    = var.postgresql_storage_mb
  administrator_login           = var.pg_admin_user
  administrator_password        = var.pg_admin_password
  zone                          = "1"
  backup_retention_days         = 7
  public_network_access_enabled = true
  tags                          = local.common_tags

  timeouts {
    create = "90m"
    delete = "90m"
  }
}

resource "azurerm_postgresql_flexible_server_database" "db_main" {
  count     = var.create_postgresql ? 1 : 0
  name      = var.postgresql_database_name
  server_id = azurerm_postgresql_flexible_server.pg[0].id
}

resource "azurerm_postgresql_flexible_server_database" "db_config" {
  count     = var.create_postgresql ? 1 : 0
  name      = "configdb"
  server_id = azurerm_postgresql_flexible_server.pg[0].id
}

######################################
# AKS (GKE analog) — OPTIONAL
######################################
resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.enable_aks ? 1 : 0
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = var.aks_kubernetes_version != "" ? var.aks_kubernetes_version : null

  default_node_pool {
    name                         = "system"
    vm_size                      = var.aks_node_vm_size
    vnet_subnet_id               = azurerm_subnet.subnet.id
    os_disk_size_gb              = var.aks_node_os_disk_gb
    only_critical_addons_enabled = false
    enable_auto_scaling          = var.aks_enable_autoscaling
    min_count                    = var.aks_min_count
    max_count                    = var.aks_max_count
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = var.aks_enable_workload_identity
  workload_identity_enabled = var.aks_enable_workload_identity

  network_profile {
    network_plugin = var.aks_network_plugin
    network_policy = var.aks_network_policy
    service_cidr   = "10.2.0.0/16"
    dns_service_ip = "10.2.0.10"
  }

  private_cluster_enabled = var.aks_private_cluster_enabled

  tags = local.common_tags
}

# Optional user node pool (Spot/autoscaling)
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.enable_aks ? 1 : 0
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[0].id
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.subnet.id
  vm_size               = var.aks_user_node_vm_size
  os_disk_size_gb       = var.aks_node_os_disk_gb

  priority       = var.aks_use_spot ? "Spot" : "Regular"
  spot_max_price = var.aks_use_spot ? var.aks_spot_max_price : null

  enable_auto_scaling = var.aks_enable_autoscaling
  min_count           = var.aks_min_count
  max_count           = var.aks_max_count

  tags = local.common_tags
}

######################################
# Kafka analog → Event Hubs (Kafka-compatible)
# NOTE: Experimental/untested with LakeRunner. This block is gated by
# var.enable_kafka and can be disabled or removed later if not needed.
######################################
resource "azurerm_eventhub_namespace" "ehns" {
  count               = var.enable_kafka ? 1 : 0
  name                = "lr-${var.installation_id}-eh-${random_string.sa.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.eventhub_sku
  capacity            = var.eventhub_capacity
  tags                = local.common_tags
}
// Only the Event Hubs namespace is provisioned here.
