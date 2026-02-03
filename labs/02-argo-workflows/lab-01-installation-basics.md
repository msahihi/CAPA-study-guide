# Lab 01: Installation and Basics

**Duration**: 25 minutes

## Objectives

By the end of this lab, you will be able to:

- Install Argo Workflows on a Kubernetes cluster
- Access the Argo Workflows UI
- Create and submit your first workflow
- Monitor workflow execution and view logs
- Understand workflow lifecycle and phases
- Use the Argo CLI to manage workflows

## Prerequisites

- Access to a Kubernetes cluster (v1.19+)
- kubectl CLI installed and configured
- Basic understanding of Kubernetes concepts
- Basic familiarity with YAML syntax

## Lab Environment Setup

Verify your Kubernetes cluster is accessible:

```bash
kubectl cluster-info
kubectl get nodes
```

Expected output should show your cluster information and node status.

## Step 1: Install Argo Workflows (5 minutes)

### 1.1 Create Argo Namespace

First, create a dedicated namespace for Argo Workflows:

```bash
kubectl create namespace argo
```

Verify the namespace was created:

```bash
kubectl get namespace argo
```

### 1.2 Install Argo Workflows

Install Argo Workflows using the official manifest:

```bash
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/install.yaml
```

**What this installs:**

- Workflow Controller: Manages workflow execution
- Argo Server: Provides UI and API
- Custom Resource Definitions (CRDs): Workflow, WorkflowTemplate, etc.
- ServiceAccount and RBAC: Required permissions

### 1.3 Verify Installation

Check that all Argo Workflows components are running:

```bash
kubectl get pods -n argo
```

Expected output:

```
NAME                                   READY   STATUS    RESTARTS   AGE
argo-server-xxxxxxxxxx-xxxxx           1/1     Running   0          1m
workflow-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

Wait until all pods show `Running` status and `1/1` ready.

### 1.4 Verify CRDs Installation

Check that Workflow CRDs are installed:

```bash
kubectl get crd | grep argoproj
```

You should see:

- workflows.argoproj.io
- workflowtemplates.argoproj.io
- clusterworkflowtemplates.argoproj.io
- cronworkflows.argoproj.io

## Step 2: Install Argo CLI (3 minutes)

### 2.1 Download Argo CLI

**For macOS:**

```bash
brew install argo
```

**For Linux:**

```bash
curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/argo-linux-amd64.gz
gunzip argo-linux-amd64.gz
chmod +x argo-linux-amd64
sudo mv argo-linux-amd64 /usr/local/bin/argo
```

**For Windows (PowerShell):**

```powershell
$url = "https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/argo-windows-amd64.gz"
Invoke-WebRequest -Uri $url -OutFile argo.gz
# Extract and move to PATH
```

### 2.2 Verify CLI Installation

```bash
argo version
```

Expected output shows both client and server versions:

```
argo: v3.5.4
  BuildDate: 2024-01-15T18:30:00Z
  GitCommit: abc123def456
  ...
```

## Step 3: Access Argo Workflows UI (3 minutes)

### 3.1 Patch Argo Server Service

By default, the Argo Server is not exposed externally. For this lab, we'll use port-forward:

```bash
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

Keep this terminal open. The UI will be accessible at `https://localhost:2746`

### 3.2 Configure Argo CLI Authentication

The Argo CLI requires authentication to communicate with the Argo Server. Set up authentication:

```bash
# Generate a token from the argo service account
export ARGO_TOKEN=$(kubectl create token argo -n argo --duration=24h)

# Configure Argo CLI to use the local server
export ARGO_SERVER='localhost:2746'
export ARGO_INSECURE_SKIP_VERIFY=true
export ARGO_NAMESPACE=argo
```

**Note**: The token expires after 24 hours. Regenerate it when needed.

Add these to your `~/.bashrc` or `~/.zshrc` for persistence (excluding the token generation, which should be run manually).

### 3.3 Access the UI

Open your browser and navigate to:

```
https://localhost:2746
```

**Note**: You may see a certificate warning. This is expected for local development. Click "Advanced" and proceed.

You should see the Argo Workflows dashboard with an empty workflow list.

### 3.4 Configure Authentication (Optional)

For production, enable proper authentication. For this lab, we'll disable authentication:

```bash
kubectl patch deployment argo-server \
  --namespace argo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
  "server",
  "--auth-mode=server"
]}]'
```

Wait for the pod to restart:

```bash
kubectl wait --for=condition=ready pod -l app=argo-server -n argo --timeout=60s

kubectl -n argo port-forward deployment/argo-server 2746:2746
```

## Step 4: Create Your First Workflow (7 minutes)

### 4.1 Create a Simple Hello World Workflow

Create a file named `hello-world.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-world-
spec:
  serviceAccountName: argo
  entrypoint: whalesay
  templates:
  - name: whalesay
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Hello Argo Workflows!'"]
```

**Explanation:**

- `generateName`: Creates unique workflow names with this prefix
- `serviceAccountName`: Service account to use for workflow execution (provides necessary RBAC permissions)
- `entrypoint`: The template to start execution
- `templates`: Defines the work to be done
- `container`: Runs a container with specified image and command

**Note**: We use `alpine:3.18` instead of `docker/whalesay:latest` because the whalesay image uses an outdated Docker manifest format that may not be supported by newer container runtimes.

### 4.2 Submit the Workflow

**Using kubectl (recommended for local development):**

```bash
kubectl create -n argo -f hello-world.yaml
```

**Using Argo CLI:**

```bash
argo submit -n argo hello-world.yaml --watch
```

The `--watch` flag streams the workflow progress to your terminal.

**Troubleshooting**: If you encounter a "could not find a token" error with the Argo CLI, ensure:

1. You've set the `ARGO_TOKEN` environment variable (see Step 3.2)
2. Port-forwarding to argo-server is active
3. Alternatively, use `kubectl create` which doesn't require these configurations

### 4.3 Monitor Workflow Status

Watch the workflow execution:

```bash
kubectl get workflow -n argo -w
```

Output:

```
NAME                STATUS    AGE   MESSAGE
hello-world-xxxxx   Pending   1s
hello-world-xxxxx   Running   5s
hello-world-xxxxx   Succeeded 10s
```

Press `Ctrl+C` to stop watching.

### 4.4 Get Detailed Workflow Information

Using Argo CLI (if configured):

```bash
argo get -n argo hello-world-xxxxx
```

Output shows complete workflow details:

```
Name:                hello-world-xxxxx
Namespace:           argo
ServiceAccount:      argo
Status:              Succeeded
Conditions:
 PodRunning          False
 Completed           True
Created:             Mon Feb 02 21:49:51 +0100 (10 seconds ago)
Started:             Mon Feb 02 21:49:51 +0100 (10 seconds ago)
Finished:            Mon Feb 02 21:50:01 +0100 (now)
Duration:            10 seconds
Progress:            1/1
ResourcesDuration:   3s*(1 cpu),3s*(100Mi memory)

STEP                  TEMPLATE  PODNAME            DURATION  MESSAGE
 ✔ hello-world-xxxxx  whalesay  hello-world-xxxxx  3s
```

Using kubectl:

```bash
kubectl get workflow -n argo hello-world-xxxxx -o yaml
```

### 4.5 Create a Parameterized Workflow

Create `hello-param.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-param-
spec:
  serviceAccountName: argo
  entrypoint: whalesay
  arguments:
    parameters:
    - name: message
      value: "Welcome to CAPA!"
  templates:
  - name: whalesay
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo '{{inputs.parameters.message}}'"]
```

Submit with custom parameter using kubectl:

```bash
kubectl create -n argo -f hello-param.yaml
```

Or using Argo CLI:

```bash
argo submit -n argo hello-param.yaml \
  --parameter message="Hello from the CLI!" \
  --watch
```

## Step 5: Monitor Workflow Execution (4 minutes)

### 5.1 List All Workflows

```bash
argo list -n argo
```

Output shows all workflows:

```
NAME                STATUS      AGE   DURATION   PRIORITY
hello-param-xxxxx   Succeeded   1m    8s         0
hello-world-xxxxx   Succeeded   2m    5s         0
```

### 5.2 Get Workflow Details

Using Argo CLI:

```bash
argo get -n argo hello-world-xxxxx
```

Using kubectl:

```bash
kubectl get workflow -n argo hello-world-xxxxx -o wide
```

This shows complete workflow information including:

- Metadata (name, namespace, creation time)
- ServiceAccount used (should show `argo`)
- Status and phase
- Parameters used
- Step details and timing
- Resource usage

### 5.3 View Workflow Logs

Using Argo CLI:

```bash
argo logs -n argo hello-world-xxxxx
```

Using kubectl:

```bash
kubectl logs -n argo hello-world-xxxxx -c main
```

You should see the output:

```
Hello Argo Workflows!
```

### 5.4 Monitor in the UI

1. Go to `https://localhost:2746`
2. Click on your workflow name
3. Observe:
   - Workflow DAG visualization
   - Node status and timing
   - Logs for each step
   - Parameters and artifacts
   - Timeline view

### 5.5 Understanding Workflow Phases

Check the workflow phase:

```bash
kubectl get workflow -n argo hello-world-xxxxx -o jsonpath='{.status.phase}'
```

**Workflow Phases:**

- `Pending`: Workflow created, not yet started
- `Running`: Workflow currently executing
- `Succeeded`: Workflow completed successfully
- `Failed`: Workflow failed with errors
- `Error`: System error occurred

## Step 6: Workflow Management (3 minutes)

### 6.1 Create a Long-Running Workflow

Create `sleep-workflow.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: sleep-
spec:
  serviceAccountName: argo
  entrypoint: sleep
  templates:
  - name: sleep
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Sleeping for 60 seconds'; sleep 60; echo 'Done!'"]
```

Submit it:

```bash
kubectl create -n argo -f sleep-workflow.yaml
```

Or with Argo CLI:

```bash
argo submit -n argo sleep-workflow.yaml
```

### 6.2 Watch Workflow Progress

Using Argo CLI:

```bash
argo watch -n argo sleep-xxxxx
```

Using kubectl:

```bash
kubectl get workflow -n argo sleep-xxxxx -w
```

This shows real-time updates as the workflow progresses through its lifecycle: Pending → Running → Succeeded/Failed.

### 6.3 Stop a Running Workflow

In a new terminal, stop the workflow.

Using Argo CLI:

```bash
argo stop -n argo sleep-xxxxx
```

Using kubectl:

```bash
kubectl patch workflow -n argo sleep-xxxxx --type merge -p '{"spec":{"shutdown":"Stop"}}'
```

The workflow status will change to `Failed` with message "stopped with strategy 'Terminate'".

### 6.4 Delete Workflows

Delete a specific workflow.

Using Argo CLI:

```bash
argo delete -n argo hello-world-xxxxx
```

Using kubectl:

```bash
kubectl delete workflow -n argo hello-world-xxxxx
```

Delete all workflows:

Using Argo CLI:

```bash
argo delete -n argo --all
```

Using kubectl:

```bash
kubectl delete workflow -n argo --all
```

### 6.5 Resubmit a Workflow

You can resubmit a completed workflow.

Using Argo CLI:

```bash
argo resubmit -n argo hello-world-xxxxx
```

Using kubectl (retrieve the workflow spec and resubmit):

```bash
kubectl get workflow -n argo hello-world-xxxxx -o yaml | kubectl create -f -
```

This creates a new workflow instance with the same configuration.

## Practice Exercises

### Exercise 1: Custom Message Workflow

Create a workflow that:

1. Takes two parameters: `greeting` and `name`
2. Uses the `alpine:latest` image
3. Echoes the message: `{greeting}, {name}! Welcome to Argo Workflows.`

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: custom-greeting-
spec:
  serviceAccountName: argo
  entrypoint: greet
  arguments:
    parameters:
    - name: greeting
      value: "Hello"
    - name: name
      value: "Student"
  templates:
  - name: greet
    inputs:
      parameters:
      - name: greeting
      - name: name
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo '{{inputs.parameters.greeting}}, {{inputs.parameters.name}}! Welcome to Argo Workflows.'"]
```

Submit:

```bash
kubectl create -n argo -f custom-greeting.yaml
```

Or with Argo CLI and parameters:

```bash
argo submit -n argo custom-greeting.yaml \
  --parameter greeting="Good morning" \
  --parameter name="DevOps Engineer" \
  --watch
```

</details>

### Exercise 2: Workflow with Resource Limits

Create a workflow that:

1. Uses the `stress:latest` image (or `alpine:latest` with sleep)
2. Sets CPU limit to 100m and memory limit to 128Mi
3. Runs for 10 seconds

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: resource-limits-
spec:
  serviceAccountName: argo
  entrypoint: limited-task
  templates:
  - name: limited-task
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Running with resource limits'; sleep 10; echo 'Complete'"]
      resources:
        limits:
          memory: 128Mi
          cpu: 100m
        requests:
          memory: 64Mi
          cpu: 50m
```

Submit and verify:

```bash
kubectl create -n argo -f resource-limits.yaml
# Or with Argo CLI
argo submit -n argo resource-limits.yaml --watch

# Verify resource limits
kubectl get pod -n argo -l workflows.argoproj.io/workflow -o jsonpath='{.items[0].spec.containers[0].resources}'
```

</details>

### Exercise 3: Multiple Workflow Submissions

Submit the hello-world workflow 5 times with different messages and monitor all of them:

<details>
<summary>Solution</summary>

```bash
# Submit 5 workflows
for i in {1..5}; do
  argo submit -n argo hello-param.yaml \
    --parameter message="Message number $i"
  sleep 1
done

# Monitor all workflows
argo list -n argo

# Watch the latest one
argo watch -n argo @latest
```

</details>

## Verification Steps

Verify your lab completion:

```bash
# Check Argo installation
kubectl get pods -n argo

# Expected output: argo-server and workflow-controller running
# NAME                                   READY   STATUS    RESTARTS   AGE
# argo-server-xxxxxxxxxx-xxxxx           1/1     Running   0          15m
# workflow-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          15m

# Verify you can submit workflows
kubectl create -n argo -f hello-world.yaml

# Verify you can view workflows
kubectl get workflow -n argo

# Expected output:
# NAME                STATUS      AGE
# hello-world-xxxxx   Succeeded   1m

# Verify you can access logs
kubectl logs -n argo hello-world-xxxxx -c main

# Expected output:
# Hello Argo Workflows!

# Clean up test workflows
kubectl delete workflow -n argo --all
```

## Troubleshooting

### Issue: Argo CLI Authentication Error

**Symptom**: `argo submit` fails with "could not find a token" or gRPC/ALPN errors

**Solution**:

1. Generate and set the authentication token:

```bash
export ARGO_TOKEN=$(kubectl create token argo -n argo --duration=24h)
export ARGO_SERVER='localhost:2746'
export ARGO_INSECURE_SKIP_VERIFY=true
```

2. Ensure port-forwarding is active:

```bash
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

3. If issues persist, use `kubectl create` instead:

```bash
kubectl create -n argo -f your-workflow.yaml
```

### Issue: Image Pull Errors

**Symptom**: Workflow fails with "unsupported manifest media type" or "ErrImagePull"

**Cause**: Using outdated container images with old Docker manifest formats (like `docker/whalesay:latest`)

**Solution**: Use modern container images like `alpine:3.18`, `busybox:latest`, or other actively maintained images.

### Issue: Pods Stuck in Pending

**Symptom**: Workflow pods don't start

**Solution**:

```bash
kubectl describe pod -n argo <pod-name>
```

Check for:

- Insufficient resources
- Image pull errors
- Node selector issues

### Issue: Cannot Access UI

**Symptom**: Browser cannot connect to localhost:2746

**Solution**:

```bash
# Verify port-forward is running
ps aux | grep port-forward

# Restart port-forward
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

### Issue: Permission Denied Errors

**Symptom**: Workflow fails with RBAC errors like "cannot patch resource pods" or "cannot create resource workflowtaskresults"

**Cause**: The workflow is using the `default` service account which lacks necessary permissions.

**Solution**: Always specify `serviceAccountName: argo` in your workflow spec:

```yaml
spec:
  serviceAccountName: argo
  # ... rest of workflow spec
```

The `argo` service account is created automatically during Argo Workflows installation and has the necessary permissions.

### Issue: Argo CLI Not Found

**Symptom**: `argo: command not found`

**Solution**:

```bash
# Check if argo is in PATH
which argo

# If not, add to PATH or use full path
export PATH=$PATH:/usr/local/bin

# Or reinstall
brew install argo  # macOS
```

## Key Takeaways

- Argo Workflows extends Kubernetes with workflow orchestration capabilities
- The Workflow Controller manages execution while Argo Server provides UI/API
- Workflows are defined as Kubernetes Custom Resources (CRDs)
- The `entrypoint` field determines which template starts execution
- The Argo CLI provides powerful workflow management commands
- Workflows progress through phases: Pending → Running → Succeeded/Failed
- Parameters enable dynamic workflow behavior
- Monitoring can be done via CLI, UI, or kubectl
- Resource limits can be set per container template

## Next Steps

Continue to [Lab 02: Templates and Steps](lab-02-templates-steps.md) to learn about different template types and creating multi-step workflows.

## Cleanup

To remove Argo Workflows from your cluster:

```bash
# Delete all workflows first
argo delete -n argo --all

# Uninstall Argo Workflows
kubectl delete -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/install.yaml

# Delete the namespace
kubectl delete namespace argo
```

## Additional Resources

- [Argo Workflows Quick Start](https://argoproj.github.io/argo-workflows/quick-start/)
- [Argo CLI Reference](https://argoproj.github.io/argo-workflows/cli/)
- [Workflow Concepts](https://argoproj.github.io/argo-workflows/workflow-concepts/)
- [Argo Server Configuration](https://argoproj.github.io/argo-workflows/argo-server/)
