# Sync Strategies

## Overview

Synchronization is the core mechanism by which Argo CD ensures that the live state of applications matches the desired state defined in Git repositories. Understanding sync strategies, policies, options, waves, hooks, and phases is essential for controlling how and when applications are deployed and updated.

This section covers the different sync strategies available in Argo CD, from manual to fully automated approaches, along with advanced features like sync waves for ordered deployments and hooks for custom actions during sync operations.

## Key Topics

### Manual vs Automated Sync

#### Manual Sync

Manual sync requires explicit user action to synchronize applications.

**Characteristics**:

- Default sync mode
- Changes in Git do not automatically deploy
- User must trigger sync via UI, CLI, or API
- Provides explicit control over deployments
- Suitable for production environments requiring approval

**Triggering Manual Sync**:

```bash
# Sync via CLI
argocd app sync myapp

# Sync with specific revision
argocd app sync myapp --revision v2.0.0

# Sync specific resources only
argocd app sync myapp --resource apps:Deployment:myapp

# Sync and prune
argocd app sync myapp --prune

# Dry run sync
argocd app sync myapp --dry-run

# Force sync (ignore sync options)
argocd app sync myapp --force

# Sync and wait for completion
argocd app sync myapp --wait

# Sync with timeout
argocd app sync myapp --timeout 300
```

**Application with Manual Sync**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/app.git
    targetRevision: main
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  # No syncPolicy defined = manual sync
```

#### Automated Sync

Automated sync automatically synchronizes applications when Git changes are detected.

**Characteristics**:

- Argo CD automatically syncs when changes detected
- No manual intervention required
- Can be configured with prune and self-heal
- Ideal for development and staging environments
- Implements true GitOps automation

**Application with Automated Sync**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/app.git
    targetRevision: main
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Revert manual changes
      allowEmpty: false # Prevent deletion of all resources
```

**Enable Automated Sync via CLI**:

```bash
# Enable automated sync
argocd app set myapp --sync-policy automated

# Enable with prune
argocd app set myapp --sync-policy automated --auto-prune

# Enable with self-heal
argocd app set myapp --sync-policy automated --self-heal

# Disable automated sync
argocd app set myapp --sync-policy none
```

### Sync Policies

#### Prune

Prune removes resources that exist in the cluster but are no longer defined in Git.

**Without Prune**:

- Resources removed from Git remain in cluster
- Manual cleanup required
- Can lead to resource drift

**With Prune**:

- Resources removed from Git are deleted from cluster
- Maintains strict sync with Git
- Automated cleanup

```yaml
syncPolicy:
  automated:
    prune: true
```

**Prune Behavior Example**:

```yaml
# Initial state in Git: deployment + service
# User removes service from Git
# With prune: service deleted from cluster
# Without prune: service remains in cluster
```

**CLI Prune Control**:

```bash
# Enable prune
argocd app set myapp --auto-prune

# Disable prune
argocd app unset myapp --auto-prune

# Manually sync with prune
argocd app sync myapp --prune
```

#### Self-Heal

Self-heal automatically reverts manual changes made directly to the cluster.

**Without Self-Heal**:

- Manual changes persist
- Application becomes OutOfSync
- Manual sync required to restore desired state

**With Self-Heal**:

- Manual changes automatically reverted
- Application automatically returns to Synced state
- Enforces Git as single source of truth

```yaml
syncPolicy:
  automated:
    selfHeal: true
```

**Self-Heal Timing**:

- Default: 5 seconds after detection
- Configurable via `controller.self.heal.timeout.seconds`

**CLI Self-Heal Control**:

```bash
# Enable self-heal
argocd app set myapp --self-heal

# Disable self-heal
argocd app unset myapp --self-heal
```

**Example Scenario**:

```bash
# Application with self-heal enabled
kubectl scale deployment myapp --replicas=5

# Argo CD detects drift (replicas should be 3)
# Within 5 seconds, Argo CD reverts to 3 replicas
# Application returns to Synced state
```

#### Allow Empty

Controls whether Argo CD can delete all resources during sync.

```yaml
syncPolicy:
  automated:
    allowEmpty: false  # Prevent accidental deletion of all resources
```

**Use Cases**:

- `false`: Safety guard against accidental deletions (default recommended)
- `true`: Allow complete application deletion during sync

### Sync Options

Sync options provide fine-grained control over sync behavior.

#### Common Sync Options

```yaml
syncPolicy:
  syncOptions:
    # Validate resources before applying
    - Validate=true

    # Automatically create namespace if it doesn't exist
    - CreateNamespace=true

    # Prune propagation policy (foreground, background, orphan)
    - PrunePropagationPolicy=foreground

    # Prune resources last (after all other resources synced)
    - PruneLast=true

    # Apply resources out of sync only
    - ApplyOutOfSyncOnly=true

    # Replace resources instead of applying
    - Replace=false

    # Use server-side apply
    - ServerSideApply=true

    # Fail on shared resource
    - FailOnSharedResource=false

    # Respect ignore differences
    - RespectIgnoreDifferences=true

    # Skip schema validation
    - SkipSchemaValidation=false
```

#### Validate

Validates resources against Kubernetes API schema before applying.

```yaml
syncPolicy:
  syncOptions:
    - Validate=true
```

**Benefits**:

- Catch invalid resources early
- Prevent failed deployments
- Validate against target cluster API

#### CreateNamespace

Automatically creates namespace if it doesn't exist.

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

**Behavior**:

- Namespace created before resources
- Namespace labeled and tracked by Argo CD
- Namespace deleted when application deleted (if prune enabled)

#### PrunePropagationPolicy

Controls how Kubernetes deletes resources during pruning.

```yaml
syncPolicy:
  syncOptions:
    - PrunePropagationPolicy=foreground
```

**Options**:

1. **foreground** (recommended):
   - Deletes dependents before deleting the owner
   - Ensures clean deletion order
   - Example: Pods deleted before Deployment

2. **background**:
   - Deletes owner immediately
   - Dependents deleted asynchronously
   - Faster but less controlled

3. **orphan**:
   - Deletes owner but leaves dependents
   - Dependents become orphaned resources

#### PruneLast

Prunes resources after all other resources have been synced and healthy.

```yaml
syncPolicy:
  syncOptions:
    - PruneLast=true
```

**Use Cases**:

- Prevent service disruption during updates
- Ensure new resources healthy before removing old
- Blue-green deployment patterns

#### ServerSideApply

Use Kubernetes server-side apply instead of client-side apply.

```yaml
syncPolicy:
  syncOptions:
    - ServerSideApply=true
```

**Benefits**:

- Better conflict resolution
- Field ownership tracking
- Support for large resources
- Recommended for CRDs and complex resources

### Retry Strategy

Configure retry behavior for failed sync operations.

```yaml
syncPolicy:
  retry:
    limit: 5
    backoff:
      duration: 5s      # Initial duration
      factor: 2         # Multiplication factor
      maxDuration: 3m   # Maximum duration
```

**Retry Calculation Example**:

- Attempt 1: Wait 5s
- Attempt 2: Wait 10s (5s × 2)
- Attempt 3: Wait 20s (10s × 2)
- Attempt 4: Wait 40s (20s × 2)
- Attempt 5: Wait 80s (40s × 2)
- Attempt 6+: Wait 180s (maxDuration)

### Sync Waves

Sync waves control the order in which resources are applied during synchronization.

#### Basic Sync Wave Concept

Resources are deployed in order of their sync wave annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

**Wave Order**:

- Lower numbers deployed first
- Default wave: 0
- Can be negative: -5, -2, -1, 0, 1, 2, 5
- Argo CD waits for wave N to be healthy before starting wave N+1

#### Sync Wave Examples

**Wave 0: Namespace and ConfigMaps**:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "0"
data:
  DATABASE_URL: postgres://db:5432/myapp
```

**Wave 1: Database**:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "1"
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
        image: postgres:14
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  selector:
    app: database
  ports:
  - port: 5432
```

**Wave 2: Application**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application
  namespace: myapp
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
        image: myapp:v1.0.0
        envFrom:
        - configMapRef:
            name: app-config
```

**Wave 3: Ingress**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: application
  namespace: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: application
            port:
              number: 80
```

#### Multi-Tier Application with Waves

```yaml
# Wave -1: Pre-deployment jobs
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-install-check
  annotations:
    argocd.argoproj.io/sync-wave: "-1"

# Wave 0: Configurations
apiVersion: v1
kind: ConfigMap
metadata:
  name: config
  annotations:
    argocd.argoproj.io/sync-wave: "0"

# Wave 1: Infrastructure (Database, Cache)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  annotations:
    argocd.argoproj.io/sync-wave: "1"

# Wave 2: Backend services
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  annotations:
    argocd.argoproj.io/sync-wave: "2"

# Wave 3: Frontend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  annotations:
    argocd.argoproj.io/sync-wave: "3"

# Wave 4: Ingress/Routes
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress
  annotations:
    argocd.argoproj.io/sync-wave: "4"

# Wave 5: Post-deployment tasks
apiVersion: batch/v1
kind: Job
metadata:
  name: post-install-verification
  annotations:
    argocd.argoproj.io/sync-wave: "5"
```

### Resource Hooks

Hooks allow executing custom actions at specific points in the sync lifecycle.

#### Hook Types

```yaml
argocd.argoproj.io/hook: PreSync    # Before sync
argocd.argoproj.io/hook: Sync       # During sync
argocd.argoproj.io/hook: PostSync   # After sync
argocd.argoproj.io/hook: SyncFail   # If sync fails
argocd.argoproj.io/hook: Skip       # Skip this resource
```

#### Hook Deletion Policies

```yaml
argocd.argoproj.io/hook-delete-policy: HookSucceeded      # Delete after success
argocd.argoproj.io/hook-delete-policy: HookFailed         # Delete after failure
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation # Delete before creating new
```

#### PreSync Hook Example

Execute database migration before deploying application:

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
    metadata:
      name: database-migration
    spec:
      containers:
      - name: migration
        image: migrate/migrate:latest
        command:
          - migrate
          - -path=/migrations
          - -database=postgres://db:5432/myapp
          - up
      restartPolicy: Never
  backoffLimit: 3
```

#### PostSync Hook Example

Run smoke tests after deployment:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-tests
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "2"
spec:
  template:
    spec:
      containers:
      - name: test
        image: curlimages/curl:latest
        command:
          - sh
          - -c
          - |
            curl -f http://myapp.myapp.svc.cluster.local/health || exit 1
      restartPolicy: Never
  backoffLimit: 5
```

#### SyncFail Hook Example

Send notification or cleanup on failure:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sync-failure-notification
  annotations:
    argocd.argoproj.io/hook: SyncFail
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: notify
        image: curlimages/curl:latest
        command:
          - sh
          - -c
          - |
            curl -X POST https://hooks.slack.com/services/XXX \
              -H 'Content-Type: application/json' \
              -d '{"text":"Sync failed for application myapp"}'
      restartPolicy: Never
```

#### Skip Hook Example

Mark resource to skip during sync:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: manual-config
  annotations:
    argocd.argoproj.io/hook: Skip
data:
  config: manually-managed
```

#### Complex Hook Workflow

```yaml
# Pre-sync: Database backup (wave -1)
apiVersion: batch/v1
kind: Job
metadata:
  name: db-backup
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "-1"
spec:
  template:
    spec:
      containers:
      - name: backup
        image: postgres:14
        command: ["pg_dump", "-U", "postgres", "myapp", ">", "/backup/dump.sql"]
      restartPolicy: Never

---
# Pre-sync: Database migration (wave 0)
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "0"
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: migrate/migrate:latest
        command: ["migrate", "up"]
      restartPolicy: Never

---
# Post-sync: Health check (wave 1)
apiVersion: batch/v1
kind: Job
metadata:
  name: health-check
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "1"
spec:
  template:
    spec:
      containers:
      - name: check
        image: curlimages/curl:latest
        command: ["curl", "-f", "http://myapp/health"]
      restartPolicy: Never

---
# Post-sync: Cache warm-up (wave 2)
apiVersion: batch/v1
kind: Job
metadata:
  name: cache-warmup
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "2"
spec:
  template:
    spec:
      containers:
      - name: warmup
        image: redis:latest
        command: ["redis-cli", "PING"]
      restartPolicy: Never

---
# Sync fail: Rollback notification
apiVersion: batch/v1
kind: Job
metadata:
  name: failure-notification
  annotations:
    argocd.argoproj.io/hook: SyncFail
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: notify
        image: alpine:latest
        command: ["echo", "Deployment failed, rolling back..."]
      restartPolicy: Never
```

### Sync Phases

Understanding sync phases helps troubleshoot sync operations.

#### Sync Phase Sequence

1. **PreSync Phase**
   - Execute PreSync hooks
   - Run in order of sync waves
   - Must complete successfully to proceed

2. **Sync Phase**
   - Apply resources marked with Sync hook
   - Execute in order of sync waves
   - Skip resources marked with Skip hook

3. **PostSync Phase**
   - Execute PostSync hooks
   - Run in order of sync waves
   - Verify application health

4. **SyncFail Phase** (if sync fails)
   - Execute SyncFail hooks
   - Cleanup or notification tasks
   - Does not prevent failure

#### Viewing Sync Phase Status

```bash
# View current sync status
argocd app get myapp

# View sync operation details
argocd app get myapp -o yaml | grep -A 20 "operation:"

# View sync history
argocd app history myapp

# View detailed sync logs
argocd app logs myapp --kind Job --name migration-job
```

## Practice Examples

### Example 1: Progressive Deployment Strategy

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: progressive-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/app.git
    targetRevision: main
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
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

**Resources with Sync Waves**:

```yaml
# ConfigMap (Wave 0)
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  annotations:
    argocd.argoproj.io/sync-wave: "0"
data:
  APP_ENV: production

---
# Database Migration (PreSync, Wave 1)
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "1"
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: migrate:latest
        command: ["./migrate.sh"]
      restartPolicy: Never

---
# Application Deployment (Wave 2)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:v2.0.0

---
# Health Check (PostSync, Wave 3)
apiVersion: batch/v1
kind: Job
metadata:
  name: health-check
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "3"
spec:
  template:
    spec:
      containers:
      - name: check
        image: curlimages/curl:latest
        command:
          - sh
          - -c
          - "curl -f http://myapp:8080/health || exit 1"
      restartPolicy: Never
```

### Example 2: Blue-Green Deployment with Hooks

```yaml
# PreSync: Create new deployment (Blue)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: myapp:v2.0.0

---
# PostSync: Switch service to blue (Wave 2)
apiVersion: v1
kind: Service
metadata:
  name: myapp
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  selector:
    app: myapp
    version: blue  # Switch to new version
  ports:
  - port: 80
    targetPort: 8080

---
# PostSync: Verify deployment (Wave 3)
apiVersion: batch/v1
kind: Job
metadata:
  name: verify-blue
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "3"
spec:
  template:
    spec:
      containers:
      - name: verify
        image: curlimages/curl:latest
        command:
          - sh
          - -c
          - |
            for i in {1..10}; do
              curl -f http://myapp/health && exit 0
              sleep 5
            done
            exit 1
      restartPolicy: Never

---
# PostSync: Delete old deployment (Wave 4)
# This would be the old myapp-green deployment
# Handled by prune if removed from Git
```

### Example 3: CLI Sync Operations

```bash
# Manual sync with options
argocd app sync myapp \
  --prune \
  --sync-option Validate=true \
  --sync-option CreateNamespace=true

# Sync specific resources
argocd app sync myapp \
  --resource apps:Deployment:myapp \
  --resource apps:Service:myapp

# Selective sync (only out-of-sync resources)
argocd app sync myapp --apply-out-of-sync-only

# Force sync (ignore sync options and annotation)
argocd app sync myapp --force

# Sync with server-side apply
argocd app sync myapp --server-side

# Dry run to preview changes
argocd app sync myapp --dry-run --prune

# Sync and wait for completion
argocd app sync myapp --wait --timeout 300

# Terminate ongoing sync
argocd app terminate-op myapp

# Rollback to previous revision
argocd app history myapp
argocd app rollback myapp 3
```

## Study Resources

- [Sync Options Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
- [Automated Sync Policy](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [Selective Sync](https://argo-cd.readthedocs.io/en/stable/user-guide/selective_sync/)

## Key Points to Remember

- Manual sync requires explicit user action; automated sync happens automatically
- Prune deletes resources removed from Git; without prune, resources persist
- Self-heal reverts manual cluster changes within 5 seconds
- Sync options provide fine-grained control over sync behavior
- CreateNamespace=true automatically creates target namespace
- PruneLast=true prunes resources after all others are healthy
- ServerSideApply=true recommended for CRDs and large resources
- Sync waves control deployment order using annotations (lower first)
- Default sync wave is 0; can be negative
- Argo CD waits for wave N to be healthy before starting wave N+1
- Hooks execute at specific sync phases: PreSync, Sync, PostSync, SyncFail
- Hook deletion policies control when hook resources are removed
- PreSync hooks run before applying manifests (e.g., migrations)
- PostSync hooks run after successful sync (e.g., tests, warm-up)
- SyncFail hooks run when sync fails (e.g., notifications, cleanup)
- Retry strategy configures backoff for failed syncs

## Hands-On Practice

For practical exercises and labs on sync strategies, see:

- [Lab 03: Managing Application Sync](../../labs/01-argo-cd/lab-03-sync-management.md)

## Sync Wave Sequencing

Sync waves control the order of resource deployment within an application.

## Prune Resources

Prune resources automatically removes Kubernetes objects no longer defined in Git.

## Replace Strategy

Replace strategy recreates resources instead of patching for certain scenarios.

## Selective Sync

Selective sync applies changes to specific application resources only.

## Sync Retry Logic

Retry logic handles transient failures during synchronization operations.

## Sync Timeout Configuration

Timeout configuration prevents indefinite sync operations and handles stuck deployments.
