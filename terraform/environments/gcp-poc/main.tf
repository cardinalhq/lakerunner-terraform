terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Local values for consistent labeling
locals {
  common_labels = merge(var.labels, {
    "lakerunner-id" = var.installation_id
    "environment"   = var.environment
    "managed-by"    = "terraform"
  })
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  default_labels = local.common_labels
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  default_labels = local.common_labels
}

# Random ID for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Main Lakerunner bucket with notifications
resource "google_storage_bucket" "lakerunner" {
  name     = "lr-${var.installation_id}-lakerunner-${random_id.bucket_suffix.hex}"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = true # Allow deletion even with contents
  labels                      = local.common_labels

  versioning {
    enabled = false # Simplified for POC
  }

  # Auto-cleanup for POC environment
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Pub/Sub topic for object notifications (excluding db/ path)
resource "google_pubsub_topic" "object_notifications" {
  name = "lr-${var.installation_id}-notifications-${random_id.bucket_suffix.hex}"
}

# Pull subscription for consuming object notifications
resource "google_pubsub_subscription" "lakerunner_notifications" {
  name  = "lr-${var.installation_id}-sub-${random_id.bucket_suffix.hex}"
  topic = google_pubsub_topic.object_notifications.name

  ack_deadline_seconds       = 20
  message_retention_duration = "604800s" # 7 days

  enable_exactly_once_delivery = true

  expiration_policy {
    ttl = "2678400s" # 31 days
  }
}

# Only otel-raw/ object creates fan out to Pub/Sub. Other prefixes (db/, etc.)
# do not generate notifications.
resource "google_storage_notification" "object_create_notify" {
  bucket             = google_storage_bucket.lakerunner.name
  topic              = google_pubsub_topic.object_notifications.id
  event_types        = ["OBJECT_FINALIZE"]
  payload_format     = "JSON_API_V1"
  object_name_prefix = "otel-raw/"

  depends_on = [
    google_pubsub_topic_iam_member.storage_publisher
  ]
}

# Service account for Pub/Sub notifications
resource "google_service_account" "pubsub_notifications" {
  account_id   = "lr-${var.installation_id}-pubsub-${random_id.bucket_suffix.hex}"
  display_name = "Lakerunner Pub/Sub Notifications"
  description  = "Service account for handling object notifications"
}

# Grant Pub/Sub publisher permission to the storage service account
resource "google_pubsub_topic_iam_member" "storage_publisher" {
  topic  = google_pubsub_topic.object_notifications.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

# Grant Pub/Sub subscriber permission to the Lakerunner service account
resource "google_pubsub_subscription_iam_member" "lakerunner_subscriber" {
  subscription = google_pubsub_subscription.lakerunner_notifications.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.lakerunner_poc.email}"
}

# Get project data for the storage service account
data "google_project" "current" {}


# Configuration
locals {
  vpc_name                 = google_compute_network.lakerunner_vpc.name
  subnet_name              = google_compute_subnetwork.lakerunner_subnet.name
  postgresql_password      = var.create_postgresql && var.postgresql_password == "" ? random_password.postgresql_password[0].result : var.postgresql_password
  postgresql_instance_name = var.postgresql_instance_name != "" ? var.postgresql_instance_name : "lr-${var.installation_id}-postgres-${random_id.bucket_suffix.hex}"
}

# Create dedicated VPC for POC environment
resource "google_compute_network" "lakerunner_vpc" {
  name                    = "lr-${var.installation_id}-vpc-${random_id.bucket_suffix.hex}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Create subnet for the POC VPC
resource "google_compute_subnetwork" "lakerunner_subnet" {
  name          = "lr-${var.installation_id}-subnet-${random_id.bucket_suffix.hex}"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.lakerunner_vpc.id

  # Secondary IP ranges for GKE if enabled
  dynamic "secondary_ip_range" {
    for_each = var.enable_gke ? [1] : []
    content {
      range_name    = "pods"
      ip_cidr_range = "10.4.0.0/14"
    }
  }

  dynamic "secondary_ip_range" {
    for_each = var.enable_gke ? [1] : []
    content {
      range_name    = "services"
      ip_cidr_range = "10.8.0.0/20"
    }
  }
}

# Internet Gateway (automatically created with VPC)
# Firewall rules for the VPC
resource "google_compute_firewall" "lakerunner_allow_internal" {
  name    = "lr-${var.installation_id}-allow-internal-${random_id.bucket_suffix.hex}"
  network = google_compute_network.lakerunner_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24", "10.4.0.0/14", "10.8.0.0/20"]
  priority      = 1000
}

resource "google_compute_firewall" "lakerunner_allow_ssh" {
  name    = "lr-${var.installation_id}-allow-ssh-${random_id.bucket_suffix.hex}"
  network = google_compute_network.lakerunner_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["lakerunner-ssh"]
  priority      = 1000
}

# Cloud Router for NAT gateway
resource "google_compute_router" "lakerunner_router" {
  name    = "lr-${var.installation_id}-router-${random_id.bucket_suffix.hex}"
  region  = var.region
  network = google_compute_network.lakerunner_vpc.id
}

# Cloud NAT for internet access from private nodes
resource "google_compute_router_nat" "lakerunner_nat" {
  name                               = "lr-${var.installation_id}-nat-${random_id.bucket_suffix.hex}"
  router                             = google_compute_router.lakerunner_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Service Account for Lakerunner
resource "google_service_account" "lakerunner_poc" {
  account_id   = "lr-${var.installation_id}-poc-${random_id.bucket_suffix.hex}"
  display_name = "Lakerunner POC Service Account"
  description  = "Service account for Lakerunner POC deployment"
}

# Service Account for Kubernetes Workload Identity
resource "google_service_account" "lakerunner_k8s" {
  count        = var.enable_gke ? 1 : 0
  account_id   = "lr-${var.installation_id}-k8s-${random_id.bucket_suffix.hex}"
  display_name = "Lakerunner Kubernetes Service Account"
  description  = "Service account for Lakerunner Kubernetes workloads via Workload Identity"
}

# IAM bindings for the service account
resource "google_project_iam_member" "lakerunner_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.lakerunner_poc.email}"
}

resource "google_project_iam_member" "lakerunner_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.lakerunner_poc.email}"
}

# PostgreSQL Configuration

# Generate random password for PostgreSQL if not provided
resource "random_password" "postgresql_password" {
  count   = var.create_postgresql && var.postgresql_password == "" ? 1 : 0
  length  = 16
  special = false
}

# Enable APIs required for Cloud SQL
resource "google_project_service" "service_networking" {
  count              = 1
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sql_admin" {
  count              = 1
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Enable Kubernetes Engine API for GKE
resource "google_project_service" "container_api" {
  count              = 1
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# Create VPC peering for Cloud SQL private networking
# NOTE: Service networking connections are PROJECT-WIDE and shared between installations
# This means destroying one installation can affect CloudSQL in other installations
resource "google_compute_global_address" "private_ip_address" {
  count         = var.create_postgresql ? 1 : 0
  name          = "google-managed-services-${var.installation_id}-${random_id.bucket_suffix.hex}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.lakerunner_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.create_postgresql ? 1 : 0
  network                 = google_compute_network.lakerunner_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address[0].name]
  deletion_policy         = "ABANDON" # Required to prevent interfering with other installations

  depends_on = [google_project_service.service_networking, google_project_service.sql_admin]

  lifecycle {
    create_before_destroy = false
  }
}

# Create PostgreSQL instance if requested
resource "google_sql_database_instance" "lakerunner_postgresql" {
  count            = var.create_postgresql ? 1 : 0
  name             = local.postgresql_instance_name
  database_version = var.postgresql_version
  region           = var.region

  settings {
    tier    = var.postgresql_machine_type
    edition = var.postgresql_edition

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.lakerunner_vpc.id
      ssl_mode        = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }

    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 2 # 2 AM
      update_track = "stable"
    }

    user_labels = local.common_labels
  }

  deletion_protection = false

  depends_on = [
    google_project_service.service_networking,
    google_project_service.sql_admin,
    google_service_networking_connection.private_vpc_connection
  ]

  # Ensure PostgreSQL is deleted before VPC peering
  lifecycle {
    create_before_destroy = false
  }
}

# Create PostgreSQL database
resource "google_sql_database" "lakerunner_database" {
  count    = var.create_postgresql ? 1 : 0
  name     = var.postgresql_database_name
  instance = google_sql_database_instance.lakerunner_postgresql[0].name
}

# Create configdb database for Lakerunner configuration
resource "google_sql_database" "lakerunner_configdb" {
  count    = var.create_postgresql ? 1 : 0
  name     = var.postgresql_configdb_name
  instance = google_sql_database_instance.lakerunner_postgresql[0].name
}

# Create PostgreSQL user
resource "google_sql_user" "lakerunner_user" {
  count    = var.create_postgresql ? 1 : 0
  name     = var.postgresql_user
  instance = google_sql_database_instance.lakerunner_postgresql[0].name
  password = local.postgresql_password
}

# Grant additional permissions to the service account for database management
resource "google_project_iam_member" "lakerunner_cloudsql_client" {
  count   = var.create_postgresql ? 1 : 0
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.lakerunner_poc.email}"
}

# IAM bindings for the Kubernetes service account
resource "google_storage_bucket_iam_member" "lakerunner_k8s_bucket_admin" {
  count  = var.enable_gke ? 1 : 0
  bucket = google_storage_bucket.lakerunner.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.lakerunner_k8s[0].email}"
}

resource "google_pubsub_subscription_iam_member" "lakerunner_k8s_subscriber" {
  count        = var.enable_gke ? 1 : 0
  subscription = google_pubsub_subscription.lakerunner_notifications.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.lakerunner_k8s[0].email}"
}

resource "google_pubsub_topic_iam_member" "lakerunner_k8s_viewer" {
  count  = var.enable_gke ? 1 : 0
  topic  = google_pubsub_topic.object_notifications.name
  role   = "roles/pubsub.viewer"
  member = "serviceAccount:${google_service_account.lakerunner_k8s[0].email}"
}

# Optional GKE cluster for container workloads
resource "google_container_cluster" "lakerunner_gke" {
  count    = var.enable_gke ? 1 : 0
  name     = "lr-${var.installation_id}-gke-${random_id.bucket_suffix.hex}"
  location = var.zone

  deletion_protection = false
  resource_labels     = local.common_labels

  depends_on = [google_project_service.container_api]

  # Use our dedicated VPC
  network    = google_compute_network.lakerunner_vpc.id
  subnetwork = google_compute_subnetwork.lakerunner_subnet.id

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Allow public endpoint for POC ease
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # IP allocation for pods and services - use secondary ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Remove default node pool (we'll create our own)
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable workload identity for future service account mappings
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Maintenance policy
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Release channel for automatic updates
  release_channel {
    channel = "REGULAR"
  }
}

# Node pool for the GKE cluster
resource "google_container_node_pool" "lakerunner_nodes" {
  count      = var.enable_gke ? 1 : 0
  name       = "lakerunner-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.lakerunner_gke[0].name
  node_count = var.gke_min_nodes

  # Auto-scaling configuration
  autoscaling {
    min_node_count = var.gke_min_nodes
    max_node_count = var.gke_max_nodes
  }

  # Node configuration
  node_config {
    preemptible  = false
    spot         = var.gke_use_spot
    machine_type = var.gke_machine_type
    disk_size_gb = var.gke_disk_size_gb
    disk_type    = "pd-standard"

    # Service account for nodes
    service_account = google_service_account.lakerunner_poc.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity configuration
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags = ["lakerunner-gke"]
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Workload Identity binding for lakerunner namespace/serviceaccount
resource "google_service_account_iam_member" "lakerunner_workload_identity" {
  count              = var.enable_gke ? 1 : 0
  service_account_id = google_service_account.lakerunner_k8s[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[lakerunner/lakerunner]"
}

