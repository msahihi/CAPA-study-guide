# Lab 02: Event Source Types

**Duration**: 35 minutes

**Difficulty**: Intermediate

## Learning Objectives

By the end of this lab, you will be able to:

- Create and configure calendar-based EventSources
- Set up resource EventSources to watch Kubernetes objects
- Implement event filtering at the dependency level
- Work with multiple event dependencies in sensors
- Use data filters to process specific events
- Combine different event source types
- Understand event context and metadata

## Prerequisites

- Completed Lab 01: Installation and Basics
- Argo Events installed with Event Bus running
- kubectl access to the cluster
- Basic understanding of cron expressions
- Familiarity with Kubernetes resource watching

## Lab Architecture

In this lab, you'll build:

```
Calendar EventSource ──┐
                       ├──> Event Bus ──> Multi-Dependency Sensor ──> Workflow
Resource EventSource ──┘
```

## Step 1: Calendar EventSource Basics

Calendar EventSources generate time-based events using cron expressions or intervals.

### Create Simple Calendar EventSource

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: calendar-eventsource
  namespace: argo-events
spec:
  calendar:
    # Schedule that runs every 2 minutes
    every-2min:
      schedule: "*/2 * * * *"
      timezone: UTC
      # Optional metadata to include in events
      metadata:
        name: "scheduled-event"
        type: "recurring"
EOF
```

### Verify Calendar EventSource

```bash
# Check EventSource status
kubectl get eventsource calendar-eventsource -n argo-events

# View EventSource pods
kubectl get pods -n argo-events | grep calendar

# Check logs to see schedule processing
kubectl logs -n argo-events -l eventsource-name=calendar-eventsource --tail=20
```

### Create Sensor for Calendar Events

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: calendar-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: calendar-dep
      eventSourceName: calendar-eventsource
      eventName: every-2min

  triggers:
    - template:
        name: scheduled-workflow
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: scheduled-
                namespace: argo-events
              spec:
                entrypoint: scheduled-task
                templates:
                  - name: scheduled-task
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Scheduled task executed at: $(date)"
                          echo "Event time: {{.Input.context.time}}"
                          echo "Task completed successfully"
EOF
```

### Monitor Calendar-Triggered Workflows

```bash
# Watch for workflows being created every 2 minutes
watch -n 10 kubectl get workflows -n argo-events

# Or use kubectl with watch flag
kubectl get workflows -n argo-events -w

# View sensor logs
kubectl logs -n argo-events -l sensor-name=calendar-sensor -f
```

**Understanding Calendar Events:**

- Schedule follows cron format: `minute hour day month weekday`
- Timezone ensures consistent scheduling across regions
- Events fire automatically based on schedule
- No external trigger needed

## Step 2: Advanced Calendar Configurations

### Create Multiple Calendar Schedules

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: calendar-multi
  namespace: argo-events
spec:
  calendar:
    # Every 5 minutes
    frequent:
      schedule: "*/5 * * * *"
      timezone: UTC
      metadata:
        frequency: "high"

    # Every hour at minute 0
    hourly:
      schedule: "0 * * * *"
      timezone: UTC
      metadata:
        frequency: "medium"

    # Daily at 2 AM
    daily:
      schedule: "0 2 * * *"
      timezone: America/New_York
      metadata:
        frequency: "low"

    # Using interval instead of cron (every 3 minutes)
    interval-based:
      interval: 3m
      metadata:
        type: "interval"
EOF
```

### Create Sensor with Schedule Filtering

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: calendar-filtered-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: frequent-event
      eventSourceName: calendar-multi
      eventName: frequent
      # Filter based on event metadata
      filters:
        data:
          - path: metadata.frequency
            type: string
            value:
              - "high"

  triggers:
    - template:
        name: frequent-task
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: frequent-task-
                namespace: argo-events
              spec:
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: alpine:latest
                      command: [echo, "Frequent task execution"]
EOF
```

**Calendar Best Practices:**

- Use UTC timezone for consistency unless specific local time is required
- Consider cluster timezone for scheduling
- Use intervals for simple recurring tasks
- Use cron for complex scheduling patterns

## Step 3: Resource EventSource

Resource EventSources watch Kubernetes resources for changes (ADD, UPDATE, DELETE).

### Create Resource EventSource for Pods

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: resource-eventsource
  namespace: argo-events
spec:
  resource:
    # Watch pod events
    pod-events:
      namespace: default
      group: ""
      version: v1
      resource: pods
      eventTypes:
        - ADD
        - UPDATE
        - DELETE
      # Optional: filter by labels
      filter:
        labels:
          - key: monitored
            operation: "=="
            value: "true"
EOF
```

### Create Test Pod with Label

```bash
# Create a pod that will be monitored
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
  labels:
    monitored: "true"
    app: test
spec:
  containers:
    - name: nginx
      image: nginx:alpine
      ports:
        - containerPort: 80
EOF
```

### Create Sensor for Resource Events

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: resource-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: pod-created
      eventSourceName: resource-eventsource
      eventName: pod-events
      # Filter only ADD events
      filters:
        data:
          - path: type
            type: string
            value:
              - "ADD"

  triggers:
    - template:
        name: pod-created-notification
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: pod-created-
                namespace: argo-events
              spec:
                entrypoint: notify
                arguments:
                  parameters:
                    - name: pod-name
                      value: "{{.Input.body.metadata.name}}"
                    - name: pod-namespace
                      value: "{{.Input.body.metadata.namespace}}"
                    - name: pod-labels
                      value: "{{.Input.body.metadata.labels}}"
                templates:
                  - name: notify
                    inputs:
                      parameters:
                        - name: pod-name
                        - name: pod-namespace
                        - name: pod-labels
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "New pod detected!"
                          echo "Name: {{inputs.parameters.pod-name}}"
                          echo "Namespace: {{inputs.parameters.pod-namespace}}"
                          echo "Labels: {{inputs.parameters.pod-labels}}"
EOF
```

### Test Resource EventSource

```bash
# Create another test pod to trigger the event
kubectl run test-pod-2 --image=nginx:alpine -l monitored=true

# Watch for workflow creation
kubectl get workflows -n argo-events -w

# View the workflow logs
sleep 5
WORKFLOW_NAME=$(kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d'/' -f2)
kubectl logs -n argo-events $WORKFLOW_NAME

# Check resource EventSource logs
kubectl logs -n argo-events -l eventsource-name=resource-eventsource --tail=30
```

## Step 4: Advanced Resource Watching

### Watch Deployments with Field Filters

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: deployment-watcher
  namespace: argo-events
spec:
  resource:
    deployment-events:
      namespace: default
      group: apps
      version: v1
      resource: deployments
      eventTypes:
        - ADD
        - UPDATE
      # Label filter
      filter:
        labels:
          - key: environment
            operation: "=="
            value: "production"
        # Optional: add more sophisticated filtering
        afterStart: true
EOF
```

### Create Sensor with Data Filtering

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: deployment-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: deployment-update
      eventSourceName: deployment-watcher
      eventName: deployment-events
      # Advanced data filtering
      filters:
        data:
          # Only trigger when replicas change
          - path: body.spec.replicas
            type: number
            comparator: ">"
            value:
              - "0"

  triggers:
    - template:
        name: deployment-alert
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: deployment-alert-
                namespace: argo-events
              spec:
                entrypoint: alert
                arguments:
                  parameters:
                    - name: deployment-name
                      value: "{{.Input.body.metadata.name}}"
                    - name: replicas
                      value: "{{.Input.body.spec.replicas}}"
                    - name: event-type
                      value: "{{.Input.type}}"
                templates:
                  - name: alert
                    inputs:
                      parameters:
                        - name: deployment-name
                        - name: replicas
                        - name: event-type
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Deployment Event Alert"
                          echo "======================"
                          echo "Deployment: {{inputs.parameters.deployment-name}}"
                          echo "Replicas: {{inputs.parameters.replicas}}"
                          echo "Event Type: {{inputs.parameters.event-type}}"
EOF
```

### Test Deployment Watching

```bash
# Create a deployment to watch
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitored-app
  namespace: default
  labels:
    environment: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: monitored
  template:
    metadata:
      labels:
        app: monitored
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
EOF

# Scale the deployment to trigger UPDATE event
kubectl scale deployment monitored-app --replicas=3

# Watch for triggered workflows
kubectl get workflows -n argo-events -w
```

## Step 5: Event Filtering Techniques

### Create EventSource with Multiple Events

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook-multi
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    production:
      port: "12000"
      endpoint: /production
      method: POST
    staging:
      port: "12000"
      endpoint: /staging
      method: POST
    development:
      port: "12000"
      endpoint: /development
      method: POST
EOF
```

### Create Sensor with Complex Filters

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: filtered-webhook-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: prod-event
      eventSourceName: webhook-multi
      eventName: production
      # Filter based on payload data
      filters:
        data:
          # Check if action is "deploy"
          - path: body.action
            type: string
            value:
              - "deploy"
          # Check if branch is main or master
          - path: body.branch
            type: string
            value:
              - "main"
              - "master"
        # Expression-based filter
        exprs:
          - expr: "body.priority == 'high' || body.urgent == true"
            fields:
              - name: "body.priority"
                path: "body.priority"
              - name: "body.urgent"
                path: "body.urgent"

  triggers:
    - template:
        name: production-deployment
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
                entrypoint: deploy
                arguments:
                  parameters:
                    - name: action
                      value: "{{.Input.body.action}}"
                    - name: branch
                      value: "{{.Input.body.branch}}"
                    - name: commit
                      value: "{{.Input.body.commit | default \"HEAD\"}}"
                templates:
                  - name: deploy
                    inputs:
                      parameters:
                        - name: action
                        - name: branch
                        - name: commit
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Production Deployment"
                          echo "Action: {{inputs.parameters.action}}"
                          echo "Branch: {{inputs.parameters.branch}}"
                          echo "Commit: {{inputs.parameters.commit}}"
EOF
```

### Test Filtering

```bash
# Port forward the webhook service
kubectl port-forward -n argo-events svc/webhook-multi-eventsource-svc 12000:12000 &

# Test 1: Valid event (should trigger)
curl -X POST http://localhost:12000/production \
  -H "Content-Type: application/json" \
  -d '{
    "action": "deploy",
    "branch": "main",
    "priority": "high",
    "commit": "abc123"
  }'

# Test 2: Invalid event (should NOT trigger - wrong branch)
curl -X POST http://localhost:12000/production \
  -H "Content-Type: application/json" \
  -d '{
    "action": "deploy",
    "branch": "feature",
    "priority": "high"
  }'

# Test 3: Invalid event (should NOT trigger - wrong action)
curl -X POST http://localhost:12000/production \
  -H "Content-Type: application/json" \
  -d '{
    "action": "test",
    "branch": "main",
    "priority": "high"
  }'

# Check workflows - should only see one from Test 1
kubectl get workflows -n argo-events

# Stop port forward
pkill -f "port-forward.*webhook-multi"
```

**Filter Types:**

- **data filters**: Check specific fields in event payload
- **context filters**: Check event metadata (source, time, etc.)
- **exprs filters**: Complex boolean expressions

## Step 6: Multiple Event Dependencies

Sensors can wait for multiple events before triggering.

### Create Multi-Dependency Sensor

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: multi-dependency-sensor
  namespace: argo-events
spec:
  # Require ALL dependencies to be satisfied
  dependencies:
    - name: webhook-dep
      eventSourceName: webhook-multi
      eventName: production
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "ready"

    - name: calendar-dep
      eventSourceName: calendar-multi
      eventName: hourly

  # Optional: dependency logic
  # Default is AND (all dependencies required)
  # Can also use OR logic

  triggers:
    - template:
        name: multi-event-workflow
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: multi-event-
                namespace: argo-events
              spec:
                entrypoint: combined
                arguments:
                  parameters:
                    - name: webhook-data
                      value: "{{.Input.webhook-dep.body | toJson}}"
                    - name: calendar-time
                      value: "{{.Input.calendar-dep.context.time}}"
                templates:
                  - name: combined
                    inputs:
                      parameters:
                        - name: webhook-data
                        - name: calendar-time
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Multi-Event Trigger"
                          echo "==================="
                          echo "Webhook Data: {{inputs.parameters.webhook-data}}"
                          echo "Calendar Time: {{inputs.parameters.calendar-time}}"
                          echo "Both events received!"
EOF
```

### Test Multi-Dependency

```bash
# This sensor needs BOTH a webhook AND the hourly calendar event
# Test by sending webhook and waiting for the next hourly trigger

# Port forward
kubectl port-forward -n argo-events svc/webhook-multi-eventsource-svc 12000:12000 &

# Send webhook
curl -X POST http://localhost:12000/production \
  -H "Content-Type: application/json" \
  -d '{"action": "ready", "message": "System ready"}'

# Watch sensor logs to see dependency status
kubectl logs -n argo-events -l sensor-name=multi-dependency-sensor -f

# The workflow will trigger when the hourly calendar event fires
# (at the top of the next hour)

# Stop port forward
pkill -f "port-forward.*webhook-multi"
```

### Create OR-Based Dependencies

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: or-dependency-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: webhook-prod
      eventSourceName: webhook-multi
      eventName: production

    - name: webhook-staging
      eventSourceName: webhook-multi
      eventName: staging

  # Use dependency groups for OR logic
  dependencyGroups:
    - name: either-environment
      dependencies:
        - webhook-prod
        - webhook-staging
      # OR logic: trigger if ANY dependency is met
      expression: "webhook-prod || webhook-staging"

  triggers:
    - template:
        name: any-environment-workflow
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: any-env-
                namespace: argo-events
              spec:
                entrypoint: main
                templates:
                  - name: main
                    container:
                      image: alpine:latest
                      command: [echo, "Triggered by either production or staging"]
EOF
```

## Step 7: Event Data Transformation

Transform event data before passing to triggers.

### Create Sensor with Transformations

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: transformation-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: webhook-dep
      eventSourceName: webhook-multi
      eventName: production
      # Transform event data using jq
      transform:
        jq: |
          {
            deploymentName: .body.app,
            version: .body.version,
            environment: "production",
            timestamp: .context.time,
            fullRef: (.body.app + ":" + .body.version)
          }

  triggers:
    - template:
        name: transformed-workflow
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: transformed-
                namespace: argo-events
              spec:
                entrypoint: deploy
                arguments:
                  parameters:
                    - name: deployment-name
                      value: "{{.Input.webhook-dep.deploymentName}}"
                    - name: version
                      value: "{{.Input.webhook-dep.version}}"
                    - name: full-ref
                      value: "{{.Input.webhook-dep.fullRef}}"
                templates:
                  - name: deploy
                    inputs:
                      parameters:
                        - name: deployment-name
                        - name: version
                        - name: full-ref
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Transformed Deployment"
                          echo "Name: {{inputs.parameters.deployment-name}}"
                          echo "Version: {{inputs.parameters.version}}"
                          echo "Full Ref: {{inputs.parameters.full-ref}}"
EOF
```

### Test Transformation

```bash
# Port forward
kubectl port-forward -n argo-events svc/webhook-multi-eventsource-svc 12000:12000 &

# Send webhook with app and version
curl -X POST http://localhost:12000/production \
  -H "Content-Type: application/json" \
  -d '{
    "app": "my-app",
    "version": "v1.2.3",
    "action": "deploy"
  }'

# Check workflow logs to see transformed data
sleep 5
WORKFLOW_NAME=$(kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d'/' -f2)
kubectl logs -n argo-events $WORKFLOW_NAME

# Stop port forward
pkill -f "port-forward.*webhook-multi"
```

## Step 8: Cleanup and Resource Review

### View All EventSources

```bash
echo "=== EventSources ==="
kubectl get eventsource -n argo-events

echo "\n=== EventSource Details ==="
kubectl get eventsource -n argo-events -o custom-columns=\
NAME:.metadata.name,\
TYPE:.spec.keys,\
AGE:.metadata.creationTimestamp
```

### View All Sensors

```bash
echo "=== Sensors ==="
kubectl get sensor -n argo-events

echo "\n=== Sensor Details ==="
kubectl get sensor -n argo-events -o custom-columns=\
NAME:.metadata.name,\
DEPENDENCIES:.spec.dependencies[*].eventSourceName,\
AGE:.metadata.creationTimestamp
```

### Cleanup Test Resources

```bash
# Clean up test pods and deployments
kubectl delete pod test-pod test-pod-2 --ignore-not-found
kubectl delete deployment monitored-app --ignore-not-found

# Optional: Clean up EventSources and Sensors
# (Keep them if continuing to next lab)
# kubectl delete eventsource calendar-eventsource calendar-multi -n argo-events
# kubectl delete sensor calendar-sensor calendar-filtered-sensor -n argo-events
```

## Verification Checklist

Ensure you have completed:

- [ ] Created calendar EventSource with cron schedule
- [ ] Calendar events trigger workflows automatically
- [ ] Created resource EventSource to watch pods
- [ ] Resource changes trigger workflows
- [ ] Implemented data filters on event payloads
- [ ] Used expression-based filters
- [ ] Created multi-dependency sensor
- [ ] Tested AND logic for dependencies
- [ ] Implemented event data transformation
- [ ] Understand different EventSource types

## Troubleshooting

### Calendar Events Not Firing

```bash
# Check calendar EventSource logs
kubectl logs -n argo-events -l eventsource-name=calendar-eventsource

# Verify schedule format (use crontab.guru for validation)
# Check timezone configuration

# Common issues:
# - Invalid cron expression
# - Timezone mismatch
# - EventSource pod not running
```

### Resource Events Not Detected

```bash
# Check resource EventSource logs
kubectl logs -n argo-events -l eventsource-name=resource-eventsource

# Verify RBAC permissions
kubectl get serviceaccount -n argo-events
kubectl describe role -n argo-events

# Check if resources match filter criteria
kubectl get pods -l monitored=true
```

### Filters Not Working

```bash
# Check sensor logs for filter evaluation
kubectl logs -n argo-events -l sensor-name=filtered-webhook-sensor

# View full event data to verify filter paths
kubectl logs -n argo-events -l eventsource-name=webhook-multi

# Test jq expressions separately
echo '{"body": {"action": "deploy"}}' | jq '.body.action'
```

## Key Concepts Review

### EventSource Types

- **Calendar**: Time-based events using cron or intervals
- **Resource**: Watch Kubernetes resources for changes
- **Webhook**: HTTP endpoints for external events
- Multiple event sources in single EventSource CRD

### Event Filtering

- **Data filters**: Match specific payload values
- **Context filters**: Match event metadata
- **Expression filters**: Complex boolean logic
- Filters applied at dependency level in Sensor

### Event Dependencies

- **AND logic**: All dependencies must be satisfied
- **OR logic**: Any dependency can satisfy
- **Dependency groups**: Complex dependency logic
- Event data available from each dependency

### Event Transformation

- Use jq for data manipulation
- Transform before passing to triggers
- Create new fields or restructure data
- Helpful for adapting event formats

## Additional Exercises

### Exercise 1: ConfigMap Watcher

Create a resource EventSource that watches ConfigMaps and triggers when specific configs change.

### Exercise 2: Business Hours Calendar

Create a calendar EventSource that only fires during business hours (9 AM - 5 PM, Monday-Friday).

### Exercise 3: Multi-Environment Filter

Create a sensor that handles different environments with different filters and triggers.

## Next Steps

In the next lab, you will:

- Work with different trigger types
- Trigger Argo Workflows with parameters
- Create Kubernetes resources dynamically
- Use HTTP triggers for external systems
- Implement conditional triggers

Continue to [Lab 03: Triggers](lab-03-triggers.md)

## Summary

In this lab, you:

- Created calendar EventSources for time-based automation
- Set up resource EventSources to watch Kubernetes objects
- Implemented sophisticated event filtering
- Worked with multiple event dependencies
- Used event data transformation
- Combined different event source types

You now understand the various EventSource types and how to filter and process events effectively!
