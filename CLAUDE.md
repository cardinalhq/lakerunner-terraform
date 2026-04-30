# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## common rules

- no emoji in source code, comments, documentation, or scripts.  emoji are OK in tests when appropriate like testing for utf-8 support.
- no advertising for Claude or Claude's creator.

## Repository Purpose

This repository provides Terraform infrastructure-as-code for deploying Lakerunner in GCP environments. It's designed primarily for customer POC (proof-of-concept) deployments, focusing on easy setup and excellent first impressions for potential customers evaluating the Lakerunner platform.

## Key Commands

- `make` or `make help` - Show available commands
- `make test` - Run full test suite (format check, validate, plan with test project)
- `make fmt` - Auto-format all Terraform files
- `make validate` - Validate Terraform configuration
- `make plan` - Run terraform plan with test project ID `lakerunner-terraform`
- `make clean` - Clean up temporary Terraform files

## Architecture Overview

### Directory Structure
```
terraform/
├── environments/poc/     # POC environment (primary focus)
├── modules/gcp/          # Reusable GCP modules (future expansion)
└── providers/gcp/        # GCP provider configuration
```

### Multi-Cloud Design
The structure is designed to support future AWS and Azure deployments, but currently focuses exclusively on GCP POC environments.

### Customer Configuration Strategy
- `terraform.tfvars.example` - Template with documented options
- `terraform.tfvars` - Customer's actual config (git-ignored for safety)
- Customers only need to change `project_id` for basic setup
- Safe upgrade path: customer configs never conflict with repo updates

### Network Configuration
The POC environment always provisions a dedicated VPC:
- VPC + subnet `10.0.0.0/24` in the configured region
- Secondary ranges for GKE pods (`10.4.0.0/14`) and services (`10.8.0.0/20`) added when `enable_gke = true`
- Cloud Router + Cloud NAT for egress from private nodes

### Core Infrastructure Components

**Storage:**
- `lakerunner` bucket - Main application bucket with Pub/Sub notifications

**Notifications:**
- GCS → Pub/Sub integration for object create events
- All notifications fire (GCS doesn't support path exclusions)
- Application must filter out `db/` path notifications in subscriber

**Kubernetes:**
- Optional GKE cluster for container workloads (`enable_gke = false` by default)
- Auto-scaling node pool (1-10 nodes) with spot instances for cost savings
- Workload Identity enabled for secure service account mappings

**Security:**
- Dedicated service accounts with least-privilege access
- Auto-cleanup after 30 days for POC resources
- No hardcoded credentials (uses GCP auth flow)

## Testing Strategy

Tests run without requiring real GCP credentials by using:
- Format validation (`terraform fmt -check`)
- Configuration validation (`terraform validate`)
- Targeted planning (`terraform plan -target=...`) with test project ID
- Test project ID: `lakerunner-terraform` (safe, no real resources)

## Customer Experience Focus

This infrastructure prioritizes:
1. **5-minute setup** - Minimal configuration required
2. **Professional outputs** - Clear resource information and next steps
3. **Safety** - Auto-cleanup, upgrade-safe configuration management
4. **Flexibility** - Supports both greenfield and enterprise network constraints

The POC environment is designed to make an excellent first impression for potential customers evaluating Lakerunner.

- never use emoji in any docs, scripts, or other files except for tests needing to test for proper emoji handling