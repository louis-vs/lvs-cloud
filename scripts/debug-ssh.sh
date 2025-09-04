#!/bin/bash

SERVER_IP="91.99.230.185"

echo "=== SSH Key Debugging ==="
echo "1. Local SSH key fingerprint:"
ssh-keygen -lf ~/.ssh/lvs-cloud.pub

echo -e "\n2. SSH key in repo:"
ssh-keygen -lf ./infrastructure/lvs-cloud.pub

echo -e "\n3. Hetzner SSH key fingerprint:"
source .env && hcloud ssh-key describe lvs-cloud-key --output json | jq -r '.fingerprint'

echo -e "\n4. Keys in SSH agent:"
ssh-add -l

echo -e "\n5. Testing SSH with verbose output (first few lines):"
timeout 10s ssh -v -o ConnectTimeout=5 ubuntu@$SERVER_IP "echo connected" 2>&1 | head -20

echo -e "\n6. Testing with specific key:"
timeout 10s ssh -v -i ~/.ssh/lvs-cloud -o ConnectTimeout=5 ubuntu@$SERVER_IP "echo connected" 2>&1 | head -20
