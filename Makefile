# ===========================================
# Makefile - Zentria Deployment Commands
# ===========================================

.PHONY: help infra-deploy infra-destroy infra-plan ansible-deploy ansible-check docker-up docker-down docker-logs ssh test

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
NC     := \033[0m

# Project
PROJECT_ID := zentria-crm
REGION     := us-central1
ZONE       := us-central1-a

# Ansible
INVENTORY  := inventory.ini
PLAYBOOK   := playbook.yml
ANSIBLE_USER := ubuntu

# Docker
APP_DIR    := /opt/zentria

# ===========================================
# Help
# ===========================================

help: ## Show this help
	@echo "$(GREEN)Zentria Deployment Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# ===========================================
# Terraform Commands (Infrastructure)
# ===========================================

infra-init: ## Initialize Terraform
	@cd terraform && terraform init

infra-plan: ## Plan infrastructure changes
	@cd terraform && terraform plan -var-file="terraform.tfvars"

infra-apply: ## Apply infrastructure changes
	@cd terraform && terraform apply -var-file="terraform.tfvars"

infra-destroy: ## Destroy all infrastructure
	@cd terraform && terraform destroy -var-file="terraform.tfvars"

infra-output: ## Show Terraform outputs (VM IP, etc.)
	@cd terraform && terraform output

# ===========================================
# Ansible Commands (Configuration)
# ===========================================

ansible-check: ## Dry-run Ansible playbook
	@ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --check

ansible-deploy: ## Run Ansible playbook
	@ansible-playbook -i $(INVENTORY) $(PLAYBOOK)

ansible-destroy: ## Stop and remove all services
	@ansible-playbook -i $(INVENTORY) playbook.yml --tags destroy

# ===========================================
# SSH Commands
# ===========================================

ssh-prod: ## SSH to production server
	@gcloud compute ssh prod-odoo --zone=$(ZONE)

# ===========================================
# Docker Commands (Direct on server)
# ===========================================

docker-up: ## Start Docker containers
	@cd $(APP_DIR) && docker compose up -d

docker-down: ## Stop Docker containers
	@cd $(APP_DIR) && docker compose down

docker-logs: ## View Docker logs
	@cd $(APP_DIR) && docker compose logs -f

docker-restart: ## Restart all containers
	@cd $(APP_DIR) && docker compose restart

docker-status: ## Show container status
	@cd $(APP_DIR) && docker compose ps

# ===========================================
# Database Commands
# ===========================================

db-backup: ## Create database backup
	@mkdir -p $(APP_DIR)/backups
	@docker compose exec -T db pg_dump -U odoo odoo > $(APP_DIR)/backups/backup_$$(date +%Y%m%d_%H%M%S).sql

db-restore: ## Restore database from backup
	@read -p "Backup file: " file; \
	docker compose exec -T db psql -U odoo -d odoo < $$file

# ===========================================
# Full Deployment
# ===========================================

deploy: infra-apply ansible-deploy ## Full deployment (infra + config)

# ===========================================
# Development
# ===========================================

test: ## Run Ansible in check mode (dry-run)
	@ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --check --diff
