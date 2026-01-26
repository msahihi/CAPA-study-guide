# Blue-Green Deployments

## Overview

Blue-Green deployment is a progressive delivery strategy that runs two identical production environments (Blue and Green). At any time, one environment serves live production traffic (active) while the other is idle or serves preview traffic. When deploying a new version, it goes to the idle environment, and after validation, traffic is switched instantly from the old version to the new version.

## Key Topics

### Blue-Green Strategy Configuration

The Blue-Green strategy in Argo Rollouts requires two Kubernetes Services: one for active (production) traffic and one for preview (testing) traffic.

**Basic Blue-Green Rollout:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app-bluegreen
spec:
  replicas: 3
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
        image: my-app:v1.0.0
        ports:
        - containerPort: 8080
  strategy:
    blueGreen:
      activeService: my-app-active
      previewService: my-app-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
```

**Blue-Green Strategy Fields:**

- `activeService`: Service receiving production traffic
- `previewService`: Service receiving preview/testing traffic
- `autoPromotionEnabled`: Whether to automatically promote after validation
- `scaleDownDelaySeconds`: Delay before scaling down old ReplicaSet
- `autoPromotionSeconds`: Time to wait before auto-promotion (if enabled)
- `previewReplicaCount`: Number of preview replicas (defaults to spec.replicas)
- `scaleDownDelayRevisionLimit`: Number of old versions to keep

### Active and Preview Services

Two services are required for Blue-Green deployments to work properly.

**Active Service (Production Traffic):**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-active
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: my-app
```

**Preview Service (Testing Traffic):**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-preview
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: my-app
```

**How Services Work:**

1. Argo Rollouts controller automatically updates service selectors
2. Active service always points to the stable ReplicaSet
3. Preview service points to the new ReplicaSet during rollout
4. After promotion, preview service is updated to point to new stable version
5. Old ReplicaSet is scaled down after scaleDownDelaySeconds

**Ingress Configuration:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-active  # Production traffic
            port:
              number: 80
  - host: preview.myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-preview  # Preview traffic
            port:
              number: 80
```

### Promotion Process

Promotion is the process of switching production traffic from the old version to the new version.

**Manual Promotion:**

```bash
# Check rollout status
kubectl argo rollouts get rollout my-app-bluegreen

# Test preview environment
curl https://preview.myapp.example.com

# Promote when ready
kubectl argo rollouts promote my-app-bluegreen
```

**Automatic Promotion:**

```yaml
strategy:
  blueGreen:
    activeService: my-app-active
    previewService: my-app-preview
    autoPromotionEnabled: true
    autoPromotionSeconds: 300  # Wait 5 minutes before auto-promoting
```

**Promotion Flow:**

1. New version deployed to preview environment
2. Preview ReplicaSet scaled to desired replicas
3. Preview service updated to point to new version
4. Testing/validation performed on preview
5. Promotion triggered (manual or automatic)
6. Active service updated to point to new version
7. Old version scaled down after scaleDownDelaySeconds

**Pre-Promotion Analysis:**

```yaml
strategy:
  blueGreen:
    activeService: my-app-active
    previewService: my-app-preview
    autoPromotionEnabled: false
    prePromotionAnalysis:
      templates:
      - templateName: smoke-tests
      args:
      - name: service-name
        value: my-app-preview
```

### Rollback Procedures

Blue-Green deployments provide instant rollback capabilities by switching services back to the previous stable version.

**Manual Rollback (Abort):**

```bash
# Abort current rollout and revert to stable
kubectl argo rollouts abort my-app-bluegreen

# This immediately:
# 1. Switches active service back to old version
# 2. Scales down preview ReplicaSet
# 3. Marks rollout as aborted
```

**Rollback to Previous Revision:**

```bash
# List revision history
kubectl argo rollouts history rollout my-app-bluegreen

# Rollback to previous version
kubectl argo rollouts undo my-app-bluegreen

# Rollback to specific revision
kubectl argo rollouts undo my-app-bluegreen --to-revision=3
```

**Rollback with kubectl:**

```bash
# Using standard kubectl rollback
kubectl rollout undo rollout/my-app-bluegreen

# Check rollout status
kubectl rollout status rollout/my-app-bluegreen
```

**Emergency Rollback Strategy:**

For critical production issues:

1. Immediately abort the rollout
2. Verify active service points to stable version
3. Check application health
4. Investigate issue in preview environment
5. Fix issue before attempting new deployment

**Scale Down Configuration:**

```yaml
strategy:
  blueGreen:
    activeService: my-app-active
    previewService: my-app-preview
    scaleDownDelaySeconds: 600  # Keep old version for 10 minutes
    scaleDownDelayRevisionLimit: 2  # Keep last 2 old versions
```

Benefits:

- `scaleDownDelaySeconds`: Provides window for quick rollback
- `scaleDownDelayRevisionLimit`: Prevents keeping too many old versions
- Allows fast switching back if issues discovered immediately after promotion

### Advanced Blue-Green Configurations

**Anti-Affinity for Blue-Green:**

```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - my-app
              topologyKey: kubernetes.io/hostname
```

**Preview Replica Count:**

```yaml
strategy:
  blueGreen:
    activeService: my-app-active
    previewService: my-app-preview
    previewReplicaCount: 1  # Use fewer replicas for preview
    autoPromotionEnabled: false
```

**Post-Promotion Analysis:**

```yaml
strategy:
  blueGreen:
    activeService: my-app-active
    previewService: my-app-preview
    autoPromotionEnabled: false
    postPromotionAnalysis:
      templates:
      - templateName: post-promotion-check
      args:
      - name: service-name
        value: my-app-active
```

## Practice Examples

### Example 1: Complete Blue-Green Setup

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-active
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-preview
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: nginx
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: nginx-rollout
spec:
  replicas: 3
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

### Example 2: Blue-Green with Auto-Promotion

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-rollout
spec:
  replicas: 5
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: api:v1.0.0
        ports:
        - containerPort: 8080
  strategy:
    blueGreen:
      activeService: api-active
      previewService: api-preview
      autoPromotionEnabled: true
      autoPromotionSeconds: 600  # Auto-promote after 10 minutes
      scaleDownDelaySeconds: 300
```

## Study Resources

- [Blue-Green Deployment Strategy](https://argoproj.github.io/argo-rollouts/features/bluegreen/) - Official documentation
- [Service Mesh Integration](https://argoproj.github.io/argo-rollouts/features/traffic-management/) - Advanced traffic management
- [Martin Fowler: Blue-Green Deployment](https://martinfowler.com/bliki/BlueGreenDeployment.html) - Conceptual overview

## Key Points to Remember

- Blue-Green requires two services: active (production) and preview (testing)
- Argo Rollouts controller automatically manages service selector updates
- Promotion switches all traffic instantly from old to new version
- AutoPromotionEnabled controls whether promotion happens automatically
- ScaleDownDelaySeconds provides a rollback window before removing old version
- Abort command immediately reverts to stable version
- Preview service allows testing new version before production promotion
- Blue-Green uses more resources as it runs two full environments
- Zero-downtime deployments with instant rollback capability
- Ideal for applications requiring thorough validation before release

## Hands-On Practice

- [Lab 02: Blue-Green Deployments](../../labs/03-argo-rollouts/lab-02-blue-green.md) - Implement Blue-Green deployments with manual and automatic promotion
