# Lab 02: Deployment Strategies - Blue-Green and Canary

**Duration**: 60 minutes

**Difficulty**: Intermediate to Advanced

## Objectives

By the end of this lab, you will be able to:

- Understand the differences between blue-green and canary deployment strategies
- Implement blue-green deployments with instant traffic switching
- Implement canary deployments with progressive traffic shifting
- Choose the appropriate strategy based on requirements
- Perform promotion and rollback operations for both strategies
- Configure auto-promotion and validation windows

## Prerequisites

- Completed [Lab 01: Installation and Basics](lab-01-installation-basics.md)
- Argo Rollouts controller installed and running
- kubectl Argo Rollouts plugin installed
- Access to a Kubernetes cluster
- Basic understanding of Kubernetes Services

## Strategy Comparison

| Aspect | Blue-Green | Canary |
|--------|-----------|--------|
| **Traffic Switch** | Instant (0% → 100%) | Gradual (0% → 10% → 25% → 50% → 100%) |
| **Risk** | Higher (all traffic switches at once) | Lower (gradual rollout with monitoring) |
| **Rollback** | Instant (switch back to blue) | Abort and revert to stable |
| **Testing** | Full testing in preview environment | Progressive validation with real traffic |
| **Resource Usage** | 2x resources during deployment | 1-2x resources (depends on canary weight) |
| **Use Case** | Low-risk updates, feature flags | High-risk updates, performance testing |
| **Validation** | Pre-production testing | Production traffic validation |

## Part 1: Blue-Green Deployment

### Step 1: Create Blue-Green Environment

```bash
# Create namespace
kubectl create namespace bluegreen-demo
kubectl config set-context --current --namespace=bluegreen-demo

# Create active and preview services
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-active
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: bluegreen-demo
---
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-preview
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: bluegreen-demo
YAML

# Verify services
kubectl get services
```

### Step 2: Deploy Blue-Green Rollout

```bash
cat <<YAML | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: bluegreen-demo
spec:
  replicas: 3
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: bluegreen-demo
  template:
    metadata:
      labels:
        app: bluegreen-demo
    spec:
      containers:
      - name: app
        image: msahihi/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    blueGreen:
      activeService: bluegreen-active
      previewService: bluegreen-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
YAML

# Watch rollout
kubectl argo rollouts get rollout bluegreen-demo --watch
```

### Step 3: Test Active Service

```bash
# Create test pod
kubectl run test-pod --image=curlimages/curl:latest --restart=Never --rm -it -- sh

# In test pod, test active service
curl -s http://bluegreen-active | grep color
# Should show: "color": "blue"
```

### Step 4: Deploy New Version to Preview

```bash
# Update to yellow version
kubectl argo rollouts set image bluegreen-demo app=msahihi/rollouts-demo:yellow

# Watch status (will pause for promotion)
kubectl argo rollouts get rollout bluegreen-demo --watch
```

### Step 5: Test Preview and Promote

```bash
# Test preview service (from test pod)
curl -s http://bluegreen-preview | grep color
# Should show: "color": "yellow"

# Test active (should still be blue)
curl -s http://bluegreen-active | grep color
# Should show: "color": "blue"

# Promote to active
kubectl argo rollouts promote bluegreen-demo

# Verify active service now shows yellow
curl -s http://bluegreen-active | grep color
# Should show: "color": "yellow"
```

### Step 6: Rollback Scenario

```bash
# Deploy red version
kubectl argo rollouts set image bluegreen-demo app=msahihi/rollouts-demo:red

# Test preview
curl -s http://bluegreen-preview | grep color
# Shows "red"

# Abort rollout (rollback)
kubectl argo rollouts abort bluegreen-demo

# Verify active still shows yellow
curl -s http://bluegreen-active | grep color
# Should show: "color": "yellow"
```

## Part 2: Canary Deployment

### Step 7: Create Canary Environment

```bash
# Create namespace
kubectl create namespace canary-demo
kubectl config set-context --current --namespace=canary-demo

# Create service
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: canary-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: canary-demo
YAML
```

### Step 8: Deploy Canary Rollout

```bash
cat <<YAML | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-demo
spec:
  replicas: 10
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: canary-demo
  template:
    metadata:
      labels:
        app: canary-demo
    spec:
      containers:
      - name: app
        image: msahihi/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 30s}
      - setWeight: 25
      - pause: {duration: 30s}
      - setWeight: 50
      - pause: {duration: 30s}
      - setWeight: 75
      - pause: {duration: 30s}
YAML

# Watch rollout
kubectl argo rollouts get rollout canary-demo --watch
```

### Step 9: Progressive Canary Rollout

```bash
# Create test pod in canary namespace
kubectl run test-pod --image=curlimages/curl:latest --restart=Never -- sh -c "sleep 3600"
kubectl wait --for=condition=ready pod/test-pod --timeout=60s

# Test initial version
for i in {1..20}; do 
  kubectl exec test-pod -- curl -s http://canary-service | grep color
done
# All should show "blue"

# Deploy new version
kubectl argo rollouts set image canary-demo app=msahihi/rollouts-demo:yellow

# Watch progressive rollout
kubectl argo rollouts get rollout canary-demo --watch

# Test during canary (run this during rollout)
for i in {1..20}; do 
  kubectl exec test-pod -- curl -s http://canary-service | grep color
done
# Should show mix: ~10% yellow, ~90% blue at first step
```

### Step 10: Manual Canary Progression

```bash
# Deploy with manual steps
cat <<YAML | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-demo
spec:
  replicas: 10
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: canary-demo
  template:
    metadata:
      labels:
        app: canary-demo
    spec:
      containers:
      - name: app
        image: msahihi/rollouts-demo:green
        ports:
        - name: http
          containerPort: 8080
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {}  # Manual promotion required
      - setWeight: 50
      - pause: {}
      - setWeight: 100
YAML

# Rollout will pause at first step
kubectl argo rollouts get rollout canary-demo

# Test traffic distribution
for i in {1..20}; do 
  kubectl exec test-pod -- curl -s http://canary-service | grep color
done
# Should show ~20% green, ~80% yellow

# Promote to next step
kubectl argo rollouts promote canary-demo

# Promote again to reach 100%
kubectl argo rollouts promote canary-demo
```

### Step 11: Canary Rollback

```bash
# Deploy new version
kubectl argo rollouts set image canary-demo app=msahihi/rollouts-demo:red

# Wait for first step (20% weight)
sleep 10

# Test traffic
for i in {1..20}; do 
  kubectl exec test-pod -- curl -s http://canary-service | grep color
done
# Should show ~20% red, ~80% green

# Abort canary rollout
kubectl argo rollouts abort canary-demo

# Verify stable version restored
for i in {1..20}; do 
  kubectl exec test-pod -- curl -s http://canary-service | grep color
done
# All should show "green"
```

## Strategy Selection Guide

### Use Blue-Green When

- Updates have low risk
- You have comprehensive test coverage
- You need instant rollback capability
- You can afford 2x resources during deployment
- Testing in preview environment is sufficient

### Use Canary When

- Updates have high risk or unknown impact
- You need real production traffic validation
- You want gradual rollout with monitoring
- Resource efficiency is important
- You need progressive risk mitigation

## Clean Up

```bash
# Clean up blue-green
kubectl delete namespace bluegreen-demo

# Clean up canary
kubectl delete namespace canary-demo

# Verify
kubectl get namespaces | grep demo
```

## Verification Checklist

- [ ] Deployed blue-green rollout with active/preview services
- [ ] Tested preview environment before promotion
- [ ] Performed manual promotion for blue-green
- [ ] Executed blue-green rollback
- [ ] Deployed canary rollout with progressive steps
- [ ] Validated traffic distribution at each canary step
- [ ] Performed manual and automatic canary progression
- [ ] Executed canary rollback/abort
- [ ] Understood when to use each strategy

## Key Takeaways

1. **Blue-Green**: Instant traffic switch between two identical environments (blue=old, green=new)
2. **Canary**: Gradual traffic shift with progressive validation stages
3. **Preview Service**: Blue-green uses preview for pre-production testing
4. **Traffic Weights**: Canary uses percentage-based traffic distribution
5. **Rollback**: Blue-green switches services instantly; canary aborts and scales down canary pods
6. **Resource Usage**: Blue-green always uses 2x; canary scales proportionally to weight
7. **Risk Management**: Canary provides better risk mitigation through gradual rollout

## Troubleshooting

### Blue-Green Issues

**Preview service not updating:**

```bash
kubectl describe service bluegreen-preview -n bluegreen-demo
kubectl get endpoints bluegreen-preview -n bluegreen-demo
```

**Promotion not working:**

```bash
kubectl argo rollouts promote bluegreen-demo --full -n bluegreen-demo
```

### Canary Issues

**Traffic not splitting correctly:**

```bash
kubectl get replicasets -n canary-demo
kubectl describe rollout canary-demo -n canary-demo
```

**Stuck at canary step:**

```bash
kubectl argo rollouts promote canary-demo -n canary-demo
# or
kubectl argo rollouts abort canary-demo -n canary-demo
```

## Additional Resources

- [Blue-Green Strategy Documentation](https://argoproj.github.io/argo-rollouts/features/bluegreen/)
- [Canary Strategy Documentation](https://argoproj.github.io/argo-rollouts/features/canary/)
- [Traffic Management](https://argoproj.github.io/argo-rollouts/features/traffic-management/)
- [Analysis and Progressive Delivery](https://argoproj.github.io/argo-rollouts/features/analysis/)

## Next Steps

- [Lab 04: Analysis and Metrics](lab-04-analysis.md) - Automated canary analysis with metrics
- [Lab 05: Traffic Management](lab-05-traffic-management.md) - Advanced traffic routing patterns
