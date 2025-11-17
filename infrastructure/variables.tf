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
