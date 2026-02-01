# Lab 05: Deploying Helm Charts with Argo CD

## Objectives

- Deploy Helm charts using Argo CD
- Manage Helm values and parameters
- Use multiple values files for different environments
- Override Helm values using Argo CD
- Understand Helm hooks vs Argo CD hooks
- Work with Helm chart dependencies
- Deploy applications from Helm repositories
- Customize Helm releases using Kustomize overlays

## Prerequisites

- Completed Labs 01-04
- Argo CD running and accessible
- Basic understanding of Helm charts
- Access to Helm chart repositories
- kubectl and Helm CLI installed

## Estimated Time

35 minutes

---

## Part 1: Understanding Helm Integration in Argo CD

### Task 1.1: Verify Helm Support

```bash
# Check Argo CD version and Helm support
argocd version

# Argo CD has native Helm support - no additional configuration needed
# It can deploy charts from:
# 1. Git repositories (charts stored in Git)
# 2. Helm repositories (OCI or HTTP-based)
# 3. OCI registries
```

### Task 1.2: Create a Simple Helm Chart for Testing

```bash
# Create a directory for our Helm chart
mkdir -p ~/helm-demo
cd ~/helm-demo

# Create chart structure
helm create my-web-app

# Explore the generated structure (use find instead of tree for cross-platform compatibility)
find my-web-app -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'
```

**Expected Output:**

```
my-web-app/
├── Chart.yaml
├── charts/
├── templates/
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests/
└── values.yaml
```

### Task 1.3: Customize the Chart Values

```bash
cd my-web-app

# Edit values.yaml
cat <<EOF > values.yaml
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25"

serviceAccount:
  create: true
  name: ""
  annotations: {}

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

autoscaling:
  enabled: false

env:
  - name: ENVIRONMENT
    value: "development"
  - name: LOG_LEVEL
    value: "info"
EOF

# Update Chart.yaml with better metadata (no dependencies)
cat <<EOF > Chart.yaml
apiVersion: v2
name: my-web-app
description: A simple web application Helm chart
type: application
version: 1.0.0
appVersion: "1.0"
keywords:
  - nginx
  - web
maintainers:
  - name: Your Team
    email: team@example.com
EOF

# Remove any existing dependencies
rm -rf charts/*.tgz charts/*/
rm -f Chart.lock

# Verify the chart is valid
helm lint .
```

---

## Part 2: Deploying Helm Charts from Git

### Task 2.1: Push Chart to Git Repository

```bash
# Initialize git repository
cd ~/helm-demo
git init
git add .
git commit -m "Initial Helm chart"

# Create GitHub repository and push
gh repo create helm-demo --public --source=. --remote=origin --push

# Or manually create repo and push:
# git remote add origin https://github.com/$GITHUB_USER/helm-demo.git
# git branch -M main
# git push -u origin main
```

### Task 2.2: Deploy Helm Chart with Argo CD

```bash
# Create an Argo CD application for the Helm chart
# Note: Do NOT use --helm-chart flag for Git repos, only use --path
argocd app create my-web-app-helm \
  --repo https://github.com/$GITHUB_USER/helm-demo.git \
  --path my-web-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Sync the application
argocd app sync my-web-app-helm

# Check status
argocd app get my-web-app-helm
```

**Expected Output:**

```
Name:               my-web-app-helm
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          default
URL:                https://localhost:8080/applications/my-web-app-helm
Repo:               https://github.com/$GITHUB_USER/helm-demo.git
Target:             HEAD
Path:               my-web-app
Sync Status:        Synced to HEAD (abc123)
Health Status:      Healthy
```

### Task 2.3: View Rendered Helm Manifests

```bash
# View the rendered manifests
argocd app manifests my-web-app-helm

# You can also use helm template locally to compare
cd ~/helm-demo/my-web-app
helm template my-web-app . --debug
```

**Question:** How does Argo CD render the Helm templates? Where are the values coming from?

---

## Part 3: Managing Helm Values

### Task 3.1: Override Values via Argo CD CLI

```bash
# Set specific Helm parameters
argocd app set my-web-app-helm \
  --helm-set replicaCount=3 \
  --helm-set image.tag=1.26

# Verify the changes
argocd app get my-web-app-helm --show-params

# Sync to apply changes
argocd app sync my-web-app-helm

# Check the deployment
kubectl get deployment -l app.kubernetes.io/instance=my-web-app-helm
```

**Expected Output:**

```
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
my-web-app   3/3     3            3           5m
```

### Task 3.2: Use Custom Values Files

```bash
# Create environment-specific values files
cd ~/helm-demo/my-web-app

# Development values
cat <<EOF > values-dev.yaml
replicaCount: 1

image:
  tag: "latest"

resources:
  limits:
    cpu: 50m
    memory: 64Mi
  requests:
    cpu: 25m
    memory: 32Mi

env:
  - name: ENVIRONMENT
    value: "development"
  - name: LOG_LEVEL
    value: "debug"
  - name: DEBUG
    value: "true"
EOF

# Production values
cat <<EOF > values-prod.yaml
replicaCount: 5

image:
  tag: "1.25"

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

env:
  - name: ENVIRONMENT
    value: "production"
  - name: LOG_LEVEL
    value: "warn"
  - name: DEBUG
    value: "false"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
EOF

# Commit and push
git add values-dev.yaml values-prod.yaml
git commit -m "Add environment-specific values"
git push
```

### Task 3.3: Deploy with Custom Values File

```bash
# Create a production instance using values-prod.yaml
argocd app create my-web-app-prod \
  --repo https://github.com/$GITHUB_USER/helm-demo.git \
  --path my-web-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production \
  --helm-set-file values=values-prod.yaml

# Create namespace first
kubectl create namespace production

# Sync the application
argocd app sync my-web-app-prod

# Verify production deployment
kubectl get deployment -n production
```

### Task 3.4: Using Multiple Values Files

```bash
# You can use multiple values files that cascade
argocd app create my-web-app-staging \
  --repo https://github.com/$GITHUB_USER/helm-demo.git \
  --path my-web-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace staging \
  --values values.yaml \
  --values values-dev.yaml

# Create namespace
kubectl create namespace staging

# Sync
argocd app sync my-web-app-staging

# Values are merged: values.yaml as base, values-dev.yaml overrides
```

---

## Part 4: Working with Helm Repositories

### Task 4.1: Add a Helm Repository to Argo CD

```bash
# Add Bitnami Helm repository
argocd repo add https://charts.bitnami.com/bitnami \
  --type helm \
  --name bitnami

# Add Prometheus community charts
argocd repo add https://prometheus-community.github.io/helm-charts \
  --type helm \
  --name prometheus-community

# List repositories
argocd repo list
```

**Expected Output:**

```
TYPE  NAME                   REPO                                                   INSECURE  OCI    LFS
helm  bitnami                https://charts.bitnami.com/bitnami                     false     false  false
helm  prometheus-community   https://prometheus-community.github.io/helm-charts     false     false  false
```

### Task 4.2: Deploy a Chart from Helm Repository

```bash
# Deploy Redis from Bitnami repository
argocd app create redis \
  --repo https://charts.bitnami.com/bitnami \
  --helm-chart redis \
  --revision 24.1.2 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --helm-set auth.password=mysecretpassword \
  --helm-set master.persistence.enabled=false \
  --helm-set replica.replicaCount=1

# Sync the application
argocd app sync redis --timeout 300

# Check Redis deployment
kubectl get pods -l app.kubernetes.io/name=redis
kubectl get svc -l app.kubernetes.io/name=redis
```

### Task 4.3: View Available Chart Versions

```bash
# Get information about the Helm chart
argocd app get redis --show-params

# You can also check available versions using helm
helm search repo bitnami/redis --versions | head -10
```

---

## Part 5: Advanced Helm Configuration

### Task 5.1: Using Helm Parameters with Complex Values

```bash
# Create an application with complex nested values
cd ~/helm-demo/my-web-app

# Add a more complex values file
cat <<EOF > values-complex.yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.example.com

extraVolumes:
  - name: config
    configMap:
      name: app-config
  - name: cache
    emptyDir: {}

extraVolumeMounts:
  - name: config
    mountPath: /etc/config
  - name: cache
    mountPath: /tmp/cache

nodeSelector:
  workload-type: web

tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "web"
    effect: "NoSchedule"
EOF

# Commit and push
git add values-complex.yaml
git commit -m "Add complex values configuration"
git push
```

### Task 5.2: Helm Release Name Customization

```bash
# By default, Argo CD uses the app name as the Helm release name
# You can customize it:

argocd app create custom-release \
  --repo https://github.com/$GITHUB_USER/helm-demo.git \
  --path my-web-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --helm-set-string fullnameOverride=my-custom-app

# This affects resource names generated by the Helm chart
```

### Task 5.3: Helm Hooks vs Argo CD Hooks

```bash
# Create a chart with Helm hooks
cd ~/helm-demo/my-web-app/templates

# Create a Helm pre-install hook
cat <<EOF > pre-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "my-web-app.fullname" . }}-pre-install
  labels:
    {{- include "my-web-app.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pre-install
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo "Running Helm pre-install hook"
          echo "This runs before Helm installs the chart"
          sleep 2
EOF

# Commit and push
cd ~/helm-demo
git add .
git commit -m "Add Helm pre-install hook"
git push

# Sync and observe
argocd app sync my-web-app-helm
kubectl get jobs -l app.kubernetes.io/instance=my-web-app-helm
```

**Question:** What's the difference between Helm hooks and Argo CD sync hooks? When would you use each?

---

## Part 6: Helm Chart Dependencies

### Task 6.1: Add Chart Dependencies

```bash
cd ~/helm-demo/my-web-app

# Add dependencies to Chart.yaml
cat <<EOF > Chart.yaml
apiVersion: v2
name: my-web-app
description: A web application with database dependency
type: application
version: 1.1.0
appVersion: "1.0"

dependencies:
  - name: postgresql
    version: 18.2.3
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
  - name: redis
    version: 24.1.2
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
EOF

# Update values.yaml to configure dependencies
cat <<EOF >> values.yaml

# Database configuration
postgresql:
  enabled: true
  auth:
    username: myapp
    password: myapp123
    database: myappdb
  primary:
    persistence:
      enabled: false

# Cache configuration
redis:
  enabled: true
  auth:
    enabled: false
  master:
    persistence:
      enabled: false
EOF

# Commit and push
git add Chart.yaml values.yaml
git commit -m "Add chart dependencies"
git push

# Argo CD will automatically fetch and deploy dependencies
argocd app sync my-web-app-helm

# Check deployed resources
kubectl get pods -l app.kubernetes.io/instance=my-web-app-helm
kubectl get svc -l app.kubernetes.io/instance=my-web-app-helm
```

### Task 6.2: Override Dependency Values

```bash
# Create values file with dependency overrides
cd ~/helm-demo/my-web-app

cat <<EOF > values-with-deps.yaml
replicaCount: 2

postgresql:
  enabled: true
  auth:
    username: produser
    password: strongpassword
    database: proddb
  primary:
    persistence:
      enabled: true
      size: 10Gi
    resources:
      requests:
        memory: 256Mi
        cpu: 250m

redis:
  enabled: true
  auth:
    enabled: true
    password: redispassword
  master:
    resources:
      requests:
        memory: 128Mi
        cpu: 100m
EOF

git add values-with-deps.yaml
git commit -m "Add dependency overrides"
git push
```

---

## Part 7: Combining Helm with Kustomize

### Task 7.1: Create Kustomize Overlays for Helm Charts

```bash
# Create kustomize structure
cd ~/helm-demo
mkdir -p kustomize-helm/{base,overlays/{dev,prod}}

# First, render base Helm templates to static manifests
helm template my-web-app ./my-web-app \
  --namespace default \
  --values ./my-web-app/values.yaml \
  > kustomize-helm/base/manifests.yaml

# Create base kustomization
cat <<EOF > kustomize-helm/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- manifests.yaml

commonLabels:
  app.kubernetes.io/managed-by: kustomize-helm
EOF

# Dev overlay with patches to modify replicas and image
cat <<EOF > kustomize-helm/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
- ../../base

patches:
- target:
    kind: Deployment
    name: my-web-app
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 1
    - op: replace
      path: /spec/template/spec/containers/0/image
      value: nginx:latest

commonLabels:
  environment: dev
EOF

# Prod overlay with patches for production settings
cat <<EOF > kustomize-helm/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: prod

resources:
- ../../base

patches:
- target:
    kind: Deployment
    name: my-web-app
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 5

commonLabels:
  environment: production
EOF

# Push to Git
git add kustomize-helm/
git commit -m "Add Kustomize overlays for Helm chart"
git push origin main
```

### Task 7.2: Deploy with Argo CD

```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace prod

# Create Argo CD application for dev environment
argocd app create my-web-app-kustomize-dev \
  --repo https://github.com/$GITHUB_USER/helm-demo.git \
  --path kustomize-helm/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev

# Create Argo CD application for prod environment
argocd app create my-web-app-kustomize-prod \
  --repo https://github.com/$GITHUB_USER/helm-demo.git \
  --path kustomize-helm/overlays/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace prod

# Sync both applications
argocd app sync my-web-app-kustomize-dev
argocd app sync my-web-app-kustomize-prod

# Check status
argocd app get my-web-app-kustomize-dev
argocd app get my-web-app-kustomize-prod

# Verify deployments
kubectl get all -n dev
kubectl get all -n prod
```

**Question:** How does combining Helm with Kustomize give you more flexibility than using either tool alone?

---

## Challenge Exercise

**Scenario:** Deploy a complete three-tier application using Helm charts with Argo CD:

**Requirements:**

1. **Frontend Service:**
   - Create a custom Helm chart for an nginx-based frontend
   - 3 replicas in production, 1 in development
   - Ingress enabled in production only
   - ConfigMap for frontend configuration

2. **Backend API:**
   - Use a Helm chart from Git repository
   - Depends on database and cache
   - Environment-specific values (dev, staging, prod)
   - Secrets for API keys

3. **Database:**
   - PostgreSQL from Bitnami Helm repository
   - Persistence enabled in production only
   - Different resource limits per environment
   - Automated backup job as Helm hook

4. **Cache:**
   - Redis from Bitnami Helm repository
   - Sentinel enabled in production
   - Memory limits based on environment

5. **Configuration Management:**
   - Use values files for each environment
   - Override critical values via Argo CD parameters
   - Implement dependencies between charts
   - Use Helm hooks for database initialization

**Deliverables:**

- All Helm charts in Git repository
- Argo CD applications for each component
- Environment-specific values files
- Documentation of value precedence
- Test results showing proper configuration per environment

---

## Cleanup

```bash
# Delete all Helm applications from Parts 1-6
echo "Deleting basic Helm applications..."
argocd app delete my-web-app-helm --yes --cascade 2>/dev/null || true
argocd app delete my-web-app-prod --yes --cascade 2>/dev/null || true
argocd app delete my-web-app-staging --yes --cascade 2>/dev/null || true
argocd app delete redis --yes --cascade 2>/dev/null || true
argocd app delete custom-release --yes --cascade 2>/dev/null || true

# Delete Kustomize + Helm applications from Part 7
echo "Deleting Kustomize+Helm applications..."
argocd app delete my-web-app-kustomize-dev --yes --cascade 2>/dev/null || true
argocd app delete my-web-app-kustomize-prod --yes --cascade 2>/dev/null || true

# Delete Challenge Exercise applications (if created)
echo "Deleting challenge exercise applications..."
argocd app delete backend-dev --yes --cascade 2>/dev/null || true
argocd app delete frontend-dev --yes --cascade 2>/dev/null || true
argocd app delete backend-staging --yes --cascade 2>/dev/null || true
argocd app delete frontend-staging --yes --cascade 2>/dev/null || true
argocd app delete backend-prod --yes --cascade 2>/dev/null || true
argocd app delete frontend-prod --yes --cascade 2>/dev/null || true

# Wait for applications to be deleted
echo "Waiting for applications to be deleted..."
sleep 10

# Verify all apps are deleted
argocd app list

# Delete namespaces
echo "Deleting namespaces..."
kubectl delete namespace default production staging dev prod --ignore-not-found

# Remove Helm repositories (if added)
echo "Removing Helm repositories..."
argocd repo rm https://charts.bitnami.com/bitnami 2>/dev/null || true
argocd repo rm https://prometheus-community.github.io/helm-charts 2>/dev/null || true

# Remove Git repository
argocd repo rm https://github.com/$GITHUB_USER/helm-demo.git 2>/dev/null || true

# Clean up local files
echo "Cleaning up local files..."
rm -rf ~/helm-demo

echo "Cleanup complete"
```

**Note:** The `--cascade` flag ensures that Kubernetes resources created by the applications are also deleted, not just the Argo CD Application objects.

---

## Summary

Excellent work! You've mastered Helm chart deployment with Argo CD. Here are the key takeaways:

- **Native Helm Support:** Argo CD has built-in support for Helm charts
- **Value Management:** Multiple ways to provide and override values
- **Helm Repositories:** Can deploy from Git or Helm repositories
- **Chart Dependencies:** Automatic handling of chart dependencies
- **Helm Hooks:** Different from Argo CD hooks, used for lifecycle management
- **Version Control:** Charts and values in Git provide full auditability
- **Multi-Environment:** Use values files for environment-specific configuration

**Helm Integration Methods:**

1. **Charts in Git:**

   ```bash
   --repo https://github.com/user/repo.git --path path/to/chart
   ```

2. **Charts from Helm Repo:**

   ```bash
   --repo https://charts.example.com --helm-chart chart-name --revision 1.0.0
   ```

3. **Value Sources:**
   - `--values`: Values file from Git
   - `--helm-set`: Individual parameter
   - `--helm-set-string`: String parameter
   - `--helm-set-file`: Values from file

**Key Commands:**

```bash
# Create Helm app from Git
argocd app create <name> --repo <url> --path <chart-path>

# Create Helm app from repo
argocd app create <name> --repo <helm-repo> --helm-chart <chart>

# Set Helm parameters
argocd app set <name> --helm-set key=value

# Add Helm repository
argocd repo add <url> --type helm --name <name>

# View parameters
argocd app get <name> --show-params
```

**Best Practices:**

1. Store charts in Git for version control
2. Use values files for environment configuration
3. Override sensitive values via sealed secrets
4. Use chart dependencies for related services
5. Pin chart versions in production
6. Test charts with `helm template` before deploying
7. Use Helm hooks for initialization tasks
8. Document value precedence clearly
9. Use semantic versioning for charts
10. Keep values files simple and readable

---

## Additional Practice

To reinforce your learning, try these additional exercises:

1. **Helm Chart Library:**
   - Create a library chart with common templates
   - Use it across multiple application charts
   - Share helpers and partials

2. **OCI Registry:**
   - Push Helm charts to OCI registry
   - Deploy from OCI registry using Argo CD
   - Implement chart signing and verification

3. **Advanced Dependencies:**
   - Create charts with complex dependency trees
   - Use condition and tags to control dependencies
   - Override nested dependency values

4. **Helm Plugins:**
   - Use Helm-secrets plugin with Argo CD
   - Integrate with external secret management
   - Implement SOPS for secret encryption

5. **Testing:**
   - Add Helm chart tests
   - Run tests as PostSync hooks
   - Implement validation jobs

6. **Umbrella Charts:**
   - Create an umbrella chart for entire application stack
   - Manage multiple microservices
   - Coordinate releases

**Helpful Resources:**

- Helm Charts: https://argo-cd.readthedocs.io/en/stable/user-guide/helm/
- Helm Values: https://helm.sh/docs/chart_template_guide/values_files/
- Chart Dependencies: https://helm.sh/docs/helm/helm_dependency/
- Bitnami Charts: https://github.com/bitnami/charts

---

## Solutions

<details>
<summary>Click to expand Challenge Exercise solutions</summary>

### Solution to Challenge Exercise

#### Step 1: Create Frontend Helm Chart

```bash
mkdir -p ~/three-tier-app/charts
cd ~/three-tier-app/charts

# Create frontend chart
helm create frontend

cd frontend

# Update Chart.yaml
cat <<EOF > Chart.yaml
apiVersion: v2
name: frontend
description: Frontend web application
type: application
version: 1.0.0
appVersion: "1.0"
EOF

# Update values.yaml
cat <<EOF > values.yaml
replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25"

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

config:
  backendUrl: "http://backend:8080"
  apiTimeout: "30s"
EOF

# Create ConfigMap template
cat <<EOF > templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "frontend.fullname" . }}-config
  labels:
    {{- include "frontend.labels" . | nindent 4 }}
data:
  config.json: |
    {
      "backendUrl": "{{ .Values.config.backendUrl }}",
      "apiTimeout": "{{ .Values.config.apiTimeout }}",
      "environment": "{{ .Values.environment | default "development" }}"
    }
EOF

# Update deployment to use ConfigMap
# Edit templates/deployment.yaml to add volume mount
```

#### Step 2: Create Backend Helm Chart with Dependencies

```bash
cd ~/three-tier-app/charts
helm create backend

cd backend

# Update Chart.yaml with dependencies
cat <<EOF > Chart.yaml
apiVersion: v2
name: backend
description: Backend API service
type: application
version: 1.0.0
appVersion: "1.0"

dependencies:
  - name: postgresql
    version: ~12.12.0
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
  - name: redis
    version: ~18.4.0
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
EOF

# Create comprehensive values
cat <<EOF > values.yaml
replicaCount: 2

image:
  repository: hashicorp/http-echo
  pullPolicy: IfNotPresent
  tag: "0.2.3"

service:
  type: ClusterIP
  port: 8080

env:
  - name: PORT
    value: "8080"

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Database dependency
postgresql:
  enabled: true
  auth:
    username: backend
    password: backendpass
    database: backenddb
  primary:
    persistence:
      enabled: false
    resources:
      requests:
        memory: 256Mi
        cpu: 250m

# Cache dependency
redis:
  enabled: true
  auth:
    enabled: false
  master:
    persistence:
      enabled: false
    resources:
      requests:
        memory: 128Mi
        cpu: 100m
EOF

# Create secret template
cat <<EOF > templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "backend.fullname" . }}-api-keys
  labels:
    {{- include "backend.labels" . | nindent 4 }}
type: Opaque
stringData:
  api-key: {{ .Values.apiKey | default "default-api-key" | quote }}
  jwt-secret: {{ .Values.jwtSecret | default "default-jwt-secret" | quote }}
EOF

# Create pre-install hook for DB initialization
cat <<EOF > templates/db-init-hook.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "backend.fullname" . }}-db-init
  labels:
    {{- include "backend.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: db-init
        image: postgres:15
        env:
        - name: PGHOST
          value: {{ include "backend.fullname" . }}-postgresql
        - name: PGUSER
          value: {{ .Values.postgresql.auth.username }}
        - name: PGPASSWORD
          value: {{ .Values.postgresql.auth.password }}
        - name: PGDATABASE
          value: {{ .Values.postgresql.auth.database }}
        command:
        - sh
        - -c
        - |
          echo "Waiting for database..."
          until pg_isready; do sleep 2; done
          echo "Initializing database schema..."
          psql -c "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, username VARCHAR(50));"
          psql -c "CREATE TABLE IF NOT EXISTS sessions (id SERIAL PRIMARY KEY, user_id INT, token VARCHAR(255));"
          echo "Database initialization complete!"
EOF
```

#### Step 3: Create Environment-Specific Values

```bash
cd ~/three-tier-app

# Development values
cat <<EOF > values-dev.yaml
frontend:
  replicaCount: 1
  image:
    tag: "latest"
  ingress:
    enabled: false
  environment: "development"

backend:
  replicaCount: 1
  apiKey: "dev-api-key-123"
  jwtSecret: "dev-jwt-secret"
  postgresql:
    enabled: true
    primary:
      persistence:
        enabled: false
      resources:
        requests:
          memory: 128Mi
          cpu: 100m
  redis:
    enabled: true

EOF

# Staging values
cat <<EOF > values-staging.yaml
frontend:
  replicaCount: 2
  image:
    tag: "1.25"
  ingress:
    enabled: true
    hosts:
      - host: staging.example.com
        paths:
          - path: /
            pathType: Prefix
  environment: "staging"

backend:
  replicaCount: 2
  apiKey: "staging-api-key-456"
  jwtSecret: "staging-jwt-secret"
  postgresql:
    enabled: true
    primary:
      persistence:
        enabled: true
        size: 5Gi
  redis:
    enabled: true
    master:
      persistence:
        enabled: true
        size: 2Gi
EOF

# Production values
cat <<EOF > values-prod.yaml
frontend:
  replicaCount: 3
  image:
    tag: "1.25"
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - host: app.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: app-tls
        hosts:
          - app.example.com
  environment: "production"
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

backend:
  replicaCount: 5
  apiKey: "prod-api-key-789"
  jwtSecret: "prod-jwt-secret-strong"
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  postgresql:
    enabled: true
    auth:
      username: produser
      password: strongprodpassword
      database: proddb
    primary:
      persistence:
        enabled: true
        size: 20Gi
      resources:
        requests:
          memory: 512Mi
          cpu: 500m
  redis:
    enabled: true
    auth:
      enabled: true
      password: redis-prod-password
    master:
      persistence:
        enabled: true
        size: 5Gi
    sentinel:
      enabled: true
EOF
```

#### Step 4: Push to Git and Create Argo CD Applications

```bash
cd ~/three-tier-app
git init
git add .
git commit -m "Initial three-tier application with Helm charts"

gh repo create three-tier-app --public --source=. --remote=origin --push

# Create namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod

# Deploy backend to dev
argocd app create backend-dev \
  --repo https://github.com/$GITHUB_USER/three-tier-app.git \
  --path charts/backend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --values ../../values-dev.yaml \
  --sync-policy automated

# Deploy frontend to dev
argocd app create frontend-dev \
  --repo https://github.com/$GITHUB_USER/three-tier-app.git \
  --path charts/frontend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --helm-set config.backendUrl=http://backend-dev:8080 \
  --values ../../values-dev.yaml \
  --sync-policy automated

# Deploy to staging
argocd app create backend-staging \
  --repo https://github.com/$GITHUB_USER/three-tier-app.git \
  --path charts/backend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace staging \
  --values ../../values-staging.yaml

argocd app create frontend-staging \
  --repo https://github.com/$GITHUB_USER/three-tier-app.git \
  --path charts/frontend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace staging \
  --helm-set config.backendUrl=http://backend-staging:8080 \
  --values ../../values-staging.yaml

# Deploy to production
argocd app create backend-prod \
  --repo https://github.com/$GITHUB_USER/three-tier-app.git \
  --path charts/backend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace prod \
  --values ../../values-prod.yaml

argocd app create frontend-prod \
  --repo https://github.com/$GITHUB_USER/three-tier-app.git \
  --path charts/frontend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace prod \
  --helm-set config.backendUrl=http://backend-prod:8080 \
  --values ../../values-prod.yaml

# Sync all applications
argocd app sync -l environment=dev
argocd app sync -l environment=staging
argocd app sync -l environment=prod
```

#### Step 5: Verify Deployments

```bash
# Check dev environment
kubectl get all -n dev
kubectl get configmap -n dev
kubectl get secret -n dev

# Check staging
kubectl get all -n staging

# Check production
kubectl get all -n prod

# Verify backend dependencies
kubectl get pods -n prod -l app.kubernetes.io/name=postgresql
kubectl get pods -n prod -l app.kubernetes.io/name=redis

# Check Helm hook jobs
kubectl get jobs -n prod -l helm.sh/hook=pre-install
```

#### Step 6: Documentation

Create `VALUES-PRECEDENCE.md`:

```markdown
# Value Precedence Documentation

## Order of Precedence (highest to lowest)

1. **Argo CD CLI Parameters** (`--helm-set`)
   - Highest priority
   - Used for environment-specific overrides
   - Example: `--helm-set config.backendUrl=http://backend:8080`

2. **Values Files** (`--values`)
   - Environment-specific values files
   - Cascading: later files override earlier ones
   - Example: `values.yaml` → `values-prod.yaml`

3. **Chart Default Values** (`values.yaml` in chart)
   - Lowest priority
   - Provides sensible defaults

## Environment Configurations

### Development
- File: `values-dev.yaml`
- Overrides: Minimal resources, latest images
- Special settings: Persistence disabled

### Staging
- File: `values-staging.yaml`
- Overrides: Production-like but smaller
- Special settings: Persistence enabled with reduced size

### Production
- File: `values-prod.yaml`
- Overrides: Maximum resources, stable versions
- Special settings: HA enabled, full persistence, monitoring

## Testing Results

✅ Dev: 1 replica frontend, 1 replica backend, no persistence
✅ Staging: 2 replicas frontend, 2 replicas backend, 5GB DB
✅ Prod: 3 replicas frontend, 5 replicas backend, 20GB DB, Redis Sentinel
```

#### Cleanup

```bash
argocd app delete backend-dev frontend-dev backend-staging frontend-staging backend-prod frontend-prod --yes
kubectl delete namespace dev staging prod
rm -rf ~/three-tier-app
```

</details>
