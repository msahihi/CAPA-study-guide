# Rollout Strategies Overview

## Overview

Argo Rollouts extends Kubernetes with advanced deployment capabilities through Custom Resource Definitions (CRDs). It provides declarative, GitOps-friendly progressive delivery strategies that go beyond the basic rolling update provided by standard Kubernetes Deployments.

## Key Topics

### Rollout Resource

The Rollout resource is the core CRD that replaces the standard Kubernetes Deployment with advanced deployment strategies.

**Basic Rollout Structure:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 5
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-app:v1
        ports:
        - containerPort: 8080
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 50
      - pause: {duration: 1m}
```

**Key Fields:**

- `replicas`: Number of desired pods
- `revisionHistoryLimit`: Number of old ReplicaSets to retain
- `selector`: Pod selector (must match template labels)
- `template`: Pod template specification
- `strategy`: Deployment strategy configuration (canary or blueGreen)

### Rollout vs Deployment Comparison

| Feature | Deployment | Rollout |
|---------|-----------|---------|
| Update Strategy | Rolling update only | Blue-Green, Canary, Progressive |
| Traffic Control | No | Yes (with ingress/service mesh) |
| Analysis | No | Yes (metrics-based) |
| Automated Rollback | No | Yes (based on metrics) |
| Manual Promotion | No | Yes |
| Pause/Resume | No | Yes |
| Weighted Traffic | No | Yes |
| Preview Environments | No | Yes (Blue-Green) |

**When to Use Rollout:**

- Need gradual traffic shifting
- Require metrics-based validation
- Want zero-downtime deployments with instant rollback
- Need preview/staging environment
- Require manual approval gates
- Want automated progressive delivery

**When to Use Deployment:**

- Simple applications with low risk
- No need for traffic control
- Basic rolling updates sufficient
- Simpler setup preferred

### Rollout Strategy Types

#### Canary Strategy

Gradually shifts traffic from old version to new version while monitoring metrics.

```yaml
strategy:
  canary:
    steps:
    - setWeight: 10
    - pause: {duration: 2m}
    - setWeight: 30
    - pause: {duration: 2m}
    - setWeight: 60
    - pause: {duration: 2m}
```

**Characteristics:**

- Progressive traffic increase
- Multiple validation stages
- Automated or manual progression
- Metrics-based analysis
- Quick rollback capability

#### Blue-Green Strategy

Runs two identical environments (blue=current, green=new) and switches traffic all at once.

```yaml
strategy:
  blueGreen:
    activeService: my-app-active
    previewService: my-app-preview
    autoPromotionEnabled: false
```

**Characteristics:**

- Full environment duplication
- Instant traffic switch
- Easy rollback
- Preview testing capability
- Higher resource usage

### Rollout Status and Phases

Understanding rollout status is critical for monitoring and troubleshooting.

**Status Phases:**

1. **Healthy**: Rollout is running and healthy
2. **Progressing**: Rollout is currently transitioning
3. **Degraded**: Rollout is not healthy
4. **Paused**: Rollout is paused (manual or automatic)
5. **Unknown**: Status cannot be determined

**Check Rollout Status:**

```bash
# Get rollout status
kubectl argo rollouts get rollout my-app

# Watch rollout progress
kubectl argo rollouts get rollout my-app --watch

# List all rollouts
kubectl argo rollouts list rollouts

# Get rollout status in JSON
kubectl get rollout my-app -o json | jq .status
```

**Status Fields:**

```yaml
status:
  replicas: 5
  updatedReplicas: 2
  readyReplicas: 5
  availableReplicas: 5
  currentPodHash: "7f9d8c8b9f"
  stableRS: "my-app-7f9d8c8b9f"
  currentStepIndex: 2
  currentStepHash: "abc123"
  conditions:
  - type: Progressing
    status: "True"
    reason: ReplicaSetUpdated
  - type: Available
    status: "True"
    reason: MinimumReplicasAvailable
  phase: Healthy
```

**Important Status Fields:**

- `currentStepIndex`: Current canary step being executed
- `currentPodHash`: Hash of the current pod template
- `stableRS`: ReplicaSet that is stable/active
- `phase`: Overall rollout health status
- `conditions`: Detailed condition information

### Rollout Operations

**Create Rollout:**

```bash
kubectl apply -f rollout.yaml
```

**Promote Rollout:**

```bash
# Manually promote to next step
kubectl argo rollouts promote my-app

# Skip all remaining steps and promote fully
kubectl argo rollouts promote my-app --full
```

**Abort Rollout:**

```bash
# Abort current rollout and revert to stable
kubectl argo rollouts abort my-app
```

**Pause/Resume Rollout:**

```bash
# Pause rollout
kubectl argo rollouts pause my-app

# Resume paused rollout
kubectl argo rollouts resume my-app
```

**Restart Rollout:**

```bash
# Restart all pods
kubectl argo rollouts restart my-app
```

**Rollback:**

```bash
# Rollback to previous version
kubectl argo rollouts undo my-app

# Rollback to specific revision
kubectl argo rollouts undo my-app --to-revision=3
```

## Practice Examples

### Example 1: Basic Canary Rollout

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: nginx-rollout
spec:
  replicas: 4
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
        ports:
        - containerPort: 80
  strategy:
    canary:
      steps:
      - setWeight: 25
      - pause: {duration: 1m}
      - setWeight: 50
      - pause: {duration: 1m}
      - setWeight: 75
      - pause: {duration: 1m}
```

### Example 2: Blue-Green Rollout

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: nginx-rollout
spec:
  replicas: 4
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
        ports:
        - containerPort: 80
  strategy:
    blueGreen:
      activeService: nginx-active
      previewService: nginx-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
```

## Study Resources

- [Argo Rollouts Concepts](https://argoproj.github.io/argo-rollouts/concepts/) - Core concepts documentation
- [Rollout Specification](https://argoproj.github.io/argo-rollouts/features/specification/) - Complete spec reference
- [kubectl Plugin Installation](https://argoproj.github.io/argo-rollouts/installation/#kubectl-plugin-installation) - CLI tool setup
- [Progressive Delivery FAQ](https://argoproj.github.io/argo-rollouts/FAQ/) - Common questions

## Key Points to Remember

- Rollouts are custom resources that extend Kubernetes Deployments with advanced strategies
- Blue-Green provides instant switching between versions with full environments
- Canary provides gradual traffic shifting with multiple validation stages
- Rollout status phases include Healthy, Progressing, Degraded, Paused, and Unknown
- kubectl Argo Rollouts plugin provides convenient commands for managing rollouts
- Rollouts maintain multiple ReplicaSets for stable and preview versions
- Manual promotion gates allow human verification before proceeding
- Rollouts can be paused, resumed, promoted, or aborted at any time
- Rollback capability allows quick reversion to previous stable versions

## Hands-On Practice

- [Lab 01: Installation and Basics](../../labs/03-argo-rollouts/lab-01-installation-basics.md) - Install controller and kubectl plugin
- [Lab 02: Blue-Green Deployments](../../labs/03-argo-rollouts/lab-02-blue-green.md) - Create and manage basic rollouts with different strategies
- [Lab 03: Canary Deployments](../../labs/03-argo-rollouts/lab-03-canary.md) - Implement canary deployments
