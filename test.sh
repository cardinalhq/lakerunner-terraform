#!/bin/bash
set -e

TF="${TF:-tofu}"

echo "Running Terraform tests with: $TF"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ENVIRONMENTS="gcp-poc azure-poc aws-poc"

echo "==> $TF fmt -check (recursive)"
(cd "$REPO_ROOT/terraform" && "$TF" fmt -check -recursive)

for env in $ENVIRONMENTS; do
  echo "==> $TF validate ($env)"
  (
    cd "$REPO_ROOT/terraform/environments/$env"
    "$TF" init -backend=false -input=false >/dev/null
    "$TF" validate
  )
done

echo "All tests passed!"
