# Traffic Management

## Overview

Traffic management is essential for progressive delivery, enabling fine-grained control over request routing between different versions of an application. Argo Rollouts integrates with various ingress controllers and service meshes to provide weighted traffic splitting, header-based routing, and mirroring capabilities. This allows safe deployment validation by exposing new versions to controlled subsets of traffic.

## Key Topics

### Ingress Controller Integration

Argo Rollouts supports multiple ingress controllers for traffic management during canary deployments.

**Traffic Management Architecture:**

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

**Required Services:**

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
    protocol: TCP
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
    protocol: TCP
  selector:
    app: my-app
```

### NGINX Ingress Controller

NGINX is the most commonly used ingress controller with Argo Rollouts.

**Basic NGINX Configuration:**

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
      - setWeight: 40
      - pause: {duration: 1m}
      - setWeight: 60
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

**How NGINX Integration Works:**

1. Argo Rollouts creates a canary Ingress automatically
2. Canary Ingress has annotations:
   - `nginx.ingress.kubernetes.io/canary: "true"`
   - `nginx.ingress.kubernetes.io/canary-weight: "<weight>"`
3. NGINX routes traffic based on weight
4. As rollout progresses, weight is updated
5. At 100% weight, canary becomes stable

**NGINX with Custom Annotations:**

```yaml
trafficRouting:
  nginx:
    stableIngress: my-app-ingress
    annotationPrefix: nginx.ingress.kubernetes.io
    additionalIngressAnnotations:
      canary-by-header: X-Canary
      canary-by-header-value: "always"
```

**NGINX with Multiple Ingresses:**

```yaml
trafficRouting:
  nginx:
    stableIngresses:
    - my-app-ingress-1
    - my-app-ingress-2
```

### ALB Ingress Controller

AWS Application Load Balancer (ALB) integration for EKS clusters.

**ALB Configuration:**

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
        alb:
          ingress: my-app-ingress
          servicePort: 80
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
        ports:
        - containerPort: 8080
```

**ALB Ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
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

**How ALB Integration Works:**

1. ALB ingress controller creates target groups
2. Argo Rollouts modifies ingress actions
3. ALB forward action distributes traffic by weight
4. Traffic split happens at ALB level
5. No additional canary ingress created

**ALB with Root Service:**

```yaml
trafficRouting:
  alb:
    ingress: my-app-ingress
    rootService: my-app-root
    servicePort: 80
```

### Istio Service Mesh

Istio provides advanced traffic management capabilities through VirtualServices.

**Istio Configuration:**

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
      - pause: {duration: 1m}
      - setWeight: 30
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

**Istio VirtualService:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-vsvc
spec:
  hosts:
  - myapp.example.com
  http:
  - name: primary
    route:
    - destination:
        host: my-app-stable
        port:
          number: 80
      weight: 100
    - destination:
        host: my-app-canary
        port:
          number: 80
      weight: 0
```

**How Istio Integration Works:**

1. Argo Rollouts modifies VirtualService weights
2. Istio Envoy proxies route traffic based on weights
3. Traffic split happens at sidecar proxy level
4. Supports advanced routing (headers, URI, etc.)
5. Works with Istio's observability features

**Istio with Multiple Routes:**

```yaml
trafficRouting:
  istio:
    virtualServices:
    - name: my-app-vsvc-primary
      routes:
      - primary
    - name: my-app-vsvc-secondary
      routes:
      - secondary
```

**Istio with DestinationRule:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app-destrule
spec:
  host: my-app-stable
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
  subsets:
  - name: stable
    labels:
      app: my-app
  - name: canary
    labels:
      app: my-app
```

### Service Mesh Support

Beyond Istio, Argo Rollouts supports other service meshes.

#### Linkerd

```yaml
trafficRouting:
  smi:
    rootService: my-app-root
    trafficSplitName: my-app-trafficsplit
```

**SMI TrafficSplit:**

```yaml
apiVersion: split.smi-spec.io/v1alpha2
kind: TrafficSplit
metadata:
  name: my-app-trafficsplit
spec:
  service: my-app-root
  backends:
  - service: my-app-stable
    weight: 100
  - service: my-app-canary
    weight: 0
```

#### AWS App Mesh

```yaml
trafficRouting:
  appMesh:
    virtualService:
      name: my-app
    virtualNodeGroup:
      canaryVirtualNodeRef:
        name: my-app-canary
      stableVirtualNodeRef:
        name: my-app-stable
```

**App Mesh VirtualService:**

```yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  name: my-app
spec:
  provider:
    virtualRouter:
      virtualRouterRef:
        name: my-app-router
```

#### Traefik

```yaml
trafficRouting:
  traefik:
    weightedTrafficServiceName: my-app-weighted
```

**Traefik Service:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-weighted
spec:
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

### Traffic Routing Rules

Advanced routing capabilities beyond simple weight-based splitting.

**Header-Based Routing (NGINX):**

```yaml
trafficRouting:
  nginx:
    stableIngress: my-app-ingress
    additionalIngressAnnotations:
      canary-by-header: X-Canary
      canary-by-header-value: "internal"
```

Users with `X-Canary: internal` header always routed to canary.

**Cookie-Based Routing (NGINX):**

```yaml
trafficRouting:
  nginx:
    stableIngress: my-app-ingress
    additionalIngressAnnotations:
      canary-by-cookie: "beta-user"
```

Users with `beta-user` cookie routed to canary.

**Header-Based Routing (Istio):**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-vsvc
spec:
  hosts:
  - myapp.example.com
  http:
  - match:
    - headers:
        x-version:
          exact: "canary"
    route:
    - destination:
        host: my-app-canary
  - name: primary
    route:
    - destination:
        host: my-app-stable
      weight: 80
    - destination:
        host: my-app-canary
      weight: 20
```

**URI-Based Routing (Istio):**

```yaml
http:
- match:
  - uri:
      prefix: "/v2"
  route:
  - destination:
      host: my-app-canary
- name: primary
  route:
  - destination:
      host: my-app-stable
```

**Geographic Routing:**

With Istio locality-based routing:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app-destrule
spec:
  host: my-app-stable
  trafficPolicy:
    loadBalancer:
      localityLbSetting:
        enabled: true
        distribute:
        - from: us-west/zone1/*
          to:
            "us-west/zone1/*": 80
            "us-west/zone2/*": 20
```

### Traffic Mirroring

Duplicate traffic to canary for testing without affecting responses.

**Istio Traffic Mirroring:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-vsvc
spec:
  hosts:
  - myapp.example.com
  http:
  - route:
    - destination:
        host: my-app-stable
      weight: 100
    mirror:
      host: my-app-canary
    mirrorPercentage:
      value: 100
```

**Benefits:**

- Test canary with production traffic
- No impact on user responses
- Validate performance and errors
- Safe pre-validation before traffic split

## Practice Examples

### Example 1: NGINX Ingress with Canary

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: nginx-app
spec:
  replicas: 4
  strategy:
    canary:
      canaryService: nginx-app-canary
      stableService: nginx-app-stable
      trafficRouting:
        nginx:
          stableIngress: nginx-app-ingress
      steps:
      - setWeight: 20
      - pause: {duration: 30s}
      - setWeight: 50
      - pause: {duration: 30s}
      - setWeight: 80
      - pause: {duration: 30s}
  selector:
    matchLabels:
      app: nginx-app
  template:
    metadata:
      labels:
        app: nginx-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-app-stable
spec:
  ports:
  - port: 80
  selector:
    app: nginx-app
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-app-canary
spec:
  ports:
  - port: 80
  selector:
    app: nginx-app
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-app-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: nginx-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-app-stable
            port:
              number: 80
```

### Example 2: Istio with Analysis

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: istio-app
spec:
  replicas: 5
  strategy:
    canary:
      canaryService: istio-app-canary
      stableService: istio-app-stable
      trafficRouting:
        istio:
          virtualService:
            name: istio-app-vsvc
            routes:
            - primary
      analysis:
        templates:
        - templateName: istio-success-rate
        startingStep: 1
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 30
      - pause: {duration: 2m}
      - setWeight: 50
      - pause: {duration: 2m}
  selector:
    matchLabels:
      app: istio-app
  template:
    metadata:
      labels:
        app: istio-app
        version: v2
    spec:
      containers:
      - name: app
        image: myapp:v2.0.0
        ports:
        - containerPort: 8080
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: istio-app-vsvc
spec:
  hosts:
  - istio-app.example.com
  http:
  - name: primary
    route:
    - destination:
        host: istio-app-stable
      weight: 100
    - destination:
        host: istio-app-canary
      weight: 0
```

## Study Resources

- [Traffic Management Overview](https://argoproj.github.io/argo-rollouts/features/traffic-management/) - Official documentation
- [NGINX Integration](https://argoproj.github.io/argo-rollouts/features/traffic-management/nginx/) - NGINX setup guide
- [Istio Integration](https://argoproj.github.io/argo-rollouts/features/traffic-management/istio/) - Istio configuration
- [ALB Integration](https://argoproj.github.io/argo-rollouts/features/traffic-management/alb/) - AWS ALB setup
- [SMI Integration](https://argoproj.github.io/argo-rollouts/features/traffic-management/smi/) - Service Mesh Interface

## Key Points to Remember

- Traffic management requires ingress controller or service mesh
- Two services needed: stable and canary
- NGINX creates automatic canary ingress with weight annotations
- ALB modifies existing ingress forward actions
- Istio updates VirtualService destination weights
- SMI (Linkerd) uses TrafficSplit resources
- Header-based and cookie-based routing available with NGINX
- Advanced routing rules (URI, headers, locality) with Istio
- Traffic mirroring allows safe testing with production traffic
- Canary service selector points to canary pods
- Stable service selector points to stable pods
- Controller automatically updates service selectors
- Multiple ingresses can be managed simultaneously
- Traffic split happens at load balancer/proxy level, not pod level

## Hands-On Practice

- [Lab 05: Traffic Management](../../labs/03-argo-rollouts/lab-05-traffic-management.md) - Configure NGINX ingress integration for weighted traffic splitting and advanced routing rules
