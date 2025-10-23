terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "lvs-cloud-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
    endpoints = {
      s3 = "https://nbg1.your-objectstorage.com"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Variables
variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "lvs-cloud"
}

variable "domain" {
  description = "Base domain for subdomains"
  type        = string
  default     = "lvs.me.uk"
}

variable "registry_pass" {
  description = "Docker registry password (plaintext for k3s registries.yaml)"
  type        = string
  sensitive   = true
}

variable "registry_htpasswd" {
  description = "Docker registry bcrypt password hash for Caddy (generate with: caddy hash-password)"
  type        = string
  sensitive   = true
}

variable "flux_ssh_key" {
  description = "Flux GitOps SSH private key for repository access"
  type        = string
  sensitive   = true
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx22" # 2 vCPU, 4GB RAM, 40GB SSD - ~€4.90/month
}

variable "location" {
  description = "Hetzner location"
  type        = string
  default     = "nbg1" # Nuremberg
}

variable "datacenter" {
  description = "Hetzner datacenter"
  type        = string
  default     = "nbg1-dc3" # Nuremberg
}

# SSH Key for server access
resource "hcloud_ssh_key" "default" {
  name       = "${var.project_name}-key"
  public_key = file("${path.module}/lvs-cloud.pub")
  labels = {
    project = var.project_name
  }
}

# Private network
resource "hcloud_network" "main" {
  name     = "${var.project_name}-network"
  ip_range = "10.0.0.0/16"

  labels = {
    project = var.project_name
  }
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# Firewall
resource "hcloud_firewall" "web" {
  name = "${var.project_name}-web"

  rule {
    direction  = "in"
    port       = "22"
    protocol   = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    port       = "80"
    protocol   = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    port       = "443"
    protocol   = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }


  labels = {
    project = var.project_name
  }
}

# Persistent storage volume
resource "hcloud_volume" "data" {
  name     = "${var.project_name}-data"
  location = var.location
  size     = 50 # 50GB initial size
  format   = "ext4"

  labels = {
    project = var.project_name
    purpose = "persistent-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Main server
resource "hcloud_server" "main" {
  name        = "${var.project_name}-server"
  image       = "ubuntu-22.04"
  server_type = var.server_type
  datacenter  = var.datacenter

  ssh_keys = [hcloud_ssh_key.default.id]

  firewall_ids = [hcloud_firewall.web.id]

  network {
    network_id = hcloud_network.main.id
    ip         = "10.0.1.10"
  }

  depends_on = [hcloud_network_subnet.main]

  labels = {
    project = var.project_name
    role    = "main"
  }

  user_data = templatefile("${path.module}/cloud-init-k3s.yml", {
    ssh_key           = trimspace(file("${path.module}/lvs-cloud.pub"))
    registry_pass     = var.registry_pass
    registry_htpasswd = var.registry_htpasswd
    flux_ssh_key      = var.flux_ssh_key
  })
}

# Attach volume to server
resource "hcloud_volume_attachment" "data" {
  volume_id = hcloud_volume.data.id
  server_id = hcloud_server.main.id
  automount = true
}

# Outputs
output "server_ip" {
  value = hcloud_server.main.ipv4_address
}

output "server_ipv6" {
  value = hcloud_server.main.ipv6_address
}

output "network_id" {
  value = hcloud_network.main.id
}

output "volume_id" {
  value = hcloud_volume.data.id
}

output "volume_device_path" {
  value = "/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.data.id}"
}

output "k3s_info" {
  value = "SSH to server: ssh ubuntu@${hcloud_server.main.ipv4_address} | kubeconfig: /etc/rancher/k3s/k3s.yaml"
}
