# Triggers and Actions

## Overview

Triggers define the actions that Sensors execute when event dependencies are satisfied. Argo Events supports multiple trigger types, allowing you to automate a wide range of tasks including launching Argo Workflows, creating or updating Kubernetes resources, making HTTP requests, publishing to message queues, and more. Triggers can be conditional, parameterized with event data, and executed in various ways to build sophisticated event-driven automation workflows.

## Key Topics

### Trigger Types

Argo Events supports various trigger types for different automation scenarios.

**Available Trigger Types:**

1. **Argo Workflow** - Submit or create Argo Workflows
2. **Kubernetes Resource (k8s)** - Create, update, or patch Kubernetes resources
3. **HTTP** - Send HTTP requests to external services
4. **AWS Lambda** - Invoke AWS Lambda functions
5. **Apache OpenWhisk** - Invoke OpenWhisk actions
6. **Kafka** - Publish messages to Kafka topics
7. **NATS** - Publish messages to NATS subjects
8. **Azure Event Hubs** - Send events to Azure Event Hubs
9. **Slack** - Send Slack notifications
10. **Log** - Log event data (debugging)
11. **Custom** - Custom trigger implementations

**Trigger Structure in Sensor:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: example-sensor
spec:
  dependencies:
    - name: event-dep
      eventSourceName: webhook
      eventName: example
  triggers:
    - template:
        name: trigger-name
        # Trigger type and configuration
        k8s:
          operation: create
          source:
            resource:
              # Resource specification
```

### Argo Workflow Triggers

The Argo Workflow trigger is specialized for submitting Argo Workflows.

**Basic Workflow Trigger:**

```yaml
triggers:
  - template:
      name: workflow-trigger
      argoWorkflow:
        operation: submit
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: event-workflow-
            spec:
              entrypoint: main
              templates:
                - name: main
                  container:
                    image: alpine:latest
                    command: [echo]
                    args: ["Hello from event!"]
```

**Workflow with Event Data:**

Extract data from events and pass as workflow parameters:

```yaml
triggers:
  - template:
      name: workflow-with-params
      argoWorkflow:
        operation: submit
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: build-deploy-
            spec:
              entrypoint: build-and-deploy
              arguments:
                parameters:
                  # Extract from event payload
                  - name: repo-url
                    value: "{{.Input.body.repository.clone_url}}"
                  - name: branch
                    value: "{{.Input.body.ref}}"
                  - name: commit-sha
                    value: "{{.Input.body.head_commit.id}}"
              templates:
                - name: build-and-deploy
                  inputs:
                    parameters:
                      - name: repo-url
                      - name: branch
                      - name: commit-sha
                  steps:
                    - - name: clone
                        template: git-clone
                        arguments:
                          parameters:
                            - name: repo-url
                              value: "{{inputs.parameters.repo-url}}"
                    - - name: build
                        template: build-image
                    - - name: deploy
                        template: deploy-app
                  # Template definitions...
```

**Using WorkflowTemplate:**

Reference existing WorkflowTemplates instead of inline workflows:

```yaml
triggers:
  - template:
      name: workflow-template-trigger
      argoWorkflow:
        operation: submit
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: from-template-
            spec:
              workflowTemplateRef:
                name: build-deploy-template
              arguments:
                parameters:
                  - name: image-tag
                    value: "{{.Input.body.tag}}"
```

### Kubernetes Resource Triggers

The k8s trigger creates, updates, or patches Kubernetes resources.

**Create Operation:**

```yaml
triggers:
  - template:
      name: create-deployment
      k8s:
        operation: create
        source:
          resource:
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: event-triggered-app
              namespace: default
            spec:
              replicas: 3
              selector:
                matchLabels:
                  app: event-app
              template:
                metadata:
                  labels:
                    app: event-app
                spec:
                  containers:
                    - name: app
                      image: "{{.Input.body.image}}"
                      ports:
                        - containerPort: 8080
```

**Update Operation:**

```yaml
triggers:
  - template:
      name: update-configmap
      k8s:
        operation: update
        source:
          resource:
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: app-config
              namespace: default
            data:
              config.json: "{{.Input.body.config}}"
```

**Patch Operation:**

Apply strategic merge patches or JSON patches:

```yaml
triggers:
  - template:
      name: patch-deployment
      k8s:
        operation: patch
        source:
          resource:
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: my-deployment
              namespace: default
        # Strategic merge patch
        patchStrategy: strategic
        patch: |
          spec:
            replicas: {{.Input.body.replicas}}
            template:
              spec:
                containers:
                  - name: app
                    image: "{{.Input.body.image}}"
```

### HTTP Triggers

Send HTTP requests to external services or webhooks.

**Basic HTTP Trigger:**

```yaml
triggers:
  - template:
      name: http-request
      http:
        url: https://api.example.com/webhook
        method: POST
        headers:
          Content-Type: application/json
          Authorization: "Bearer {{.Input.body.token}}"
        payload:
          - src:
              dependencyName: event-dep
              dataKey: body
            dest: data
        # Optional: Secure data from secrets
        secureHeaders:
          - name: auth-secret
            key: api-key
```

**HTTP with Custom Payload:**

```yaml
triggers:
  - template:
      name: http-notification
      http:
        url: https://notifications.example.com/notify
        method: POST
        headers:
          Content-Type: application/json
        payload:
          - src:
              dependencyName: event-dep
              dataTemplate: |
                {
                  "event": "deployment",
                  "repository": "{{.Input.body.repository.name}}",
                  "commit": "{{.Input.body.head_commit.id}}",
                  "author": "{{.Input.body.head_commit.author.name}}",
                  "timestamp": "{{.Input.body.head_commit.timestamp}}"
                }
            dest: body
```

### Message Queue Triggers

Publish events to message queues.

**Kafka Trigger:**

```yaml
triggers:
  - template:
      name: kafka-publish
      kafka:
        url: kafka-broker.default.svc:9092
        topic: events
        partition: 0
        # Message payload from event
        payload:
          - src:
              dependencyName: event-dep
              dataKey: body
            dest: message
        # Optional: Message key
        partitioningKey: "{{.Input.body.id}}"
```

**NATS Trigger:**

```yaml
triggers:
  - template:
      name: nats-publish
      nats:
        url: nats://nats.default.svc:4222
        subject: events.workflow.completed
        payload:
          - src:
              dependencyName: event-dep
              dataKey: body
            dest: message
```

### Slack Triggers

Send Slack notifications.

```yaml
triggers:
  - template:
      name: slack-notification
      slack:
        slackToken:
          name: slack-secret
          key: token
        channel: "#deployments"
        message: |
          :rocket: Deployment triggered!
          Repository: {{.Input.body.repository.name}}
          Branch: {{.Input.body.ref}}
          Commit: {{.Input.body.head_commit.id}}
          Author: {{.Input.body.head_commit.author.name}}
```

### Trigger Templates

Trigger templates define reusable trigger configurations with parameters.

**Template Parameters:**

```yaml
triggers:
  - template:
      name: parameterized-trigger
      # Template parameters
      parameters:
        - src:
            dependencyName: event-dep
            dataKey: body.environment
          dest: environment
        - src:
            dependencyName: event-dep
            dataKey: body.version
          dest: version
      k8s:
        operation: create
        source:
          resource:
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: app-{{.Parameters.environment}}
            spec:
              replicas: 3
              template:
                spec:
                  containers:
                    - name: app
                      image: "myapp:{{.Parameters.version}}"
```

### Trigger Conditions

Execute triggers conditionally based on event data.

**Simple Conditions:**

```yaml
triggers:
  - template:
      name: conditional-trigger
      # Only trigger if branch is main
      conditions: "branch == 'main'"
      argoWorkflow:
        operation: submit
        source:
          resource:
            # Workflow spec...
```

**Complex Conditions:**

Use expressions with multiple criteria:

```yaml
triggers:
  - template:
      name: production-deploy
      conditions: "branch == 'main' && approved == 'true' && environment == 'production'"
      argoWorkflow:
        operation: submit
        source:
          resource:
            # Production workflow spec...
```

**Condition Variables:**

Variables in conditions come from trigger parameters:

```yaml
triggers:
  - template:
      name: environment-trigger
      parameters:
        - src:
            dependencyName: github-push
            dataKey: body.ref
          dest: branch
        - src:
            dependencyName: approval
            dataKey: body.approved
          dest: approved
      # Use parameters in conditions
      conditions: "branch == 'refs/heads/main' && approved == true"
      k8s:
        # Trigger action...
```

### Trigger Policy

Control trigger execution behavior.

**Retry Policy:**

```yaml
triggers:
  - template:
      name: http-with-retry
      retryStrategy:
        steps: 3
        duration: 10s
        factor: 2
        jitter: 0.1
      http:
        url: https://api.example.com/endpoint
        method: POST
```

**Rate Limiting:**

```yaml
triggers:
  - template:
      name: rate-limited-trigger
      rateLimit:
        unit: Second
        requestsPerUnit: 10
      k8s:
        # Trigger action...
```

### Data Transformation

Transform event data before passing to triggers.

**Using dataTemplate:**

```yaml
triggers:
  - template:
      name: transformed-trigger
      k8s:
        operation: create
        source:
          resource:
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: event-data
            data:
              # Transform event data
              event.json: |
                {
                  "repository": "{{.Input.body.repository.name}}",
                  "branch": "{{.Input.body.ref | split('/') | last}}",
                  "author": "{{.Input.body.head_commit.author.name}}",
                  "message": "{{.Input.body.head_commit.message}}",
                  "timestamp": "{{.Input.body.head_commit.timestamp}}"
                }
```

**Using JQ Transformation:**

```yaml
dependencies:
  - name: webhook-dep
    eventSourceName: webhook
    eventName: example
    transform:
      jq: |
        {
          repo: .body.repository.name,
          branch: .body.ref | split("/")[-1],
          author: .body.head_commit.author.name
        }
```

### Multiple Triggers

Sensors can execute multiple triggers for a single event or set of events.

**Parallel Triggers:**

```yaml
triggers:
  # Trigger 1: Create workflow
  - template:
      name: workflow-trigger
      argoWorkflow:
        operation: submit
        source:
          # Workflow spec...
  # Trigger 2: Send notification
  - template:
      name: slack-notification
      slack:
        channel: "#builds"
        message: "Build started for {{.Input.body.repository.name}}"
  # Trigger 3: Update status
  - template:
      name: update-status
      http:
        url: https://api.example.com/status
        method: POST
```

## Practice Examples

### Example 1: Workflow Trigger with Parameters

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-workflow-sensor
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
                generateName: webhook-wf-
              spec:
                entrypoint: main
                arguments:
                  parameters:
                    - name: message
                      value: "{{.Input.body.message}}"
                    - name: user
                      value: "{{.Input.body.user}}"
                templates:
                  - name: main
                    inputs:
                      parameters:
                        - name: message
                        - name: user
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - echo "Message from {{inputs.parameters.user}}: {{inputs.parameters.message}}"
```

### Example 2: Kubernetes Resource Trigger

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: create-deployment-sensor
spec:
  dependencies:
    - name: webhook-dep
      eventSourceName: webhook
      eventName: deploy
  triggers:
    - template:
        name: create-deployment
        k8s:
          operation: create
          source:
            resource:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                generateName: app-
                namespace: default
                labels:
                  app: event-app
              spec:
                replicas: "{{.Input.body.replicas}}"
                selector:
                  matchLabels:
                    app: event-app
                template:
                  metadata:
                    labels:
                      app: event-app
                  spec:
                    containers:
                      - name: app
                        image: "{{.Input.body.image}}"
                        ports:
                          - containerPort: 8080
```

### Example 3: HTTP Trigger

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: http-trigger-sensor
spec:
  dependencies:
    - name: calendar-dep
      eventSourceName: calendar
      eventName: daily-report
  triggers:
    - template:
        name: send-report
        http:
          url: https://api.example.com/reports
          method: POST
          headers:
            Content-Type: application/json
          payload:
            - src:
                dependencyName: calendar-dep
                dataTemplate: |
                  {
                    "report_date": "{{.Input.metadata.name}}",
                    "timestamp": "{{.Input.time}}",
                    "type": "daily"
                  }
              dest: body
```

### Example 4: Conditional Trigger

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: conditional-sensor
spec:
  dependencies:
    - name: github-push
      eventSourceName: github
      eventName: push
  triggers:
    # Only trigger for main branch
    - template:
        name: production-deploy
        parameters:
          - src:
              dependencyName: github-push
              dataKey: body.ref
            dest: ref
        conditions: "ref == 'refs/heads/main'"
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: prod-deploy-
              spec:
                entrypoint: deploy
                # Deploy workflow...
```

### Example 5: Multiple Triggers

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: multi-trigger-sensor
spec:
  dependencies:
    - name: webhook-dep
      eventSourceName: webhook
      eventName: deploy
  triggers:
    # Trigger 1: Start deployment workflow
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
                # Workflow spec...
    # Trigger 2: Send Slack notification
    - template:
        name: slack-notify
        slack:
          slackToken:
            name: slack-secret
            key: token
          channel: "#deployments"
          message: "Deployment started for {{.Input.body.service}}"
    # Trigger 3: Update external status
    - template:
        name: update-status
        http:
          url: https://status.example.com/api/update
          method: POST
          headers:
            Content-Type: application/json
          payload:
            - src:
                dependencyName: webhook-dep
                dataTemplate: |
                  {
                    "service": "{{.Input.body.service}}",
                    "status": "deploying",
                    "timestamp": "{{.Input.time}}"
                  }
              dest: body
```

## Study Resources

- [Trigger Specification](https://argoproj.github.io/argo-events/sensors/triggers/) - Complete trigger reference
- [Trigger Examples](https://github.com/argoproj/argo-events/tree/master/examples/sensors) - Official examples
- [Parameterization Guide](https://argoproj.github.io/argo-events/sensors/parameterization/) - Event data extraction
- [Trigger Conditions](https://argoproj.github.io/argo-events/sensors/trigger-conditions/) - Conditional triggers

## Key Points to Remember

- Triggers define what actions to execute when event dependencies are satisfied
- Argo Workflow trigger (argoWorkflow) is a specialized trigger for submitting workflows
- Kubernetes resource trigger (k8s) can create, update, or patch any Kubernetes resource
- HTTP triggers enable integration with external REST APIs and webhooks
- Multiple triggers can be executed for a single event or set of events
- Event data can be extracted and passed to triggers using templates like `{{.Input.body.field}}`
- Trigger conditions allow conditional execution based on event data
- Triggers support retry strategies for handling transient failures
- Parameters can be used to make triggers reusable and flexible
- WorkflowTemplates can be referenced instead of defining workflows inline
- Trigger operations include create, update, patch for K8s resources; submit for workflows
- Data transformation can be applied using dataTemplate or JQ filters
- Slack, Kafka, NATS, and other integrations are supported as first-class trigger types
- Triggers execute in parallel by default unless dependencies are chained
- Log triggers are useful for debugging event flow

## Hands-On Practice

- [Lab 02: Event Sources](../../labs/04-argo-events/lab-02-event-sources.md) - Create sensors with various trigger types
- [Lab 03: Triggers](../../labs/04-argo-events/lab-03-triggers.md) - Work with different trigger actions and conditions
- [Lab 04: Integration with Argo Workflows](../../labs/04-argo-events/lab-04-integration.md) - Build end-to-end automation with triggers
