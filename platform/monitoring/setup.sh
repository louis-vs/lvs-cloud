#!/bin/bash

# Setup script for monitoring stack
set -e

STACK_DIR="/opt/monitoring-stack"
REGISTRY_USER="admin"
REGISTRY_PASS="registry123"

echo "Setting up monitoring stack..."

# Create directories
sudo mkdir -p $STACK_DIR/{traefik/acme,registry/{data,auth},grafana/{data,provisioning/{dashboards,datasources}},prometheus/{config,data},loki/{config,data}}

# Set proper permissions
sudo chown -R 472:472 $STACK_DIR/grafana/data
sudo chown -R 65534:65534 $STACK_DIR/prometheus/data
sudo chown -R 10001:10001 $STACK_DIR/loki/data

# Create registry auth
sudo htpasswd -Bbn $REGISTRY_USER $REGISTRY_PASS | sudo tee $STACK_DIR/registry/auth/htpasswd

# Create Traefik ACME file
sudo touch $STACK_DIR/traefik/acme/acme.json
sudo chmod 600 $STACK_DIR/traefik/acme/acme.json

# Create Prometheus config
sudo tee $STACK_DIR/prometheus/config/prometheus.yml > /dev/null << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']

  - job_name: 'ruby-app'
    static_configs:
      - targets: ['app.lvs.me.uk:443']
    scrape_interval: 30s
EOF

# Create Loki config
sudo tee $STACK_DIR/loki/config/local-config.yaml > /dev/null << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOF

# Create Grafana datasource config
sudo tee $STACK_DIR/grafana/provisioning/datasources/datasources.yml > /dev/null << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
EOF

echo "✅ Setup complete!"
echo "Registry credentials: $REGISTRY_USER / $REGISTRY_PASS"
echo "Grafana admin password: admin123"
