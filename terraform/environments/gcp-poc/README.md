# Lakerunner POC Environment - Google Cloud Platform

This Terraform configuration creates a minimal GCP environment perfect for evaluating Lakerunner.

For AWS see `../aws-poc/`. For Azure see `../azure-poc/`.

## Quick Start (5 minutes)

### Prerequisites

#### 1. GCP Project Setup
- Create a new GCP project or use an existing one
- Enable billing on the project
- Note your **Project ID** (you'll need this)

#### 2. Required Tools
Install these tools on your local machine:
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.0+)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) 

#### 3. Authentication
```bash
# Login to Google Cloud
gcloud auth login

# Set your project
gcloud config set project YOUR-PROJECT-ID

# Enable Application Default Credentials for Terraform
gcloud auth application-default login
```

### Setup Steps

1. **Download Configuration**
   ```bash
   # Clone or download the terraform files to your local machine
   cd terraform/environments/gcp-poc/
   ```

2. **Configure Your Deployment**
   Copy the example configuration:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   Edit `terraform.tfvars` and set **at minimum**:
   ```hcl
   # REQUIRED: Your GCP Project ID
   project_id = "your-gcp-project-id-here"

   # REQUIRED: Choose your region (closest to you)
   region = "us-central1"  # or us-east1, europe-west1, etc.
   ```

3. **Deploy Infrastructure**
   ```bash
   # Initialize Terraform (downloads providers)
   terraform init

   # Preview what will be created
   terraform plan

   # Deploy (might take up to 20-30 minutes)
   terraform apply
   ```

   When prompted, type `yes` to confirm.

## Configuration Options

### Basic Setup (Recommended for POC)
The defaults work great for POC. Just set `project_id` and `region`.

### Optional Features
Add these to your `terraform.tfvars` if you have existing infra:

```hcl
# Bring your own Kubernetes cluster (you must wire Workload Identity yourself)
enable_gke = false

# Use existing PostgreSQL (instead of creating new)
create_postgresql = false
postgresql_instance_name = "your-existing-db"
```

## What Gets Created

### Core Infrastructure
- **VPC Network** - Dedicated private network
- **Cloud Storage Bucket** - For telemetry data
- **PostgreSQL Database** - For metadata storage
- **Pub/Sub Topics** - For event notifications
- **Service Accounts** - With appropriate permissions
- **GKE Cluster** - Kubernetes for container workloads (default on)


## After Deployment

### 1. Get Connection Information
```bash
# View all outputs
terraform output

# Get specific values
terraform output lakerunner_bucket
terraform output postgresql_connection_string
```

### 2. Connect to GKE (if enabled)
```bash
# Configure kubectl
gcloud container clusters get-credentials CLUSTER-NAME --zone=ZONE --project=PROJECT-ID

# Verify connection
kubectl get nodes
```

### 3. Next Steps
- Deploy lakerunner with helm charts

## Troubleshooting

### Common Issues

**"API not enabled" errors:**
- Wait 2-3 minutes for APIs to fully enable, then retry

**Permission errors:**
- Ensure you have Owner or Editor role on the GCP project
- Re-run `gcloud auth application-default login`

**Resource quota errors:**
- Check GCP quotas in Console → IAM & Admin → Quotas
- Request quota increases if needed

### Getting Help
- Check GCP Console for resource status
- Contact support (slack or email) with the deployment logs

## Upgrading
Your configuration is safe during upgrades - see [UPGRADE.md](../../../UPGRADE.md) for details.

## Out of Scope
Conductor/maestro requires its own PostgreSQL database (`maestro` DB and user, see `charts/maestro/values.yaml`). This POC terraform does not provision it.
Operators wanting to run conductor alongside lakerunner must create that database manually on the same Cloud SQL instance.

## Cleanup

To remove all resources:
```bash
terraform destroy
```

 **Warning:** This will permanently delete all data and resources.
