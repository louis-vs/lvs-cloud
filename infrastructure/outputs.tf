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
