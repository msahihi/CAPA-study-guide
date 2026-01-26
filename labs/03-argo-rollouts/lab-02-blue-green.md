# Lab 02: Blue-Green Deployments

**Duration**: 35 minutes

**Difficulty**: Intermediate

## Objectives

By the end of this lab, you will be able to:

- Implement blue-green deployment strategy with Argo Rollouts
- Configure active and preview services for blue-green deployments
- Perform manual promotion from preview to active
- Execute rollback operations to previous versions
- Understand auto-promotion and scale-down configurations
- Test preview environments before promoting to production

## Prerequisites

- Completed [Lab 01: Installation and Basics](lab-01-installation-basics.md)
- Argo Rollouts controller installed and running
- kubectl Argo Rollouts plugin installed
- Access to a Kubernetes cluster
- Basic understanding of Kubernetes Services

## Lab Scenario

You are deploying a customer-facing web application that requires zero-downtime deployments with the ability to test new versions in a production-like environment before switching traffic. Blue-green deployment allows you to maintain two identical environments (blue=current, green=new) and instantly switch all traffic when ready.

## Step 1: Environment Setup

### 1.1 Create Namespace

Create a dedicated namespace for this lab:

```bash
# Create namespace
kubectl create namespace bluegreen-demo

# Set as default namespace
kubectl config set-context --current --namespace=bluegreen-demo

# Verify
kubectl config view --minify | grep namespace:
```

### 1.2 Create Active and Preview Services

Create two services: one for active (production) traffic and one for preview (testing):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-active
  namespace: bluegreen-demo
  labels:
    app: bluegreen-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: bluegreen-demo
---
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-preview
  namespace: bluegreen-demo
  labels:
    app: bluegreen-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: bluegreen-demo
EOF
```

### 1.3 Verify Services

Check that both services are created:

```bash
# List services
kubectl get services -n bluegreen-demo

# Describe active service
kubectl describe service bluegreen-active -n bluegreen-demo

# Describe preview service
kubectl describe service bluegreen-preview -n bluegreen-demo
```

**Expected Output:**

```
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
bluegreen-active    ClusterIP   10.96.100.10    <none>        80/TCP    10s
bluegreen-preview   ClusterIP   10.96.100.11    <none>        80/TCP    10s
```

## Step 2: Create Blue-Green Rollout

### 2.1 Deploy Initial Version (Blue)

Create a rollout with blue-green strategy:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: bluegreen-demo
  namespace: bluegreen-demo
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
        version: blue
    spec:
      containers:
      - name: bluegreen-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
        env:
        - name: VERSION
          value: "blue"
  strategy:
    blueGreen:
      # Reference to service that the rollout modifies as the active service
      activeService: bluegreen-active
      # Reference to service that the rollout modifies as the preview service
      previewService: bluegreen-preview
      # Auto promotion disabled - requires manual promotion
      autoPromotionEnabled: false
      # Time to wait before scaling down the old ReplicaSet after promotion
      scaleDownDelaySeconds: 30
      # Anti-affinity configuration to prevent blue and green from running on same node
      antiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          weight: 1
          podAffinityTerm:
            labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - bluegreen-demo
            topologyKey: kubernetes.io/hostname
EOF
```

### 2.2 Verify Initial Deployment

Check the rollout status:

```bash
# Get rollout status
kubectl argo rollouts get rollout bluegreen-demo -n bluegreen-demo

# Watch rollout (wait for healthy status)
kubectl argo rollouts get rollout bluegreen-demo --watch -n bluegreen-demo
# Press Ctrl+C after status shows Healthy
```

**Expected Output:**

```
Name:            bluegreen-demo
Namespace:       bluegreen-demo
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          argoproj/rollouts-demo:blue (stable, active)
Replicas:
  Desired:       3
  Current:       3
  Updated:       3
  Ready:         3
  Available:     3

NAME                                       KIND        STATUS     AGE  INFO
⟳ bluegreen-demo                           Rollout     ✔ Healthy  45s
└──# revision:1
   └──⧉ bluegreen-demo-7bf8c5f8d9          ReplicaSet  ✔ Healthy  45s  stable,active
      ├──□ bluegreen-demo-7bf8c5f8d9-abc   Pod         ✔ Running  45s  ready:1/1
      ├──□ bluegreen-demo-7bf8c5f8d9-def   Pod         ✔ Running  45s  ready:1/1
      └──□ bluegreen-demo-7bf8c5f8d9-ghi   Pod         ✔ Running  45s  ready:1/1
```

### 2.3 Verify Service Endpoints

Check which pods the services are routing to:

```bash
# Get endpoints for active service
kubectl get endpoints bluegreen-active -n bluegreen-demo

# Get endpoints for preview service
kubectl get endpoints bluegreen-preview -n bluegreen-demo

# Both should point to the same pods initially
kubectl get endpoints -n bluegreen-demo -o wide
```

## Step 3: Test Active Service

### 3.1 Create Test Pod

Deploy a test pod to access services from within the cluster:

```bash
# Create test pod
kubectl run test-pod --image=curlimages/curl:latest -n bluegreen-demo \
  --restart=Never --rm -it -- sh

# If the above exits immediately, use this alternative:
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: bluegreen-demo
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["/bin/sh", "-c", "sleep 3600"]
EOF

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/test-pod -n bluegreen-demo --timeout=60s
```

### 3.2 Test Active Service

Access the active service:

```bash
# Execute curl in test pod to check active service
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-active | grep -i "color\|version"

# Run multiple requests to see consistent response
for i in {1..5}; do
  echo "Request $i:"
  kubectl exec -it test-pod -n bluegreen-demo -- \
    curl -s http://bluegreen-active | grep "color"
done
```

**Expected Output:**

```
Request 1:
"color": "blue"
Request 2:
"color": "blue"
Request 3:
"color": "blue"
```

### 3.3 Test Preview Service

Access the preview service (should show same version initially):

```bash
# Test preview service
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-preview | grep -i "color\|version"
```

## Step 4: Deploy New Version (Green)

### 4.1 Update Rollout Image

Deploy a new version to create the green environment:

```bash
# Update to yellow version (representing new version)
kubectl argo rollouts set image bluegreen-demo \
  bluegreen-demo=argoproj/rollouts-demo:yellow \
  -n bluegreen-demo

# Watch the rollout progress
kubectl argo rollouts get rollout bluegreen-demo --watch -n bluegreen-demo
```

**Observe:**

- New ReplicaSet (green) is created
- Preview service is updated to point to green environment
- Active service still points to blue environment (old version)
- Rollout is in "Paused" state waiting for promotion

**Expected Output:**

```
Name:            bluegreen-demo
Namespace:       bluegreen-demo
Status:          ॥ Paused
Message:         BlueGreenPause
Strategy:        BlueGreen
Images:          argoproj/rollouts-demo:blue (stable, active)
                 argoproj/rollouts-demo:yellow (preview)
Replicas:
  Desired:       3
  Current:       6
  Updated:       3
  Ready:         6
  Available:     6

NAME                                       KIND        STATUS     AGE    INFO
⟳ bluegreen-demo                           Rollout     ॥ Paused   2m30s
├──# revision:2
│  └──⧉ bluegreen-demo-789xyz              ReplicaSet  ✔ Healthy  15s    preview
│     ├──□ bluegreen-demo-789xyz-aaa       Pod         ✔ Running  15s    ready:1/1
│     ├──□ bluegreen-demo-789xyz-bbb       Pod         ✔ Running  15s    ready:1/1
│     └──□ bluegreen-demo-789xyz-ccc       Pod         ✔ Running  15s    ready:1/1
└──# revision:1
   └──⧉ bluegreen-demo-7bf8c5f8d9          ReplicaSet  ✔ Healthy  2m30s  stable,active
      ├──□ bluegreen-demo-7bf8c5f8d9-abc   Pod         ✔ Running  2m30s  ready:1/1
      ├──□ bluegreen-demo-7bf8c5f8d9-def   Pod         ✔ Running  2m30s  ready:1/1
      └──□ bluegreen-demo-7bf8c5f8d9-ghi   Pod         ✔ Running  2m30s  ready:1/1
```

### 4.2 Verify Both Environments Running

Check that both blue and green environments are running:

```bash
# List all ReplicaSets
kubectl get replicasets -n bluegreen-demo -l app=bluegreen-demo

# List all pods with labels
kubectl get pods -n bluegreen-demo -l app=bluegreen-demo --show-labels

# Check pod distribution
echo "Blue (stable) pods:"
kubectl get pods -n bluegreen-demo -l app=bluegreen-demo,rollouts-pod-template-hash!=\
$(kubectl get rollout bluegreen-demo -n bluegreen-demo -o jsonpath='{.status.currentPodHash}')

echo "Green (preview) pods:"
kubectl get pods -n bluegreen-demo -l app=bluegreen-demo,rollouts-pod-template-hash=\
$(kubectl get rollout bluegreen-demo -n bluegreen-demo -o jsonpath='{.status.currentPodHash}')
```

## Step 5: Test Preview Environment

### 5.1 Test Preview Service with New Version

Access the preview service to test the new version:

```bash
# Test preview service (should show yellow/green version)
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-preview | grep "color"

# Test multiple times to confirm consistency
for i in {1..5}; do
  echo "Preview Request $i:"
  kubectl exec -it test-pod -n bluegreen-demo -- \
    curl -s http://bluegreen-preview | grep "color"
done
```

**Expected Output:**

```
Preview Request 1:
"color": "yellow"
Preview Request 2:
"color": "yellow"
```

### 5.2 Verify Active Service Still Serves Old Version

Confirm active service hasn't changed:

```bash
# Test active service (should still show blue version)
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-active | grep "color"

# Compare both services side by side
echo "=== Active Service ==="
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-active | grep "color"

echo "=== Preview Service ==="
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-preview | grep "color"
```

### 5.3 Perform Integration Tests on Preview

Simulate integration testing on preview environment:

```bash
# Test various endpoints on preview
echo "Testing preview environment..."

# Health check
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-preview/

# Test response time
kubectl exec -it test-pod -n bluegreen-demo -- \
  sh -c 'time curl -s http://bluegreen-preview > /dev/null'

# Test with headers
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s -H "User-Agent: IntegrationTest" http://bluegreen-preview | grep color
```

## Step 6: Manual Promotion

### 6.1 Promote to Active

After testing preview, promote the new version to active:

```bash
# Promote the rollout
kubectl argo rollouts promote bluegreen-demo -n bluegreen-demo

# Watch the promotion process
kubectl argo rollouts get rollout bluegreen-demo --watch -n bluegreen-demo
```

**Observe:**

- Active service switches to point to green (yellow) version
- Preview service updates to also point to green version
- Old blue version is marked for scale-down after delay
- Status changes from "Paused" to "Healthy"

**Expected Output After Promotion:**

```
Name:            bluegreen-demo
Namespace:       bluegreen-demo
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          argoproj/rollouts-demo:yellow (stable, active)
Replicas:
  Desired:       3
  Current:       6
  Updated:       3
  Ready:         6
  Available:     6

NAME                                       KIND        STATUS         AGE    INFO
⟳ bluegreen-demo                           Rollout     ✔ Healthy      5m
├──# revision:2
│  └──⧉ bluegreen-demo-789xyz              ReplicaSet  ✔ Healthy      2m45s  stable,active
│     ├──□ bluegreen-demo-789xyz-aaa       Pod         ✔ Running      2m45s  ready:1/1
│     ├──□ bluegreen-demo-789xyz-bbb       Pod         ✔ Running      2m45s  ready:1/1
│     └──□ bluegreen-demo-789xyz-ccc       Pod         ✔ Running      2m45s  ready:1/1
└──# revision:1
   └──⧉ bluegreen-demo-7bf8c5f8d9          ReplicaSet  • ScalingDown  5m     delay:28s
      ├──□ bluegreen-demo-7bf8c5f8d9-abc   Pod         ✔ Running      5m     ready:1/1
      ├──□ bluegreen-demo-7bf8c5f8d9-def   Pod         ✔ Running      5m     ready:1/1
      └──□ bluegreen-demo-7bf8c5f8d9-ghi   Pod         ✔ Running      5m     ready:1/1
```

### 6.2 Verify Traffic Switch

Confirm active service now serves new version:

```bash
# Test active service - should now show yellow
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-active | grep "color"

# Test multiple times to verify consistent routing
for i in {1..10}; do
  kubectl exec -it test-pod -n bluegreen-demo -- \
    curl -s http://bluegreen-active | grep "color"
done
```

**Expected Output:**

```
"color": "yellow"
"color": "yellow"
"color": "yellow"
```

### 6.3 Observe Scale-Down Delay

Watch the old version scale down after the configured delay:

```bash
# Watch pods being terminated
kubectl get pods -n bluegreen-demo -l app=bluegreen-demo --watch

# After 30 seconds (scaleDownDelaySeconds), old pods should terminate
# Press Ctrl+C to exit
```

## Step 7: Rollback Scenario

### 7.1 Deploy Another Version

Deploy a new version to practice rollback:

```bash
# Deploy red version
kubectl argo rollouts set image bluegreen-demo \
  bluegreen-demo=argoproj/rollouts-demo:red \
  -n bluegreen-demo

# Wait for preview to be ready
sleep 10

# Check status
kubectl argo rollouts get rollout bluegreen-demo -n bluegreen-demo
```

### 7.2 Test Preview and Decide to Rollback

Test preview and decide not to promote:

```bash
# Test preview service
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-preview | grep "color"

# Verify active is still on previous version
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-active | grep "color"

# Simulate finding an issue - decide to rollback/abort
echo "Issue found in preview! Aborting rollout..."
```

### 7.3 Abort Rollout

Abort the rollout to discard the new version:

```bash
# Abort the rollout
kubectl argo rollouts abort bluegreen-demo -n bluegreen-demo

# Watch the rollout status
kubectl argo rollouts get rollout bluegreen-demo --watch -n bluegreen-demo
```

**Observe:**

- Rollout status changes to "Degraded" or "Healthy" (depending on version)
- Preview ReplicaSet is scaled down
- Active service continues pointing to stable version
- New pods are terminated

**Expected Output:**

```
Name:            bluegreen-demo
Namespace:       bluegreen-demo
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          argoproj/rollouts-demo:yellow (stable, active)
Replicas:
  Desired:       3
  Current:       3
  Updated:       3
  Ready:         3
  Available:     3

NAME                                       KIND        STATUS     AGE  INFO
⟳ bluegreen-demo                           Rollout     ✔ Healthy  8m
└──# revision:2
   └──⧉ bluegreen-demo-789xyz              ReplicaSet  ✔ Healthy  5m   stable,active
      ├──□ bluegreen-demo-789xyz-aaa       Pod         ✔ Running  5m   ready:1/1
      ├──□ bluegreen-demo-789xyz-bbb       Pod         ✔ Running  5m   ready:1/1
      └──□ bluegreen-demo-789xyz-ccc       Pod         ✔ Running  5m   ready:1/1
```

### 7.4 Verify Rollback

Confirm active service still serves the stable version:

```bash
# Test active service
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-active | grep "color"
# Should still show "yellow"

# Verify preview service also reverted
kubectl exec -it test-pod -n bluegreen-demo -- \
  curl -s http://bluegreen-preview | grep "color"
# Should also show "yellow"
```

## Step 8: Auto-Promotion Configuration

### 8.1 Enable Auto-Promotion

Modify the rollout to enable automatic promotion:

```bash
kubectl patch rollout bluegreen-demo -n bluegreen-demo --type merge -p '
{
  "spec": {
    "strategy": {
      "blueGreen": {
        "autoPromotionEnabled": true,
        "autoPromotionSeconds": 30
      }
    }
  }
}'

# Verify the change
kubectl get rollout bluegreen-demo -n bluegreen-demo -o jsonpath='{.spec.strategy.blueGreen.autoPromotionEnabled}'
```

### 8.2 Test Auto-Promotion

Deploy a new version to test auto-promotion:

```bash
# Deploy green version
kubectl argo rollouts set image bluegreen-demo \
  bluegreen-demo=argoproj/rollouts-demo:green \
  -n bluegreen-demo

# Watch for automatic promotion after 30 seconds
kubectl argo rollouts get rollout bluegreen-demo --watch -n bluegreen-demo
```

**Observe:**

- Rollout pauses initially
- After 30 seconds, automatically promotes without manual intervention
- Active service switches to new version
- Old version scales down

### 8.3 Disable Auto-Promotion

Return to manual promotion mode:

```bash
kubectl patch rollout bluegreen-demo -n bluegreen-demo --type merge -p '
{
  "spec": {
    "strategy": {
      "blueGreen": {
        "autoPromotionEnabled": false
      }
    }
  }
}'

# Verify
kubectl get rollout bluegreen-demo -n bluegreen-demo -o yaml | grep autoPromotion
```

## Step 9: Advanced Configurations

### 9.1 Configure Preview Replicas

Set different replica counts for preview:

```bash
kubectl patch rollout bluegreen-demo -n bluegreen-demo --type merge -p '
{
  "spec": {
    "strategy": {
      "blueGreen": {
        "previewReplicaCount": 1
      }
    }
  }
}'

# Deploy new version to test
kubectl argo rollouts set image bluegreen-demo \
  bluegreen-demo=argoproj/rollouts-demo:orange \
  -n bluegreen-demo

# Wait and check replica counts
sleep 5
kubectl get replicasets -n bluegreen-demo -l app=bluegreen-demo
```

### 9.2 Configure Max Unavailable

Set maxUnavailable during promotion:

```bash
kubectl patch rollout bluegreen-demo -n bluegreen-demo --type merge -p '
{
  "spec": {
    "strategy": {
      "blueGreen": {
        "maxUnavailable": "25%"
      }
    }
  }
}'
```

## Step 10: Monitoring and Observability

### 10.1 View Rollout History

Check rollout revision history:

```bash
# View history
kubectl argo rollouts history rollout bluegreen-demo -n bluegreen-demo

# Get detailed history
kubectl rollout history rollout bluegreen-demo -n bluegreen-demo
```

### 10.2 Check Rollout Events

Monitor events related to the rollout:

```bash
# Get events for rollout
kubectl get events -n bluegreen-demo \
  --field-selector involvedObject.name=bluegreen-demo \
  --sort-by='.lastTimestamp'

# Watch events live
kubectl get events -n bluegreen-demo --watch
```

### 10.3 Export Rollout Metrics

Get rollout metrics and status:

```bash
# Get rollout status in JSON
kubectl get rollout bluegreen-demo -n bluegreen-demo -o json | \
  jq '{name: .metadata.name, status: .status.phase, replicas: .status.replicas, ready: .status.readyReplicas}'

# Get current step and images
kubectl get rollout bluegreen-demo -n bluegreen-demo -o json | \
  jq '{images: .status.conditions, stable: .status.stableRS, current: .status.currentPodHash}'
```

## Step 11: Clean Up

### 11.1 Delete Test Resources

Clean up the test pod:

```bash
# Delete test pod
kubectl delete pod test-pod -n bluegreen-demo

# Verify deletion
kubectl get pods -n bluegreen-demo
```

### 11.2 Delete Rollout and Services

Remove the rollout and services:

```bash
# Delete rollout
kubectl delete rollout bluegreen-demo -n bluegreen-demo

# Delete services
kubectl delete service bluegreen-active bluegreen-preview -n bluegreen-demo

# Verify deletion
kubectl get all -n bluegreen-demo
```

### 11.3 Delete Namespace

Remove the namespace:

```bash
# Delete namespace
kubectl delete namespace bluegreen-demo

# Verify
kubectl get namespace bluegreen-demo
```

## Verification

Confirm successful lab completion:

```bash
# Verify Argo Rollouts is still running
kubectl get deployment argo-rollouts -n argo-rollouts

# List any remaining rollouts
kubectl argo rollouts list rollouts --all-namespaces
```

## Lab Completion Checklist

- [ ] Created blue-green rollout with active and preview services
- [ ] Deployed initial version and verified active service
- [ ] Updated to new version and tested preview environment
- [ ] Performed manual promotion from preview to active
- [ ] Verified traffic switch after promotion
- [ ] Executed rollback by aborting a rollout
- [ ] Tested auto-promotion configuration
- [ ] Configured preview replica count
- [ ] Monitored rollout events and history
- [ ] Successfully cleaned up all resources

## Key Takeaways

1. **Blue-Green Strategy**: Maintains two identical environments (blue=current, green=new) enabling instant traffic switching with zero downtime

2. **Service Management**: Uses separate active and preview services to route traffic to different ReplicaSets, allowing testing before promotion

3. **Manual vs Auto Promotion**: Manual promotion provides control gates for validation; auto-promotion enables hands-off deployments after a timeout

4. **Rollback Capability**: Aborting a rollout immediately discards the new version and maintains the stable version in production

5. **Scale Down Delay**: Configurable delay keeps old version running briefly after promotion to enable quick rollback if issues are detected

6. **Testing Strategy**: Preview service allows comprehensive testing of new version in production-like environment before affecting users

## Troubleshooting

### Preview Service Not Updating

If preview service doesn't point to new version:

```bash
# Check service selector
kubectl describe service bluegreen-preview -n bluegreen-demo

# Check rollout status
kubectl argo rollouts get rollout bluegreen-demo -n bluegreen-demo

# Check endpoints
kubectl get endpoints bluegreen-preview -n bluegreen-demo -o yaml

# Verify pod labels
kubectl get pods -n bluegreen-demo --show-labels
```

### Promotion Not Working

If promotion command doesn't work:

```bash
# Check rollout is paused
kubectl get rollout bluegreen-demo -n bluegreen-demo -o jsonpath='{.status.pauseConditions}'

# Check for errors in rollout status
kubectl get rollout bluegreen-demo -n bluegreen-demo -o yaml | grep -A 10 conditions

# Retry promotion
kubectl argo rollouts promote bluegreen-demo -n bluegreen-demo

# Force full promotion
kubectl argo rollouts promote bluegreen-demo --full -n bluegreen-demo
```

### Old Pods Not Scaling Down

If old pods don't scale down after promotion:

```bash
# Check scale down delay setting
kubectl get rollout bluegreen-demo -n bluegreen-demo -o jsonpath='{.spec.strategy.blueGreen.scaleDownDelaySeconds}'

# Check rollout status
kubectl argo rollouts get rollout bluegreen-demo -n bluegreen-demo

# Manually scale down old ReplicaSet if needed
OLD_RS=$(kubectl get rs -n bluegreen-demo -l app=bluegreen-demo --sort-by=.metadata.creationTimestamp | head -2 | tail -1 | awk '{print $1}')
kubectl scale rs/$OLD_RS --replicas=0 -n bluegreen-demo
```

## Next Steps

Continue to the next lab:

- [Lab 03: Canary Deployments](lab-03-canary.md) - Implement canary rollout strategy with progressive traffic splitting

## Additional Resources

- [Blue-Green Deployment Documentation](https://argoproj.github.io/argo-rollouts/features/bluegreen/)
- [Blue-Green Strategy Specification](https://argoproj.github.io/argo-rollouts/features/specification/#bluegreen)
- [Service Mesh Integration](https://argoproj.github.io/argo-rollouts/features/traffic-management/)
- [Best Practices for Blue-Green](https://argoproj.github.io/argo-rollouts/best-practices/)
