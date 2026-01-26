# Lab 01: Installation and Basics

**Duration**: 25 minutes

**Difficulty**: Beginner

## Objectives

By the end of this lab, you will be able to:

- Install Argo Rollouts controller in a Kubernetes cluster
- Install and configure the kubectl Argo Rollouts plugin
- Create your first Rollout resource
- Compare Rollout behavior with standard Deployments
- Use basic kubectl plugin commands to manage rollouts
- Understand the difference between Rollout and Deployment resources

## Prerequisites

- Access to a Kubernetes cluster (minikube, kind, or cloud-based)
- kubectl installed and configured
- Cluster admin permissions
- Basic understanding of Kubernetes Deployments
- curl or wget installed for downloading the plugin

## Lab Environment Setup

Verify your cluster is running and you have admin access:

```bash
# Check cluster connection
kubectl cluster-info

# Verify you have admin permissions
kubectl auth can-i create namespaces
# Should return "yes"

# Check Kubernetes version (1.19+ recommended)
kubectl version --short
```

## Step 1: Install Argo Rollouts Controller

### 1.1 Create Argo Rollouts Namespace

First, create a dedicated namespace for Argo Rollouts:

```bash
# Create namespace
kubectl create namespace argo-rollouts

# Verify namespace creation
kubectl get namespace argo-rollouts
```

**Expected Output:**

```
NAME            STATUS   AGE
argo-rollouts   Active   5s
```

### 1.2 Install Argo Rollouts Using Manifests

Install the latest stable release of Argo Rollouts:

```bash
# Install Argo Rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Wait for rollouts controller to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argo-rollouts -n argo-rollouts
```

### 1.3 Verify Installation

Check that all Argo Rollouts components are running:

```bash
# Check pods in argo-rollouts namespace
kubectl get pods -n argo-rollouts

# Check deployments
kubectl get deployments -n argo-rollouts

# Check services
kubectl get services -n argo-rollouts

# View controller logs
kubectl logs -n argo-rollouts deployment/argo-rollouts --tail=20
```

**Expected Output:**

```
NAME                             READY   STATUS    RESTARTS   AGE
argo-rollouts-7d9c6d5f9c-abcde   1/1     Running   0          2m
```

### 1.4 Verify CRDs Installation

Confirm that Rollout Custom Resource Definitions are installed:

```bash
# List Argo Rollouts CRDs
kubectl get crd | grep argoproj.io

# Get detailed info about Rollout CRD
kubectl explain rollout

# Check available API versions
kubectl api-resources | grep rollouts
```

**Expected Output:**

```
NAME                              APIVERSION                   NAMESPACED   KIND
analysisruns                      argoproj.io/v1alpha1         true         AnalysisRun
analysistemplates                 argoproj.io/v1alpha1         true         AnalysisTemplate
clusteranalysistemplates          argoproj.io/v1alpha1         false        ClusterAnalysisTemplate
experiments                       argoproj.io/v1alpha1         true         Experiment
rollouts                          argoproj.io/v1alpha1         true         Rollout
```

## Step 2: Install kubectl Argo Rollouts Plugin

### 2.1 Download and Install Plugin

Install the kubectl plugin for Argo Rollouts management:

**For Linux:**

```bash
# Download the latest release
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64

# Make it executable
chmod +x kubectl-argo-rollouts-linux-amd64

# Move to PATH
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify installation
kubectl argo rollouts version
```

**For macOS:**

```bash
# Download the latest release
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-amd64

# Make it executable
chmod +x kubectl-argo-rollouts-darwin-amd64

# Move to PATH
sudo mv kubectl-argo-rollouts-darwin-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify installation
kubectl argo rollouts version
```

**For Windows (PowerShell):**

```powershell
# Download the latest release
Invoke-WebRequest -Uri https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-windows-amd64 -OutFile kubectl-argo-rollouts.exe

# Move to PATH (adjust path as needed)
Move-Item kubectl-argo-rollouts.exe C:\Windows\System32\

# Verify installation
kubectl argo rollouts version
```

### 2.2 Verify Plugin Installation

Test the plugin functionality:

```bash
# Check plugin version
kubectl argo rollouts version

# View available commands
kubectl argo rollouts --help

# List commands for managing rollouts
kubectl argo rollouts list rollouts --help
```

**Expected Output:**

```
kubectl-argo-rollouts: v1.6.0+abc1234
  BuildDate: 2024-01-15T10:30:00Z
  GitCommit: abc1234567890abcdef1234567890abcdef12345
  Platform: linux/amd64
```

## Step 3: Create Your First Rollout

### 3.1 Create a Working Namespace

Create a namespace for testing rollouts:

```bash
# Create demo namespace
kubectl create namespace rollouts-demo

# Set as default namespace (optional)
kubectl config set-context --current --namespace=rollouts-demo
```

### 3.2 Create a Basic Rollout

Create a simple rollout using a basic rolling update strategy:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollout-demo
  namespace: rollouts-demo
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 40
      - pause: {duration: 10s}
      - setWeight: 60
      - pause: {duration: 10s}
      - setWeight: 80
      - pause: {duration: 10s}
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: rollout-demo
  template:
    metadata:
      labels:
        app: rollout-demo
    spec:
      containers:
      - name: rollouts-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
EOF
```

### 3.3 Verify Rollout Creation

Check the rollout status:

```bash
# Get rollout status
kubectl argo rollouts get rollout rollout-demo

# Watch rollout status (live updates)
kubectl argo rollouts get rollout rollout-demo --watch

# Press Ctrl+C to exit watch mode after observing
```

**Expected Output:**

```
Name:            rollout-demo
Namespace:       rollouts-demo
Status:          ✔ Healthy
Strategy:        Canary
  Step:          8/8
  SetWeight:     100
  ActualWeight:  100
Images:          argoproj/rollouts-demo:blue (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5

NAME                                       KIND        STATUS     AGE  INFO
⟳ rollout-demo                             Rollout     ✔ Healthy  30s
└──# revision:1
   └──⧉ rollout-demo-7bf8c5f8d9            ReplicaSet  ✔ Healthy  30s  stable
      ├──□ rollout-demo-7bf8c5f8d9-abcde   Pod         ✔ Running  30s  ready:1/1
      ├──□ rollout-demo-7bf8c5f8d9-fghij   Pod         ✔ Running  30s  ready:1/1
      ├──□ rollout-demo-7bf8c5f8d9-klmno   Pod         ✔ Running  30s  ready:1/1
      ├──□ rollout-demo-7bf8c5f8d9-pqrst   Pod         ✔ Running  30s  ready:1/1
      └──□ rollout-demo-7bf8c5f8d9-uvwxy   Pod         ✔ Running  30s  ready:1/1
```

### 3.4 Explore Rollout Resources

Examine the resources created by the rollout:

```bash
# List all rollouts
kubectl argo rollouts list rollouts -n rollouts-demo

# Get rollout details in YAML
kubectl get rollout rollout-demo -n rollouts-demo -o yaml

# List ReplicaSets created by rollout
kubectl get replicasets -n rollouts-demo -l app=rollout-demo

# List pods created by rollout
kubectl get pods -n rollouts-demo -l app=rollout-demo
```

### 3.5 Create a Service for the Rollout

Create a service to access the rollout:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: rollout-demo
  namespace: rollouts-demo
spec:
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: rollout-demo
EOF
```

Verify service creation:

```bash
# Get service
kubectl get service rollout-demo -n rollouts-demo

# Test service connectivity (from within cluster)
kubectl run -it --rm test-pod --image=curlimages/curl:latest \
  --restart=Never -n rollouts-demo \
  -- curl http://rollout-demo
```

## Step 4: Compare Rollout with Standard Deployment

### 4.1 Create a Standard Deployment

Create a regular Kubernetes Deployment for comparison:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-demo
  namespace: rollouts-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: deployment-demo
  template:
    metadata:
      labels:
        app: deployment-demo
    spec:
      containers:
      - name: deployment-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
EOF
```

### 4.2 Compare Resource Structures

Compare the YAML structure of both resources:

```bash
# Get Rollout structure
kubectl get rollout rollout-demo -n rollouts-demo -o yaml > rollout.yaml

# Get Deployment structure
kubectl get deployment deployment-demo -n rollouts-demo -o yaml > deployment.yaml

# Compare key differences
diff -u deployment.yaml rollout.yaml | head -50
```

**Key Differences:**

- Rollout uses `apiVersion: argoproj.io/v1alpha1`
- Rollout has `kind: Rollout`
- Rollout includes `strategy.canary` or `strategy.blueGreen`
- Rollout has additional status fields for progressive delivery

### 4.3 Update Both Resources

Perform updates to see the difference in behavior:

```bash
# Update Rollout image
kubectl argo rollouts set image rollout-demo \
  rollouts-demo=argoproj/rollouts-demo:yellow \
  -n rollouts-demo

# Watch Rollout update (in a new terminal or background)
kubectl argo rollouts get rollout rollout-demo --watch -n rollouts-demo &

# Wait a moment, then update Deployment image
kubectl set image deployment/deployment-demo \
  deployment-demo=argoproj/rollouts-demo:yellow \
  -n rollouts-demo

# Watch Deployment update
kubectl rollout status deployment/deployment-demo -n rollouts-demo
```

**Observe:**

- Rollout pauses at defined steps (20%, 40%, 60%, 80%)
- Rollout requires manual promotion at the first pause
- Deployment performs standard rolling update without pauses
- Rollout provides granular control over traffic shifting

### 4.4 Promote the Rollout

Since the rollout is paused at the first step, promote it:

```bash
# Check current rollout status
kubectl argo rollouts get rollout rollout-demo -n rollouts-demo

# Promote to next step
kubectl argo rollouts promote rollout-demo -n rollouts-demo

# The rollout will now proceed through remaining steps automatically
# Watch the progression
kubectl argo rollouts get rollout rollout-demo --watch -n rollouts-demo
```

## Step 5: Basic Rollout Management Commands

### 5.1 List Rollouts

View all rollouts in the namespace:

```bash
# List rollouts in current namespace
kubectl argo rollouts list rollouts -n rollouts-demo

# List rollouts in all namespaces
kubectl argo rollouts list rollouts --all-namespaces

# Get rollout with output format
kubectl get rollouts -n rollouts-demo -o wide
```

### 5.2 View Rollout Status

Get detailed status information:

```bash
# Get rollout status with details
kubectl argo rollouts get rollout rollout-demo -n rollouts-demo

# Watch rollout status continuously
kubectl argo rollouts get rollout rollout-demo --watch -n rollouts-demo

# Get rollout history
kubectl argo rollouts history rollout rollout-demo -n rollouts-demo
```

### 5.3 Pause and Resume

Control rollout progression:

```bash
# Pause rollout (stop at current step)
kubectl argo rollouts pause rollout-demo -n rollouts-demo

# Verify paused status
kubectl argo rollouts get rollout rollout-demo -n rollouts-demo

# Resume rollout
kubectl argo rollouts resume rollout-demo -n rollouts-demo

# Verify resumed status
kubectl argo rollouts get rollout rollout-demo -n rollouts-demo
```

### 5.4 Abort Rollout

Abort an in-progress rollout:

```bash
# Start a new rollout
kubectl argo rollouts set image rollout-demo \
  rollouts-demo=argoproj/rollouts-demo:red \
  -n rollouts-demo

# Wait for it to pause
sleep 5

# Abort the rollout
kubectl argo rollouts abort rollout-demo -n rollouts-demo

# Check status - should revert to stable version
kubectl argo rollouts get rollout rollout-demo -n rollouts-demo
```

### 5.5 Restart Rollout

Restart all pods in a rollout:

```bash
# Restart rollout (similar to kubectl rollout restart)
kubectl argo rollouts restart rollout-demo -n rollouts-demo

# Watch the restart process
kubectl argo rollouts get rollout rollout-demo --watch -n rollouts-demo
```

## Step 6: Understanding Rollout Status Fields

### 6.1 Examine Status Fields

View and understand rollout status fields:

```bash
# Get full rollout status
kubectl get rollout rollout-demo -n rollouts-demo -o jsonpath='{.status}' | jq

# Check specific status fields
echo "Phase: $(kubectl get rollout rollout-demo -n rollouts-demo -o jsonpath='{.status.phase}')"
echo "Current Step: $(kubectl get rollout rollout-demo -n rollouts-demo -o jsonpath='{.status.currentStepIndex}')"
echo "Replicas: $(kubectl get rollout rollout-demo -n rollouts-demo -o jsonpath='{.status.replicas}')"
echo "Ready Replicas: $(kubectl get rollout rollout-demo -n rollouts-demo -o jsonpath='{.status.readyReplicas}')"
```

### 6.2 Understand ReplicaSets

Examine how rollouts manage ReplicaSets:

```bash
# List all ReplicaSets for the rollout
kubectl get replicasets -n rollouts-demo -l app=rollout-demo

# Get stable ReplicaSet name
kubectl get rollout rollout-demo -n rollouts-demo -o jsonpath='{.status.stableRS}'

# Get current ReplicaSet hash
kubectl get rollout rollout-demo -n rollouts-demo -o jsonpath='{.status.currentPodHash}'

# Describe ReplicaSet to see ownership
kubectl describe replicaset -n rollouts-demo -l app=rollout-demo
```

**Key Points:**

- Rollouts maintain multiple ReplicaSets (stable and canary/preview)
- The stable ReplicaSet runs the proven version
- The canary/preview ReplicaSet runs the new version during rollout
- Rollouts control the replica count in each ReplicaSet based on strategy

## Step 7: Clean Up Resources

### 7.1 Delete Demo Resources

Clean up the resources created in this lab:

```bash
# Delete rollout
kubectl delete rollout rollout-demo -n rollouts-demo

# Delete deployment
kubectl delete deployment deployment-demo -n rollouts-demo

# Delete service
kubectl delete service rollout-demo -n rollouts-demo

# Delete namespace (optional)
kubectl delete namespace rollouts-demo

# Verify deletion
kubectl get all -n rollouts-demo
```

### 7.2 Keep Argo Rollouts Installed

Keep the Argo Rollouts controller installed for future labs:

```bash
# Verify controller is still running
kubectl get pods -n argo-rollouts

# If you want to uninstall (not recommended for continuing labs)
# kubectl delete -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
# kubectl delete namespace argo-rollouts
```

## Verification

Confirm you've completed the lab successfully:

```bash
# Verify Argo Rollouts is installed
kubectl get deployment argo-rollouts -n argo-rollouts

# Verify kubectl plugin is working
kubectl argo rollouts version

# Verify you can create and manage rollouts
kubectl argo rollouts list rollouts --all-namespaces
```

## Lab Completion Checklist

- [ ] Argo Rollouts controller installed and running
- [ ] kubectl Argo Rollouts plugin installed and verified
- [ ] Created first Rollout resource successfully
- [ ] Compared Rollout with standard Deployment
- [ ] Performed rollout update with canary strategy
- [ ] Used basic management commands (promote, pause, resume, abort)
- [ ] Understood rollout status fields and phases
- [ ] Examined ReplicaSet management by rollouts
- [ ] Successfully cleaned up demo resources

## Key Takeaways

1. **Argo Rollouts Architecture**: The controller watches Rollout resources and manages progressive delivery through ReplicaSet manipulation

2. **Rollout vs Deployment**: Rollouts provide advanced deployment strategies with fine-grained control over traffic and validation, while Deployments offer simple rolling updates

3. **kubectl Plugin**: The Argo Rollouts plugin provides convenient commands for managing rollouts, including promote, pause, resume, abort, and real-time status viewing

4. **Progressive Delivery**: Rollouts enable gradual rollout of changes with manual or automated promotion between steps

5. **ReplicaSet Management**: Rollouts create and manage multiple ReplicaSets (stable and canary/preview) to enable traffic splitting and quick rollbacks

## Troubleshooting

### Controller Not Starting

If the Argo Rollouts controller doesn't start:

```bash
# Check controller logs
kubectl logs -n argo-rollouts deployment/argo-rollouts

# Check controller events
kubectl describe deployment argo-rollouts -n argo-rollouts

# Verify CRDs are installed
kubectl get crd rollouts.argoproj.io
```

### Plugin Command Not Found

If kubectl plugin is not recognized:

```bash
# Verify plugin is in PATH
which kubectl-argo-rollouts

# Check plugin permissions
ls -la $(which kubectl-argo-rollouts)

# Manually test plugin
kubectl-argo-rollouts version

# Verify kubectl can discover plugins
kubectl plugin list | grep rollouts
```

### Rollout Stuck in Progressing

If rollout is stuck:

```bash
# Check rollout conditions
kubectl get rollout rollout-demo -n rollouts-demo -o jsonpath='{.status.conditions}' | jq

# Check pod status
kubectl get pods -n rollouts-demo -l app=rollout-demo

# Check events
kubectl get events -n rollouts-demo --sort-by='.lastTimestamp'

# Abort and retry
kubectl argo rollouts abort rollout-demo -n rollouts-demo
kubectl argo rollouts retry rollout rollout-demo -n rollouts-demo
```

## Next Steps

Continue to the next lab:

- [Lab 02: Blue-Green Deployments](lab-02-blue-green.md) - Implement blue-green deployment strategy with active and preview services

## Additional Resources

- [Argo Rollouts Installation Guide](https://argoproj.github.io/argo-rollouts/installation/)
- [kubectl Plugin Documentation](https://argoproj.github.io/argo-rollouts/features/kubectl-plugin/)
- [Rollout Specification](https://argoproj.github.io/argo-rollouts/features/specification/)
- [Getting Started Guide](https://argoproj.github.io/argo-rollouts/getting-started/)
- [Progressive Delivery FAQ](https://argoproj.github.io/argo-rollouts/FAQ/)
