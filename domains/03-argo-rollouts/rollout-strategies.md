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

## Traffic Management

Traffic management enables fine-grained control over request routing between application versions during progressive delivery.

### Traffic Management Architecture

```
                    ┌─────────────────┐
                    │  Ingress/       │
                    │  Service Mesh   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Traffic Split  │
                    │  20% │ 80%      │
                    └────┬─────┬──────┘
                         │     │
                 ┌───────▼─┐ ┌─▼────────┐
                 │ Canary  │ │  Stable  │
                 │ Service │ │ Service  │
                 └─────────┘ └──────────┘
```

### Required Services for Traffic Management

```yaml
# Stable Service
apiVersion: v1
kind: Service
metadata:
  name: my-app-stable
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
---
# Canary Service
apiVersion: v1
kind: Service
metadata:
  name: my-app-canary
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

### NGINX Ingress Controller Integration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 5
  strategy:
    canary:
      canaryService: my-app-canary
      stableService: my-app-stable
      trafficRouting:
        nginx:
          stableIngress: my-app-ingress
      steps:
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 50
      - pause: {duration: 1m}
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
        image: my-app:v1.0.0
        ports:
        - containerPort: 8080
```

**Corresponding NGINX Ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: my-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-stable
            port:
              number: 80
```

### Service Mesh Integration (Istio)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 5
  strategy:
    canary:
      canaryService: my-app-canary
      stableService: my-app-stable
      trafficRouting:
        istio:
          virtualService:
            name: my-app-vsvc
            routes:
            - primary
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 30
      - pause: {duration: 2m}
      - setWeight: 50
      - pause: {duration: 2m}
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
        image: my-app:v1.0.0
```

**Corresponding Istio VirtualService:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-vsvc
spec:
  hosts:
  - my-app.example.com
  http:
  - name: primary
    route:
    - destination:
        host: my-app-stable
      weight: 100
    - destination:
        host: my-app-canary
      weight: 0
```

### Traffic Management Strategies

**Weight-Based Routing:**

- Percentage-based traffic distribution
- Gradual increase during canary
- Works with NGINX, Istio, ALB, Traefik

**Header-Based Routing:**

- Route specific users to canary
- A/B testing scenarios
- Beta testing groups

**Mirroring (Shadow Traffic):**

- Duplicate production traffic to canary
- Test without affecting users
- Supported by Istio

### Traffic Management Best Practices

1. **Use Separate Services**: Always use separate stable and canary services for traffic management
2. **Start Small**: Begin with 5-10% traffic to canary
3. **Monitor Metrics**: Watch error rates, latency, throughput during rollout
4. **Progressive Increase**: Use multiple small steps rather than large jumps
5. **Automated Rollback**: Configure analysis templates to automatically abort on failures
6. **Test Header Routing**: Use headers for internal testing before general availability

## Hands-On Practice

- [Lab 01: Installation and Basics](../../labs/03-argo-rollouts/lab-01-installation-basics.md) - Install controller and kubectl plugin
- [Deployment Strategies](../../labs/03-argo-rollouts/lab-02-deployment-strategies.md) - Compare and implement blue-green and canary deployments
- [Lab 04: Analysis and Metrics](../../labs/03-argo-rollouts/lab-04-analysis.md) - Automated canary analysis
- [Lab 05: Traffic Management](../../labs/03-argo-rollouts/lab-05-traffic-management.md) - Advanced traffic routing patterns
