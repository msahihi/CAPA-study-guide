# Core Concepts

## Overview

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It follows the GitOps pattern where Git repositories serve as the source of truth for defining the desired application state. Argo CD automates the deployment of applications to Kubernetes clusters by continuously monitoring Git repositories and synchronizing the actual state with the desired state.

Understanding Argo CD's core architecture, components, and fundamental concepts is essential for the CAPA exam. This section covers the architectural components, GitOps principles, Application Custom Resource Definition (CRD), and key status concepts.

## Key Topics

### Argo CD Architecture

Argo CD consists of several key components that work together to provide GitOps-based continuous delivery:

#### API Server

- **Purpose**: Exposes the Argo CD API and serves the Web UI
- **Responsibilities**:
  - Application management operations (CRUD)
  - Invoking application operations (sync, rollback, user-defined actions)
  - Repository and cluster credential management
  - Authentication and authorization (RBAC)
  - Listening to Git webhook events
  - Serving the gRPC/REST API consumed by the Web UI and CLI
- **Access Methods**: REST API, gRPC API, Web UI
- **Port**: Typically runs on port 8080 (HTTP) and 8443 (HTTPS)

#### Repository Server

- **Purpose**: Internal service that maintains a local cache of Git repositories
- **Responsibilities**:
  - Cloning and fetching Git repositories
  - Generating Kubernetes manifests from various sources:
    - Raw Kubernetes YAML/JSON files
    - Helm charts
    - Kustomize applications
    - Jsonnet files
  - Caching repository data to improve performance
  - Handling credential management for Git repositories
- **Performance**: Uses caching to avoid repeated Git operations
- **Scalability**: Can be scaled horizontally for high-load environments

#### Application Controller

- **Purpose**: Kubernetes controller that continuously monitors running applications
- **Responsibilities**:
  - Watching Application resources in the cluster
  - Comparing the live state (actual) with the desired state (Git)
  - Detecting out-of-sync applications
  - Triggering sync operations (for auto-sync enabled apps)
  - Updating application status and health
  - Invoking user-defined hooks for lifecycle events
- **Reconciliation Loop**: Continuously polls Git repositories and clusters
- **Default Polling Interval**: 3 minutes (configurable)

#### Redis

- **Purpose**: Cache and temporary storage for Argo CD
- **Responsibilities**:
  - Caching application state
  - Storing temporary data
  - Queuing background operations
- **Note**: Required for Argo CD operation

#### Dex (Optional)

- **Purpose**: Identity provider integration
- **Responsibilities**:
  - SSO integration with external identity providers
  - OAuth2/OIDC authentication
  - Integration with LDAP, SAML, GitHub, GitLab, etc.

### GitOps Principles

Argo CD implements the following GitOps principles:

1. **Declarative Configuration**
   - Entire system state is described declaratively
   - Git repositories contain the desired state
   - No manual kubectl commands to production

2. **Version Controlled**
   - All configuration is stored in Git
   - Full audit trail of changes
   - Easy rollback to previous states

3. **Automated Synchronization**
   - Argo CD automatically applies changes from Git
   - Continuous monitoring and reconciliation
   - Self-healing capabilities

4. **Continuous Reconciliation**
   - Detect and correct drift from desired state
   - Alert on out-of-sync conditions
   - Optional auto-sync to maintain desired state

### Application CRD Structure

The Application Custom Resource Definition (CRD) is the core resource in Argo CD. It defines an application and its desired state.

#### Basic Application Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  # Finalizer ensures resources are deleted properly
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  # The project the application belongs to
  project: default

  # Source of the application manifests
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook

  # Destination cluster and namespace
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook

  # Sync policy (optional)
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - Validate=true
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

#### Application Spec Components

**Source Configuration**:

```yaml
source:
  # Git repository URL
  repoURL: https://github.com/example/repo.git

  # Branch, tag, or commit SHA
  targetRevision: main

  # Path within the repository
  path: kubernetes/production

  # Helm specific configuration (if using Helm)
  helm:
    releaseName: my-release
    valueFiles:
      - values.yaml
      - values-prod.yaml
    parameters:
      - name: image.tag
        value: "v1.0.0"
    values: |
      replicaCount: 3

  # Kustomize specific configuration
  kustomize:
    namePrefix: prod-
    commonLabels:
      environment: production
    images:
      - nginx=nginx:1.21.0

  # Directory/plugin options
  directory:
    recurse: true
    jsonnet:
      extVars:
        - name: environment
          value: production
```

**Destination Configuration**:

```yaml
destination:
  # Target cluster (can use cluster name or server URL)
  server: https://kubernetes.default.svc
  # Or use cluster name
  # name: in-cluster

  # Target namespace
  namespace: production
```

**Multiple Sources** (for advanced scenarios):

```yaml
sources:
  - repoURL: https://github.com/example/app.git
    path: helm
    targetRevision: main
    helm:
      valueFiles:
        - $values/values-prod.yaml
  - repoURL: https://github.com/example/config.git
    targetRevision: main
    ref: values
```

### Sync Status Concepts

Argo CD tracks two critical aspects of application state: Sync Status and Health Status.

#### Sync Status

Sync Status indicates whether the live state matches the desired state in Git.

**Sync Status Values**:

1. **Synced**
   - Live state matches the desired state
   - All resources are up-to-date with Git
   - No manual changes detected

2. **OutOfSync**
   - Live state differs from desired state
   - Possible causes:
     - New commits in Git repository
     - Manual changes to cluster resources
     - Drift from desired configuration
   - Action: Requires sync operation

3. **Unknown**
   - Unable to determine sync status
   - Possible causes:
     - Cluster unreachable
     - Repository inaccessible
     - Parsing errors in manifests

#### Sync Status Details

```yaml
status:
  sync:
    status: OutOfSync
    comparedTo:
      source:
        repoURL: https://github.com/example/repo.git
        path: app
        targetRevision: main
      destination:
        server: https://kubernetes.default.svc
        namespace: production
    revision: abc123def456
```

### Health Status Concepts

Health Status indicates the operational health of deployed resources.

#### Health Status Values

1. **Healthy**
   - Application is running correctly
   - All resources are functioning as expected
   - Ready to serve traffic

2. **Progressing**
   - Application is being deployed or updated
   - Resources are being created or modified
   - Waiting for pods to become ready

3. **Degraded**
   - Application is running but with issues
   - Some replicas are not ready
   - Partial failure state

4. **Suspended**
   - Application is intentionally suspended
   - Zero replicas or paused state
   - Not an error condition

5. **Missing**
   - Expected resources are not present
   - Application may have been deleted
   - Requires investigation

6. **Unknown**
   - Unable to determine health
   - Resource type not recognized
   - Custom health check failed

#### Health Assessment Rules

Argo CD uses built-in health assessment logic for common Kubernetes resources:

**Deployment Health**:

```yaml
# Healthy when:
# - All replicas are updated
# - All replicas are available
# - No old replicas are running

status:
  replicas: 3
  updatedReplicas: 3
  availableReplicas: 3
  unavailableReplicas: 0
```

**Service Health**:

```yaml
# Healthy when:
# - Service exists and is properly configured
# - For LoadBalancer type: external IP is assigned
```

**Custom Health Checks**:

```yaml
# Can be defined in argocd-cm ConfigMap
resource.customizations.health.argoproj.io_Rollout: |
  hs = {}
  if obj.status ~= nil then
    if obj.status.phase == "Healthy" then
      hs.status = "Healthy"
      hs.message = "Rollout is healthy"
      return hs
    end
  end
  hs.status = "Progressing"
  hs.message = "Rollout is progressing"
  return hs
```

### Application Status Conditions

Applications maintain various conditions that provide detailed status information:

```yaml
status:
  conditions:
    - type: ComparisonError
      message: "Failed to parse manifests"
      lastTransitionTime: "2024-01-15T10:30:00Z"
    - type: InvalidSpecError
      message: "Invalid targetRevision"
      lastTransitionTime: "2024-01-15T10:25:00Z"
```

**Common Condition Types**:

- `ComparisonError`: Error comparing live vs desired state
- `InvalidSpecError`: Invalid application specification
- `OrphanedResourceWarning`: Resources exist but not in Git
- `ExceededResourceQuota`: Resource quota exceeded

### Resource Hooks

Hooks allow custom actions during sync operations:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "1"
spec:
  template:
    spec:
      containers:
      - name: migration
        image: migrate-tool:latest
        command: ["./migrate.sh"]
      restartPolicy: Never
```

**Hook Types**:

- `PreSync`: Before sync operation
- `Sync`: During sync operation
- `PostSync`: After sync operation
- `Skip`: Skip this resource during sync
- `SyncFail`: Execute if sync fails

## Practice Examples

### Example 1: Simple Application Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/kubernetes-manifests.git
    targetRevision: main
    path: nginx
  destination:
    server: https://kubernetes.default.svc
    namespace: nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Example 2: Helm Application with Values

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis-helm
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: redis
    targetRevision: 17.8.0
    helm:
      releaseName: redis
      parameters:
        - name: auth.enabled
          value: "false"
        - name: replica.replicaCount
          value: "3"
      values: |
        master:
          persistence:
            enabled: true
            size: 8Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: redis
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Example 3: Kustomize Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/kustomize-app.git
    targetRevision: main
    path: overlays/production
    kustomize:
      namePrefix: prod-
      commonLabels:
        environment: production
      images:
        - myapp=myregistry.com/myapp:v2.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Example 4: CLI Commands for Core Operations

```bash
# Get application status
argocd app get guestbook

# List all applications
argocd app list

# Get application details in YAML
argocd app get guestbook -o yaml

# Show application sync status
argocd app sync-status guestbook

# View application resources
argocd app resources guestbook

# View application history
argocd app history guestbook

# Get application manifests
argocd app manifests guestbook

# Diff between live and desired state
argocd app diff guestbook

# View application logs
argocd app logs guestbook

# Wait for application to be synced
argocd app wait guestbook --sync

# Wait for application to be healthy
argocd app wait guestbook --health
```

### Example 5: Application with Sync Waves

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: multi-tier-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/app.git
    targetRevision: main
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true

---
# Database ConfigMap (Wave 0 - deployed first)
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  annotations:
    argocd.argoproj.io/sync-wave: "0"
data:
  DB_HOST: postgres.db.svc.cluster.local

---
# Database Deployment (Wave 1)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
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
        image: postgres:14

---
# Application Deployment (Wave 2 - deployed after database)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: application
  template:
    metadata:
      labels:
        app: application
    spec:
      containers:
      - name: app
        image: myapp:latest
```

## Study Resources

- [Argo CD Official Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD Core Concepts](https://argo-cd.readthedocs.io/en/stable/core_concepts/)
- [Argo CD Architecture](https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/)
- [Application CRD Specification](https://argo-cd.readthedocs.io/en/stable/operator-manual/application.yaml)
- [GitOps Principles - OpenGitOps](https://opengitops.dev/)
- [Argo CD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Understanding Sync Status](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Resource Health Assessment](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)

## Key Points to Remember

- Argo CD consists of three main components: API Server, Repository Server, and Application Controller
- The API Server handles all API operations, authentication, and serves the Web UI
- The Repository Server clones Git repositories and generates Kubernetes manifests
- The Application Controller monitors applications and ensures desired state matches live state
- GitOps principles: Declarative, Version Controlled, Automated, Continuously Reconciled
- The Application CRD is the core resource defining what to deploy and where
- Sync Status indicates if live state matches desired state (Synced/OutOfSync/Unknown)
- Health Status indicates operational health (Healthy/Progressing/Degraded/Suspended/Missing/Unknown)
- Applications require source (Git repo) and destination (cluster + namespace) configuration
- Default reconciliation interval is 3 minutes (polling Git and cluster state)
- Argo CD supports multiple manifest formats: plain YAML, Helm, Kustomize, Jsonnet
- Sync waves control the order of resource deployment using annotations
- Resource hooks (PreSync, Sync, PostSync, SyncFail) enable custom actions during sync
- The `resources-finalizer.argocd.argoproj.io` finalizer ensures proper resource cleanup
- Applications can use automated sync policies with prune and self-heal capabilities

## Hands-On Practice

For practical exercises and labs on Argo CD core concepts, see:

- [Lab 01: Installing Argo CD](../../labs/01-argo-cd/lab-01-installation.md)
- [Lab 02: Deploying Your First Application](../../labs/01-argo-cd/lab-02-first-app.md)
- [Lab 03: Managing Application Sync](../../labs/01-argo-cd/lab-03-sync-management.md)
