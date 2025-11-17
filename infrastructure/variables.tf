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

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx23" # 2 vCPU, 8GB RAM, 40GB SSD - cx22 replacement
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

variable "S3_ACCESS_KEY" {
  description = "S3 access key for etcd backups (Hetzner Object Storage)"
  type        = string
  sensitive   = true
}

variable "S3_SECRET_KEY" {
  description = "S3 secret key for etcd backups (Hetzner Object Storage)"
  type        = string
  sensitive   = true
}
