# Lab 01: Installation and Basics

**Duration**: 25 minutes

**Difficulty**: Beginner

**Argo Events Version**: v1.9+ (tested with v1.9.10)

## Learning Objectives

By the end of this lab, you will be able to:

- Install Argo Events in a Kubernetes cluster
- Set up the event bus infrastructure using NATS
- Create your first webhook EventSource
- Create a basic Sensor to respond to events
- Trigger Argo Workflows from webhook events
- Understand the event flow from source to trigger

## Prerequisites

- Running Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl CLI installed and configured
- Argo Workflows installed (from previous labs)
- Basic understanding of Kubernetes resources
- curl or similar tool for testing webhooks

## Lab Architecture

In this lab, you'll build:

```
External System → Webhook EventSource → Event Bus (NATS) → Sensor → Argo Workflow
```

## Step 1: Install Argo Events

### Install Argo Events Core Components

```bash
# Create namespace for Argo Events
kubectl create namespace argo-events

# Install Argo Events core components
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml

# Install validating webhook (optional but recommended)
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml

# Verify installation
kubectl get pods -n argo-events
```

**Note**: The validating webhook is optional but recommended for production environments. It validates EventSource and Sensor configurations before they are applied to the cluster.

**Expected Output:**

```
NAME                                  READY   STATUS    RESTARTS   AGE
controller-manager-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

**Note**: Modern Argo Events (v1.9+) consolidates all controllers into a single `controller-manager` pod. Earlier versions had separate pods for eventbus-controller, eventsource-controller, and sensor-controller.

### Verify CRDs Installation

```bash
# Check installed Custom Resource Definitions
kubectl get crd | grep argoproj.io

# Specifically check Argo Events CRDs
kubectl get crd eventsources.argoproj.io
kubectl get crd sensors.argoproj.io
kubectl get crd eventbus.argoproj.io
```

**Understanding the Components:**

- **controller-manager**: Manages all Argo Events resources including EventBus, EventSource, and Sensor resources

## Step 2: Set Up Event Bus

The Event Bus is the messaging layer that connects EventSources to Sensors. It acts as the transport layer, enabling a publish-subscribe pattern where EventSources publish events and Sensors subscribe to them.

**Available EventBus implementations:**

- **NATS** (Deprecated - legacy option)
- **JetStream** (Recommended - modern NATS streaming)
- **Kafka** (For distributed streaming platforms)

This lab uses the **native** EventBus, which is JetStream-based and recommended for most use cases.

### Create Default Event Bus

```bash
# Create event bus in argo-events namespace
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    native:
      # Number of NATS replicas
      replicas: 3
      # Authentication strategy
      auth: token
EOF
```

### Verify Event Bus Status

```bash
# Check event bus resource
kubectl get eventbus -n argo-events

# Check event bus pods
kubectl get pods -n argo-events | grep eventbus

# View event bus details
kubectl describe eventbus default -n argo-events
```

**Expected Output:**

```
NAME      AGE
default   10s
```

The EventBus status can be checked with:

```bash
kubectl get eventbus default -n argo-events -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}{"\n"}'
```

Expected: `True`

### Wait for Event Bus to be Ready

```bash
# Wait for all eventbus pods to be running
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=eventbus -n argo-events --timeout=300s
```

**Key Concepts:**

- **Event Bus**: Acts as the transport layer between EventSources and Sensors
- **Native EventBus**: Uses JetStream (modern NATS streaming) for reliable event delivery
- **Publish-Subscribe Pattern**: EventSources publish events, Sensors subscribe to them
- **Replicas**: 3 replicas is the minimum for NATS clustering and high availability
- **Authentication**: Token-based auth secures communication between components

## Step 3: Create Your First Webhook EventSource

EventSources capture events from external systems. A webhook EventSource exposes an HTTP server that allows external entities to trigger workloads via HTTP requests. Argo Events supports 20+ EventSource types including webhooks, calendars, Kafka, cloud providers (AWS, GCP, Azure), and more.

### Create Webhook EventSource

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook-eventsource
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    # Define a webhook endpoint named "example"
    example:
      port: "12000"
      endpoint: /example
      method: POST
EOF
```

### Verify EventSource

```bash
# Check EventSource resource
kubectl get eventsource -n argo-events

# Check EventSource pods
kubectl get pods -n argo-events | grep webhook-eventsource

# View EventSource details
kubectl describe eventsource webhook-eventsource -n argo-events
```

### Expose EventSource Service

For testing, we'll expose the EventSource service locally:

```bash
# Port-forward the webhook service
kubectl port-forward -n argo-events svc/webhook-eventsource-eventsource-svc 12000:12000 &

# Store the process ID for later cleanup
WEBHOOK_PORT_FORWARD_PID=$!
```

**Understanding EventSource Configuration:**

- **service**: Exposes the EventSource as a Kubernetes Service
- **webhook.example**: Named webhook endpoint (can have multiple)
- **port**: Port on which the webhook listens
- **endpoint**: HTTP path for the webhook
- **method**: HTTP method (POST, GET, etc.)

## Step 4: Set Up RBAC for Sensors

Before creating sensors that trigger workflows, we need to configure proper permissions.

### Create Service Account and RBAC

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: operate-workflow-sa
  namespace: argo-events
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: operate-workflow-role
  namespace: argo-events
rules:
  - apiGroups:
      - argoproj.io
    resources:
      - workflows
      - workflowtemplates
      - cronworkflows
      - clusterworkflowtemplates
    verbs:
      - create
      - get
      - list
      - watch
      - update
      - patch
      - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operate-workflow-rolebinding
  namespace: argo-events
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: operate-workflow-role
subjects:
  - kind: ServiceAccount
    name: operate-workflow-sa
    namespace: argo-events
EOF
```

### Verify RBAC Configuration

```bash
# Check service account
kubectl get serviceaccount operate-workflow-sa -n argo-events

# Check role and rolebinding
kubectl get role operate-workflow-role -n argo-events
kubectl get rolebinding operate-workflow-rolebinding -n argo-events
```

### Copy Artifact Repository Credentials

If you completed the Argo Workflows labs, copy the MinIO credentials:

```bash
# Copy minio-credentials secret from argo namespace
kubectl get secret minio-credentials -n argo -o yaml | \
  sed 's/namespace: argo/namespace: argo-events/' | \
  kubectl apply -f -
```

**Note**: If you don't have MinIO set up, workflows will still run but won't be able to store artifacts.

## Step 5: Create a Basic Sensor

Sensors define a set of event dependencies (inputs) and triggers (outputs). They function as event dependency managers, listening to the EventBus and executing triggers when event conditions are met. Argo Events supports multiple trigger types including Argo Workflows, Kubernetes objects, HTTP requests, AWS Lambda, Kafka messages, and more.

### Create Sensor with Workflow Trigger

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-sensor
  namespace: argo-events
spec:
  # Use service account with workflow permissions
  template:
    serviceAccountName: operate-workflow-sa

  # Define event dependencies
  dependencies:
    - name: test-dep
      eventSourceName: webhook-eventsource
      eventName: example

  # Define triggers
  triggers:
    - template:
        name: webhook-workflow-trigger
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: webhook-workflow-
                namespace: argo-events
              spec:
                entrypoint: print-message
                arguments:
                  parameters:
                    - name: message
                      # Extract message from webhook payload
                      value: "hello from webhook"
                templates:
                  - name: print-message
                    inputs:
                      parameters:
                        - name: message
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "========================================="
                          echo "Message: {{inputs.parameters.message}}"
                          echo "========================================="
EOF
```

### Verify Sensor

```bash
# Check Sensor resource
kubectl get sensor -n argo-events

# Check Sensor pods
kubectl get pods -n argo-events | grep webhook-sensor

# View Sensor details
kubectl describe sensor webhook-sensor -n argo-events

# Check Sensor logs
kubectl logs -n argo-events -l sensor-name=webhook-sensor
```

**Understanding Sensor Configuration:**

- **template.serviceAccountName**: Service account for executing triggers (required for creating Kubernetes resources)
- **dependencies**: Event dependencies the sensor monitors (inputs)
- **eventSourceName**: References the EventSource to listen to
- **eventName**: Specific event within the EventSource
- **triggers**: Actions to execute when dependencies are satisfied (outputs)
- **k8s.operation**: Kubernetes operation (create, update, patch, delete)
- **trigger types**: Supports Argo Workflows, K8s objects, HTTP, Lambda, Kafka, Slack, and more

## Step 6: Test the Event Flow

Now let's trigger the webhook and watch the complete event flow.

### Send Test Webhook Event

```bash
# Send a POST request to the webhook endpoint
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from my first webhook"}' \
  http://localhost:12000/example

# Expected response: success
```

### Monitor Workflow Creation

```bash
# Watch for workflow creation
kubectl get workflows -n argo-events -w

# In another terminal, view workflow details
kubectl get workflows -n argo-events

# View specific workflow logs
WORKFLOW_NAME=$(kubectl get workflows -n argo-events -o name | tail -1 | cut -d'/' -f2)
kubectl logs -n argo-events $WORKFLOW_NAME
```

### View Sensor Logs

```bash
# Check sensor logs to see event processing
kubectl logs -n argo-events -l sensor-name=webhook-sensor --tail=50

# Expected log entries:
# - "Received event"
# - "Triggered workflow"
```

### Verify Workflow Execution

```bash
# List all workflows created by the sensor
kubectl get workflows -n argo-events -l workflows.argoproj.io/creator=webhook-sensor

# View workflow status
kubectl get workflow $WORKFLOW_NAME -n argo-events -o yaml | grep phase

# If using argo CLI, view workflow in UI
argo list -n argo-events
argo get $WORKFLOW_NAME -n argo-events
```

## Step 7: Understanding Event Data Flow

Let's trace the complete event flow to understand how data moves through the system.

### Examine EventSource Output

```bash
# View EventSource logs
kubectl logs -n argo-events -l eventsource-name=webhook-eventsource --tail=20

# You should see:
# - Webhook server started
# - Received HTTP request
# - Published event to event bus
```

### Examine Event Bus

```bash
# View event bus stats
kubectl get pods -n argo-events | grep eventbus-default

# Connect to NATS pod to view subjects
NATS_POD=$(kubectl get pods -n argo-events -l app.kubernetes.io/component=eventbus -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n argo-events $NATS_POD -- nats-server --help
```

### Examine Sensor Processing

```bash
# View sensor logs with more detail
kubectl logs -n argo-events -l sensor-name=webhook-sensor --tail=50 -f

# Send another webhook to see real-time processing
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"message": "Testing event flow"}' \
  http://localhost:12000/example
```

## Step 8: Enhanced Sensor with Parameterization

Let's create a more advanced sensor that extracts data from the webhook payload.

### Create Enhanced Sensor

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-sensor-enhanced
  namespace: argo-events
spec:
  template:
    serviceAccountName: operate-workflow-sa

  dependencies:
    - name: webhook-dep
      eventSourceName: webhook-eventsource
      eventName: example

  triggers:
    - template:
        name: parameterized-workflow
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: webhook-param-
                namespace: argo-events
              spec:
                entrypoint: process-data
                arguments:
                  parameters:
                    - name: message
                      # Extract from webhook body
                      value: "{{.Input.body.message}}"
                    - name: user
                      # Extract user from webhook body with default
                      value: "{{.Input.body.user | default \"anonymous\"}}"
                    - name: timestamp
                      # Add event timestamp
                      value: "{{.Input.context.time}}"
                templates:
                  - name: process-data
                    inputs:
                      parameters:
                        - name: message
                        - name: user
                        - name: timestamp
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Message: {{inputs.parameters.message}}"
                          echo "User: {{inputs.parameters.user}}"
                          echo "Timestamp: {{inputs.parameters.timestamp}}"
                          echo "Processing complete!"
EOF
```

### Test Enhanced Sensor

```bash
# Delete the old sensor to avoid conflicts
kubectl delete sensor webhook-sensor -n argo-events

# Send webhook with parameters
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello from enhanced webhook",
    "user": "admin",
    "priority": "high"
  }' \
  http://localhost:12000/example

# View the triggered workflow
sleep 5
WORKFLOW_NAME=$(kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d'/' -f2)
kubectl logs -n argo-events $WORKFLOW_NAME
```

**Key Parameterization Concepts:**

- **{{.Input.body.*}}**: Access webhook request body fields
- **{{.Input.context.*}}**: Access event metadata (time, source, etc.)
- **default function**: Provide default values for missing fields
- **Template expressions**: Use Go template syntax for data extraction

## Step 9: Cleanup and Verification

### Stop Port Forwarding

```bash
# Kill the port-forward process
kill $WEBHOOK_PORT_FORWARD_PID 2>/dev/null || true

# Verify it's stopped
ps aux | grep port-forward | grep -v grep
```

### View All Created Resources

```bash
# List all Argo Events resources
echo "=== EventSources ==="
kubectl get eventsource -n argo-events

echo "=== Sensors ==="
kubectl get sensor -n argo-events

echo "=== Event Bus ==="
kubectl get eventbus -n argo-events

echo "=== Workflows Created ==="
kubectl get workflows -n argo-events
```

### Optional: Cleanup Resources

```bash
# If you want to clean up for the next lab
# Note: Don't run this if continuing to the next lab

# Delete sensors and eventsources
kubectl delete sensor --all -n argo-events
kubectl delete eventsource --all -n argo-events

# Delete workflows
kubectl delete workflows --all -n argo-events

# Keep the event bus for next lab
# kubectl delete eventbus default -n argo-events
```

## Verification Checklist

Ensure you have completed:

- [ ] Argo Events controllers are running
- [ ] Event bus is created and ready
- [ ] Webhook EventSource is created and accessible
- [ ] Basic Sensor is created and running
- [ ] Successfully sent webhook event via curl
- [ ] Workflow was automatically created
- [ ] Workflow executed successfully
- [ ] Enhanced sensor with parameterization works
- [ ] Can extract data from webhook payload
- [ ] Understand the event flow: EventSource → Event Bus → Sensor → Trigger

## Troubleshooting

### EventSource Pod Not Starting

```bash
# Check EventSource pod logs
kubectl logs -n argo-events -l eventsource-name=webhook-eventsource

# Common issues:
# - Event bus not ready
# - Port conflicts
# - Resource limits
```

### Sensor Not Triggering

```bash
# Check sensor logs
kubectl logs -n argo-events -l sensor-name=webhook-sensor-enhanced

# Verify event dependency
kubectl describe sensor webhook-sensor-enhanced -n argo-events

# Check if events are being received
kubectl logs -n argo-events -l eventsource-name=webhook-eventsource
```

### Workflow Not Created

```bash
# Check sensor has permissions
kubectl get serviceaccount -n argo-events
kubectl describe role -n argo-events

# Check sensor trigger configuration
kubectl get sensor webhook-sensor-enhanced -n argo-events -o yaml
```

### Port Forward Issues

```bash
# Check if port is already in use
lsof -i :12000

# Use a different local port
kubectl port-forward -n argo-events svc/webhook-eventsource-eventsource-svc 12001:12000 &
```

## Key Concepts Review

### Event Bus Architecture

- Acts as the transport layer for Argo Events
- Implements publish-subscribe pattern
- Native EventBus uses JetStream (modern NATS streaming)
- Decouples EventSources (publishers) from Sensors (subscribers)
- Provides reliable event delivery with persistence
- Minimum 3 replicas for NATS clustering and high availability

### EventSource Types

Argo Events supports 20+ EventSource types:

- **Webhook**: HTTP endpoints for external systems
- **Calendar**: Time-based events (cron schedules, intervals)
- **Resource**: Kubernetes resource changes
- **Cloud Providers**: AWS (SNS, SQS, S3), GCP (Pub/Sub), Azure (Event Hubs)
- **Message Queues**: Kafka, NATS, MQTT, Redis, RabbitMQ, AMQP
- **Git**: GitHub, GitLab, Bitbucket webhooks
- **Storage**: S3, GCS, Minio

### Sensor Components

- **Dependencies**: Event dependencies to monitor (inputs) - defines which events to wait for
- **Triggers**: Actions to execute when conditions are met (outputs)
- **Filters**: Control which events to process based on conditions
- **Parameterization**: Extract and pass event data using Go templates
- **ServiceAccount**: Required for creating Kubernetes resources

### Event Flow

1. External system sends event to EventSource
2. EventSource publishes event to Event Bus
3. Sensor subscribes to and receives event from Event Bus
4. Sensor evaluates dependencies and filters
5. Sensor executes configured triggers (creates workflows, K8s objects, HTTP calls, etc.)

## Additional Exercises

### Exercise 1: Multiple Webhooks

Create an EventSource with multiple webhook endpoints:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: multi-webhook
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    endpoint1:
      port: "12000"
      endpoint: /webhook1
      method: POST
    endpoint2:
      port: "12000"
      endpoint: /webhook2
      method: POST
EOF
```

Create sensors for each endpoint and test them independently.

### Exercise 2: Workflow with Artifacts

Modify the sensor to trigger a workflow that processes data and outputs artifacts:

```yaml
# Add to workflow template
outputs:
  artifacts:
    - name: results
      path: /tmp/results.txt
```

### Exercise 3: Event Logging

Create a sensor with a log trigger to debug event data:

```yaml
triggers:
  - template:
      name: log-trigger
      log:
        intervalSeconds: 1
```

## Next Steps

In the next lab, you will:

- Explore different EventSource types (calendar, resource)
- Implement event filtering
- Work with multiple event dependencies
- Use different trigger types

Continue to [Lab 02: Event Sources](lab-02-event-sources.md)

## Summary

In this lab, you:

- Installed Argo Events and its core components
- Set up NATS-based Event Bus infrastructure
- Created a webhook EventSource to receive HTTP events
- Built a Sensor to trigger Argo Workflows from events
- Tested the complete event-driven flow
- Learned event data extraction and parameterization
- Understood the architecture and component interactions

You now have a working Argo Events installation and understand the basics of event-driven workflow automation!
