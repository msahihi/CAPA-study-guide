# Application Management

## Overview

Application management is at the core of Argo CD operations. This section covers how to create, manage, and organize applications using various methods including the UI, CLI, and declarative approaches. Understanding application patterns like App-of-Apps, repository management, project organization, and ApplicationSets is crucial for the CAPA exam.

Effective application management enables teams to deploy applications consistently, scale operations, and maintain GitOps best practices across multiple environments and clusters.

## Key Topics

### Creating Applications

#### Creating Applications via UI

**Steps to Create Application via Web UI**:

1. Login to Argo CD Web UI
2. Click "+ NEW APP" button
3. Fill in application details:
   - **Application Name**: Unique identifier
   - **Project**: Select project (default or custom)
   - **Sync Policy**: Manual or Automatic
   - **Repository URL**: Git repository URL
   - **Revision**: Branch, tag, or commit SHA
   - **Path**: Path to manifests in repository
   - **Cluster URL**: Target cluster
   - **Namespace**: Target namespace
4. Configure sync options (optional)
5. Click "CREATE"

**UI Advantages**:

- Visual interface for quick application creation
- Form validation and helper text
- Real-time preview of settings
- Easy to explore available options

**UI Limitations**:

- Not version controlled
- Manual process (not automated)
- Difficult to replicate at scale

#### Creating Applications via CLI

**Basic Application Creation**:

```bash
# Create a simple application
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Create with specific revision
argocd app create myapp \
  --repo https://github.com/example/repo.git \
  --path kubernetes/overlays/production \
  --revision v2.0.0 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production

# Create with automated sync
argocd app create myapp \
  --repo https://github.com/example/repo.git \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace myapp \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Create Helm application
argocd app create redis \
  --repo https://charts.bitnami.com/bitnami \
  --helm-chart redis \
  --revision 17.8.0 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace redis \
  --helm-set auth.enabled=false \
  --helm-set replica.replicaCount=3

# Create Kustomize application
argocd app create myapp \
  --repo https://github.com/example/kustomize-app.git \
  --path overlays/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production \
  --kustomize-image myapp=myregistry.com/myapp:v2.0.0
```

**CLI Management Commands**:

```bash
# List applications
argocd app list

# Get application details
argocd app get myapp

# Sync application
argocd app sync myapp

# Delete application
argocd app delete myapp

# Set application parameters
argocd app set myapp --parameter key=value

# Diff application
argocd app diff myapp

# Rollback application
argocd app rollback myapp <HISTORY_ID>

# Terminate sync operation
argocd app terminate-op myapp
```

#### Creating Applications Declaratively

**Declarative Application Definition**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  # Add finalizer to ensure proper cleanup
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  # Labels for organization
  labels:
    app: myapp
    environment: production
  # Annotations for additional metadata
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.slack: my-channel
spec:
  project: production-project

  source:
    repoURL: https://github.com/example/app.git
    targetRevision: main
    path: kubernetes/production

  destination:
    server: https://kubernetes.default.svc
    namespace: production

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

  # Ignore differences in specific fields
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

**Apply Declarative Application**:

```bash
# Apply application definition
kubectl apply -f application.yaml

# Verify application creation
argocd app list

# Watch application sync
argocd app sync myapp --watch
```

### App-of-Apps Pattern

The App-of-Apps pattern allows managing multiple applications as a single application. This is a powerful pattern for organizing applications hierarchically.

#### Basic App-of-Apps Structure

**Parent Application** (app-of-apps.YAML):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/apps.git
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Repository Structure**:

```
apps/
├── app-of-apps.yaml (parent application)
└── apps/
    ├── frontend.yaml
    ├── backend.yaml
    ├── database.yaml
    └── monitoring.yaml
```

**Child Applications** (apps/frontend.YAML):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/example/frontend.git
    targetRevision: main
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**apps/backend.YAML**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/example/backend.git
    targetRevision: main
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: backend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### Multi-Environment App-of-Apps

```
environments/
├── production/
│   ├── app-of-apps.yaml
│   └── apps/
│       ├── frontend.yaml
│       ├── backend.yaml
│       └── database.yaml
├── staging/
│   ├── app-of-apps.yaml
│   └── apps/
│       ├── frontend.yaml
│       ├── backend.yaml
│       └── database.yaml
└── development/
    ├── app-of-apps.yaml
    └── apps/
        ├── frontend.yaml
        └── backend.yaml
```

**Production App-of-Apps** (production/app-of-apps.YAML):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: production-apps
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/example/environments.git
    targetRevision: main
    path: production/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Repository Management

#### Adding Git Repositories via CLI

```bash
# Add public repository
argocd repo add https://github.com/example/public-repo.git

# Add private repository with username/password
argocd repo add https://github.com/example/private-repo.git \
  --username myuser \
  --password mypassword

# Add repository with SSH key
argocd repo add git@github.com:example/private-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Add repository with token
argocd repo add https://github.com/example/private-repo.git \
  --username token \
  --password ghp_xxxxxxxxxxxx

# Add Helm repository
argocd repo add https://charts.bitnami.com/bitnami \
  --type helm \
  --name bitnami

# List repositories
argocd repo list

# Remove repository
argocd repo rm https://github.com/example/repo.git
```

#### Adding Repositories Declaratively

**Secret for Repository Credentials**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/example/private-repo.git
  username: myuser
  password: mypassword
```

**SSH Repository Secret**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-ssh
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@github.com:example/private-repo.git
  sshPrivateKey: |
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA...
    -----END RSA PRIVATE KEY-----
```

**Helm Repository Secret**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: helm-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: helm
  url: https://charts.example.com
  username: myuser
  password: mypassword
```

#### Repository Credentials Template

Define credentials once and use for multiple repositories:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: https://github.com/example
  username: myuser
  password: ghp_xxxxxxxxxxxx
```

Then configure in `argocd-cm`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  repository.credentials: |
    - url: https://github.com/example
      passwordSecret:
        name: github-creds
        key: password
      usernameSecret:
        name: github-creds
        key: username
```

### Project Management

Projects provide logical grouping and access control for applications.

#### Creating Projects via CLI

```bash
# Create project
argocd proj create myproject

# Create project with description
argocd proj create production \
  --description "Production applications"

# Add source repository
argocd proj add-source myproject https://github.com/example/repo.git

# Add destination
argocd proj add-destination myproject \
  https://kubernetes.default.svc \
  production

# Add cluster resource whitelist
argocd proj allow-cluster-resource myproject \
  apps Deployment

# Add namespace resource whitelist
argocd proj allow-namespace-resource myproject \
  production apps Deployment

# List projects
argocd proj list

# Get project details
argocd proj get myproject

# Delete project
argocd proj delete myproject
```

#### Declarative Project Definition

**Basic Project**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications

  # Allow all sources
  sourceRepos:
    - '*'

  # Restrict destinations
  destinations:
    - namespace: production
      server: https://kubernetes.default.svc
    - namespace: monitoring
      server: https://kubernetes.default.svc

  # Allow specific resource types
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: 'rbac.authorization.k8s.io'
      kind: ClusterRole
    - group: 'rbac.authorization.k8s.io'
      kind: ClusterRoleBinding

  # Allow all namespaced resources
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'

  # Deny specific resources
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange
```

**Restricted Project**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-app
  namespace: argocd
spec:
  description: Team application project

  # Specific source repositories
  sourceRepos:
    - https://github.com/team/app-repo.git
    - https://charts.bitnami.com/bitnami

  # Specific destinations
  destinations:
    - namespace: team-dev
      server: https://kubernetes.default.svc
    - namespace: team-staging
      server: https://kubernetes.default.svc

  # No cluster resources allowed
  clusterResourceWhitelist: []

  # Specific namespace resources
  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: 'apps'
      kind: StatefulSet
    - group: ''
      kind: Service
    - group: ''
      kind: ConfigMap
    - group: ''
      kind: Secret

  # Orphaned resources settings
  orphanedResources:
    warn: true

  # Sync windows
  syncWindows:
    - kind: allow
      schedule: '0 9 * * 1-5'
      duration: 8h
      applications:
        - '*'
      manualSync: true
    - kind: deny
      schedule: '0 0 * * 0,6'
      duration: 24h
      applications:
        - '*'
      manualSync: false
```

### ApplicationSets

ApplicationSets provide automated application generation based on templates and generators.

#### List Generator

Generate applications from a static list:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: production
            url: https://prod-cluster.example.com
            namespace: apps
          - cluster: staging
            url: https://staging-cluster.example.com
            namespace: apps
          - cluster: development
            url: https://dev-cluster.example.com
            namespace: apps

  template:
    metadata:
      name: '{{cluster}}-myapp'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/app.git
        targetRevision: main
        path: kubernetes
      destination:
        server: '{{url}}'
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

#### Git Directory Generator

Generate applications based on directories in a Git repository:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-from-dirs
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/example/apps.git
        revision: main
        directories:
          - path: apps/*

  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/apps.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

#### Git File Generator

Generate applications based on JSON/YAML files in Git:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-from-files
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/example/app-config.git
        revision: main
        files:
          - path: "configs/*.yaml"

  template:
    metadata:
      name: '{{app.name}}'
    spec:
      project: default
      source:
        repoURL: '{{app.repoURL}}'
        targetRevision: '{{app.targetRevision}}'
        path: '{{app.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{app.namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

**Example config file** (configs/frontend.YAML):

```yaml
app:
  name: frontend
  repoURL: https://github.com/example/frontend.git
  targetRevision: v2.0.0
  path: kubernetes/production
  namespace: frontend
```

#### Cluster Generator

Generate applications for each cluster registered in Argo CD:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production

  template:
    metadata:
      name: '{{name}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/guestbook.git
        targetRevision: main
        path: kubernetes
      destination:
        server: '{{server}}'
        namespace: guestbook
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

#### Matrix Generator

Combine multiple generators:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: matrix-apps
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - git:
              repoURL: https://github.com/example/apps.git
              revision: main
              directories:
                - path: apps/*
          - list:
              elements:
                - env: production
                  cluster: https://prod.example.com
                - env: staging
                  cluster: https://staging.example.com

  template:
    metadata:
      name: '{{path.basename}}-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/apps.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: '{{cluster}}'
        namespace: '{{path.basename}}-{{env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Practice Examples

### Example 1: Complete Application Lifecycle

```bash
# Create application
argocd app create myapp \
  --repo https://github.com/example/myapp.git \
  --path kubernetes/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace myapp \
  --sync-policy automated

# Watch application sync
argocd app wait myapp --sync

# Get application details
argocd app get myapp

# View application resources
argocd app resources myapp

# View live manifests
argocd app manifests myapp

# Compare live vs desired state
argocd app diff myapp

# Manually sync if needed
argocd app sync myapp

# Rollback to previous version
argocd app history myapp
argocd app rollback myapp 2

# Delete application
argocd app delete myapp
```

### Example 2: Multi-Environment Setup

**Directory Structure**:

```
environments/
├── base/
│   └── app-of-apps.yaml
├── dev/
│   └── apps/
│       ├── frontend.yaml
│       └── backend.yaml
├── staging/
│   └── apps/
│       ├── frontend.yaml
│       └── backend.yaml
└── prod/
    └── apps/
        ├── frontend.yaml
        ├── backend.yaml
        └── database.yaml
```

**Base App-of-Apps**:

```bash
# Apply base app-of-apps for dev
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/environments.git
    targetRevision: main
    path: dev/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Apply for staging
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: staging-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/environments.git
    targetRevision: main
    path: staging/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Apply for production
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prod-apps
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/example/environments.git
    targetRevision: main
    path: prod/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - Validate=true
EOF
```

### Example 3: ApplicationSet for Multi-Cluster

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-deployment
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - clusters:
              selector:
                matchLabels:
                  argocd.argoproj.io/secret-type: cluster
          - git:
              repoURL: https://github.com/example/apps.git
              revision: main
              directories:
                - path: apps/*

  template:
    metadata:
      name: '{{path.basename}}-{{name}}'
      labels:
        app: '{{path.basename}}'
        cluster: '{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/apps.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: '{{server}}'
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
```

## Study Resources

- [Application Management](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Repository Management](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/)
- [Project Management](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [ApplicationSet Generators](https://argocd-applicationset.readthedocs.io/en/stable/Generators/)

## Key Points to Remember

- Applications can be created via UI, CLI, or declaratively using YAML
- Declarative approach is preferred for GitOps and version control
- App-of-Apps pattern manages multiple applications as a single unit
- Repository credentials can be stored as Secrets with label `argocd.argoproj.io/secret-type: repository`
- Repository credential templates allow reusing credentials for multiple repos
- Projects provide logical grouping and RBAC for applications
- Projects can restrict source repos, destinations, and resource types
- ApplicationSets automate application generation using templates and generators
- Common ApplicationSet generators: List, Git Directory, Git File, Cluster, Matrix
- Matrix generator combines multiple generators for complex scenarios
- Applications require finalizers for proper resource cleanup
- Source can be Git repository or Helm chart
- Destination specifies target cluster and namespace
- Multiple sources can be used for advanced scenarios (e.g., separating values)

## Hands-On Practice

For practical exercises and labs on application management, see:

- [Lab 02: Deploying Your First Application](../../labs/01-argo-cd/lab-02-first-app.md)
- [Lab 05: Working with Helm Charts](../../labs/01-argo-cd/lab-05-helm.md)

## Application Health Assessment

Health assessment monitors application readiness and availability states.

## Application Sync Automation

Automation streamlines application deployment and reduces manual intervention.

## Application Notifications

Notifications alert teams about deployment status and application health changes.
