# AWS POC + Cross-Cloud Cleanup Design

Date: 2026-05-04

## Goal

Add an `aws-poc` Terraform environment that mirrors the existing GCP and Azure
POC patterns, while simultaneously simplifying all three POCs by removing
Kafka and removing static workload credentials in favor of federated identity
from a managed Kubernetes cluster.

## In scope

1. **New environment**: `terraform/environments/aws-poc/`
2. **Rename**: `terraform/environments/poc/` → `terraform/environments/gcp-poc/`
3. **Update path references**: `Makefile`, `test.sh`, `CLAUDE.md`, `UPGRADE.md`,
   and the inner `README.md`
4. **Remove Kafka entirely** from `gcp-poc` (Managed Kafka cluster, topics,
   IAM bindings, `enable_kafka` and `kafka_*` variables, Kafka outputs) and
   from `azure-poc` (Event Hubs namespace, `enable_kafka` and `eventhub_*`
   variables, Kafka outputs)
5. **Remove static credentials**: `google_storage_hmac_key.lakerunner_s3_key`
   and `s3_access_key/secret/endpoint/region` outputs from `gcp-poc`;
   `storage_account_access_key` output from `azure-poc`
6. **Default-on managed Kubernetes** in all three POCs:
   `enable_eks/gke/aks = true`. Workload identity is the only auth path.

## Out of scope

- Multi-region or multi-AZ-active deployments (POC is single region, RDS is
  single-AZ).
- VPC endpoints, transit gateways, or any of the heavier prod-style AWS
  networking.
- A shared `modules/` library. Each POC remains a self-contained root module,
  matching today's convention.
- Pulling resources out of `gcp-poc` / `azure-poc` beyond the Kafka and
  static-credential removals listed above.
- Migration tooling for any existing `poc/` deployment's local tfstate.
  Existing deployers `mv` their state directory or re-init by hand.
- Backwards-compatibility shims (no aliasing of removed variables, no
  deprecation warnings).

## Directory layout after the change

```
terraform/
├── environments/
│   ├── gcp-poc/    (renamed from poc/, Kafka and HMAC keys removed,
│   │                enable_gke = true by default)
│   ├── azure-poc/  (Event Hubs and access-key output removed,
│   │                enable_aks = true by default)
│   └── aws-poc/    (NEW)
├── modules/
│   ├── gcp/
│   ├── azure/      (NEW empty placeholder for symmetry)
│   └── aws/        (NEW empty placeholder for symmetry)
└── providers/
    ├── gcp/
    ├── azure/
    └── aws/        (NEW)
```

## AWS POC components

### Storage and eventing

Mirrors the production `aws/production/us-east-2/cardinalhq-bucket-sqs.tf`
pattern.

- `aws_s3_bucket` named `lr-${installation_id}-lakerunner-${random_hex}`.
  Versioning off, force-destroy on, public access blocked, TLS-only bucket
  policy, 30-day lifecycle expiration on all objects (matches GCP POC's
  bucket lifecycle).
- `aws_sqs_queue` named `lr-${installation_id}-notifications-${random_hex}`,
  SSE managed by SQS, default retention.
- `aws_sqs_queue_policy` allowing `s3.amazonaws.com` to `SendMessage`,
  scoped by `aws:SourceAccount` (current account) and `aws:SourceArn` of
  the bucket.
- `aws_s3_bucket_notification` sending `s3:ObjectCreated:*` to the queue.
  No path filter; the consumer filters out `db/` (parity with GCP POC).
- `aws_s3_bucket_public_access_block` with all four flags `true`.

### Networking

- `aws_vpc` with CIDR `10.0.0.0/16`.
- 2 public subnets (`10.0.0.0/24`, `10.0.1.0/24`) and 2 private subnets
  (`10.0.10.0/24`, `10.0.11.0/24`) across the first two AZs from
  `data.aws_availability_zones.available`.
- `aws_internet_gateway` and a single `aws_nat_gateway` in one public
  subnet (cost-conscious POC default).
- Route tables wiring private subnets through NAT to the IGW.
- Security groups: one for EKS nodes (allow all egress, intra-SG ingress),
  one for RDS (5432 from inside the VPC).
- No VPC endpoints (POC simplification).

### Compute (EKS, default on)

- `aws_eks_cluster` named `lr-${installation_id}-eks` on the private subnets,
  public endpoint enabled.
- `aws_iam_openid_connect_provider` for the cluster's OIDC issuer (required
  for IRSA).
- One `aws_eks_node_group` with autoscaling 1-10 (matches GCP defaults),
  instance types `["t3.large"]`, capacity type `SPOT` by default, 50 GB
  gp3 disks, on the private subnets.
- IAM roles for the cluster control plane and the node group with the AWS
  managed policies (`AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`,
  `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`).

### Workload identity (IRSA)

- `aws_iam_role` for the Lakerunner workload, trust policy bound to the
  cluster's OIDC issuer for ServiceAccount `lakerunner/lakerunner`.
- Inline IAM policy granting:
  - `s3:GetObject`, `PutObject`, `DeleteObject`, `ListBucket`,
    `GetBucketLocation` on the bucket and its objects.
  - `sqs:ReceiveMessage`, `DeleteMessage`, `GetQueueAttributes`,
    `GetQueueUrl` on the queue.
- Output: role ARN and a `kubectl annotate serviceaccount lakerunner
  eks.amazonaws.com/role-arn=...` command (mirrors GCP's annotation
  command output).

### Database (RDS Postgres, default on)

- `aws_db_subnet_group` across the two private subnets.
- `aws_db_instance` running Postgres 17 on `db.t4g.medium`, 20 GB gp3,
  single-AZ, 7-day automated backups, deletion protection off.
- Security group permitting 5432 from inside the VPC.
- Database initialization (creating the `lakerunner` and `config`
  databases) uses the `cyrilgdn/postgresql` provider after the instance
  is up. This mirrors the GCP POC's two-database pattern on a single
  instance.
- Auto-generated password via `random_password` when
  `var.postgresql_password` is empty.

### Tagging

- `aws` provider configured with `default_tags` from a `local.common_tags`
  map containing `lakerunner-id`, `environment`, `managed-by=terraform`,
  merged with `var.tags`.

## Variables

| Variable | Type | Default | Notes |
|---|---|---|---|
| `installation_id` | string | `"poc"` | 3-10 chars, regex-validated like GCP |
| `region` | string | `"us-east-2"` | matches prod region |
| `environment` | string | `"poc"` | |
| `tags` | map(string) | `{}` | |
| `vpc_cidr` | string | `"10.0.0.0/16"` | |
| `create_postgresql` | bool | `true` | |
| `postgresql_instance_class` | string | `"db.t4g.medium"` | |
| `postgresql_allocated_storage` | number | `20` | GB |
| `postgresql_engine_version` | string | `"17"` | |
| `postgresql_database_name` | string | `"lakerunner"` | |
| `postgresql_configdb_name` | string | `"config"` | |
| `postgresql_username` | string | `"lakerunner"` | |
| `postgresql_password` | string (sensitive) | `""` | auto-generated when empty |
| `enable_eks` | bool | `true` | |
| `eks_kubernetes_version` | string | `"1.31"` | |
| `eks_node_min` | number | `1` | |
| `eks_node_max` | number | `10` | |
| `eks_node_instance_types` | list(string) | `["t3.large"]` | |
| `eks_node_use_spot` | bool | `true` | |
| `eks_node_disk_size` | number | `50` | GB |

## Outputs

- Storage / eventing: `lakerunner_bucket`, `lakerunner_bucket_arn`,
  `sqs_queue_name`, `sqs_queue_url`, `sqs_queue_arn`.
- Network: `vpc_id`, `vpc_cidr`, `private_subnet_ids`, `public_subnet_ids`.
- Identity: `lakerunner_role_arn`,
  `service_account_annotation_command`.
- EKS: `eks_cluster_name`, `eks_cluster_endpoint` (sensitive),
  `eks_oidc_provider_arn`, `kubectl_command`.
- Postgres: `postgresql_endpoint`, `postgresql_port`,
  `postgresql_database_name`, `postgresql_configdb_name`,
  `postgresql_user`, `postgresql_password` (sensitive),
  `postgresql_connection_string` (sensitive).
- Environment: `region`, `account_id`.
- `deployment_summary` heredoc mirroring the GCP POC's, sized to the
  resources actually present.

## Provider configuration

In `terraform/providers/aws/`:

- `versions.tf` declaring `aws ~> 5.0`, `random ~> 3.0`,
  `kubernetes ~> 2.0`, `cyrilgdn/postgresql ~> 1.22`.
- `provider.tf` configuring the `aws` provider with `default_tags`.

The root `aws-poc/main.tf` uses these providers directly. The
`kubernetes` and `postgresql` providers are configured from EKS / RDS
outputs and are only meaningfully exercised when those resources exist.

## Cross-cutting changes to existing POCs

### `gcp-poc` (after rename)

Remove:
- `google_storage_hmac_key.lakerunner_s3_key` resource.
- `s3_access_key`, `s3_secret_key`, `s3_endpoint`, `s3_region` outputs.
- `google_managed_kafka_cluster`, `google_managed_kafka_topic`,
  `google_project_iam_member.lakerunner_kafka_admin`, and
  `google_project_service.managed_kafka_api` resources.
- `enable_kafka`, `kafka_cpu_count`, `kafka_memory_gb` variables.
- `kafka_cluster_id`, `kafka_cluster_name`, `kafka_topics`,
  `kafka_connection_info` outputs.
- The S3-compatible and Kafka sections from `deployment_summary`.

Change:
- `enable_gke` default from `false` to `true`.

### `azure-poc`

Remove:
- `azurerm_eventhub_namespace.ehns` resource.
- `enable_kafka`, `eventhub_sku`, `eventhub_capacity` variables.
- `kafka_bootstrap_server` output.
- `storage_account_access_key` output.

Change:
- `enable_aks` default from `false` to `true`.

### Repository plumbing

- `Makefile`:
  - `fmt`: run `terraform fmt -recursive` once at `terraform/` root
    so all three environments (and any future modules) are formatted
    in one pass.
  - `validate`: loop over each `terraform/environments/*/` directory and
    run `terraform init -backend=false && terraform validate`. AWS and
    Azure both validate without real credentials.
  - `plan`: stays GCP-specific. The current `-var="project_id=..."`
    seeding only works for GCP, and AWS / Azure plans need real
    credentials anyway. Renamed to `plan-gcp` and the `plan` target
    becomes an alias for `plan-gcp`.
- `test.sh`: rewritten to:
  1. `terraform fmt -check -recursive` once at `terraform/` root.
  2. `terraform init -backend=false && terraform validate` in each of
     the three environments.
  3. `terraform plan -var="project_id=lakerunner-terraform"
     -target=google_storage_bucket.lakerunner` in `gcp-poc` only,
     matching today's behavior.
- `CLAUDE.md`: update the "Architecture Overview" and "Key Commands"
  sections to reflect the renamed `gcp-poc/` directory and the AWS
  addition.
- `UPGRADE.md`: add a note about the `poc/` → `gcp-poc/` rename and what
  existing deployers need to do (move local state, re-init).
- `terraform/environments/gcp-poc/README.md`: update path references and
  drop the Kafka and S3-compatibility sections.

## Testing strategy

Per existing pattern, tests run without requiring real cloud credentials:

- `terraform fmt -check` recursively across all three environments.
- `terraform validate` for each of the three environments. (AWS validate
  works without credentials.)
- `terraform plan` for `gcp-poc` only, using the synthetic project ID
  `lakerunner-terraform`, matching today's behavior.

A separate manual smoke test (real `terraform apply` in a sandbox AWS
account) is expected before merge. Not automated.

## Risks and trade-offs

- **Local state migration on rename**: a `git mv environments/poc
  environments/gcp-poc` does not move any deployer's local tfstate
  outside this repo. Existing deployers will see a fresh-init prompt at
  the new path unless they manually move their state. Documented in
  `UPGRADE.md`; not automated.
- **EKS-on-by-default cost**: a default `terraform apply` against the AWS
  POC now stands up an EKS control plane (~$73/mo) plus 1+ Spot t3.large
  nodes (~$15-30/mo) plus an RDS t4g.medium (~$25/mo) plus a NAT Gateway
  (~$33/mo + data). This is a real meter-running cost. The 30-day bucket
  lifecycle and "POC" framing partially mitigate, but documented clearly
  in the AWS POC README so demoing customers know.
- **Single NAT, single-AZ RDS**: explicit cost-vs-resilience trade made
  for POC. Not appropriate for prod.
- **`db/` consumer-side filter**: the AWS POC, like the GCP POC, sends
  every `s3:ObjectCreated:*` event to SQS and relies on the Lakerunner
  consumer to drop `db/` traffic. Documented inline in the
  `aws_s3_bucket_notification` resource.
