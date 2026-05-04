.PHONY: help test check clean fmt validate plan plan-gcp

ENVIRONMENTS := gcp-poc azure-poc aws-poc

# Default target
help: ## Show this help message
	@echo "Lakerunner Terraform"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

test: ## Run all tests (format check + validate all envs + plan gcp-poc)
	@./test.sh

check: test ## Alias for test

fmt: ## Format Terraform files (recursive across all envs)
	@echo "Formatting Terraform files..."
	@cd terraform && terraform fmt -recursive

validate: ## Validate all environments (no credentials needed)
	@for env in $(ENVIRONMENTS); do \
		echo "==> Validating $$env"; \
		(cd terraform/environments/$$env && terraform init -backend=false -input=false >/dev/null && terraform validate) || exit 1; \
	done

plan: plan-gcp ## Alias for plan-gcp

plan-gcp: ## Run terraform plan against gcp-poc with the test project ID
	@echo "Running terraform plan against gcp-poc..."
	@cd terraform/environments/gcp-poc && terraform plan -var="project_id=lakerunner-terraform"

clean: ## Clean up temporary files
	@echo "Cleaning up..."
	@find . -name "*.tfstate*" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.plan" -delete
