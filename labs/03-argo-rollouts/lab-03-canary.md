# Lab 03: Canary Deployments

**Duration**: 40 minutes

**Difficulty**: Intermediate

## Objectives

By the end of this lab, you will be able to:

- Implement canary deployment strategy with traffic splitting
- Configure multi-step canary rollouts with weight-based traffic distribution
- Use manual and automatic progression between canary steps
- Implement pause durations for validation windows
- Perform pause and resume operations on canary rollouts
- Execute rollback and abort operations
- Understand stable and canary ReplicaSet management

## Prerequisites

- Completed [Lab 01: Installation and Basics](lab-01-installation-basics.md)
- Completed [Lab 02: Blue-Green Deployments](lab-02-blue-green.md)
- Argo Rollouts controller installed and running
- kubectl Argo Rollouts plugin installed
- Access to a Kubernetes cluster

## Lab Scenario

You are deploying updates to a high-traffic e-commerce application. Rather than switching all traffic at once, you need to gradually shift traffic from the old version to the new version while monitoring metrics and user feedback. Canary deployments allow you to progressively increase traffic to the new version through multiple validation stages.

## Step 1: Environment Setup

### 1.1 Create Namespace

Create a dedicated namespace for canary deployments:

```bash
# Create namespace
kubectl create namespace canary-demo

# Set as default namespace
kubectl config set-context --current --namespace=canary-demo

# Verify
kubectl config view --minify | grep namespace:
```

### 1.2 Create Service

Create a service for the canary rollout:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: canary-service
  namespace: canary-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: canary-demo
EOF
```

### 1.3 Verify Service

Check the service:

```bash
# Get service
kubectl get service canary-service -n canary-demo

# Describe service
kubectl describe service canary-service -n canary-demo
```

## Step 2: Create Basic Canary Rollout

### 2.1 Deploy Initial Version

Create a canary rollout with multiple steps:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-demo
  namespace: canary-demo
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
      - name: canary-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 30s}
      - setWeight: 20
      - pause: {duration: 30s}
      - setWeight: 40
      - pause: {duration: 30s}
      - setWeight: 60
      - pause: {duration: 30s}
      - setWeight: 80
      - pause: {duration: 30s}
EOF
```

### 2.2 Monitor Initial Deployment

Watch the rollout being created:

```bash
# Get rollout status
kubectl argo rollouts get rollout canary-demo -n canary-demo

# Watch until healthy
kubectl argo rollouts get rollout canary-demo --watch -n canary-demo
# Press Ctrl+C after status shows Healthy
```

**Expected Output:**

```
Name:            canary-demo
Namespace:       canary-demo
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          argoproj/rollouts-demo:blue (stable)
Replicas:
  Desired:       10
  Current:       10
  Updated:       10
  Ready:         10
  Available:     10

NAME                                       KIND        STATUS     AGE  INFO
⟳ canary-demo                              Rollout     ✔ Healthy  45s
└──# revision:1
   └──⧉ canary-demo-7bf8c5f8d9             ReplicaSet  ✔ Healthy  45s  stable
      ├──□ canary-demo-7bf8c5f8d9-aaaaa    Pod         ✔ Running  45s  ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-bbbbb    Pod         ✔ Running  45s  ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-ccccc    Pod         ✔ Running  45s  ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-ddddd    Pod         ✔ Running  45s  ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-eeeee    Pod         ✔ Running  45s  ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-fffff    Pod         ✔ Running  45s  ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-ggggg    Pod         ✔ Running  45s  ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-hhhhh    Pod         ✔ Running  45s  ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-iiiii    Pod         ✔ Running  45s  ready:1/1
      └──□ canary-demo-7bf8c5f8d9-jjjjj    Pod         ✔ Running  45s  ready:1/1
```

### 2.3 Create Test Pod

Deploy a test pod for accessing the service:

```bash
# Create test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: canary-demo
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["/bin/sh", "-c", "sleep 3600"]
EOF

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/test-pod -n canary-demo --timeout=60s
```

## Step 3: Perform Canary Deployment

### 3.1 Deploy New Version

Update to a new version to trigger canary rollout:

```bash
# Update to yellow version
kubectl argo rollouts set image canary-demo \
  canary-demo=argoproj/rollouts-demo:yellow \
  -n canary-demo

# Immediately watch the rollout
kubectl argo rollouts get rollout canary-demo --watch -n canary-demo
```

**Observe:**

- Canary ReplicaSet is created with 1 pod (10% of 10 replicas)
- Stable ReplicaSet maintains 9 pods (90%)
- Rollout pauses for 30 seconds at each step
- Weight gradually increases: 10% → 20% → 40% → 60% → 80% → 100%

**Expected Output at 10% Step:**

```
Name:            canary-demo
Namespace:       canary-demo
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/9
  SetWeight:     10
  ActualWeight:  10
Images:          argoproj/rollouts-demo:blue (stable)
                 argoproj/rollouts-demo:yellow (canary)
Replicas:
  Desired:       10
  Current:       10
  Updated:       1
  Ready:         10
  Available:     10

NAME                                       KIND        STATUS        AGE   INFO
⟳ canary-demo                              Rollout     ॥ Paused      2m
├──# revision:2
│  └──⧉ canary-demo-789xyz                 ReplicaSet  ✔ Healthy     10s   canary
│     └──□ canary-demo-789xyz-aaaaa        Pod         ✔ Running     10s   ready:1/1
└──# revision:1
   └──⧉ canary-demo-7bf8c5f8d9             ReplicaSet  ✔ Healthy     2m    stable
      ├──□ canary-demo-7bf8c5f8d9-aaaaa    Pod         ✔ Running     2m    ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-bbbbb    Pod         ✔ Running     2m    ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-ccccc    Pod         ✔ Running     2m    ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-ddddd    Pod         ✔ Running     2m    ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-eeeee    Pod         ✔ Running     2m    ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-fffff    Pod         ✔ Running     2m    ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-ggggg    Pod         ✔ Running     2m    ready:1/1
      ├──□ canary-demo-7bf8c5f8d9-hhhhh    Pod         ✔ Running     2m    ready:1/1
      └──□ canary-demo-7bf8c5f8d9-iiiii    Pod         ✔ Running     2m    ready:1/1
```

### 3.2 Test Traffic Distribution

Test the service to observe traffic splitting:

```bash
# Test traffic distribution (run in separate terminal or background)
# This will show approximately 10% yellow, 90% blue initially

for i in {1..20}; do
  kubectl exec -it test-pod -n canary-demo -- \
    curl -s http://canary-service | grep -o '"color":"[^"]*"'
done | sort | uniq -c
```

**Expected Output:**

```
      2 "color":"yellow"    # ~10%
     18 "color":"blue"      # ~90%
```

### 3.3 Monitor Step Progression

Watch as the rollout progresses through steps automatically:

```bash
# Continue watching (if not already watching)
kubectl argo rollouts get rollout canary-demo --watch -n canary-demo

# In another terminal, continuously test traffic distribution
while true; do
  echo "=== Traffic Distribution at $(date +%H:%M:%S) ==="
  for i in {1..10}; do
    kubectl exec -it test-pod -n canary-demo -- \
      curl -s http://canary-service 2>/dev/null | grep -o '"color":"[^"]*"'
  done | sort | uniq -c
  echo ""
  sleep 10
done
```

**Observe Traffic Progression:**

- At 10%: ~1 canary pod, ~9 stable pods
- At 20%: ~2 canary pods, ~8 stable pods
- At 40%: ~4 canary pods, ~6 stable pods
- At 60%: ~6 canary pods, ~4 stable pods
- At 80%: ~8 canary pods, ~2 stable pods
- At 100%: All pods are canary, stable scaled to 0

## Step 4: Manual Pause and Resume

### 4.1 Create Rollout with Manual Gates

Create a rollout that requires manual promotion:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-manual
  namespace: canary-demo
spec:
  replicas: 10
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: canary-manual
  template:
    metadata:
      labels:
        app: canary-manual
    spec:
      containers:
      - name: canary-manual
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {}  # Indefinite pause - requires manual promotion
      - setWeight: 30
      - pause: {}  # Indefinite pause
      - setWeight: 50
      - pause: {}  # Indefinite pause
      - setWeight: 70
      - pause: {}  # Indefinite pause
      - setWeight: 100
EOF
```

Wait for initial deployment:

```bash
kubectl argo rollouts get rollout canary-manual --watch -n canary-demo
# Press Ctrl+C after healthy
```

### 4.2 Deploy with Manual Gates

Update the manual canary:

```bash
# Update image
kubectl argo rollouts set image canary-manual \
  canary-manual=argoproj/rollouts-demo:yellow \
  -n canary-demo

# Watch rollout - it will pause at 10% indefinitely
kubectl argo rollouts get rollout canary-manual -n canary-demo
```

**Expected Output:**

```
Name:            canary-manual
Namespace:       canary-demo
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/8
  SetWeight:     10
  ActualWeight:  10
```

### 4.3 Manually Promote Through Steps

Promote through each step manually:

```bash
# Promote to next step (10% → 30%)
kubectl argo rollouts promote canary-manual -n canary-demo

# Check status
kubectl argo rollouts get rollout canary-manual -n canary-demo

# Wait and observe, then promote again (30% → 50%)
kubectl argo rollouts promote canary-manual -n canary-demo

# Check status
kubectl argo rollouts get rollout canary-manual -n canary-demo

# Continue promoting until fully deployed
kubectl argo rollouts promote canary-manual -n canary-demo
kubectl argo rollouts promote canary-manual -n canary-demo
```

### 4.4 Use Full Promotion

Skip remaining steps and fully promote:

```bash
# Deploy another version
kubectl argo rollouts set image canary-manual \
  canary-manual=argoproj/rollouts-demo:green \
  -n canary-demo

# Wait for first pause
sleep 5

# Fully promote (skip all remaining steps)
kubectl argo rollouts promote canary-manual --full -n canary-demo

# Watch immediate full deployment
kubectl argo rollouts get rollout canary-manual --watch -n canary-demo
```

## Step 5: Pause and Resume Operations

### 5.1 Pause During Rollout

Pause a rollout in progress:

```bash
# Start new rollout on original canary
kubectl argo rollouts set image canary-demo \
  canary-demo=argoproj/rollouts-demo:red \
  -n canary-demo

# Wait a few seconds for it to start
sleep 5

# Pause the rollout
kubectl argo rollouts pause canary-demo -n canary-demo

# Check status - should show paused
kubectl argo rollouts get rollout canary-demo -n canary-demo
```

**Expected Output:**

```
Status:          ॥ Paused
Message:         manually paused
```

### 5.2 Resume Rollout

Resume the paused rollout:

```bash
# Resume rollout
kubectl argo rollouts resume canary-demo -n canary-demo

# Watch it continue progressing
kubectl argo rollouts get rollout canary-demo --watch -n canary-demo
```

### 5.3 Pause at Specific Step

```bash
# Deploy new version
kubectl argo rollouts set image canary-demo \
  canary-demo=argoproj/rollouts-demo:orange \
  -n canary-demo

# Wait for 40% step
sleep 70  # Wait through 10%, 20% steps (30s each + buffer)

# Pause at current step
kubectl argo rollouts pause canary-demo -n canary-demo

# Check current step
kubectl argo rollouts get rollout canary-demo -n canary-demo | grep "Step:"

# Validate at this traffic level, then resume when ready
kubectl argo rollouts resume canary-demo -n canary-demo
```

## Step 6: Rollback and Abort

### 6.1 Abort Canary Rollout

Abort a rollout to revert to stable version:

```bash
# Deploy new version
kubectl argo rollouts set image canary-demo \
  canary-demo=argoproj/rollouts-demo:bad \
  -n canary-demo

# Wait for first step
sleep 10

# Abort the rollout
kubectl argo rollouts abort canary-demo -n canary-demo

# Watch rollback
kubectl argo rollouts get rollout canary-demo --watch -n canary-demo
```

**Observe:**

- Canary ReplicaSet scales to 0
- Stable ReplicaSet returns to full replica count
- All traffic returns to stable version
- Status shows "Degraded" then returns to "Healthy"

### 6.2 Verify Traffic Restored

Test that traffic returned to stable:

```bash
# Test traffic
for i in {1..10}; do
  kubectl exec -it test-pod -n canary-demo -- \
    curl -s http://canary-service | grep -o '"color":"[^"]*"'
done | sort | uniq -c

# Should show 100% orange (stable version)
```

### 6.3 Retry Aborted Rollout

Retry a failed/aborted rollout:

```bash
# Check current revision
kubectl argo rollouts history rollout canary-demo -n canary-demo

# Retry the rollout to previous failed version (if you want to retry)
kubectl argo rollouts retry rollout canary-demo -n canary-demo

# Or deploy a new version
kubectl argo rollouts set image canary-demo \
  canary-demo=argoproj/rollouts-demo:purple \
  -n canary-demo
```

## Step 7: Advanced Canary Configurations

### 7.1 Configure Max Surge and Max Unavailable

Create rollout with maxSurge and maxUnavailable:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-advanced
  namespace: canary-demo
spec:
  replicas: 10
  selector:
    matchLabels:
      app: canary-advanced
  template:
    metadata:
      labels:
        app: canary-advanced
    spec:
      containers:
      - name: canary-advanced
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      maxSurge: "25%"        # Allow 25% extra pods during rollout
      maxUnavailable: 0      # Ensure no downtime
      steps:
      - setWeight: 25
      - pause: {duration: 20s}
      - setWeight: 50
      - pause: {duration: 20s}
      - setWeight: 75
      - pause: {duration: 20s}
EOF
```

### 7.2 Test Max Surge Configuration

Deploy and observe pod counts:

```bash
# Wait for initial deployment
kubectl argo rollouts get rollout canary-advanced --watch -n canary-demo
# Press Ctrl+C when healthy

# Update image
kubectl argo rollouts set image canary-advanced \
  canary-advanced=argoproj/rollouts-demo:yellow \
  -n canary-advanced

# Watch pod counts during rollout
watch "kubectl get pods -n canary-demo -l app=canary-advanced | tail -n +2 | wc -l"
# Press Ctrl+C to exit

# You should see up to 13 pods (10 + 25% surge) during transition
```

### 7.3 Configure Canary with Analysis

Create a canary with placeholder for analysis (we'll implement in next lab):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-with-analysis
  namespace: canary-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: canary-with-analysis
  template:
    metadata:
      labels:
        app: canary-with-analysis
    spec:
      containers:
      - name: app
        image: argoproj/rollouts-demo:blue
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
      - setWeight: 20
      - pause: {duration: 30s}
      # Analysis would go here (covered in Lab 04)
      - setWeight: 50
      - pause: {duration: 30s}
      - setWeight: 80
      - pause: {duration: 30s}
EOF
```

## Step 8: Monitoring Canary Rollouts

### 8.1 View Detailed Status

Get comprehensive rollout information:

```bash
# Get detailed status
kubectl argo rollouts get rollout canary-demo -n canary-demo

# Get status in JSON
kubectl get rollout canary-demo -n canary-demo -o json | jq .status

# Get current step and weight
kubectl get rollout canary-demo -n canary-demo -o jsonpath='{.status.currentStepIndex}{" / "}{.spec.strategy.canary.steps | length}{"\n"}'

kubectl get rollout canary-demo -n canary-demo -o jsonpath='{.status.canary.weights}{"\n"}'
```

### 8.2 Monitor ReplicaSet Changes

Track ReplicaSet scaling during canary:

```bash
# Watch ReplicaSets
watch -n 2 'kubectl get replicasets -n canary-demo -l app=canary-demo'

# Get replica counts
kubectl get replicasets -n canary-demo -l app=canary-demo \
  -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas
```

### 8.3 View Rollout Events

Monitor events during rollout:

```bash
# Watch events
kubectl get events -n canary-demo \
  --field-selector involvedObject.name=canary-demo \
  --sort-by='.lastTimestamp' \
  --watch

# Get recent events
kubectl get events -n canary-demo \
  --field-selector involvedObject.name=canary-demo \
  --sort-by='.lastTimestamp' | tail -20
```

### 8.4 View Rollout History

Check revision history:

```bash
# View history
kubectl argo rollouts history rollout canary-demo -n canary-demo

# Get specific revision details
kubectl rollout history rollout canary-demo --revision=2 -n canary-demo
```

## Step 9: Traffic Verification Script

### 9.1 Create Traffic Testing Script

Create a script to continuously monitor traffic distribution:

```bash
cat > /tmp/test-traffic.sh <<'EOF'
#!/bin/bash

NAMESPACE=${1:-canary-demo}
SERVICE=${2:-canary-service}
REQUESTS=${3:-50}

echo "Testing traffic distribution for $SERVICE in $NAMESPACE"
echo "Sending $REQUESTS requests..."
echo ""

kubectl exec -it test-pod -n $NAMESPACE -- sh -c "
for i in \$(seq 1 $REQUESTS); do
  curl -s http://$SERVICE 2>/dev/null | grep -o '\"color\":\"[^\"]*\"'
done
" | sort | uniq -c | awk '{
  color=$2
  count=$1
  total='$REQUESTS'
  percentage=(count/total)*100
  printf "%s: %d requests (%.1f%%)\n", color, count, percentage
}'
EOF

chmod +x /tmp/test-traffic.sh
```

### 9.2 Use Traffic Testing Script

Test traffic during a rollout:

```bash
# Deploy new version
kubectl argo rollouts set image canary-demo \
  canary-demo=argoproj/rollouts-demo:cyan \
  -n canary-demo

# Test traffic at different stages
sleep 10
echo "=== At 10% ==="
/tmp/test-traffic.sh canary-demo canary-service 100

sleep 30
echo "=== At 20% ==="
/tmp/test-traffic.sh canary-demo canary-service 100

sleep 30
echo "=== At 40% ==="
/tmp/test-traffic.sh canary-demo canary-service 100
```

## Step 10: Clean Up

### 10.1 Delete Rollouts

Remove all canary rollouts:

```bash
# Delete rollouts
kubectl delete rollout canary-demo -n canary-demo
kubectl delete rollout canary-manual -n canary-demo
kubectl delete rollout canary-advanced -n canary-demo
kubectl delete rollout canary-with-analysis -n canary-demo

# Verify deletion
kubectl get rollouts -n canary-demo
```

### 10.2 Delete Services and Pods

Clean up remaining resources:

```bash
# Delete test pod
kubectl delete pod test-pod -n canary-demo

# Delete service
kubectl delete service canary-service -n canary-demo

# Verify
kubectl get all -n canary-demo
```

### 10.3 Delete Namespace

Remove the namespace:

```bash
# Delete namespace
kubectl delete namespace canary-demo

# Verify
kubectl get namespace canary-demo
```

### 10.4 Clean Up Test Script

```bash
# Remove test script
rm /tmp/test-traffic.sh
```

## Verification

Confirm successful lab completion:

```bash
# Verify Argo Rollouts is still running
kubectl get deployment argo-rollouts -n argo-rollouts

# Verify namespace is deleted
kubectl get namespace canary-demo
# Should show "not found"
```

## Lab Completion Checklist

- [ ] Created basic canary rollout with multiple steps
- [ ] Deployed new version and observed automatic progression
- [ ] Tested traffic distribution at different weight percentages
- [ ] Implemented manual promotion gates with indefinite pauses
- [ ] Performed pause and resume operations during rollout
- [ ] Executed rollback using abort command
- [ ] Configured maxSurge and maxUnavailable settings
- [ ] Monitored ReplicaSet scaling during canary
- [ ] Created traffic testing script for validation
- [ ] Successfully cleaned up all resources

## Key Takeaways

1. **Progressive Traffic Shifting**: Canary deployments gradually shift traffic from old to new version through weighted steps, minimizing blast radius of issues

2. **Step Configuration**: Steps define traffic weight percentages and pause durations, allowing validation at each stage before proceeding

3. **Manual vs Automatic**: Indefinite pauses (`pause: {}`) require manual promotion, while duration-based pauses (`pause: {duration: 30s}`) proceed automatically

4. **Pause and Resume**: Ability to pause rollout at any time for investigation, then resume when ready, provides operational flexibility

5. **Abort and Rollback**: Aborting canary immediately scales down new version and returns all traffic to stable version, enabling quick recovery

6. **Replica Management**: Canary maintains two ReplicaSets with sizes proportional to traffic weights (e.g., 20% weight = 2 of 10 replicas for canary)

7. **MaxSurge**: Allows temporary over-provisioning during rollout to ensure zero downtime and smooth transitions

## Troubleshooting

### Traffic Distribution Not Matching Weights

If traffic doesn't match expected weights:

```bash
# Check ReplicaSet pod counts
kubectl get replicasets -n canary-demo -l app=canary-demo

# Verify pods are ready
kubectl get pods -n canary-demo -l app=canary-demo

# Check service endpoints
kubectl get endpoints canary-service -n canary-demo -o yaml

# Verify service selector matches pod labels
kubectl describe service canary-service -n canary-demo
```

### Rollout Stuck at Step

If rollout doesn't progress:

```bash
# Check rollout status
kubectl argo rollouts get rollout canary-demo -n canary-demo

# Check for pause conditions
kubectl get rollout canary-demo -n canary-demo -o jsonpath='{.status.pauseConditions}'

# Check if manually paused
kubectl get rollout canary-demo -n canary-demo -o jsonpath='{.status.message}'

# Resume if paused
kubectl argo rollouts resume canary-demo -n canary-demo

# Promote if waiting at indefinite pause
kubectl argo rollouts promote canary-demo -n canary-demo
```

### Canary Pods Not Starting

If canary pods fail to start:

```bash
# Check pod status
kubectl get pods -n canary-demo -l app=canary-demo

# Describe failing pods
kubectl describe pods -n canary-demo -l app=canary-demo

# Check pod logs
kubectl logs -n canary-demo -l app=canary-demo --tail=50

# Check events
kubectl get events -n canary-demo --sort-by='.lastTimestamp' | tail -20
```

## Next Steps

Continue to the next lab:

- [Lab 04: Analysis and Metrics](lab-04-analysis.md) - Integrate Prometheus metrics for automated canary validation

## Additional Resources

- [Canary Deployment Documentation](https://argoproj.github.io/argo-rollouts/features/canary/)
- [Canary Strategy Specification](https://argoproj.github.io/argo-rollouts/features/specification/#canary)
- [Traffic Management](https://argoproj.github.io/argo-rollouts/features/traffic-management/)
- [Best Practices](https://argoproj.github.io/argo-rollouts/best-practices/)
