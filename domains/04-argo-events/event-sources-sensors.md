# Event Sources and Sensors

## Overview

Argo Events uses two primary Custom Resource Definitions (CRDs) to implement event-driven automation: EventSource and Sensor. EventSources capture events from various sources and publish them to the event bus, while Sensors listen to events on the event bus and trigger actions based on defined conditions. This separation of concerns allows for flexible, scalable, and maintainable event-driven architectures.

## Key Topics

### EventSource CRD

The EventSource is a Kubernetes custom resource that defines where events come from and how to capture them.

**EventSource Structure:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook-example
  namespace: argo-events
spec:
  # Event source type configuration
  webhook:
    example:
      port: "12000"
      endpoint: /example
      method: POST
  # Service specification for exposing the event source
  service:
    ports:
      - port: 12000
        targetPort: 12000
```

**Key Components:**

- **metadata**: Standard Kubernetes metadata (name, namespace, labels)
- **spec**: Defines the event source type and configuration
- **service**: Optional service configuration for exposing event sources
- **eventSourceType**: The type of event source (webhook, calendar, resource, etc.)

### Event Source Types

Argo Events supports multiple event source types for different use cases.

**Webhook Event Source:**

Exposes HTTP endpoints to receive webhook events from external systems.

```yaml
spec:
  webhook:
    github-webhook:
      port: "12000"
      endpoint: /github
      method: POST
      # Optional: URL validation
      url: "https://my-domain.com/github"
```

**Calendar Event Source:**

Generates events based on time schedules using cron expressions or intervals.

```yaml
spec:
  calendar:
    example-schedule:
      # Cron schedule (every 5 minutes)
      schedule: "*/5 * * * *"
      # Timezone
      timezone: America/New_York
      # Optional: Event data
      metadata:
        name: "scheduled-event"
```

**Resource Event Source:**

Watches Kubernetes resources for changes (create, update, delete).

```yaml
spec:
  resource:
    example-resource:
      namespace: default
      group: ""
      version: v1
      resource: pods
      # Event types to watch
      eventTypes:
        - ADD
        - UPDATE
        - DELETE
      # Optional: Label selector
      filter:
        labels:
          - key: app
            operation: "=="
            value: myapp
```

**Message Queue Event Sources:**

Connect to message queues like Kafka, NATS, AWS SNS/SQS, GCP Pub/Sub, Azure Event Hubs.

```yaml
spec:
  kafka:
    example-topic:
      url: kafka-broker.default.svc:9092
      topic: mytopic
      partition: "0"
      # Consumer group
      consumerGroup:
        groupName: argo-events-consumer
        rebalanceStrategy: range
```

**Other Event Source Types:**

- **GitHub**: GitHub webhook events (push, pull_request, issues, etc.)
- **GitLab**: GitLab webhook events
- **Slack**: Slack events API
- **AWS SNS/SQS**: AWS messaging services
- **GCP Pub/Sub**: Google Cloud messaging
- **Azure Event Hubs**: Azure messaging
- **Redis**: Redis Pub/Sub and streams
- **AMQP**: RabbitMQ and other AMQP brokers
- **File**: Watch file system changes
- **HDFS**: Hadoop Distributed File System events

### Sensor CRD

The Sensor is a Kubernetes custom resource that defines event dependencies and triggers actions when events are received.

**Sensor Structure:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-sensor
  namespace: argo-events
spec:
  # Event dependencies - what events to listen for
  dependencies:
    - name: test-dep
      eventSourceName: webhook-example
      eventName: example
  # Triggers - what actions to take
  triggers:
    - template:
        name: workflow-trigger
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: webhook-workflow-
              spec:
                entrypoint: whalesay
                templates:
                  - name: whalesay
                    container:
                      image: docker/whalesay:latest
                      command: [cowsay]
                      args: ["hello from webhook"]
```

**Key Components:**

- **dependencies**: List of event dependencies (required events)
- **triggers**: List of actions to execute when dependencies are satisfied
- **template**: Defines the trigger action type and configuration

### Event Dependencies

Sensors define dependencies on events from event sources.

**Simple Dependency:**

```yaml
dependencies:
  - name: webhook-dep
    eventSourceName: webhook-source
    eventName: example
```

**Multiple Dependencies:**

Sensors can wait for multiple events before triggering.

```yaml
dependencies:
  - name: github-push
    eventSourceName: github
    eventName: push-event
  - name: approval-webhook
    eventSourceName: approval-webhook
    eventName: approved
```

**Dependency Filters:**

Filter events based on data, context, or expressions.

```yaml
dependencies:
  - name: filtered-event
    eventSourceName: webhook-source
    eventName: example
    # Data filter - check event payload
    filters:
      data:
        - path: body.repository.name
          type: string
          value:
            - "my-repo"
```

**Filter Types:**

- **data**: Filter based on event payload data
- **context**: Filter based on event context (source, subject, time)
- **exprs**: Filter using complex expressions with multiple conditions

### Event Processing

**Event Data Extraction:**

Extract data from events to pass to triggers.

```yaml
triggers:
  - template:
      name: workflow-trigger
      k8s:
        operation: create
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: webhook-workflow-
            spec:
              arguments:
                parameters:
                  # Extract data from event payload
                  - name: repo-name
                    value: "{{.Input.body.repository.name}}"
                  - name: commit-sha
                    value: "{{.Input.body.head_commit.id}}"
```

**Event Transformation:**

Transform event data before passing to triggers.

```yaml
dependencies:
  - name: webhook-dep
    eventSourceName: webhook-source
    eventName: example
    # Transform event data
    transform:
      jq: |
        {
          repository: .body.repository.name,
          branch: .body.ref | split("/") | .[-1],
          author: .body.head_commit.author.name
        }
```

### Sensor Triggers

Sensors support multiple trigger types for different actions.

**Available Trigger Types:**

- **k8s**: Create/update Kubernetes resources
- **argoWorkflow**: Trigger Argo Workflows (specialized K8s trigger)
- **http**: Send HTTP requests
- **awsLambda**: Invoke AWS Lambda functions
- **kafka**: Publish to Kafka topics
- **nats**: Publish to NATS subjects
- **slack**: Send Slack messages
- **log**: Log events (for debugging)
- **custom**: Custom trigger implementations

**Trigger Conditions:**

Execute triggers conditionally based on event data.

```yaml
triggers:
  - template:
      name: conditional-trigger
      conditions: "branch == 'main'"
      k8s:
        operation: create
        source:
          resource:
            # Kubernetes resource spec
```

## Practice Examples

### Example 1: Simple Webhook EventSource

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    example:
      port: "12000"
      endpoint: /example
      method: POST
```

### Example 2: GitHub EventSource

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  github:
    example:
      # Repository owner
      owner: myorg
      # Repository name
      repository: myrepo
      # Webhook events to capture
      events:
        - push
        - pull_request
      # GitHub webhook configuration
      webhook:
        endpoint: /push
        port: "12000"
        method: POST
        url: "https://webhook.example.com"
      # GitHub API token (from secret)
      apiToken:
        name: github-access
        key: token
      # Webhook secret for validation
      webhookSecret:
        name: github-access
        key: secret
```

### Example 3: Resource EventSource

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: resource
  namespace: argo-events
spec:
  resource:
    deployment-events:
      namespace: production
      group: apps
      version: v1
      resource: deployments
      eventTypes:
        - ADD
        - UPDATE
      filter:
        labels:
          - key: monitor
            operation: "=="
            value: "true"
```

### Example 4: Calendar EventSource

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: calendar
  namespace: argo-events
spec:
  calendar:
    daily-backup:
      # Every day at 2 AM
      schedule: "0 2 * * *"
      timezone: UTC
      metadata:
        name: daily-backup
```

### Example 5: Sensor with Workflow Trigger

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-workflow
  namespace: argo-events
spec:
  dependencies:
    - name: webhook-dep
      eventSourceName: webhook
      eventName: example
  triggers:
    - template:
        name: trigger-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: webhook-workflow-
              spec:
                entrypoint: main
                arguments:
                  parameters:
                    - name: message
                      value: "{{.Input.body.message}}"
                templates:
                  - name: main
                    inputs:
                      parameters:
                        - name: message
                    container:
                      image: alpine:latest
                      command: [echo]
                      args: ["{{inputs.parameters.message}}"]
```

### Example 6: Multi-Dependency Sensor

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: multi-event-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: github-push
      eventSourceName: github
      eventName: push
      filters:
        data:
          - path: body.ref
            type: string
            value:
              - "refs/heads/main"
    - name: approval
      eventSourceName: approval-webhook
      eventName: approved
  triggers:
    - template:
        name: deploy-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: deploy-
              spec:
                entrypoint: deploy
                arguments:
                  parameters:
                    - name: commit-sha
                      value: "{{.Input.github-push.body.head_commit.id}}"
                    - name: approver
                      value: "{{.Input.approval.body.approver}}"
                templates:
                  - name: deploy
                    inputs:
                      parameters:
                        - name: commit-sha
                        - name: approver
                    container:
                      image: deployment-tool:latest
                      command: [deploy]
                      args:
                        - "--commit={{inputs.parameters.commit-sha}}"
                        - "--approver={{inputs.parameters.approver}}"
```
