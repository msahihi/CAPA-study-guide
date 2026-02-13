# Canary Deployments

## Overview

Canary deployment is a progressive delivery strategy that gradually shifts traffic from an old version to a new version while monitoring metrics and KPIs. The name comes from the "canary in a coal mine" concept - a small percentage of users are exposed to the new version first to detect problems before full rollout. This approach minimizes risk and allows for quick rollback if issues are detected.

## Key Topics

### Canary Strategy Configuration

Canary deployments use a step-based approach to gradually increase traffic to the new version.

**Basic Canary Rollout:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app-canary
spec:
  replicas: 10
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
        image: my-app:v2.0.0
        ports:
        - containerPort: 8080
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 20
      - pause: {duration: 2m}
      - setWeight: 40
      - pause: {duration: 2m}
      - setWeight: 60
      - pause: {duration: 2m}
      - setWeight: 80
      - pause: {duration: 2m}
```

**Canary Strategy Fields:**

- `steps`: Ordered list of canary deployment steps
- `maxSurge`: Maximum number of pods above desired count (default: 25%)
- `maxUnavailable`: Maximum number of pods unavailable during update (default: 25%)
- `trafficRouting`: Configuration for traffic management
- `analysis`: Analysis configuration for automated validation

### Traffic Splitting

Traffic splitting is the core mechanism of canary deployments, controlling what percentage of requests go to the new version.

**Weight-Based Traffic Splitting:**

```yaml
strategy:
  canary:
    trafficRouting:
      nginx:
        stableIngress: my-app-stable
        annotationPrefix: nginx.ingress.kubernetes.io
    steps:
    - setWeight: 10      # 10% to canary, 90% to stable
    - pause: {duration: 5m}
    - setWeight: 25      # 25% to canary, 75% to stable
    - pause: {duration: 5m}
    - setWeight: 50      # 50% to canary, 50% to stable
    - pause: {duration: 5m}
    - setWeight: 75      # 75% to canary, 25% to stable
    - pause: {duration: 5m}
    # At end, 100% goes to canary (becomes new stable)
```

**How Traffic Splitting Works:**

1. `setWeight: 10` - Routes 10% of traffic to canary version
2. Load balancer/ingress controller distributes traffic accordingly
3. Both versions run simultaneously
4. As weight increases, more traffic shifts to canary
5. After final step, canary becomes the new stable version

**Traffic Routing with NGINX Ingress:**

```yaml
strategy:
  canary:
    trafficRouting:
      nginx:
        stableIngress: my-app-ingress
        annotationPrefix: nginx.ingress.kubernetes.io
    steps:
    - setWeight: 20
    - pause: {}  # Manual pause
```

**Corresponding Ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: myapp.example.com
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

**Canary Ingress (Created Automatically):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress-canary
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "20"
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-canary
            port:
              number: 80
```

### Canary Steps and Pause Duration

Canary steps define the progression of the deployment. Each step can set traffic weight, pause, or run analysis.

**Step Types:**

1. **setWeight** - Set traffic percentage to canary
2. **pause** - Pause rollout (manual or duration-based)
3. **analysis** - Run analysis before proceeding
4. **experiment** - Run A/B testing experiment
5. **setCanaryScale** - Set canary replica count

**Pause Options:**

```yaml
# Duration-based pause
- pause: {duration: 10m}

# Indefinite pause (requires manual promotion)
- pause: {}

# Pause until specified time
- pause: {duration: 1h}
```

**Example with Multiple Step Types:**

```yaml
strategy:
  canary:
    steps:
    # Initial canary
    - setWeight: 10
    - pause: {duration: 5m}

    # Analysis before increasing
    - analysis:
        templates:
        - templateName: success-rate

    # Increase weight
    - setWeight: 25
    - pause: {duration: 10m}

    # Manual verification gate
    - pause: {}  # Requires manual promotion

    # Continue rollout
    - setWeight: 50
    - pause: {duration: 5m}

    # Final analysis
    - analysis:
        templates:
        - templateName: performance-check

    # Full rollout
    - setWeight: 75
    - pause: {duration: 5m}
```

**Dynamic Step Timing:**

```yaml
strategy:
  canary:
    steps:
    - setWeight: 20
    - pause: {duration: 30s}
    - setWeight: 40
    - pause: {duration: 1m}
    - setWeight: 60
    - pause: {duration: 2m}
    - setWeight: 80
    - pause: {duration: 5m}
```

Pattern: Increase pause duration as weight increases (more users affected).

### Automated Promotion

Automated promotion advances the canary deployment automatically based on analysis results.

**Analysis-Based Promotion:**

```yaml
strategy:
  canary:
    analysis:
      templates:
      - templateName: success-rate
      - templateName: latency
      startingStep: 2   # Start analysis at step 2
      args:
      - name: service-name
        value: my-app-canary
    steps:
    - setWeight: 10
    - pause: {duration: 5m}
    - setWeight: 20      # Analysis starts here (step 2)
    - pause: {duration: 5m}
    - setWeight: 40
    - pause: {duration: 5m}
```

**Background Analysis:**

```yaml
strategy:
  canary:
    analysis:
      templates:
      - templateName: continuous-monitoring
      startingStep: 1
      args:
      - name: service-name
        value: my-app-canary
    steps:
    - setWeight: 20
    - pause: {duration: 10m}
    - setWeight: 50
    - pause: {duration: 10m}
```

**Analysis runs in background during entire canary process.**

**Automatic Rollback on Failure:**

```yaml
strategy:
  canary:
    analysis:
      templates:
      - templateName: error-rate
      args:
      - name: service-name
        value: my-app-canary
    steps:
    - setWeight: 25
    - pause: {duration: 5m}
    # If error-rate analysis fails, automatic rollback occurs
```

**Step-Specific Analysis:**

```yaml
strategy:
  canary:
    steps:
    - setWeight: 10
    - pause: {duration: 5m}

    # Run analysis before continuing
    - analysis:
        templates:
        - templateName: smoke-tests
        args:
        - name: service-name
          value: my-app-canary

    # Only proceeds if analysis succeeds
    - setWeight: 50
    - pause: {duration: 10m}
```

**Auto-Promotion Configuration:**

```yaml
strategy:
  canary:
    # Analysis determines if rollout continues
    analysis:
      templates:
      - templateName: success-rate
      - templateName: error-rate
      - templateName: latency-p95

    # Automatically promote if all analysis passes
    steps:
    - setWeight: 20
    - pause: {duration: 5m}
    - analysis:
        templates:
        - templateName: comprehensive-check
    - setWeight: 50
    - pause: {duration: 5m}
```

### Canary with ReplicaSet Management

**MaxSurge and MaxUnavailable:**

```yaml
strategy:
  canary:
    maxSurge: "25%"        # Max 25% extra pods during rollout
    maxUnavailable: 0      # No pods can be unavailable
    steps:
    - setWeight: 25
    - pause: {duration: 5m}
    - setWeight: 50
    - pause: {duration: 5m}
```

**SetCanaryScale:**

```yaml
strategy:
  canary:
    steps:
    # Start with 1 canary pod regardless of weight
    - setCanaryScale:
        replicas: 1
    - pause: {duration: 5m}

    # Set specific percentage
    - setCanaryScale:
        weight: 25
    - pause: {duration: 5m}

    # Back to weight-based scaling
    - setWeight: 50
    - pause: {duration: 5m}
```

## Practice Examples

### Example 1: Basic Canary with Progressive Steps

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: app-canary
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v2
        ports:
        - containerPort: 8080
  strategy:
    canary:
      maxSurge: 1
      maxUnavailable: 0
      steps:
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 40
      - pause: {duration: 2m}
      - setWeight: 60
      - pause: {duration: 2m}
      - setWeight: 80
      - pause: {duration: 1m}
```

### Example 2: Canary with NGINX Traffic Management

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: nginx-canary
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
        image: nginx:1.20
        ports:
        - containerPort: 80
  strategy:
    canary:
      canaryService: nginx-canary
      stableService: nginx-stable
      trafficRouting:
        nginx:
          stableIngress: nginx-ingress
      steps:
      - setWeight: 10
      - pause: {duration: 30s}
      - setWeight: 25
      - pause: {duration: 30s}
      - setWeight: 50
      - pause: {}  # Manual gate
```

### Example 3: Canary with Analysis

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-canary
spec:
  replicas: 10
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
        image: api:v3.0.0
        ports:
        - containerPort: 8080
  strategy:
    canary:
      canaryService: api-canary
      stableService: api-stable
      analysis:
        templates:
        - templateName: success-rate
        - templateName: latency
        startingStep: 1
        args:
        - name: service-name
          value: api-canary
      steps:
      - setWeight: 20
      - pause: {duration: 5m}
      - setWeight: 40
      - pause: {duration: 5m}
      - setWeight: 60
      - pause: {duration: 5m}
```

## Study Resources

- [Canary Deployment Strategy](https://argoproj.github.io/argo-rollouts/features/canary/) - Official documentation
- [Traffic Management](https://argoproj.github.io/argo-rollouts/features/traffic-management/) - Traffic routing configuration

## Key Points to Remember

- Canary deployments gradually shift traffic from old to new version
- Traffic weight controls percentage of requests to canary version
- Steps define the progression: setWeight, pause, analysis
- Pause duration can be time-based or indefinite (manual gate)
- Traffic routing requires ingress controller or service mesh integration
- Automated promotion based on analysis results
- Analysis failures trigger automatic rollback
- MaxSurge and MaxUnavailable control pod scaling during rollout
- SetCanaryScale provides fine-grained replica control
- Canary uses less resources than Blue-Green (no full duplication)
- Suitable for gradual validation with real user traffic
- Multiple validation gates reduce deployment risk

## Hands-On Practice

- [Lab 03: Canary Deployments](../../labs/03-argo-rollouts/lab-02-deployment-strategies.md) - Create basic canary rollouts
- [Lab 04: Analysis and Metrics](../../labs/03-argo-rollouts/lab-04-analysis.md) - Implement canary with automated metrics-based validation
- [Lab 05: Traffic Management](../../labs/03-argo-rollouts/lab-05-traffic-management.md) - Configure traffic routing with NGINX ingress
