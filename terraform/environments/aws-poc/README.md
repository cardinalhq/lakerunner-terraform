# Lakerunner POC Environment - AWS

This Terraform configuration creates a minimal AWS environment for evaluating Lakerunner.

For GCP see `../gcp-poc/`. For Azure see `../azure-poc/`.

## Quick Start

### Prerequisites

- AWS account with admin (or equivalent) permissions
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.3+)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws configure` or `aws sso login`)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)

### Setup Steps

1. **Configure your deployment**
   ```bash
   cd terraform/environments/aws-poc/
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars - region, installation_id, optionally tighten postgresql_allowed_cidr
   ```

2. **Deploy**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   Expect ~15-20 minutes (EKS control plane is the long pole).

3. **Connect to the cluster**
   ```bash
   eval "$(terraform output -raw kubectl_command)"
   kubectl get nodes
   ```

4. **Annotate the Lakerunner ServiceAccount with the IRSA role**
   ```bash
   kubectl create namespace lakerunner
   kubectl create serviceaccount lakerunner -n lakerunner
   eval "$(terraform output -raw service_account_annotation_command)"
   ```

   The Lakerunner Helm chart can then run as ServiceAccount `lakerunner/lakerunner` and pick up the IAM role automatically via IRSA.

## What Gets Created

- **VPC** with two public + two private subnets across two AZs, single NAT Gateway
- **S3 bucket** for telemetry data, with all `s3:ObjectCreated:*` events routed to:
- **SQS queue** consumed by Lakerunner. The consumer filters out the `db/` prefix (parity with the GCP POC).
- **EKS cluster** with one managed node group (Spot by default, autoscaling 1-10)
- **OIDC provider** + **IAM role** for IRSA, scoped to ServiceAccount `lakerunner/lakerunner`, with permissions on the bucket and the queue
- **RDS Postgres** (publicly accessible for POC ease) with two databases: `lakerunner` and `config`

## Cost Notes

A default `terraform apply` is meter-running. Approximate monthly idle cost in `us-east-2`:

- EKS control plane: ~$73
- 1x t3.large Spot node: ~$15
- NAT Gateway: ~$33 + data
- RDS db.t4g.medium single-AZ: ~$25
- S3, SQS, IPs: low single digits

Disable EKS or Postgres via the `enable_eks` / `create_postgresql` variables to skip those.

## Cleanup

```bash
terraform destroy
```

Note: an `aws_eip` may take a moment to release. The S3 bucket has `force_destroy = true` so non-empty buckets will still be destroyed.

## Out of Scope

- Multi-AZ RDS, HA control plane, custom KMS keys, VPC endpoints
- IAM users with static access keys (workload auth is IRSA only)
- Kafka / MSK
