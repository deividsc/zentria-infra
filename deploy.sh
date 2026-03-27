#!/bin/bash
# ===========================================
# Quick Deploy Script
# One-command deployment to GCP
# ===========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
command -v gcloud >/dev/null 2>&1 || error "gcloud CLI not installed"
command -v ansible >/dev/null 2>&1 || error "Ansible not installed"
command -v terraform >/dev/null 2>&1 || error "Terraform not installed"

# Get VM IP
log "Getting VM IP..."
VM_IP=$(gcloud compute instances describe odoo-zentria \
    --zone=us-central1-a \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null)

if [ -z "$VM_IP" ]; then
    warn "VM not found. Running Terraform first..."
    cd terraform
    terraform init
    terraform apply -var-file="terraform.tfvars"
    cd ..
    VM_IP=$(gcloud compute instances describe odoo-zentria \
        --zone=us-central1-a \
        --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
fi

log "VM IP: $VM_IP"

# Wait for VM to be ready
log "Waiting for VM to be ready..."
sleep 10

# Update inventory
log "Updating inventory..."
sed -i "s/ansible_host=.*/ansible_host=$VM_IP/" ansible/inventory.ini

# Run Ansible
log "Running Ansible playbook..."
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --diff

log "Deployment complete!"
log "Odoo should be available at: http://$VM_IP:8069"
