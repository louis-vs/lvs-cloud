# Application Migration to Helm Charts

## Overview

Applications in v2 are packaged as **Helm charts** with values files that include **Flux image setter markers**. This enables automatic deployments when new images are pushed.

## Helm Chart Structure

```
applications/ruby-demo-app/
├── chart/
│   ├── Chart.yaml           # Helm chart metadata
│   ├── values.yaml          # Default values
│   └── templates/
│       ├── deployment.yaml  # Kubernetes Deployment
│       ├── service.yaml     # Kubernetes Service
│       ├── ingress.yaml     # Kubernetes Ingress (TLS + cert-manager)
│       └── _helpers.tpl     # Template helpers
├── values.yaml              # Production values with Flux setters
└── helmrelease.yaml         # Flux HelmRelease
```

## Creating a Helm Chart

### Chart.yaml

```yaml
apiVersion: v2
name: ruby-demo-app
description: Ruby Sinatra demo application
type: application
version: 1.0.0
appVersion: "1.0.0"
```

### Default values.yaml (in chart/)

```yaml
replicaCount: 2

image:
  repository: registry.lvs.me.uk/ruby-demo-app
  pullPolicy: IfNotPresent
  tag: ""  # Override via parent values

service:
  type: ClusterIP
  port: 80
  targetPort: 9292

ingress:
  enabled: true
  className: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: app.lvs.me.uk
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: ruby-demo-app-tls
      hosts:
        - app.lvs.me.uk

resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
  limits:
    cpu: "1"
    memory: "1Gi"

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10

env: []
  # - name: DATABASE_URL
  #   value: postgresql://user:pass@postgresql:5432/db

envFrom: []
  # - secretRef:
  #     name: app-secrets
```

### templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "ruby-demo-app.fullname" . }}
  labels:
    {{- include "ruby-demo-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "ruby-demo-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "ruby-demo-app.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        {{- with .Values.readinessProbe }}
        readinessProbe:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with .Values.livenessProbe }}
        livenessProbe:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with .Values.resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with .Values.env }}
        env:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with .Values.envFrom }}
        envFrom:
          {{- toYaml . | nindent 10 }}
        {{- end }}
```

### templates/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "ruby-demo-app.fullname" . }}
  labels:
    {{- include "ruby-demo-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "ruby-demo-app.selectorLabels" . | nindent 4 }}
```

### templates/ingress.yaml

```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "ruby-demo-app.fullname" . }}
  labels:
    {{- include "ruby-demo-app.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "ruby-demo-app.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
```

### templates/_helpers.tpl

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "ruby-demo-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ruby-demo-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ruby-demo-app.labels" -}}
helm.sh/chart: {{ include "ruby-demo-app.chart" . }}
{{ include "ruby-demo-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ruby-demo-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ruby-demo-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ruby-demo-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
```

## Production Values with Flux Setters

Create `applications/ruby-demo-app/values.yaml` (outside `chart/`):

```yaml
# Production overrides
image:
  repository: registry.lvs.me.uk/ruby-demo-app   # {"$imagepolicy": "flux-system:ruby-demo-app:name"}
  tag: "1.0.0"                                    # {"$imagepolicy": "flux-system:ruby-demo-app:tag"}
  pullPolicy: IfNotPresent

replicaCount: 2

env:
  - name: DATABASE_URL
    value: postgresql://ruby_demo_user:CHANGEME@postgresql:5432/ruby_demo
  - name: RACK_ENV
    value: production

resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
  limits:
    cpu: "1"
    memory: "1Gi"
```

**Key**: The `# {"$imagepolicy": "..."}` comments are **Flux image setters**. Flux will update the `repository` and `tag` fields when new images are detected.

## HelmRelease

Create `applications/ruby-demo-app/helmrelease.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: ruby-demo-app
  namespace: default
spec:
  interval: 2m
  chart:
    spec:
      chart: ./applications/ruby-demo-app/chart
      sourceRef:
        kind: GitRepository
        name: monorepo
        namespace: flux-system
  valuesFiles:
    - ./applications/ruby-demo-app/values.yaml
```

**Alternative**: Inline values instead of `valuesFiles`:

```yaml
  values:
    image:
      repository: registry.lvs.me.uk/ruby-demo-app   # {"$imagepolicy": "flux-system:ruby-demo-app:name"}
      tag: "1.0.0"                                    # {"$imagepolicy": "flux-system:ruby-demo-app:tag"}
```

## Flux Image Automation

Create `platform/flux-image-automation/ruby-demo-app.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: ruby-demo-app
  namespace: flux-system
spec:
  image: registry.lvs.me.uk/ruby-demo-app
  interval: 1m
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: ruby-demo-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: ruby-demo-app
  policy:
    semver:
      range: ">=1.0.0"
```

**Note**: The `ImageUpdateAutomation` is global (one per repo) and is defined once in `platform/flux-image-automation/image-update.yaml`.

## Database-Enabled Apps

### Environment Variables

Use a Kubernetes Secret for database passwords:

```yaml
# applications/ruby-demo-app/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ruby-demo-app-db
  namespace: default
type: Opaque
stringData:
  DATABASE_URL: postgresql://ruby_demo_user:${POSTGRES_RUBY_PASSWORD}@postgresql:5432/ruby_demo
```

**Note**: Inject `POSTGRES_RUBY_PASSWORD` via Terraform or Flux's secret management (e.g., SOPS, sealed-secrets).

### Use in Deployment

Update `values.yaml`:

```yaml
envFrom:
  - secretRef:
      name: ruby-demo-app-db
```

## Testing Locally

### Render Helm Chart

```bash
cd applications/ruby-demo-app
helm template . --debug
```

### Install Manually (for testing)

```bash
helm install ruby-demo-app ./chart -f values.yaml
```

### Validate Manifests

```bash
helm template . --debug | kubectl apply --dry-run=client -f -
```

## CI/CD Integration

### Build Workflow

```yaml
name: Build Application

on:
  push:
    branches: [main]
    paths:
      - 'applications/ruby-demo-app/**'
      - '!applications/ruby-demo-app/chart/**'  # Ignore chart changes

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to registry
        run: |
          echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login registry.lvs.me.uk \
            -u robot_user --password-stdin

      - name: Build and push
        run: |
          cd applications/ruby-demo-app
          VERSION=$(git rev-parse --short HEAD)
          docker build -t registry.lvs.me.uk/ruby-demo-app:${VERSION} .
          docker tag registry.lvs.me.uk/ruby-demo-app:${VERSION} \
                     registry.lvs.me.uk/ruby-demo-app:1.2.3  # Use semver
          docker push registry.lvs.me.uk/ruby-demo-app:1.2.3
```

**Flux takes over**: Detects new tag → updates values.yaml → commits → deploys.

## Migration Checklist

For each application:

- [ ] Create Helm chart in `applications/<app>/chart/`
- [ ] Add `Chart.yaml`, `values.yaml` (defaults), `templates/`
- [ ] Create production `values.yaml` with Flux image setters
- [ ] Create `helmrelease.yaml`
- [ ] Add `ImageRepository` + `ImagePolicy` in `platform/flux-image-automation/`
- [ ] Update GitHub Actions to build + push with semver tags
- [ ] Remove old `docker-compose.prod.yml` and `deploy.sh`
- [ ] Test deployment: `flux reconcile helmrelease <app>`

## Common Patterns

### Apps with PVCs

Add `volumeClaimTemplates` or `persistentVolumeClaim` in `values.yaml`:

```yaml
persistence:
  enabled: true
  storageClass: longhorn
  accessMode: ReadWriteOnce
  size: 5Gi
  mountPath: /app/data
```

Update `deployment.yaml` template:

```yaml
{{- if .Values.persistence.enabled }}
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: {{ include "ruby-demo-app.fullname" . }}-data
{{- end }}
```

### Apps with Secrets

Use `envFrom` or `env` with `secretKeyRef`:

```yaml
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: ruby-demo-app-secrets
        key: api-key
```

### Apps with ConfigMaps

```yaml
envFrom:
  - configMapRef:
      name: ruby-demo-app-config
```

### Apps with Init Containers

Useful for database migrations:

```yaml
# In deployment.yaml template
initContainers:
  - name: migrate
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
    command: ["bundle", "exec", "rake", "db:migrate"]
    env:
      - name: DATABASE_URL
        value: {{ .Values.env.DATABASE_URL }}
```

## Troubleshooting

### HelmRelease Failing

```bash
# Check status
flux get helmreleases -A

# Describe for events
kubectl describe helmrelease ruby-demo-app -n default

# Check Helm controller logs
kubectl -n flux-system logs deploy/helm-controller -f

# Manually render chart
helm template applications/ruby-demo-app/chart -f applications/ruby-demo-app/values.yaml
```

### Image Not Updating

```bash
# Check ImageRepository
flux get images repository

# Check ImagePolicy
flux get images policy

# Check ImageUpdateAutomation
flux get images update

# Force image reflector to scan
flux reconcile image repository ruby-demo-app

# Check if Flux committed tag update
git log --oneline -5
```

### Pods CrashLooping

```bash
# Check pod logs
kubectl logs -f ruby-demo-app-<pod-hash>

# Describe pod for events
kubectl describe pod ruby-demo-app-<pod-hash>

# Check probes
kubectl get pod ruby-demo-app-<pod-hash> -o yaml | grep -A 10 Probe
```

## Next Steps

- [Flux Setup](FLUX_SETUP.md) - Configure Flux Image Automation
- [Storage Setup](STORAGE.md) - Add PVCs for stateful apps
