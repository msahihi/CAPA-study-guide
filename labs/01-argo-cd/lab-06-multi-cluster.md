# Lab 06: Multi-Cluster Management with Argo CD

## Objectives

- Add external Kubernetes clusters to Argo CD
- Deploy applications to multiple clusters simultaneously
- Implement cluster-specific configurations
- Use cluster generators for ApplicationSets
- Configure cluster credentials and authentication
- Implement disaster recovery patterns
- Manage applications across dev, staging, and production clusters
- Monitor multi-cluster deployments

## Prerequisites

- Completed Labs 01-05
- Argo CD running and accessible
- Access to create multiple Kubernetes clusters (minikube, kind, or k3d)
- Understanding of kubeconfig and cluster contexts
- kubectl CLI configured

## Estimated Time

45 minutes

---

## Part 1: Setting Up Multiple Clusters

### Task 1.1: Create Additional Kubernetes Clusters

We'll create three clusters to simulate different environments:

- **cluster-dev:** Development cluster
- **cluster-staging:** Staging cluster
- **cluster-prod:** Production cluster

**Using kind:**

```bash
# Create development cluster
cat <<EOF | kind create cluster --name dev --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
  - containerPort: 30443
    hostPort: 30443
EOF

# Create staging cluster
cat <<EOF | kind create cluster --name staging --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 31080
    hostPort: 31080
EOF

# Create production cluster
cat <<EOF | kind create cluster --name prod --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 32080
    hostPort: 32080
EOF

# Verify all clusters are running
kind get clusters
```

**Using minikube:**

```bash
# Create development cluster
minikube start -p dev --cpus=2 --memory=2048

# Create staging cluster
minikube start -p staging --cpus=2 --memory=2048

# Create production cluster
minikube start -p prod --cpus=2 --memory=2048

# List all clusters
minikube profile list
```

**Using k3d:**

```bash
# Create development cluster
k3d cluster create dev -p "30080:80@loadbalancer"

# Create staging cluster
k3d cluster create staging -p "31080:80@loadbalancer"

# Create production cluster
k3d cluster create prod -p "32080:80@loadbalancer"

# List clusters
k3d cluster list
```

### Task 1.2: Verify Cluster Contexts

```bash
# List all Kubernetes contexts
kubectl config get-contexts

# Test connectivity to each cluster
kubectl config use-context kind-dev
kubectl cluster-info

kubectl config use-context kind-staging
kubectl cluster-info

kubectl config use-context kind-prod
kubectl cluster-info

# Assume Argo CD is running in the first cluster (or separate mgmt cluster)
# For this lab, we'll use the 'dev' cluster as the Argo CD management cluster
kubectl config use-context kind-dev
```

**Expected Output:**

```
CURRENT   NAME           CLUSTER        AUTHINFO       NAMESPACE
*         kind-dev       kind-dev       kind-dev
          kind-staging   kind-staging   kind-staging
          kind-prod      kind-prod      kind-prod
```

### Task 1.3: Install Argo CD on Management Cluster

If Argo CD is not yet installed on your management cluster:

```bash
# Use dev cluster as management cluster
kubectl config use-context kind-dev

# Create argocd namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Login
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --insecure
```

---

## Part 2: Adding External Clusters to Argo CD

### Task 2.1: Add Clusters Using CLI

```bash
# Switch to management cluster context
kubectl config use-context kind-dev

# List current clusters in Argo CD
argocd cluster list

# Add staging cluster
kubectl config use-context kind-staging
argocd cluster add kind-staging --name staging

# Add production cluster
kubectl config use-context kind-prod
argocd cluster add kind-prod --name prod

# Switch back to management cluster
kubectl config use-context kind-dev

# List clusters again
argocd cluster list
```

**Expected Output:**

```
SERVER                          NAME      VERSION  STATUS      MESSAGE                                              PROJECT
https://kubernetes.default.svc  in-cluster  1.27     Successful
https://staging-server:6443     staging     1.27     Successful
https://prod-server:6443        prod        1.27     Successful
```

**Question:** What happens when you add a cluster? What resources are created?

### Task 2.2: Verify Cluster Registration

```bash
# Check the secrets created for cluster credentials
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# View cluster details
argocd cluster get staging
argocd cluster get prod

# Check what was installed in remote clusters
kubectl config use-context kind-staging
kubectl get serviceaccount -n kube-system | grep argocd
kubectl get clusterrole | grep argocd

# Check prod cluster
kubectl config use-context kind-prod
kubectl get serviceaccount -n kube-system | grep argocd

# Return to management cluster
kubectl config use-context kind-dev
```

**Understanding Cluster Registration:**

- Creates a ServiceAccount in the remote cluster
- Creates ClusterRole and ClusterRoleBinding for permissions
- Stores cluster credentials in a Secret in Argo CD namespace

### Task 2.3: Label Clusters

```bash
# Add labels to clusters for easier management
argocd cluster set staging --label environment=staging --label tier=non-prod
argocd cluster set prod --label environment=production --label tier=prod

# Add label to in-cluster
argocd cluster set https://kubernetes.default.svc --label environment=development --label tier=non-prod

# List clusters with labels
argocd cluster list -o wide
```

---

## Part 3: Deploying Applications to Multiple Clusters

### Task 3.1: Create a Simple Multi-Cluster Application

```bash
# Create application repository
mkdir -p ~/multi-cluster-app
cd ~/multi-cluster-app

# Create base manifests
mkdir -p manifests

cat <<EOF > manifests/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: web-app
EOF

cat <<EOF > manifests/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
        env:
        - name: CLUSTER_NAME
          value: "default"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
EOF

cat <<EOF > manifests/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
  namespace: web-app
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Initialize Git repository
git init
git add .
git commit -m "Initial multi-cluster application"

# Push to GitHub
gh repo create multi-cluster-app --public --source=. --remote=origin --push
```

### Task 3.2: Deploy to Staging Cluster

```bash
# Create application targeting staging cluster
argocd app create web-app-staging \
  --repo https://github.com/$GITHUB_USER/multi-cluster-app.git \
  --path manifests \
  --dest-server $(argocd cluster get staging -o json | jq -r .server) \
  --dest-namespace web-app \
  --sync-policy automated \
  --self-heal \
  --label environment=staging

# Alternative using cluster name (requires Argo CD 2.5+)
# argocd app create web-app-staging \
#   --repo https://github.com/$GITHUB_USER/multi-cluster-app.git \
#   --path manifests \
#   --dest-name staging \
#   --dest-namespace web-app

# Sync the application
argocd app sync web-app-staging

# Check status
argocd app get web-app-staging
```

### Task 3.3: Deploy to Production Cluster

```bash
# Create application for production
argocd app create web-app-prod \
  --repo https://github.com/$GITHUB_USER/multi-cluster-app.git \
  --path manifests \
  --dest-server $(argocd cluster get prod -o json | jq -r .server) \
  --dest-namespace web-app \
  --sync-policy automated \
  --self-heal \
  --label environment=production

# Sync
argocd app sync web-app-prod

# Check status
argocd app get web-app-prod
```

### Task 3.4: Verify Deployments on Remote Clusters

```bash
# Check staging cluster
kubectl config use-context kind-staging
kubectl get all -n web-app
kubectl get pods -n web-app -o wide

# Check production cluster
kubectl config use-context kind-prod
kubectl get all -n web-app
kubectl get pods -n web-app -o wide

# Return to management cluster
kubectl config use-context kind-dev
```

---

## Part 4: Cluster-Specific Configurations

### Task 4.1: Create Cluster-Specific Overlays with Kustomize

```bash
cd ~/multi-cluster-app

# Restructure for kustomize
mkdir -p base overlays/{staging,prod}

# Move base manifests
mv manifests/* base/

# Create base kustomization
cat <<EOF > base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- deployment.yaml
- service.yaml
EOF

# Create staging overlay
cat <<EOF > overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: web-app

resources:
- ../../base

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 2
    - op: replace
      path: /spec/template/spec/containers/0/env/0/value
      value: "staging"
  target:
    kind: Deployment
    name: web-app

commonLabels:
  environment: staging
  tier: non-prod
EOF

# Create production overlay
cat <<EOF > overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: web-app

resources:
- ../../base

patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 5
    - op: replace
      path: /spec/template/spec/containers/0/env/0/value
      value: "production"
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/cpu
      value: "100m"
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/memory
      value: "128Mi"
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/cpu
      value: "200m"
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/memory
      value: "256Mi"
  target:
    kind: Deployment
    name: web-app

commonLabels:
  environment: production
  tier: prod
EOF

# Commit changes
git add .
git commit -m "Add kustomize overlays for cluster-specific configs"
git push
```

### Task 4.2: Update Applications to Use Overlays

```bash
# Update staging application
argocd app set web-app-staging --path overlays/staging

# Update production application
argocd app set web-app-prod --path overlays/prod

# Sync applications
argocd app sync web-app-staging
argocd app sync web-app-prod

# Verify replica counts
kubectl config use-context kind-staging
kubectl get deployment web-app -n web-app -o jsonpath='{.spec.replicas}'
echo " replicas in staging"

kubectl config use-context kind-prod
kubectl get deployment web-app -n web-app -o jsonpath='{.spec.replicas}'
echo " replicas in production"

kubectl config use-context kind-dev
```

---

## Part 5: Using ApplicationSets for Multi-Cluster Deployment

ApplicationSets allow you to create multiple applications from a single template.

### Task 5.1: Install ApplicationSet Controller (if not already installed)

```bash
# ApplicationSet controller is included in Argo CD 2.5+
# Verify it's running
kubectl get deployment argocd-applicationset-controller -n argocd
```

### Task 5.2: Create ApplicationSet with Cluster Generator

```bash
# Create ApplicationSet manifest
cat <<EOF > applicationset-multicluster.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: web-app-multicluster
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          tier: non-prod
  template:
    metadata:
      name: 'web-app-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/$GITHUB_USER/multi-cluster-app.git
        targetRevision: HEAD
        path: 'overlays/{{metadata.labels.environment}}'
      destination:
        server: '{{server}}'
        namespace: web-app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
EOF

# Apply the ApplicationSet
kubectl apply -f applicationset-multicluster.yaml -n argocd

# Watch applications being created
watch kubectl get applications -n argocd
# Press Ctrl+C when done
```

### Task 5.3: Create ApplicationSet for All Clusters

```bash
# Create comprehensive ApplicationSet
cat <<EOF > applicationset-all-clusters.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-all-clusters
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchExpressions:
        - key: environment
          operator: In
          values:
          - development
          - staging
          - production
  template:
    metadata:
      name: 'guestbook-{{metadata.labels.environment}}'
      labels:
        environment: '{{metadata.labels.environment}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{server}}'
        namespace: 'guestbook-{{metadata.labels.environment}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
EOF

# Apply
kubectl apply -f applicationset-all-clusters.yaml -n argocd

# List generated applications
argocd app list -l environment
```

### Task 5.4: Use Git Generator with Cluster Matrix

```bash
# Create more sophisticated ApplicationSet
cat <<EOF > applicationset-matrix.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: matrix-multicluster
  namespace: argocd
spec:
  generators:
  - matrix:
      generators:
      - git:
          repoURL: https://github.com/$GITHUB_USER/multi-cluster-app.git
          revision: HEAD
          directories:
          - path: overlays/*
      - clusters:
          selector:
            matchLabels:
              tier: non-prod
  template:
    metadata:
      name: '{{path.basename}}-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/$GITHUB_USER/multi-cluster-app.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: '{{server}}'
        namespace: web-app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
EOF

# This creates applications for each combination of overlay and cluster
```

---

## Part 6: Disaster Recovery and Cluster Failover

### Task 6.1: Implement Active-Passive Setup

```bash
# Create a critical application in production
cd ~/multi-cluster-app

cat <<EOF > critical-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: critical-service-prod
  namespace: argocd
  annotations:
    backup-cluster: "staging"
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: $(argocd cluster get prod -o json | jq -r .server)
    namespace: critical
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

kubectl apply -f critical-app.yaml

# Create backup application (not synced by default)
cat <<EOF > critical-app-backup.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: critical-service-backup
  namespace: argocd
  annotations:
    primary-app: "critical-service-prod"
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: $(argocd cluster get staging -o json | jq -r .server)
    namespace: critical
  syncPolicy:
    # Manual sync - only activate during failover
    syncOptions:
    - CreateNamespace=true
EOF

kubectl apply -f critical-app-backup.yaml
```

### Task 6.2: Simulate Cluster Failure and Failover

```bash
# Check primary application
argocd app get critical-service-prod

# Simulate cluster failure (remove prod cluster)
# WARNING: This is for demonstration only
argocd cluster rm prod --yes

# Verify cluster is removed
argocd cluster list

# Activate backup application
argocd app sync critical-service-backup

# Verify application is running on backup cluster
kubectl config use-context kind-staging
kubectl get all -n critical

# Restore production cluster
kubectl config use-context kind-dev
argocd cluster add kind-prod --name prod

# Add back labels
argocd cluster set prod --label environment=production --label tier=prod

# Sync primary application
argocd app sync critical-service-prod
```

---

## Part 7: Monitoring Multi-Cluster Deployments

### Task 7.1: View Multi-Cluster Dashboard

```bash
# List all applications with cluster information
argocd app list -o wide

# Get applications by cluster
argocd app list --dest-server $(argocd cluster get staging -o json | jq -r .server)
argocd app list --dest-server $(argocd cluster get prod -o json | jq -r .server)

# View application health across all clusters
for app in $(argocd app list -o name); do
  echo "Application: $app"
  argocd app get $app | grep -E "Health Status|Sync Status"
  echo "---"
done
```

### Task 7.2: Create Monitoring Script

```bash
cat <<'EOF' > monitor-clusters.sh
#!/bin/bash

echo "=== Multi-Cluster Status ==="
echo "Time: $(date)"
echo ""

# Check cluster connectivity
echo "--- Cluster Status ---"
argocd cluster list

# Check applications per cluster
echo -e "\n--- Applications by Cluster ---"
for cluster in $(argocd cluster list -o json | jq -r '.[].name'); do
  echo "Cluster: $cluster"
  argocd app list -o wide | grep $cluster || echo "  No applications"
done

# Health summary
echo -e "\n--- Health Summary ---"
echo "Healthy: $(argocd app list -o json | jq '[.[] | select(.status.health.status=="Healthy")] | length')"
echo "Progressing: $(argocd app list -o json | jq '[.[] | select(.status.health.status=="Progressing")] | length')"
echo "Degraded: $(argocd app list -o json | jq '[.[] | select(.status.health.status=="Degraded")] | length')"

# Sync status
echo -e "\n--- Sync Status ---"
echo "Synced: $(argocd app list -o json | jq '[.[] | select(.status.sync.status=="Synced")] | length')"
echo "OutOfSync: $(argocd app list -o json | jq '[.[] | select(.status.sync.status=="OutOfSync")] | length')"

echo -e "\n=== End of Report ==="
EOF

chmod +x monitor-clusters.sh
./monitor-clusters.sh
```

---

## Challenge Exercise

**Scenario:** Your organization needs a complete multi-cluster GitOps setup for a microservices platform:

**Requirements:**

1. **Cluster Architecture:**
   - 1 Management cluster (running Argo CD)
   - 2 Development clusters (dev-east, dev-west)
   - 2 Staging clusters (staging-east, staging-west)
   - 2 Production clusters (prod-east, prod-west)

2. **Application Deployment:**
   - Deploy a microservices application (3+ services) to all clusters
   - Each cluster should have region-specific configuration
   - Production clusters should have 5 replicas, staging 2, dev 1
   - Use different resource limits per environment

3. **ApplicationSets:**
   - Create ApplicationSet that deploys to all clusters based on labels
   - Use cluster generator with label selectors
   - Implement different sync policies per environment

4. **Disaster Recovery:**
   - Implement active-active setup for production (both regions active)
   - Implement active-passive for staging
   - Create runbook for cluster failover procedure

5. **Monitoring and Alerts:**
   - Create dashboard showing status of all clusters
   - Implement health checks across clusters
   - Create alerts for sync failures

**Deliverables:**

- All clusters configured and registered
- ApplicationSets for automated multi-cluster deployment
- Cluster-specific configurations
- DR plan and failover procedure
- Monitoring dashboard and scripts
- Complete documentation

---

## Cleanup

```bash
# Delete all applications
argocd app delete -l environment=staging --yes
argocd app delete -l environment=production --yes
argocd app delete critical-service-prod critical-service-backup --yes

# Delete ApplicationSets
kubectl delete applicationset -n argocd --all

# Remove clusters from Argo CD
argocd cluster rm staging --yes
argocd cluster rm prod --yes

# Delete kind clusters
kind delete cluster --name dev
kind delete cluster --name staging
kind delete cluster --name prod

# Or for minikube
minikube delete -p dev
minikube delete -p staging
minikube delete -p prod

# Or for k3d
k3d cluster delete dev
k3d cluster delete staging
k3d cluster delete prod

# Clean up local files
rm -rf ~/multi-cluster-app
rm -f applicationset-*.yaml critical-app*.yaml monitor-clusters.sh
```

---

## Summary

Excellent work! You've mastered multi-cluster management with Argo CD. Here are the key takeaways:

- **Cluster Registration:** Add external clusters using `argocd cluster add`
- **Multi-Cluster Deployment:** Deploy applications to multiple clusters from single Argo CD instance
- **Cluster Labels:** Use labels for cluster selection and targeting
- **ApplicationSets:** Automate deployment across multiple clusters
- **Cluster Generators:** Select clusters dynamically based on labels
- **Disaster Recovery:** Implement failover strategies for production workloads
- **Monitoring:** Track health and sync status across all clusters

**Key Concepts:**

1. **Cluster Types:**
   - **In-cluster:** Cluster where Argo CD is installed
   - **External clusters:** Remote clusters registered with Argo CD

2. **Authentication Methods:**
   - ServiceAccount (default, most common)
   - Bearer token
   - TLS certificates
   - OIDC

3. **ApplicationSet Generators:**
   - **Cluster Generator:** Create apps based on registered clusters
   - **Git Generator:** Create apps from Git repo structure
   - **Matrix Generator:** Combine multiple generators
   - **List Generator:** Create apps from static list

**Key Commands:**

```bash
# Cluster management
argocd cluster add <context> --name <name>
argocd cluster list
argocd cluster get <name>
argocd cluster set <name> --label key=value
argocd cluster rm <name>

# Multi-cluster applications
argocd app create <name> --dest-server <server-url>
argocd app create <name> --dest-name <cluster-name>

# ApplicationSets
kubectl apply -f applicationset.yaml
kubectl get applicationset -n argocd
kubectl get applications -n argocd
```

**Best Practices:**

1. Use a dedicated management cluster for Argo CD
2. Label clusters for easy selection and routing
3. Use ApplicationSets for similar apps across clusters
4. Implement cluster-specific configurations with overlays
5. Test failover procedures regularly
6. Monitor cluster connectivity and health
7. Use namespace isolation for multi-tenancy
8. Implement RBAC per cluster
9. Document cluster topology and dependencies
10. Automate cluster registration in CI/CD

**Security Considerations:**

1. Limit cluster admin permissions
2. Use dedicated ServiceAccounts per cluster
3. Rotate cluster credentials regularly
4. Audit cross-cluster access
5. Implement network policies between clusters
6. Use TLS for cluster communication
7. Monitor for unauthorized cluster access

---

## Additional Practice

To reinforce your learning, try these additional exercises:

1. **Hub-and-Spoke Architecture:**
   - Create regional hub clusters
   - Deploy to spoke clusters from regional hubs
   - Implement cascading deployment patterns

2. **Progressive Delivery:**
   - Deploy to dev clusters first
   - Promote to staging after validation
   - Promote to production with approval gates

3. **Cluster Federation:**
   - Implement service mesh across clusters
   - Configure cross-cluster service discovery
   - Load balance traffic across clusters

4. **Advanced ApplicationSets:**
   - Use merge generators
   - Implement cluster decision resource
   - Create dynamic cluster selection

5. **Backup and Restore:**
   - Backup Argo CD configuration
   - Backup application manifests
   - Practice full disaster recovery

6. **Compliance and Governance:**
   - Implement policy enforcement across clusters
   - Audit deployments per cluster
   - Generate compliance reports

**Helpful Resources:**

- Multi-Cluster: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters
- ApplicationSets: https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/
- Cluster Generator: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/
- Disaster Recovery: https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/

---

## Solutions

<details>
<summary>Click to expand Challenge Exercise solutions</summary>

### Solution to Challenge Exercise

This is a comprehensive solution for a production-grade multi-cluster setup.

#### Step 1: Create All Clusters

```bash
# Create management cluster (Argo CD will run here)
kind create cluster --name mgmt

# Create development clusters
kind create cluster --name dev-east
kind create cluster --name dev-west

# Create staging clusters
kind create cluster --name staging-east
kind create cluster --name staging-west

# Create production clusters
kind create cluster --name prod-east
kind create cluster --name prod-west

# Verify all clusters
kind get clusters
kubectl config get-contexts
```

#### Step 2: Install Argo CD on Management Cluster

```bash
# Switch to management cluster
kubectl config use-context kind-mgmt

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Port forward and login
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --insecure
```

#### Step 3: Register All Clusters with Labels

```bash
# Register development clusters
argocd cluster add kind-dev-east --name dev-east
argocd cluster set dev-east --label environment=development --label region=east --label tier=dev

argocd cluster add kind-dev-west --name dev-west
argocd cluster set dev-west --label environment=development --label region=west --label tier=dev

# Register staging clusters
argocd cluster add kind-staging-east --name staging-east
argocd cluster set staging-east --label environment=staging --label region=east --label tier=non-prod

argocd cluster add kind-staging-west --name staging-west
argocd cluster set staging-west --label environment=staging --label region=west --label tier=non-prod --label dr-role=passive

# Register production clusters
argocd cluster add kind-prod-east --name prod-east
argocd cluster set prod-east --label environment=production --label region=east --label tier=prod --label dr-role=active

argocd cluster add kind-prod-west --name prod-west
argocd cluster set prod-west --label environment=production --label region=west --label tier=prod --label dr-role=active

# List all clusters with labels
argocd cluster list -o wide
```

#### Step 4: Create Microservices Application

```bash
mkdir -p ~/enterprise-microservices/{base,overlays/{dev,staging,prod}}
cd ~/enterprise-microservices

# Create base manifests for frontend service
cat <<EOF > base/frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.25
        ports:
        - containerPort: 80
        env:
        - name: BACKEND_URL
          value: "http://backend:8080"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
EOF

# Create backend service
cat <<EOF > base/backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: hashicorp/http-echo:0.2.3
        args: ["-text=Backend API"]
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          value: "postgres://db:5432"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
EOF

# Create database service
cat <<EOF > base/database-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: microservices
spec:
  serviceName: database
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          value: "postgres"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
EOF

# Create services
cat <<EOF > base/services.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: microservices
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: microservices
spec:
  selector:
    app: backend
  ports:
  - port: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: microservices
spec:
  selector:
    app: database
  ports:
  - port: 5432
  clusterIP: None
EOF

# Create namespace
cat <<EOF > base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
EOF

# Create base kustomization
cat <<EOF > base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- frontend-deployment.yaml
- backend-deployment.yaml
- database-statefulset.yaml
- services.yaml
EOF

# Create dev overlay
cat <<EOF > overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

patches:
- target:
    kind: Deployment
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 1

commonLabels:
  environment: development
EOF

# Create staging overlay
cat <<EOF > overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

patches:
- target:
    kind: Deployment
    name: frontend
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 2
- target:
    kind: Deployment
    name: backend
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 2

commonLabels:
  environment: staging
EOF

# Create prod overlay
cat <<EOF > overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

patches:
- target:
    kind: Deployment
    name: frontend
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 5
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/cpu
      value: "100m"
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/memory
      value: "128Mi"
- target:
    kind: Deployment
    name: backend
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 5
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/cpu
      value: "100m"
    - op: replace
      path: /spec/template/spec/containers/0/resources/requests/memory
      value: "128Mi"
- target:
    kind: StatefulSet
    name: database
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3

commonLabels:
  environment: production
EOF

# Push to Git
git init
git add .
git commit -m "Initial microservices application"
gh repo create enterprise-microservices --public --source=. --remote=origin --push
```

#### Step 5: Create ApplicationSets

```bash
# ApplicationSet for development clusters
cat <<EOF > applicationset-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices-dev
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: development
  template:
    metadata:
      name: 'microservices-{{metadata.labels.region}}-dev'
      labels:
        environment: development
        region: '{{metadata.labels.region}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/$GITHUB_USER/enterprise-microservices.git
        targetRevision: HEAD
        path: overlays/dev
      destination:
        server: '{{server}}'
        namespace: microservices
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
EOF

# ApplicationSet for staging (active-passive)
cat <<EOF > applicationset-staging.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices-staging
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: staging
        matchExpressions:
        - key: dr-role
          operator: NotIn
          values:
          - passive
  template:
    metadata:
      name: 'microservices-{{metadata.labels.region}}-staging'
      labels:
        environment: staging
        region: '{{metadata.labels.region}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/$GITHUB_USER/enterprise-microservices.git
        targetRevision: HEAD
        path: overlays/staging
      destination:
        server: '{{server}}'
        namespace: microservices
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
EOF

# ApplicationSet for production (active-active)
cat <<EOF > applicationset-prod.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices-prod
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
          dr-role: active
  template:
    metadata:
      name: 'microservices-{{metadata.labels.region}}-prod'
      labels:
        environment: production
        region: '{{metadata.labels.region}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/$GITHUB_USER/enterprise-microservices.git
        targetRevision: HEAD
        path: overlays/prod
      destination:
        server: '{{server}}'
        namespace: microservices
      syncPolicy:
        automated:
          prune: false  # Manual prune for production
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
        retry:
          limit: 3
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
EOF

# Apply ApplicationSets
kubectl apply -f applicationset-dev.yaml
kubectl apply -f applicationset-staging.yaml
kubectl apply -f applicationset-prod.yaml

# Wait and verify applications are created
sleep 10
argocd app list
```

#### Step 6: Create DR Runbook

```bash
cat <<EOF > DR-RUNBOOK.md
# Disaster Recovery Runbook

## Production Active-Active Setup

Both prod-east and prod-west are active. Traffic is load balanced between regions.

### Scenario 1: Single Region Failure

If prod-east fails:
1. Verify failure: \`argocd cluster get prod-east\`
2. Traffic automatically routes to prod-west (handled by external LB)
3. Monitor prod-west for increased load
4. Investigate and fix prod-east
5. Re-sync applications once cluster is healthy

### Scenario 2: Complete Production Failure

If both production regions fail:
1. Activate staging-west (passive DR):
   \`\`\`bash
   argocd cluster set staging-west --label dr-role=active
   # This will trigger ApplicationSet to deploy prod config
   \`\`\`
2. Update DNS to point to staging-west
3. Monitor application health
4. Fix production clusters
5. Perform controlled failback:
   \`\`\`bash
   # Re-sync production
   argocd app sync -l environment=production
   # Verify health
   # Update DNS back to production
   # Deactivate staging-west
   argocd cluster set staging-west --label dr-role=passive
   \`\`\`

## Staging Active-Passive Setup

staging-east is active, staging-west is passive (standby).

### Failover Procedure

1. Detect staging-east failure
2. Activate passive cluster:
   \`\`\`bash
   kubectl label cluster staging-west dr-role-
   argocd app create microservices-west-staging \\
     --repo https://github.com/$GITHUB_USER/enterprise-microservices.git \\
     --path overlays/staging \\
     --dest-name staging-west \\
     --dest-namespace microservices \\
     --sync-policy automated
   argocd app sync microservices-west-staging
   \`\`\`
3. Update application endpoints
4. Fix staging-east
5. Failback when ready

## Testing DR Procedures

Perform quarterly DR drills:
1. Schedule maintenance window
2. Simulate region failure
3. Execute failover procedures
4. Validate application functionality
5. Measure RTO/RPO
6. Document lessons learned
7. Update runbook

## Contact Information

- On-call: [PagerDuty link]
- Slack: #platform-incidents
- Management: [Contact list]
EOF
```

#### Step 7: Create Monitoring Dashboard

```bash
cat <<'EOF' > dashboard.sh
#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║      Multi-Cluster Microservices Dashboard                 ║"
echo "╔════════════════════════════════════════════════════════════╗"
echo ""

# Cluster health
echo "=== CLUSTER HEALTH ==="
for cluster in dev-east dev-west staging-east staging-west prod-east prod-west; do
  status=$(argocd cluster get $cluster 2>&1)
  if echo "$status" | grep -q "Successful"; then
    echo -e "${GREEN}✓${NC} $cluster: Healthy"
  else
    echo -e "${RED}✗${NC} $cluster: Unhealthy"
  fi
done

# Application health by environment
echo -e "\n=== APPLICATION HEALTH ==="

for env in development staging production; do
  echo -e "\n$env:"
  apps=$(argocd app list -l environment=$env -o json)
  total=$(echo "$apps" | jq '. | length')
  healthy=$(echo "$apps" | jq '[.[] | select(.status.health.status=="Healthy")] | length')
  synced=$(echo "$apps" | jq '[.[] | select(.status.sync.status=="Synced")] | length')

  echo "  Total Apps: $total"
  echo "  Healthy: $healthy/$total"
  echo "  Synced: $synced/$total"

  if [ "$healthy" -eq "$total" ] && [ "$synced" -eq "$total" ]; then
    echo -e "  Status: ${GREEN}ALL HEALTHY${NC}"
  else
    echo -e "  Status: ${YELLOW}ATTENTION NEEDED${NC}"
  fi
done

# Resource summary by cluster
echo -e "\n=== RESOURCE DISTRIBUTION ==="
echo "Region | Dev | Staging | Production"
echo "-------|-----|---------|------------"

for region in east west; do
  dev=$(kubectl --context kind-dev-$region get pods -n microservices 2>/dev/null | wc -l || echo 0)
  stg=$(kubectl --context kind-staging-$region get pods -n microservices 2>/dev/null | wc -l || echo 0)
  prd=$(kubectl --context kind-prod-$region get pods -n microservices 2>/dev/null | wc -l || echo 0)
  printf "%-6s | %-3s | %-7s | %-10s\n" "$region" "$dev" "$stg" "$prd"
done

# Recent sync events
echo -e "\n=== RECENT SYNC EVENTS ==="
argocd app list -o json | jq -r '.[] | "\(.metadata.name): \(.status.sync.status) (\(.status.operationState.finishedAt // "in progress"))"' | head -5

echo -e "\n=== END OF DASHBOARD ==="
echo "Last updated: $(date)"
EOF

chmod +x dashboard.sh
./dashboard.sh
```

#### Step 8: Verify Complete Setup

```bash
# Run monitoring dashboard
./dashboard.sh

# Verify each cluster
for cluster in dev-east dev-west staging-east prod-east prod-west; do
  echo "=== Checking $cluster ==="
  context="kind-$cluster"
  kubectl --context $context get pods -n microservices
done

# Test DR failover (staging)
echo "Testing staging DR failover..."
argocd cluster set staging-west --label dr-role=active
sleep 10
argocd app list -l environment=staging
# Should see staging-west application now

# Revert
argocd cluster set staging-west --label dr-role=passive
```

#### Step 9: Create Complete Documentation

```bash
cat <<EOF > ARCHITECTURE.md
# Multi-Cluster Architecture Documentation

## Overview

7 Kubernetes clusters managed by single Argo CD instance:
- 1 Management cluster (Argo CD)
- 2 Development clusters (active-active)
- 2 Staging clusters (active-passive)
- 2 Production clusters (active-active)

## Cluster Topology

\`\`\`
                    [Management Cluster]
                           |
         +-----------------+-----------------+
         |                 |                 |
    [Dev Clusters]   [Staging Clusters]  [Prod Clusters]
    |           |     |              |    |            |
  dev-east  dev-west  staging-east  staging-west  prod-east  prod-west
  (active)  (active)  (active)      (passive)     (active)   (active)
\`\`\`

## Application Deployment

### Development
- All changes deploy automatically to both regions
- Used for feature development and testing
- No redundancy requirements
- Resource limits: Minimal

### Staging
- Active-passive setup for cost optimization
- Primary: staging-east (active)
- DR: staging-west (passive, manual activation)
- Resource limits: Medium

### Production
- Active-active across both regions
- Geographic load distribution
- Automatic failover capabilities
- Resource limits: Maximum
- 5 replicas per service per region

## ApplicationSet Strategy

Three ApplicationSets manage deployments:
1. **microservices-dev**: Deploys to all dev clusters
2. **microservices-staging**: Deploys to active staging cluster
3. **microservices-prod**: Deploys to all production clusters

## Disaster Recovery

### RTO/RPO Targets
- Development: 1 hour / 1 hour
- Staging: 30 minutes / 15 minutes
- Production: 5 minutes / 0 minutes

### Procedures
See DR-RUNBOOK.md for detailed procedures.

## Monitoring

- Dashboard: \`./dashboard.sh\`
- Argo CD UI: https://localhost:8080
- Cluster health checks: Every 5 minutes
- Application sync checks: Continuous

## Maintenance Windows

- Development: Anytime
- Staging: Tue/Thu 2-4 AM UTC
- Production: Sat 2-6 AM UTC

## Contacts

- Platform Team: platform@example.com
- On-call: [PagerDuty]
- Slack: #platform
EOF
```

#### Cleanup

```bash
# Delete all ApplicationSets
kubectl delete applicationset -n argocd --all

# Delete all applications
argocd app delete -l environment=development --yes
argocd app delete -l environment=staging --yes
argocd app delete -l environment=production --yes

# Remove clusters
for cluster in dev-east dev-west staging-east staging-west prod-east prod-west; do
  argocd cluster rm $cluster --yes
done

# Delete kind clusters
kind delete cluster --name mgmt
kind delete cluster --name dev-east
kind delete cluster --name dev-west
kind delete cluster --name staging-east
kind delete cluster --name staging-west
kind delete cluster --name prod-east
kind delete cluster --name prod-west

# Clean up files
rm -rf ~/enterprise-microservices
rm -f applicationset-*.yaml DR-RUNBOOK.md dashboard.sh ARCHITECTURE.md
```

</details>
