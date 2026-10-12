# Convenience targets. Run `make help` to list them.
TF_DIR := terraform/envs/dev
REGION ?= us-east-1

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: fmt
fmt: ## terraform fmt
	terraform -chdir=$(TF_DIR) fmt -recursive

.PHONY: validate
validate: ## terraform validate
	terraform -chdir=$(TF_DIR) init -backend=false && terraform -chdir=$(TF_DIR) validate

.PHONY: plan
plan: ## terraform plan
	terraform -chdir=$(TF_DIR) init && terraform -chdir=$(TF_DIR) plan

.PHONY: apply
apply: ## terraform apply
	terraform -chdir=$(TF_DIR) init && terraform -chdir=$(TF_DIR) apply

.PHONY: bootstrap
bootstrap: ## Create remote-state backend (run once)
	scripts/bootstrap-backend.sh $(REGION)

.PHONY: deploy
deploy: ## Install Argo CD, secrets, apps after apply
	scripts/deploy.sh

.PHONY: test
test: ## Run app unit tests
	cd app && npm ci && npm test

.PHONY: pause
pause: ## Scale down / stop compute to save credits
	scripts/pause.sh

.PHONY: resume
resume: ## Resume compute
	scripts/resume.sh

.PHONY: destroy
destroy: ## FULL teardown of all AWS resources
	scripts/cleanup.sh
