# ===========================================
# Terraform - GCP Infrastructure
# ===========================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "zentria-terraform-state"
    prefix = "terraform/state"
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
# VPC Network
# ===========================================

resource "google_compute_network" "vpc" {
  name                    = "zentria-vpc"
  auto_create_subnetworks = false
  description             = "Zentria VPC Network"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "zentria-subnet"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region

  private_ip_google_access = true
}

# ===========================================
# Firewall Rules
# ===========================================

resource "google_compute_firewall" "allow_http_https" {
  name        = "allow-http-https"
  network     = google_compute_network.vpc.name
  description = "Allow HTTP and HTTPS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

resource "google_compute_firewall" "allow_odoo" {
  name        = "allow-odoo"
  network     = google_compute_network.vpc.name
  description = "Allow Odoo ports"

  allow {
    protocol = "tcp"
    ports    = ["8069", "8072"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["odoo-server"]
}

resource "google_compute_firewall" "allow_ssh" {
  name        = "allow-ssh"
  network     = google_compute_network.vpc.name
  description = "Allow SSH from anywhere"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-access"]
}

resource "google_compute_firewall" "allow_internal" {
  name        = "allow-internal"
  network     = google_compute_network.vpc.name
  description = "Allow internal traffic"

  allow {
    protocol = "all"
  }

  source_tags = ["odoo-server"]
}

# ===========================================
# Static IP
# ===========================================

resource "google_compute_address" "static_ip" {
  name         = "zentria-static-ip"
  region       = var.region
  address_type = "EXTERNAL"
  description  = "Static IP for Odoo server"
}

# ===========================================
# VM Instance
# ===========================================

resource "google_compute_instance" "odoo_vm" {
  name         = "odoo-zentria"
  machine_type = "e2-micro"
  zone         = var.zone
  description  = "Odoo server for Zentria CRM"

  tags = ["http-server", "https-server", "odoo-server", "ssh-access"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
      size  = 30
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.name
    access_config {
      nat_ip = google_compute_address.static_ip.id
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  labels = {
    environment = var.environment
    project     = "zentria"
    managed_by  = "terraform"
  }
}

# ===========================================
# Outputs
# ===========================================

output "vm_ip" {
  description = "VM External IP"
  value       = google_compute_instance.odoo_vm.network_interface[0].access_config[0].nat_ip
}

output "vm_name" {
  description = "VM Instance Name"
  value       = google_compute_instance.odoo_vm.name
}

output "static_ip" {
  description = "Static IP Address"
  value       = google_compute_address.static_ip.address
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "gcloud compute ssh ${google_compute_instance.odoo_vm.name} --zone=${var.zone}"
}
