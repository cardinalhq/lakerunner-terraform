##############
# Storage / eventing
##############
output "lakerunner_bucket" {
  description = "S3 bucket name receiving Lakerunner data"
  value       = aws_s3_bucket.lakerunner.bucket
}

output "lakerunner_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.lakerunner.arn
}

output "sqs_queue_name" {
  description = "SQS queue receiving s3:ObjectCreated:* events"
  value       = aws_sqs_queue.notifications.name
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.notifications.url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.notifications.arn
}

##############
# Network
##############
output "vpc_id" { value = aws_vpc.main.id }
output "vpc_cidr" { value = aws_vpc.main.cidr_block }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }

##############
# Identity (IRSA)
##############
output "lakerunner_role_arn" {
  description = "IAM role ARN to be assumed by the lakerunner ServiceAccount via IRSA"
  value       = var.enable_eks ? aws_iam_role.lakerunner[0].arn : null
}

output "service_account_annotation_command" {
  description = "kubectl command to wire the lakerunner ServiceAccount to the IAM role"
  value       = var.enable_eks ? "kubectl annotate serviceaccount lakerunner eks.amazonaws.com/role-arn=${aws_iam_role.lakerunner[0].arn} -n lakerunner" : null
}

##############
# EKS
##############
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.enable_eks ? aws_eks_cluster.main[0].name : null
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint"
  value       = var.enable_eks ? aws_eks_cluster.main[0].endpoint : null
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = var.enable_eks ? aws_iam_openid_connect_provider.eks[0].arn : null
}

output "kubectl_command" {
  description = "Command to configure kubectl"
  value       = var.enable_eks ? "aws eks update-kubeconfig --name=${aws_eks_cluster.main[0].name} --region=${var.region}" : null
}

##############
# Postgres
##############
output "postgresql_endpoint" {
  description = "RDS instance endpoint"
  value       = var.create_postgresql ? aws_db_instance.main[0].address : null
}

output "postgresql_port" {
  description = "RDS instance port"
  value       = var.create_postgresql ? aws_db_instance.main[0].port : null
}

output "postgresql_database_name" {
  value = var.postgresql_database_name
}

output "postgresql_configdb_name" {
  value = var.postgresql_configdb_name
}

output "postgresql_user" {
  value = var.postgresql_username
}

output "postgresql_password" {
  value     = local.postgresql_password
  sensitive = true
}

output "postgresql_connection_string" {
  description = "Postgres connection string (sslmode=require)"
  value       = var.create_postgresql ? "postgresql://${var.postgresql_username}:${local.postgresql_password}@${aws_db_instance.main[0].address}:${aws_db_instance.main[0].port}/${var.postgresql_database_name}?sslmode=require" : null
  sensitive   = true
}

##############
# Environment
##############
output "region" { value = var.region }
output "account_id" { value = data.aws_caller_identity.current.account_id }

output "deployment_summary" {
  description = "POC deployment summary"
  value       = <<-EOT
    Storage:
      Lakerunner Bucket: ${aws_s3_bucket.lakerunner.bucket}
      SQS Queue: ${aws_sqs_queue.notifications.name}
      SQS URL: ${aws_sqs_queue.notifications.url}
      ${var.create_postgresql ? "Database:\n      RDS Endpoint: ${aws_db_instance.main[0].address}:${aws_db_instance.main[0].port}\n      Databases: ${var.postgresql_database_name}, ${var.postgresql_configdb_name}\n      User: ${var.postgresql_username}\n      Password: [SENSITIVE - 'terraform output -raw postgresql_password']" : "Enable Postgres with create_postgresql=true for database support"}

    Network:
      VPC: ${aws_vpc.main.id} (${aws_vpc.main.cidr_block})
      Public subnets: ${join(", ", aws_subnet.public[*].id)}
      Private subnets: ${join(", ", aws_subnet.private[*].id)}

    ${var.enable_eks ? "Kubernetes:\n      EKS Cluster: ${aws_eks_cluster.main[0].name}\n      Nodes: ${var.eks_node_min}-${var.eks_node_max} ${join(",", var.eks_node_instance_types)} (${var.eks_node_use_spot ? "SPOT" : "ON_DEMAND"})\n      kubectl: aws eks update-kubeconfig --name=${aws_eks_cluster.main[0].name} --region=${var.region}\n\n    Identity (IRSA):\n      Role ARN: ${aws_iam_role.lakerunner[0].arn}\n      Annotate SA: kubectl annotate serviceaccount lakerunner eks.amazonaws.com/role-arn=${aws_iam_role.lakerunner[0].arn} -n lakerunner" : "Enable EKS with enable_eks=true for container workloads"}
  EOT
}
