# ===========================================
# Terraform Variables
# ===========================================

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ===========================================
# Provider Configuration
# ===========================================

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ===========================================
# Variable Definitions (for tfvars)
# ===========================================

# Create terraform.tfvars with:
# project_id   = "your-project-id"
# region       = "us-central1"
# zone         = "us-central1-a"
# environment  = "dev"
