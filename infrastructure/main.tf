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

  user_data = templatefile("${path.module}/cloud-init.yml", {
    ssh_key           = trimspace(file("${path.module}/lvs-cloud.pub"))
    registry_pass     = var.registry_pass
    registry_htpasswd = var.registry_htpasswd
  })
}

# Attach volume to server
resource "hcloud_volume_attachment" "data" {
  volume_id = hcloud_volume.data.id
  server_id = hcloud_server.main.id
  automount = true
}
