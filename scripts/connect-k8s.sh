#!/usr/bin/env bash

set -e

SERVER_IP=$(dig +short app.lvs.me.uk)

echo "Setting up kubectl access to LVS Cloud..."

# Kill any existing SSH tunnels to port 6443
echo "Cleaning up existing tunnels..."
pkill -f "ssh.*6443:127.0.0.1:6443" 2>/dev/null || true
sleep 1

# Start new SSH tunnel in background, fully detached from shell
echo "Starting SSH tunnel to $SERVER_IP:6443..."
ssh -N -L 6443:127.0.0.1:6443 ubuntu@$SERVER_IP </dev/null >/dev/null 2>&1 &
TUNNEL_PID=$!
disown
echo "SSH tunnel started (PID: $TUNNEL_PID)"

# Wait for tunnel to be established
sleep 2

# Download k3s kubeconfig from server
echo "Downloading kubeconfig from server..."
ssh ubuntu@$SERVER_IP "cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-lvs-cloud.yaml

# Create ~/.kube directory if it doesn't exist
mkdir -p ~/.kube

# Update server URL to use local tunnel
sed -i.bak 's|https://127.0.0.1:6443|https://127.0.0.1:6443|g' /tmp/k3s-lvs-cloud.yaml

# Merge into ~/.kube/config
echo "Merging kubeconfig into ~/.kube/config..."
if [ -f ~/.kube/config ]; then
  cp ~/.kube/config ~/.kube/config.backup.$(date +%s)
  KUBECONFIG=~/.kube/config:/tmp/k3s-lvs-cloud.yaml kubectl config view --flatten > /tmp/merged-config
  mv /tmp/merged-config ~/.kube/config
else
  cp /tmp/k3s-lvs-cloud.yaml ~/.kube/config
fi

# Rename context to lvs-cloud
kubectl config rename-context default lvs-cloud 2>/dev/null || true

# Set lvs-cloud as current context
kubectl config use-context lvs-cloud

# Clean up temp files
rm -f /tmp/k3s-lvs-cloud.yaml /tmp/k3s-lvs-cloud.yaml.bak

echo ""
echo "✅ kubectl configured successfully!"
echo "   Context: lvs-cloud"
echo "   Tunnel PID: $TUNNEL_PID"
echo ""
echo "You can now use kubectl in any shell."
echo "To kill the tunnel: pkill -f 'ssh.*6443:127.0.0.1:6443'"
