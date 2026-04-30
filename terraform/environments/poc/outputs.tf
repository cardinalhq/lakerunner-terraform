# Main Lakerunner bucket outputs
output "lakerunner_bucket" {
  description = "Main Lakerunner bucket name"
  value       = google_storage_bucket.lakerunner.name
}

output "lakerunner_bucket_url" {
  description = "URL for the Lakerunner bucket"
  value       = google_storage_bucket.lakerunner.url
}

output "object_notifications_topic" {
  description = "Pub/Sub topic for object notifications"
  value       = google_pubsub_topic.object_notifications.name
}

output "pubsub_subscription_id" {
  description = "Pub/Sub subscription for object notifications"
  value       = google_pubsub_subscription.lakerunner_notifications.name
}


output "project_id" {
  description = "GCP Project ID used for this POC"
  value       = var.project_id
}

output "region" {
  description = "GCP Region used for this POC"
  value       = var.region
}

# Network outputs
output "vpc_name" {
  description = "VPC name (dedicated for POC)"
  value       = google_compute_network.lakerunner_vpc.name
}

output "vpc_id" {
  description = "VPC ID (full resource ID)"
  value       = google_compute_network.lakerunner_vpc.id
}

output "subnet_name" {
  description = "Subnet name (dedicated for POC)"
  value       = google_compute_subnetwork.lakerunner_subnet.name
}

output "subnet_id" {
  description = "Subnet ID (full resource ID)"
  value       = google_compute_subnetwork.lakerunner_subnet.id
}

output "subnet_cidr" {
  description = "Subnet CIDR range"
  value       = google_compute_subnetwork.lakerunner_subnet.ip_cidr_range
}

# Service Account outputs
output "service_account_email" {
  description = "Lakerunner service account email"
  value       = google_service_account.lakerunner_poc.email
}

# PostgreSQL outputs
output "postgresql_instance_name" {
  description = "PostgreSQL instance name (created or existing)"
  value       = var.create_postgresql ? google_sql_database_instance.lakerunner_postgresql[0].name : var.postgresql_instance_name
}

output "postgresql_connection_name" {
  description = "PostgreSQL connection name for Cloud SQL Proxy"
  value       = var.create_postgresql ? google_sql_database_instance.lakerunner_postgresql[0].connection_name : null
}

output "postgresql_private_ip_address" {
  description = "PostgreSQL private IP address"
  value       = var.create_postgresql ? google_sql_database_instance.lakerunner_postgresql[0].private_ip_address : null
}

output "postgresql_database_name" {
  description = "PostgreSQL database name"
  value       = var.postgresql_database_name
}

output "postgresql_configdb_name" {
  description = "PostgreSQL configdb name"
  value       = var.postgresql_configdb_name
}

output "postgresql_user" {
  description = "PostgreSQL username"
  value       = var.postgresql_user
}

output "postgresql_password" {
  description = "PostgreSQL password (auto-generated if not provided)"
  value       = local.postgresql_password
  sensitive   = true
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string for applications"
  value       = var.create_postgresql ? "postgresql://${var.postgresql_user}:${local.postgresql_password}@${google_sql_database_instance.lakerunner_postgresql[0].private_ip_address}:5432/${var.postgresql_database_name}" : null
  sensitive   = true
}

# GKE outputs (when enabled)
output "gke_cluster_name" {
  description = "Name of the GKE cluster (when enabled)"
  value       = var.enable_gke ? google_container_cluster.lakerunner_gke[0].name : null
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint (when enabled)"
  value       = var.enable_gke ? google_container_cluster.lakerunner_gke[0].endpoint : null
  sensitive   = true
}

output "gke_cluster_location" {
  description = "GKE cluster location (when enabled)"
  value       = var.enable_gke ? google_container_cluster.lakerunner_gke[0].location : null
}

output "kubectl_command" {
  description = "Command to configure kubectl (when GKE enabled)"
  value       = var.enable_gke ? "gcloud container clusters get-credentials ${google_container_cluster.lakerunner_gke[0].name} --zone=${google_container_cluster.lakerunner_gke[0].location} --project=${var.project_id}" : null
}

# Kubernetes Workload Identity outputs (when enabled)
output "k8s_service_account_email" {
  description = "GCP service account email for Kubernetes Workload Identity (when GKE enabled)"
  value       = var.enable_gke ? google_service_account.lakerunner_k8s[0].email : null
}

output "k8s_service_account_annotation_command" {
  description = "Command to annotate Kubernetes service account for Workload Identity (when GKE enabled)"
  value       = var.enable_gke ? "kubectl annotate serviceaccount lakerunner iam.gke.io/gcp-service-account=${google_service_account.lakerunner_k8s[0].email} -n lakerunner" : null
}

# S3 Compatibility outputs
output "s3_access_key" {
  description = "S3 compatible access key for the bucket"
  value       = google_storage_hmac_key.lakerunner_s3_key.access_id
}

output "s3_secret_key" {
  description = "S3 compatible secret key for the bucket"
  value       = google_storage_hmac_key.lakerunner_s3_key.secret
  sensitive   = true
}

output "s3_endpoint" {
  description = "S3 compatible endpoint URL"
  value       = "https://storage.googleapis.com"
}

output "s3_region" {
  description = "S3 compatible region"
  value       = "auto"
}

# Kafka outputs (when enabled)
output "kafka_cluster_id" {
  description = "Managed Kafka cluster ID (when enabled)"
  value       = var.enable_kafka ? google_managed_kafka_cluster.lakerunner_kafka[0].cluster_id : null
}

output "kafka_cluster_name" {
  description = "Kafka cluster name (when enabled)"
  value       = var.enable_kafka ? google_managed_kafka_cluster.lakerunner_kafka[0].name : null
}

output "kafka_topics" {
  description = "Created Kafka topics (when enabled)"
  value       = var.enable_kafka ? [for topic in google_managed_kafka_topic.lakerunner_topics : topic.topic_id] : []
}

output "kafka_connection_info" {
  description = "Kafka connection information (when enabled)"
  value       = var.enable_kafka ? "Cluster: ${google_managed_kafka_cluster.lakerunner_kafka[0].cluster_id} (Location: ${var.region})" : "Kafka not enabled"
}

output "deployment_summary" {
  description = "POC deployment summary"
  value       = <<-EOT
    Storage:
      Lakerunner Bucket: ${google_storage_bucket.lakerunner.name}
      Notifications Topic: ${google_pubsub_topic.object_notifications.name}
      Notifications Subscription: ${google_pubsub_subscription.lakerunner_notifications.name}
      S3 Compatible Access:
        Endpoint: https://storage.googleapis.com
        Access Key: ${google_storage_hmac_key.lakerunner_s3_key.access_id}
        Secret Key: [SENSITIVE - use 'terraform output -raw s3_secret_key' to view]
        Region: auto
      ${var.create_postgresql ? "Database:\n      PostgreSQL Instance: ${google_sql_database_instance.lakerunner_postgresql[0].name}\n      Databases: ${var.postgresql_database_name}, ${var.postgresql_configdb_name}\n      User: ${var.postgresql_user}\n      Private IP: ${google_sql_database_instance.lakerunner_postgresql[0].private_ip_address}\n      Both lrdb and configdb ready for Lakerunner" : "Enable PostgreSQL with create_postgresql=true for database support"}

    Network:
      VPC: ${google_compute_network.lakerunner_vpc.name} (dedicated)
      Subnet: ${google_compute_subnetwork.lakerunner_subnet.name} (${google_compute_subnetwork.lakerunner_subnet.ip_cidr_range})
      Private networking with Cloud NAT for internet access

    Identity:
      Service Account: ${google_service_account.lakerunner_poc.email}

    ${var.enable_gke ? "Kubernetes:\n      GKE Cluster: ${google_container_cluster.lakerunner_gke[0].name}\n      Location: ${google_container_cluster.lakerunner_gke[0].location}\n      Nodes: ${var.gke_min_nodes}-${var.gke_max_nodes} ${var.gke_machine_type}\n      kubectl: gcloud container clusters get-credentials ${google_container_cluster.lakerunner_gke[0].name} --zone=${google_container_cluster.lakerunner_gke[0].location} --project=${var.project_id}" : "Enable Kubernetes with enable_gke=true for container workloads"}

    ${var.enable_kafka ? "Kafka:\n      Cluster ID: ${google_managed_kafka_cluster.lakerunner_kafka[0].cluster_id}\n      Location: ${var.region}\n      Topics: lakerunner-objstore-ingest-logs, lakerunner-objstore-ingest-metrics, lakerunner-objstore-ingest-traces" : "Enable Kafka with enable_kafka=true for event streaming"}
  EOT
}
