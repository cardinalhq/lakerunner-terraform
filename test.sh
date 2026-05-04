#!/bin/bash
set -e

echo "Running Terraform tests..."

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ENVIRONMENTS="gcp-poc azure-poc aws-poc"

echo "==> terraform fmt -check (recursive)"
(cd "$REPO_ROOT/terraform" && terraform fmt -check -recursive)

for env in $ENVIRONMENTS; do
  echo "==> terraform validate ($env)"
  (
    cd "$REPO_ROOT/terraform/environments/$env"
    terraform init -backend=false -input=false >/dev/null
    terraform validate
  )
done

echo "==> terraform plan (gcp-poc dry-run with synthetic project ID)"
(
  cd "$REPO_ROOT/terraform/environments/gcp-poc"
  terraform plan \
    -var="project_id=lakerunner-terraform" \
    -target=google_storage_bucket.lakerunner \
    -out=test.plan
  rm -f test.plan
)

echo "All tests passed!"
