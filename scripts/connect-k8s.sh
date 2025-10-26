#!/usr/bin/env bash

SERVER_IP=$(dig +short app.lvs.me.uk)

echo "Setting up SSH tunnel for kubectl access..."
ssh -N -L 6443:127.0.0.1:6443 ubuntu@$SERVER_IP &

ssh ubuntu@$SERVER_IP "cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-kubeconfig.yaml
export KUBECONFIG=/tmp/k3s-kubeconfig.yaml
