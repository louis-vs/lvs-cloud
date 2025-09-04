#!/bin/bash

# Test SSH connection to server
SERVER_IP="91.99.230.185"

echo "Testing SSH connection to $SERVER_IP..."

# Test connection and basic setup
ssh ubuntu@$SERVER_IP << 'EOF'
echo "=== Server Info ==="
whoami
hostname
uptime

echo -e "\n=== Docker Status ==="
docker version --format '{{.Server.Version}}' 2>/dev/null || echo "Docker not ready"
docker info --format '{{.ServerVersion}}' 2>/dev/null || echo "Docker daemon not accessible"

echo -e "\n=== System Status ==="
df -h /
free -h

echo -e "\n=== Network ==="
ip addr show | grep "inet " | grep -v "127.0.0.1"
EOF

if [ $? -eq 0 ]; then
    echo -e "\n✅ SSH connection successful!"
else
    echo -e "\n❌ SSH connection failed"
    exit 1
fi
