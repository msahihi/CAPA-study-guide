# Installation and Configuration

## Overview

Installing and properly configuring Argo CD is a fundamental skill for the CAPA exam. This section covers various installation methods, initial setup procedures, CLI installation, accessing the Web UI, and important configuration options. Understanding these concepts ensures you can deploy and configure Argo CD in different environments and meet specific organizational requirements.

Argo CD can be installed using several methods, each suitable for different use cases, from quick testing to production-grade deployments. After installation, proper configuration of settings, repositories, and access controls is essential for secure and efficient operations.

## Key Topics

### Installation Methods

#### Method 1: kubectl apply (Non-HA Installation)

The simplest installation method, suitable for development and testing environments.

**Installation Steps**:

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify installation
kubectl get pods -n argocd

# Expected pods:
# - argocd-application-controller
# - argocd-applicationset-controller
# - argocd-dex-server
# - argocd-notifications-controller
# - argocd-redis
# - argocd-repo-server
# - argocd-server
```

**Characteristics**:

- Single replica for all components
- Suitable for testing and development
- Not recommended for production
- Quick to install and setup
- Minimal resource requirements

#### Method 2: kubectl apply (HA Installation)

High Availability installation for production environments.

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD HA version
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml

# Verify installation
kubectl get pods -n argocd

# HA deployment includes:
# - Multiple replicas of critical components
# - Redis HA with sentinel
# - Separate repo-server instances
```

**Characteristics**:

- Multiple replicas for high availability
- Redis HA with sentinel
- Recommended for production
- Higher resource requirements
- Better resilience and scalability

#### Method 3: Helm Chart Installation

Most flexible installation method with extensive configuration options.

```bash
# Add Argo CD Helm repository
helm repo add argo-cd https://argoproj.github.io/argo-helm
helm repo update

# Install with default values
helm install argocd argo-cd/argo-cd \
  --namespace argocd \
  --create-namespace

# Install with custom values
helm install argocd argo-cd/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values values.yaml
```

**Sample Helm values.YAML**:

```yaml
# values.yaml for production deployment
global:
  image:
    tag: v2.9.3

server:
  replicas: 2
  service:
    type: LoadBalancer
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - argocd.example.com
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.example.com
  config:
    url: https://argocd.example.com
    application.instanceLabelKey: argocd.argoproj.io/instance

controller:
  replicas: 2
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 1000m
      memory: 1Gi

repoServer:
  replicas: 2
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

redis-ha:
  enabled: true

dex:
  enabled: true

applicationSet:
  enabled: true

notifications:
  enabled: true
```

**Helm Commands**:

```bash
# Upgrade existing installation
helm upgrade argocd argo-cd/argo-cd \
  --namespace argocd \
  --values values.yaml

# List installed releases
helm list -n argocd

# Uninstall
helm uninstall argocd -n argocd

# Get default values
helm show values argo-cd/argo-cd > default-values.yaml
```

#### Method 4: Operator Installation

Using the Argo CD Operator for automated lifecycle management.

```bash
# Install Argo CD Operator using OLM (OpenShift/OKD)
kubectl create -f https://operatorhub.io/install/argocd-operator.yaml

# Create ArgoCD instance
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: argocd
  namespace: argocd
spec:
  server:
    route:
      enabled: true
    replicas: 2
  controller:
    replicas: 2
  repo:
    replicas: 2
  ha:
    enabled: true
  redis:
    replicas: 3
EOF
```

**Operator Benefits**:

- Automated installation and upgrades
- Simplified configuration management
- Built-in backup and restore
- Day 2 operations automation
- Native OpenShift/OKD integration

### Initial Setup

#### Accessing the Initial Admin Password

After installation, retrieve the initial admin password:

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Or using argocd CLI
argocd admin initial-password -n argocd
```

#### Port Forwarding (Quick Access)

```bash
# Port forward to access Argo CD API server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI at: https://localhost:8080
# Username: admin
# Password: (retrieved from secret above)
```

#### Exposing the Argo CD API Server

**Option 1: LoadBalancer Service**

```bash
# Patch service to LoadBalancer type
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IP
kubectl get svc argocd-server -n argocd
```

**Option 2: Ingress**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              name: https
  tls:
  - hosts:
    - argocd.example.com
    secretName: argocd-tls
```

**Option 3: OpenShift Route**

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: argocd-server
  namespace: argocd
spec:
  host: argocd.apps.example.com
  to:
    kind: Service
    name: argocd-server
  port:
    targetPort: https
  tls:
    termination: passthrough
    insecureEdgeTerminationPolicy: Redirect
```

#### Changing the Admin Password

```bash
# Login first
argocd login <ARGOCD_SERVER>

# Update password
argocd account update-password

# Or update for specific user
argocd account update-password --account <username>
```

### CLI Installation

#### Linux Installation

```bash
# Download latest version
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Install to /usr/local/bin
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Remove download
rm argocd-linux-amd64

# Verify installation
argocd version
```

#### macOS Installation

```bash
# Using Homebrew
brew install argocd

# Or download directly
curl -sSL -o argocd-darwin-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
sudo install -m 555 argocd-darwin-amd64 /usr/local/bin/argocd
rm argocd-darwin-amd64

# Verify installation
argocd version
```

#### Windows Installation

```powershell
# Download from GitHub releases
# https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe

# Or using Chocolatey
choco install argocd-cli

# Verify installation
argocd version
```

#### CLI Login

```bash
# Login using username/password
argocd login <ARGOCD_SERVER>

# Login with specific credentials
argocd login <ARGOCD_SERVER> --username admin --password <password>

# Login with SSO
argocd login <ARGOCD_SERVER> --sso

# Login with token
argocd login <ARGOCD_SERVER> --auth-token <token>

# Skip TLS verification (not recommended for production)
argocd login <ARGOCD_SERVER> --insecure

# Verify login
argocd account get-user-info
```

### Accessing the UI

#### Initial Login

1. Navigate to Argo CD URL (https://argocd.example.com)
2. Accept certificate warning (if using self-signed cert)
3. Enter credentials:
   - Username: `admin`
   - Password: (from initial admin secret)
4. (Optional) Change password after first login

#### UI Overview

**Main Sections**:

- **Applications**: View and manage all applications
- **Settings**: Configure repositories, clusters, projects, and system settings
- **User Info**: Account settings and tokens

**Application View Features**:

- Grid/List view toggle
- Filter by project, cluster, namespace
- Search functionality
- Sync status and health indicators
- Quick actions (sync, delete, refresh)

### Configuration Options

#### Core Configuration (argocd-cm ConfigMap)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Application timeout settings
  timeout.reconciliation: 180s
  timeout.hard.reconciliation: 0

  # Repository settings
  repositories: |
    - url: https://github.com/example/repo
      passwordSecret:
        name: repo-credentials
        key: password
      usernameSecret:
        name: repo-credentials
        key: username
      insecure: false
      enableLfs: true

  # Resource exclusions
  resource.exclusions: |
    - apiGroups:
      - "*"
      kinds:
      - "ProviderConfigUsage"
      clusters:
      - "*"

  # Resource inclusions
  resource.inclusions: |
    - apiGroups:
      - "*"
      kinds:
      - "*"
      clusters:
      - "*"

  # URL for Argo CD
  url: https://argocd.example.com

  # Anonymous access
  users.anonymous.enabled: "false"

  # Enable admin user
  admin.enabled: "true"

  # Application instance label key
  application.instanceLabelKey: argocd.argoproj.io/instance

  # Enable App-in-Any-Namespace
  application.namespaces: |
    - app-team-one
    - app-team-two

  # Diff customization
  resource.customizations.ignoreDifferences.all: |
    managedFieldsManagers:
    - kube-controller-manager

  # Custom health checks
  resource.customizations.health.argoproj.io_Application: |
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        if obj.status.health.message ~= nil then
          hs.message = obj.status.health.message
        end
      end
    end
    return hs
```

#### Command Parameters Configuration (argocd-cmd-params-cm)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  # API server settings
  server.insecure: "false"
  server.basehref: "/"
  server.rootpath: "/"
  server.staticassets: "/shared/app"

  # Repository server settings
  reposerver.parallelism.limit: "0"

  # Controller settings
  controller.status.processors: "20"
  controller.operation.processors: "10"
  controller.self.heal.timeout.seconds: "5"
  controller.repo.server.timeout.seconds: "60"

  # Application resync period
  timeout.reconciliation: "180s"

  # TLS configuration
  server.tls.minversion: "1.2"
  server.tls.maxversion: "1.3"
  server.tls.ciphers: "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:TLS_RSA_WITH_AES_256_GCM_SHA384"
```

#### RBAC Configuration (argocd-rbac-cm)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default policy
  policy.default: role:readonly

  # CSV format policies
  policy.csv: |
    # Grant admin role to admin user
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, projects, *, *, allow

    # Grant developer role specific permissions
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, create, */*, allow

    # Assign roles to users
    g, admin-user, role:admin
    g, dev-team, role:developer

  # OIDC group claims
  scopes: '[groups, email]'
```

#### Notification Configuration (argocd-notifications-cm)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Notification services
  service.slack: |
    token: $slack-token

  service.email: |
    host: smtp.gmail.com
    port: 587
    username: $email-username
    password: $email-password
    from: argocd@example.com

  # Notification templates
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} is now running new version.
    slack:
      attachments: |
        [{
          "title": "{{ .app.metadata.name}}",
          "title_link":"{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "color": "#18be52",
          "fields": [
          {
            "title": "Sync Status",
            "value": "{{.app.status.sync.status}}",
            "short": true
          },
          {
            "title": "Repository",
            "value": "{{.app.spec.source.repoURL}}",
            "short": true
          }
          ]
        }]

  # Triggers
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
```

### Post-Installation Configuration

#### Disable TLS for Internal Communication

```bash
# Edit deployment
kubectl edit deployment argocd-server -n argocd

# Add flag to container args
args:
  - /usr/local/bin/argocd-server
  - --insecure
```

#### Configure Resource Limits

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
spec:
  template:
    spec:
      containers:
      - name: argocd-server
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi
```

#### Configure Storage

```yaml
# Redis persistence
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: argocd-redis
  namespace: argocd
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  storageClassName: standard

---
# Update redis deployment to use PVC
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-redis
  namespace: argocd
spec:
  template:
    spec:
      volumes:
      - name: redis-data
        persistentVolumeClaim:
          claimName: argocd-redis
```

## Practice Examples

### Example 1: Complete Non-HA Installation

```bash
#!/bin/bash

# Install Argo CD
echo "Installing Argo CD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get initial password
echo "Retrieving initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Admin password: $ARGOCD_PASSWORD"

# Port forward
echo "Setting up port forwarding..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Install CLI
echo "Installing Argo CD CLI..."
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Login
echo "Logging in..."
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure

echo "Installation complete!"
echo "Access UI at: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

### Example 2: Production Helm Installation

```yaml
# production-values.yaml
global:
  image:
    tag: v2.9.3

server:
  replicas: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 5
  service:
    type: ClusterIP
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - argocd.production.example.com
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.production.example.com
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
  config:
    url: https://argocd.production.example.com

controller:
  replicas: 2
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 1000m
      memory: 1Gi

repoServer:
  replicas: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 5
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

redis-ha:
  enabled: true
  replicas: 3

dex:
  enabled: true
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
```

```bash
# Install with production values
helm install argocd argo-cd/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values production-values.yaml \
  --wait
```

### Example 3: CLI Configuration

```bash
# Login to Argo CD
argocd login argocd.example.com

# Configure default context
argocd context

# Add context
argocd context <server-url>

# List contexts
argocd context --list

# Delete context
argocd context --delete <server-url>

# Get current context
argocd context --current

# Configure CLI preferences
cat > ~/.argocd/config << EOF
contexts:
- name: argocd.example.com
  server: argocd.example.com
  user: admin
current-context: argocd.example.com
servers:
- server: argocd.example.com
users:
- auth-token: <token>
  name: admin
EOF
```

### Example 4: Custom ConfigMap Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  admin.enabled: "true"
  users.anonymous.enabled: "false"

  # Git webhook configuration
  webhook.github.secret: github-webhook-secret

  # Repository credentials templates
  repository.credentials: |
    - url: https://github.com/example
      passwordSecret:
        name: github-creds
        key: password
      usernameSecret:
        name: github-creds
        key: username

  # Resource tracking method
  application.resourceTrackingMethod: annotation

  # Orphaned resources monitoring
  application.orphaned.resources: |
    warn: true

  # Git commit status badge
  statusbadge.enabled: "true"

  # Custom links
  ui.bannercontent: "Production Argo CD Instance"
  ui.bannerurl: "https://docs.example.com"
  ui.bannerpermanent: "true"
  ui.bannerposition: "top"

  # External links
  resource.customizations.external.links: |
    - title: "Open Grafana"
      url: https://grafana.example.com/d/app?var-app={{.metadata.name}}
      icon: "fa-chart-line"
```

## Study Resources

- [Argo CD Installation Guide](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Argo CD Operator Manual](https://argo-cd.readthedocs.io/en/stable/operator-manual/)
- [High Availability Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/)
- [Argo CD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Configuration Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Ingress Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)
- [CLI Installation](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

## Key Points to Remember

- Argo CD can be installed using kubectl (non-HA/HA), Helm, or Operator
- Non-HA installation is for development/testing; HA is for production
- Initial admin password is stored in `argocd-initial-admin-secret`
- CLI can be installed on Linux, macOS, and Windows
- Port forwarding provides quick access: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
- Argo CD can be exposed via LoadBalancer, Ingress, or OpenShift Route
- Main configuration is stored in `argocd-cm` ConfigMap
- Command parameters are in `argocd-cmd-params-cm` ConfigMap
- RBAC policies are configured in `argocd-rbac-cm` ConfigMap
- Helm installation provides most flexibility with values.YAML
- Default namespace is `argocd` but can be changed
- High Availability requires Redis HA and multiple replicas
- SSL/TLS can be terminated at ingress or passed through to Argo CD
- Resource limits and requests should be configured for production
- Argo CD UI provides visual interface for all operations

## Hands-On Practice

For practical exercises and labs on Argo CD installation and configuration, see:

- [Lab 01: Installing Argo CD](../../labs/01-argo-cd/lab-01-installation.md)
- [Lab 02: Deploying Your First Application](../../labs/01-argo-cd/lab-02-first-app.md)
