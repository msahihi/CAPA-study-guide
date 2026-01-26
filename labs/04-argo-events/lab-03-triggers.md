# Lab 03: Triggers and Actions

**Duration**: 35 minutes

**Difficulty**: Intermediate

## Learning Objectives

By the end of this lab, you will be able to:

- Use different trigger types (K8s, HTTP, Log)
- Trigger Argo Workflows with dynamic parameters
- Create Kubernetes resources dynamically from events
- Implement HTTP triggers to call external services
- Use trigger conditions for conditional execution
- Parameterize triggers with event data
- Chain multiple triggers in a single sensor
- Implement retry policies for triggers

## Prerequisites

- Completed Lab 01 and Lab 02
- Argo Events and Argo Workflows installed
- kubectl access to the cluster
- Basic understanding of Kubernetes resources
- Familiarity with HTTP requests

## Lab Architecture

In this lab, you'll build:

```
EventSource → Sensor → Multiple Triggers:
                       ├─> Argo Workflow (with params)
                       ├─> Kubernetes Resources (dynamic)
                       ├─> HTTP Request (external API)
                       └─> Log (debugging)
```

## Step 1: Argo Workflow Triggers with Parameters

### Create EventSource for Workflow Testing

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: workflow-trigger-source
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    workflow-webhook:
      port: "12000"
      endpoint: /workflow
      method: POST
EOF
```

### Create Sensor with Parameterized Workflow Trigger

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: workflow-param-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: workflow-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook

  triggers:
    - template:
        name: parameterized-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: param-workflow-
                namespace: argo-events
              spec:
                entrypoint: main
                arguments:
                  parameters:
                    # Extract parameters from webhook payload
                    - name: image
                      value: "{{.Input.body.image | default \"alpine:latest\"}}"
                    - name: command
                      value: "{{.Input.body.command | default \"echo\"}}"
                    - name: args
                      value: "{{.Input.body.args | default \"Hello World\"}}"
                    - name: environment
                      value: "{{.Input.body.environment | default \"dev\"}}"
                templates:
                  - name: main
                    inputs:
                      parameters:
                        - name: image
                        - name: command
                        - name: args
                        - name: environment
                    container:
                      image: "{{inputs.parameters.image}}"
                      command: ["{{inputs.parameters.command}}"]
                      args: ["{{inputs.parameters.args}}"]
                      env:
                        - name: ENVIRONMENT
                          value: "{{inputs.parameters.environment}}"
EOF
```

### Test Parameterized Workflow Trigger

```bash
# Port forward the webhook
kubectl port-forward -n argo-events svc/workflow-trigger-source-eventsource-svc 12000:12000 &
WEBHOOK_PID=$!

# Test 1: Default parameters
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{}'

# Test 2: Custom parameters
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "image": "python:3.9-alpine",
    "command": "python",
    "args": "-c \"print(\\\"Hello from Python\\\")\""",
    "environment": "production"
  }'

# Test 3: Script execution
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "image": "bash:latest",
    "command": "bash",
    "args": "-c \"echo Starting...; sleep 2; echo Done!\""
  }'

# Watch workflows
kubectl get workflows -n argo-events -w

# View workflow logs
sleep 10
kubectl logs -n argo-events -l workflows.argoproj.io/creator=workflow-param-sensor --tail=50
```

## Step 2: Advanced Workflow Triggers

### Create Sensor with DAG Workflow

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: dag-workflow-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: build-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "build"

  triggers:
    - template:
        name: dag-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: dag-build-
                namespace: argo-events
              spec:
                entrypoint: build-pipeline
                arguments:
                  parameters:
                    - name: repo
                      value: "{{.Input.body.repository}}"
                    - name: branch
                      value: "{{.Input.body.branch}}"
                    - name: commit
                      value: "{{.Input.body.commit}}"
                templates:
                  - name: build-pipeline
                    dag:
                      tasks:
                        - name: checkout
                          template: checkout-code

                        - name: test
                          template: run-tests
                          dependencies: [checkout]

                        - name: build
                          template: build-image
                          dependencies: [test]

                        - name: scan
                          template: security-scan
                          dependencies: [build]

                  - name: checkout-code
                    container:
                      image: alpine/git
                      command: [sh, -c]
                      args:
                        - |
                          echo "Checking out {{workflow.parameters.repo}}"
                          echo "Branch: {{workflow.parameters.branch}}"
                          echo "Commit: {{workflow.parameters.commit}}"

                  - name: run-tests
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args: ["echo Running tests...; sleep 2; echo Tests passed!"]

                  - name: build-image
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args: ["echo Building image...; sleep 3; echo Build complete!"]

                  - name: security-scan
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args: ["echo Running security scan...; sleep 2; echo Scan complete!"]
EOF
```

### Test DAG Workflow

```bash
# Trigger DAG workflow
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "action": "build",
    "repository": "myorg/myapp",
    "branch": "main",
    "commit": "abc123"
  }'

# Watch the DAG workflow progress
kubectl get workflows -n argo-events -w

# View workflow in detail (if argo CLI is installed)
WORKFLOW_NAME=$(kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d'/' -f2)
kubectl get workflow $WORKFLOW_NAME -n argo-events -o yaml | grep -A 20 status
```

## Step 3: Kubernetes Resource Triggers

Create Kubernetes resources dynamically from events.

### Create Sensor that Creates Deployments

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: k8s-resource-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: deploy-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "deploy"

  triggers:
    # Trigger 1: Create Deployment
    - template:
        name: create-deployment
        k8s:
          operation: create
          source:
            resource:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                generateName: "{{.Input.body.appName}}-"
                namespace: default
                labels:
                  app: "{{.Input.body.appName}}"
                  managed-by: argo-events
              spec:
                replicas: 2
                selector:
                  matchLabels:
                    app: "{{.Input.body.appName}}"
                template:
                  metadata:
                    labels:
                      app: "{{.Input.body.appName}}"
                      version: "{{.Input.body.version}}"
                  spec:
                    containers:
                      - name: "{{.Input.body.appName}}"
                        image: "{{.Input.body.image}}"
                        ports:
                          - containerPort: 80
                        env:
                          - name: VERSION
                            value: "{{.Input.body.version}}"

    # Trigger 2: Create Service
    - template:
        name: create-service
        k8s:
          operation: create
          source:
            resource:
              apiVersion: v1
              kind: Service
              metadata:
                name: "{{.Input.body.appName}}-svc"
                namespace: default
                labels:
                  app: "{{.Input.body.appName}}"
              spec:
                selector:
                  app: "{{.Input.body.appName}}"
                ports:
                  - protocol: TCP
                    port: 80
                    targetPort: 80
                type: ClusterIP
EOF
```

### Test Kubernetes Resource Creation

```bash
# Trigger deployment creation
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "action": "deploy",
    "appName": "nginx-app",
    "image": "nginx:alpine",
    "version": "v1.0.0"
  }'

# Watch for resources being created
kubectl get deployments -n default -w

# Verify deployment and service
kubectl get deployment,service -n default -l managed-by=argo-events

# Check deployment details
kubectl describe deployment -n default -l app=nginx-app
```

### Create Sensor for ConfigMap Updates

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: configmap-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: config-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "update-config"

  triggers:
    - template:
        name: update-configmap
        k8s:
          operation: create
          source:
            resource:
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: "{{.Input.body.configName}}"
                namespace: default
              data:
                config.yaml: |
                  {{.Input.body.configData}}
EOF
```

### Test ConfigMap Creation

```bash
# Create ConfigMap via webhook
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "action": "update-config",
    "configName": "app-config",
    "configData": "database:\n  host: localhost\n  port: 5432\napp:\n  name: myapp\n  version: 1.0"
  }'

# Verify ConfigMap
kubectl get configmap app-config -n default -o yaml
```

## Step 4: HTTP Triggers

Send HTTP requests to external services.

### Setup Mock HTTP Server

First, let's create a simple HTTP echo server for testing:

```bash
# Create a simple echo server deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-server
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-server
  template:
    metadata:
      labels:
        app: echo-server
    spec:
      containers:
        - name: echo
          image: hashicorp/http-echo:latest
          args:
            - "-text=Echo server received request"
          ports:
            - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo-server
  namespace: default
spec:
  selector:
    app: echo-server
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5678
EOF
```

### Create Sensor with HTTP Trigger

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: http-trigger-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: webhook-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "notify"

  triggers:
    # HTTP Trigger to external service
    - template:
        name: http-notification
        http:
          url: "http://echo-server.default.svc.cluster.local"
          method: POST
          headers:
            Content-Type: application/json
          payload:
            - src:
                dependencyName: webhook-event
                dataKey: body
              dest: body
          # Optional: timeout
          timeout: 10

    # Log trigger for debugging
    - template:
        name: log-notification
        log:
          intervalSeconds: 1
EOF
```

### Test HTTP Trigger

```bash
# Send notification event
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "action": "notify",
    "message": "Deployment completed",
    "status": "success",
    "timestamp": "2024-01-01T12:00:00Z"
  }'

# Check sensor logs to see HTTP request
kubectl logs -n argo-events -l sensor-name=http-trigger-sensor --tail=30

# Check echo server logs
kubectl logs -n default -l app=echo-server --tail=20
```

### Advanced HTTP Trigger with Parameters

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: advanced-http-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: webhook-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "webhook-out"

  triggers:
    - template:
        name: external-webhook
        http:
          url: "http://echo-server.default.svc.cluster.local"
          method: POST
          headers:
            Content-Type: application/json
            X-Event-Source: argo-events
            X-Event-Type: "{{.Input.body.eventType}}"
          # Build custom payload
          payload:
            - src:
                dependencyName: webhook-event
                dataTemplate: |
                  {
                    "event": "{{.Input.body.eventType}}",
                    "timestamp": "{{.Input.context.time}}",
                    "data": {{.Input.body | toJson}},
                    "source": "argo-events"
                  }
              dest: body
          # Retry policy
          retryStrategy:
            steps: 3
            duration: 1s
EOF
```

### Test Advanced HTTP Trigger

```bash
# Send webhook
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "action": "webhook-out",
    "eventType": "deployment.completed",
    "application": "myapp",
    "version": "v1.0.0"
  }'

# View sensor logs
kubectl logs -n argo-events -l sensor-name=advanced-http-sensor --tail=50
```

## Step 5: Conditional Triggers

Execute triggers based on conditions.

### Create Sensor with Conditional Triggers

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: conditional-trigger-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: webhook-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook

  triggers:
    # Production deployment (only if environment is production)
    - template:
        name: production-deploy
        conditions: "environment == \"production\""
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: prod-deploy-
                namespace: argo-events
              spec:
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Production Deployment"
                          echo "Extra validations..."
                          echo "Deployment complete"

    # Development deployment (only if environment is dev)
    - template:
        name: dev-deploy
        conditions: "environment == \"dev\" || environment == \"development\""
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: dev-deploy-
                namespace: argo-events
              spec:
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: alpine:latest
                      command: [echo, "Development Deployment - Fast track"]

    # High priority (only if priority is high)
    - template:
        name: high-priority-notify
        conditions: "priority == \"high\" || urgent == true"
        http:
          url: "http://echo-server.default.svc.cluster.local"
          method: POST
          payload:
            - src:
                dependencyName: webhook-event
                dataTemplate: '{"alert": "High priority event"}'
              dest: body

  # Define parameters for condition evaluation
  template:
    serviceAccountName: argo-events-sa
    container:
      env:
        - name: environment
          value: "{{.Input.body.environment}}"
        - name: priority
          value: "{{.Input.body.priority}}"
        - name: urgent
          value: "{{.Input.body.urgent}}"
EOF
```

### Test Conditional Triggers

```bash
# Test 1: Production deployment
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "production",
    "priority": "normal"
  }'

# Test 2: Development deployment
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "dev",
    "priority": "normal"
  }'

# Test 3: High priority notification
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "production",
    "priority": "high"
  }'

# Test 4: Urgent flag
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "dev",
    "priority": "normal",
    "urgent": true
  }'

# Watch workflows to see which triggers fired
kubectl get workflows -n argo-events -w
```

## Step 6: Trigger Policies and Error Handling

### Create Sensor with Retry Policies

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: retry-policy-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: webhook-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "retry-test"

  triggers:
    - template:
        name: workflow-with-retry
        # Retry policy for trigger execution
        retryStrategy:
          steps: 3
          duration: 2s
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: retry-workflow-
                namespace: argo-events
              spec:
                entrypoint: main
                # Workflow-level retry
                retryStrategy:
                  limit: 2
                  retryPolicy: "Always"
                templates:
                  - name: main
                    # Step-level retry
                    retryStrategy:
                      limit: 3
                      retryPolicy: "OnFailure"
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Attempting task..."
                          # Simulate occasional failure
                          if [ $((RANDOM % 3)) -eq 0 ]; then
                            echo "Success!"
                            exit 0
                          else
                            echo "Failed, will retry..."
                            exit 1
                          fi
EOF
```

### Test Retry Policies

```bash
# Trigger workflow with retry
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "action": "retry-test"
  }'

# Watch workflow and observe retries
kubectl get workflows -n argo-events -w

# View workflow details to see retry attempts
WORKFLOW_NAME=$(kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d'/' -f2)
kubectl describe workflow $WORKFLOW_NAME -n argo-events
```

## Step 7: Multiple Triggers with Parameters

### Create Sensor with Multiple Coordinated Triggers

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: multi-trigger-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: webhook-event
      eventSourceName: workflow-trigger-source
      eventName: workflow-webhook
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "full-deploy"

  triggers:
    # Trigger 1: Build workflow
    - template:
        name: build-workflow
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: build-
                namespace: argo-events
              spec:
                entrypoint: build
                arguments:
                  parameters:
                    - name: app
                      value: "{{.Input.body.application}}"
                    - name: version
                      value: "{{.Input.body.version}}"
                templates:
                  - name: build
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - echo "Building {{workflow.parameters.app}}:{{workflow.parameters.version}}"

    # Trigger 2: Create deployment
    - template:
        name: create-k8s-resources
        k8s:
          operation: create
          source:
            resource:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: "{{.Input.body.application}}"
                namespace: default
              spec:
                replicas: 1
                selector:
                  matchLabels:
                    app: "{{.Input.body.application}}"
                template:
                  metadata:
                    labels:
                      app: "{{.Input.body.application}}"
                  spec:
                    containers:
                      - name: app
                        image: "{{.Input.body.image}}:{{.Input.body.version}}"

    # Trigger 3: Send notification
    - template:
        name: send-notification
        http:
          url: "http://echo-server.default.svc.cluster.local"
          method: POST
          payload:
            - src:
                dependencyName: webhook-event
                dataTemplate: |
                  {
                    "type": "deployment",
                    "application": "{{.Input.body.application}}",
                    "version": "{{.Input.body.version}}",
                    "status": "initiated"
                  }
              dest: body

    # Trigger 4: Log for debugging
    - template:
        name: log-event
        log:
          intervalSeconds: 1
EOF
```

### Test Multiple Triggers

```bash
# Trigger all actions at once
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "action": "full-deploy",
    "application": "my-web-app",
    "image": "nginx",
    "version": "alpine"
  }'

# Watch all resources being created
echo "=== Workflows ==="
kubectl get workflows -n argo-events

echo "=== Deployments ==="
kubectl get deployments -n default

# View sensor logs
kubectl logs -n argo-events -l sensor-name=multi-trigger-sensor --tail=50
```

## Step 8: Cleanup

### Stop Port Forwarding

```bash
# Kill port-forward process
kill $WEBHOOK_PID 2>/dev/null || true
pkill -f "port-forward.*workflow-trigger-source"
```

### Cleanup Test Resources

```bash
# Clean up deployments and services
kubectl delete deployment nginx-app my-web-app echo-server -n default --ignore-not-found
kubectl delete service nginx-app-svc echo-server -n default --ignore-not-found
kubectl delete configmap app-config -n default --ignore-not-found

# Clean up workflows
kubectl delete workflows --all -n argo-events

# Optional: Clean up sensors (keep for next lab)
# kubectl delete sensor --all -n argo-events
# kubectl delete eventsource workflow-trigger-source -n argo-events
```

### View All Resources

```bash
echo "=== Sensors ==="
kubectl get sensor -n argo-events

echo "=== EventSources ==="
kubectl get eventsource -n argo-events

echo "=== Remaining Workflows ==="
kubectl get workflows -n argo-events
```

## Verification Checklist

Ensure you have completed:

- [ ] Created Argo Workflow triggers with parameters
- [ ] Triggered DAG workflows from events
- [ ] Created Kubernetes Deployments dynamically
- [ ] Created Services and ConfigMaps from events
- [ ] Sent HTTP requests to external services
- [ ] Implemented conditional triggers
- [ ] Used trigger retry policies
- [ ] Chained multiple triggers in one sensor
- [ ] Extracted and passed event data to triggers
- [ ] Understand different trigger types and use cases

## Troubleshooting

### Workflow Not Created

```bash
# Check sensor logs
kubectl logs -n argo-events -l sensor-name=workflow-param-sensor

# Verify sensor has permissions
kubectl describe serviceaccount -n argo-events

# Check RBAC
kubectl get role,rolebinding -n argo-events
```

### HTTP Trigger Failing

```bash
# Check sensor logs for HTTP errors
kubectl logs -n argo-events -l sensor-name=http-trigger-sensor --tail=50

# Test HTTP endpoint manually
kubectl run curl-test --image=curlimages/curl -it --rm -- \
  curl -X POST http://echo-server.default.svc.cluster.local

# Check network policies
kubectl get networkpolicies -A
```

### Conditional Trigger Not Firing

```bash
# Check condition evaluation in sensor logs
kubectl logs -n argo-events -l sensor-name=conditional-trigger-sensor

# Verify condition syntax
kubectl get sensor conditional-trigger-sensor -n argo-events -o yaml

# Test with explicit values
curl -X POST http://localhost:12000/workflow \
  -H "Content-Type: application/json" \
  -d '{"environment": "production", "priority": "high"}'
```

### K8s Resource Creation Failed

```bash
# Check sensor logs for errors
kubectl logs -n argo-events -l sensor-name=k8s-resource-sensor

# Verify RBAC permissions for resource creation
kubectl auth can-i create deployments --as=system:serviceaccount:argo-events:argo-events-sa

# Check for resource conflicts
kubectl get deployments -A -l managed-by=argo-events
```

## Key Concepts Review

### Trigger Types

- **k8s**: Create/update/patch/delete Kubernetes resources
- **argoWorkflow**: Submit/resubmit Argo Workflows
- **http**: Send HTTP requests to external services
- **log**: Log events for debugging
- **kafka/nats**: Publish to message queues
- **awsLambda**: Invoke serverless functions

### Trigger Operations

- **create**: Create new resources
- **update**: Update existing resources
- **patch**: Patch resources
- **delete**: Delete resources

### Parameterization

- Extract data from event payload
- Use template expressions
- Pass parameters to workflows
- Build dynamic resource specs

### Conditional Execution

- Use conditions field for logic
- Access event data in conditions
- Boolean expressions supported
- Multiple conditions per sensor

### Error Handling

- Retry strategies for triggers
- Workflow-level retries
- Step-level retries
- Timeout configurations

## Additional Exercises

### Exercise 1: Slack Notification

Create an HTTP trigger that sends notifications to Slack webhook.

### Exercise 2: Update vs Create

Modify K8s trigger to update existing deployments instead of creating new ones.

### Exercise 3: Trigger Chaining

Create a sensor where one trigger's output becomes another's input.

### Exercise 4: External API Integration

Integrate with a real external API (e.g., GitHub API) using HTTP triggers.

## Next Steps

In the next lab, you will:

- Build end-to-end CI/CD automation
- Integrate GitHub webhooks
- Trigger Argo Workflows from Git events
- Deploy applications with Argo CD
- Implement complete GitOps workflow

Continue to [Lab 04: Integration](lab-04-integration.md)

## Summary

In this lab, you:

- Created parameterized Argo Workflow triggers
- Dynamically created Kubernetes resources from events
- Sent HTTP requests to external services
- Implemented conditional trigger execution
- Used retry policies for reliability
- Chained multiple triggers together
- Extracted and transformed event data

You now have a comprehensive understanding of Argo Events triggers and can build complex event-driven automation!
