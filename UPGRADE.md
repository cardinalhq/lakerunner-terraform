# Upgrading Lakerunner Terraform

## Safe Upgrade Process

Your `terraform.tfvars` files are automatically ignored by git, so you can safely pull updates without conflicts.

### Step 1: Backup Your Settings
```bash
# Backup your current configuration (substitute your cloud below)
cp terraform/environments/gcp-poc/terraform.tfvars terraform.tfvars.backup
```

### Step 2: Pull Updates
```bash
git pull origin main
```

### Step 3: Check for New Settings
```bash
# Compare your settings with the latest example for your cloud
diff terraform/environments/gcp-poc/terraform.tfvars terraform/environments/gcp-poc/terraform.tfvars.example
```

### Step 4: Apply Updates
```bash
cd terraform/environments/gcp-poc   # or aws-poc / azure-poc
terraform plan
terraform apply
```

## What's Safe to Update

**Always Safe**: We never modify your `terraform.tfvars` files
**Infrastructure Improvements**: New resources, better defaults
**Provider Updates**: Newer Terraform provider versions

## Configuration File Strategy

- `terraform.tfvars.example` - Template with latest options (we may update this)
- `terraform.tfvars` - Your custom settings (never tracked in git)
- Your settings persist through all updates

## Notable Past Changes

### Directory Rename: `poc/` -> `gcp-poc/`

The original GCP-only POC directory `terraform/environments/poc/` was renamed to `terraform/environments/gcp-poc/` when AWS and Azure POCs were added.

If you have an existing local deployment, your `terraform.tfstate` lives inside the old directory and is not moved by the repo update. Either:

```bash
# Move your local state and tfvars into the new directory
mv terraform/environments/poc/terraform.tfstate* terraform/environments/gcp-poc/
mv terraform/environments/poc/terraform.tfvars terraform/environments/gcp-poc/
mv terraform/environments/poc/.terraform terraform/environments/gcp-poc/ 2>/dev/null || true
rmdir terraform/environments/poc
```

Or re-init from scratch in the new directory and `terraform import` your existing resources.

### Removed: Kafka and Static Object-Store Credentials

Older versions of this repo provisioned a managed Kafka cluster (gated by `enable_kafka`) and emitted S3-compatible HMAC keys (on GCP) or a Storage Account access key (on Azure). Both were removed; the workload now authenticates exclusively via Workload Identity / IRSA from the managed Kubernetes cluster. If you were using the static credentials, switch your workload to assume the role / service account emitted by the new outputs.

## Need Help?

If you encounter issues during upgrade, compare your `terraform.tfvars` with the latest `.example` file to see new available options.
