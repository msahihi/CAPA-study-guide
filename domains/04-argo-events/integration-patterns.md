# Integration Patterns

## Overview

Argo Events excels at integrating with external systems and implementing common automation patterns in cloud-native environments. This topic covers practical integration patterns including CI/CD automation, webhook-based automation for version control systems, resource watching for Kubernetes state changes, calendar-based triggers for scheduled operations, and integration with external message queues and services. Understanding these patterns is essential for building robust event-driven automation in production environments.

## Key Topics

### CI/CD Integration

Argo Events is commonly used to automate CI/CD pipelines by triggering builds, tests, and deployments in response to code changes.

**GitHub Push Integration:**

Trigger workflows when code is pushed to GitHub repositories:

```yaml
# EventSource for GitHub webhooks
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  github:
    ci-webhook:
      owner: myorg
      repository: myapp
      events:
        - push
        - pull_request
      webhook:
        endpoint: /github
        port: "12000"
        method: POST
        url: "https://webhook.example.com"
      apiToken:
        name: github-access
        key: token
      webhookSecret:
        name: github-access
        key: secret
---
# Sensor to trigger CI/CD workflow
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: github-ci-sensor
spec:
  dependencies:
    - name: github-push
      eventSourceName: github
      eventName: ci-webhook
      filters:
        data:
          - path: body.ref
            type: string
            value:
              - "refs/heads/main"
              - "refs/heads/develop"
  triggers:
    - template:
        name: ci-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: ci-build-
              spec:
                entrypoint: ci-pipeline
                arguments:
                  parameters:
                    - name: repo-url
                      value: "{{.Input.body.repository.clone_url}}"
                    - name: branch
                      value: "{{.Input.body.ref}}"
                    - name: commit-sha
                      value: "{{.Input.body.head_commit.id}}"
                    - name: commit-message
                      value: "{{.Input.body.head_commit.message}}"
                templates:
                  - name: ci-pipeline
                    inputs:
                      parameters:
                        - name: repo-url
                        - name: branch
                        - name: commit-sha
                        - name: commit-message
                    steps:
                      - - name: clone
                          template: git-clone
                      - - name: test
                          template: run-tests
                      - - name: build
                          template: build-image
                      - - name: push
                          template: push-image
                      - - name: deploy
                          template: deploy-app
                  # Template definitions...
```

**GitLab Integration:**

Similar pattern for GitLab webhooks:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: gitlab
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  gitlab:
    ci-webhook:
      projectID: "12345"
      events:
        - PushEvents
        - TagPushEvents
        - MergeRequestsEvents
      webhook:
        endpoint: /gitlab
        port: "12000"
        method: POST
        url: "https://webhook.example.com/gitlab"
      gitlabBaseURL: "https://gitlab.example.com"
      accessToken:
        name: gitlab-access
        key: token
      secretToken:
        name: gitlab-access
        key: secret
```

### Webhook Automation

Webhook automation enables integration with a wide variety of external services.

**Container Registry Webhooks:**

Trigger deployments when new container images are pushed:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: docker-registry
spec:
  webhook:
    image-pushed:
      port: "12000"
      endpoint: /registry
      method: POST
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: registry-sensor
spec:
  dependencies:
    - name: image-push
      eventSourceName: docker-registry
      eventName: image-pushed
      filters:
        data:
          - path: body.action
            type: string
            value:
              - "push"
          - path: body.target.repository
            type: string
            value:
              - "myapp"
  triggers:
    - template:
        name: update-deployment
        parameters:
          - src:
              dependencyName: image-push
              dataKey: body.target.tag
            dest: image-tag
        k8s:
          operation: patch
          source:
            resource:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: myapp
                namespace: production
          patchStrategy: strategic
          patch: |
            spec:
              template:
                spec:
                  containers:
                    - name: myapp
                      image: "registry.example.com/myapp:{{.Parameters.image-tag}}"
```

**Generic Webhook with Validation:**

Accept webhooks from any service with payload validation:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: generic-webhook
spec:
  webhook:
    custom-service:
      port: "12000"
      endpoint: /webhook
      method: POST
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-sensor
spec:
  dependencies:
    - name: webhook-event
      eventSourceName: generic-webhook
      eventName: custom-service
      filters:
        # Validate payload structure
        data:
          - path: body.event_type
            type: string
            value:
              - "deployment.requested"
          - path: body.environment
            type: string
            value:
              - "staging"
              - "production"
        # Validate with expressions
        exprs:
          - expr: "version != ''"
            fields:
              - name: version
                path: body.version
  triggers:
    - template:
        name: validated-action
        argoWorkflow:
          # Trigger workflow...
```

### Resource Watching

Resource watching enables reactive automation based on Kubernetes object state changes.

**Pod State Monitoring:**

React to pod failures or completions:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: pod-watcher
spec:
  resource:
    failed-pods:
      namespace: production
      group: ""
      version: v1
      resource: pods
      eventTypes:
        - UPDATE
      filter:
        labels:
          - key: app
            operation: "=="
            value: critical-app
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: pod-failure-sensor
spec:
  dependencies:
    - name: pod-event
      eventSourceName: pod-watcher
      eventName: failed-pods
      filters:
        data:
          - path: body.status.phase
            type: string
            value:
              - "Failed"
  triggers:
    # Alert on pod failure
    - template:
        name: alert-slack
        slack:
          slackToken:
            name: slack-secret
            key: token
          channel: "#alerts"
          message: |
            :warning: Pod Failed in Production!
            Pod: {{.Input.body.metadata.name}}
            Namespace: {{.Input.body.metadata.namespace}}
            Reason: {{.Input.body.status.reason}}
    # Trigger auto-remediation workflow
    - template:
        name: remediation-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              # Remediation workflow spec...
```

**Deployment Monitoring:**

Watch for deployment changes and sync to external systems:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: deployment-watcher
spec:
  resource:
    deployments:
      namespace: production
      group: apps
      version: v1
      resource: deployments
      eventTypes:
        - ADD
        - UPDATE
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: deployment-sync-sensor
spec:
  dependencies:
    - name: deployment-change
      eventSourceName: deployment-watcher
      eventName: deployments
  triggers:
    - template:
        name: sync-external-cmdb
        http:
          url: https://cmdb.example.com/api/deployments
          method: POST
          headers:
            Content-Type: application/json
          payload:
            - src:
                dependencyName: deployment-change
                dataTemplate: |
                  {
                    "name": "{{.Input.body.metadata.name}}",
                    "namespace": "{{.Input.body.metadata.namespace}}",
                    "replicas": {{.Input.body.spec.replicas}},
                    "image": "{{.Input.body.spec.template.spec.containers[0].image}}",
                    "timestamp": "{{.Input.metadata.creationTimestamp}}"
                  }
              dest: body
```

**ConfigMap Changes:**

React to configuration changes:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: config-watcher
spec:
  resource:
    config-changes:
      namespace: default
      group: ""
      version: v1
      resource: configmaps
      eventTypes:
        - UPDATE
      filter:
        labels:
          - key: reload-on-change
            operation: "=="
            value: "true"
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: config-reload-sensor
spec:
  dependencies:
    - name: config-update
      eventSourceName: config-watcher
      eventName: config-changes
  triggers:
    - template:
        name: restart-pods
        k8s:
          operation: patch
          source:
            resource:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: "{{.Input.body.metadata.labels.app}}"
                namespace: "{{.Input.body.metadata.namespace}}"
          patchStrategy: strategic
          patch: |
            spec:
              template:
                metadata:
                  annotations:
                    kubectl.kubernetes.io/restartedAt: "{{.Input.metadata.creationTimestamp}}"
```

### Calendar-Based Triggers

Calendar event sources provide scheduled automation.

**Scheduled Maintenance:**

Run maintenance tasks on a schedule:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: maintenance-schedule
spec:
  calendar:
    daily-cleanup:
      # Every day at 2 AM
      schedule: "0 2 * * *"
      timezone: America/New_York
      metadata:
        task: "daily-cleanup"
    weekly-backup:
      # Every Sunday at 3 AM
      schedule: "0 3 * * 0"
      timezone: America/New_York
      metadata:
        task: "weekly-backup"
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: maintenance-sensor
spec:
  dependencies:
    - name: cleanup-schedule
      eventSourceName: maintenance-schedule
      eventName: daily-cleanup
  triggers:
    - template:
        name: cleanup-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: cleanup-
              spec:
                entrypoint: cleanup
                templates:
                  - name: cleanup
                    steps:
                      - - name: delete-old-pods
                          template: delete-pods
                      - - name: clean-pvc
                          template: clean-volumes
                      - - name: prune-images
                          template: prune-images
                  # Template definitions...
```

**Business Hours Automation:**

Trigger actions during business hours:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: business-hours
spec:
  calendar:
    workday-start:
      # Monday-Friday at 9 AM
      schedule: "0 9 * * 1-5"
      timezone: America/New_York
    workday-end:
      # Monday-Friday at 6 PM
      schedule: "0 18 * * 1-5"
      timezone: America/New_York
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: business-hours-sensor
spec:
  dependencies:
    - name: workday-start
      eventSourceName: business-hours
      eventName: workday-start
  triggers:
    - template:
        name: scale-up
        k8s:
          operation: patch
          source:
            resource:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: business-app
                namespace: production
          patchStrategy: strategic
          patch: |
            spec:
              replicas: 10
```

**Interval-Based Triggers:**

Simple interval triggers:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: intervals
spec:
  calendar:
    every-5-minutes:
      interval: "5m"
    every-hour:
      interval: "1h"
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: interval-sensor
spec:
  dependencies:
    - name: periodic-check
      eventSourceName: intervals
      eventName: every-5-minutes
  triggers:
    - template:
        name: health-check
        argoWorkflow:
          # Health check workflow...
```

### External System Integration

**AWS Integration:**

Integrate with AWS services:

```yaml
# AWS SNS EventSource
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: aws-sns
spec:
  sns:
    notifications:
      topicArn: arn:aws:sns:us-east-1:123456789:my-topic
      webhook:
        endpoint: /sns
        port: "12000"
      region: us-east-1
      accessKey:
        name: aws-secret
        key: accesskey
      secretKey:
        name: aws-secret
        key: secretkey
---
# AWS SQS EventSource
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: aws-sqs
spec:
  sqs:
    queue:
      queue: my-queue
      region: us-east-1
      waitTimeSeconds: 20
      accessKey:
        name: aws-secret
        key: accesskey
      secretKey:
        name: aws-secret
        key: secretkey
```

**Kafka Integration:**

Process Kafka messages:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: kafka
spec:
  kafka:
    events:
      url: kafka-broker.kafka.svc:9092
      topic: application-events
      partition: "0"
      consumerGroup:
        groupName: argo-events-consumer
        rebalanceStrategy: range
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: kafka-sensor
spec:
  dependencies:
    - name: kafka-event
      eventSourceName: kafka
      eventName: events
  triggers:
    - template:
        name: process-event
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: process-kafka-
              spec:
                entrypoint: process
                arguments:
                  parameters:
                    - name: message
                      value: "{{.Input.body}}"
                # Workflow processing...
```

**Slack Integration:**

Respond to Slack events:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: slack
spec:
  slack:
    commands:
      signingSecret:
        name: slack-secret
        key: signing-secret
      token:
        name: slack-secret
        key: token
      webhook:
        endpoint: /slack
        port: "12000"
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: slack-sensor
spec:
  dependencies:
    - name: slack-command
      eventSourceName: slack
      eventName: commands
      filters:
        data:
          - path: body.command
            type: string
            value:
              - "/deploy"
  triggers:
    - template:
        name: deploy-from-slack
        argoWorkflow:
          # Deployment workflow...
    - template:
        name: slack-response
        slack:
          channel: "{{.Input.body.channel_id}}"
          message: "Deployment started!"
```

### Multi-Event Coordination

Coordinate multiple events from different sources:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: coordinated-sensor
spec:
  dependencies:
    # Dependency 1: Code pushed to main
    - name: github-push
      eventSourceName: github
      eventName: push
      filters:
        data:
          - path: body.ref
            type: string
            value:
              - "refs/heads/main"
    # Dependency 2: CI tests passed
    - name: ci-success
      eventSourceName: ci-webhook
      eventName: test-complete
      filters:
        data:
          - path: body.status
            type: string
            value:
              - "success"
    # Dependency 3: Manual approval via webhook
    - name: approval
      eventSourceName: approval-webhook
      eventName: approved
      filters:
        data:
          - path: body.approved
            type: string
            value:
              - "true"
  triggers:
    # Only trigger when ALL dependencies are satisfied
    - template:
        name: production-deploy
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
                arguments:
                  parameters:
                    - name: commit-sha
                      value: "{{.Input.github-push.body.head_commit.id}}"
                    - name: approver
                      value: "{{.Input.approval.body.approver}}"
                    - name: test-report
                      value: "{{.Input.ci-success.body.report_url}}"
                # Deployment workflow...
```

## Practice Examples

### Example 1: Complete CI/CD Pipeline

```yaml
# GitHub EventSource
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github-events
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  github:
    myrepo:
      owner: myorg
      repository: myapp
      events:
        - push
      webhook:
        endpoint: /github
        port: "12000"
        method: POST
      apiToken:
        name: github-access
        key: token
      webhookSecret:
        name: github-access
        key: secret
---
# CI/CD Sensor
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: ci-cd-pipeline
  namespace: argo-events
spec:
  dependencies:
    - name: github-push
      eventSourceName: github-events
      eventName: myrepo
      filters:
        data:
          - path: body.ref
            type: string
            value:
              - "refs/heads/main"
  triggers:
    # Trigger 1: Run CI/CD workflow
    - template:
        name: ci-cd-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: ci-cd-
              spec:
                entrypoint: ci-cd
                arguments:
                  parameters:
                    - name: repo-url
                      value: "{{.Input.body.repository.clone_url}}"
                    - name: commit-sha
                      value: "{{.Input.body.head_commit.id}}"
                templates:
                  - name: ci-cd
                    steps:
                      - - name: test
                          template: run-tests
                      - - name: build
                          template: build-docker
                      - - name: deploy-staging
                          template: deploy-staging
                      - - name: integration-test
                          template: integration-tests
                      - - name: deploy-production
                          template: deploy-production
                  # Templates...
    # Trigger 2: Notify Slack
    - template:
        name: notify-slack
        slack:
          slackToken:
            name: slack-secret
            key: token
          channel: "#deployments"
          message: |
            :rocket: Deployment started
            Repo: {{.Input.body.repository.name}}
            Commit: {{.Input.body.head_commit.id}}
            Author: {{.Input.body.head_commit.author.name}}
```

### Example 2: Auto-Scaling Based on Resource Events

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: pod-metrics
spec:
  resource:
    high-cpu-pods:
      namespace: production
      group: ""
      version: v1
      resource: pods
      eventTypes:
        - UPDATE
      filter:
        labels:
          - key: autoscale
            operation: "=="
            value: "true"
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: autoscale-sensor
spec:
  dependencies:
    - name: pod-metrics
      eventSourceName: pod-metrics
      eventName: high-cpu-pods
  triggers:
    - template:
        name: scale-deployment
        parameters:
          - src:
              dependencyName: pod-metrics
              dataKey: body.metadata.labels.app
            dest: app-name
        k8s:
          operation: patch
          source:
            resource:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: "{{.Parameters.app-name}}"
                namespace: production
          patchStrategy: strategic
          patch: |
            spec:
              replicas: 5
```

## Study Resources

- [Integration Patterns Guide](https://argoproj.github.io/argo-events/tutorials/01-introduction/) - Official tutorials
- [EventSource Gallery](https://argoproj.github.io/argo-events/concepts/event_source/) - All event source types
- [Real-World Examples](https://github.com/argoproj/argo-events/tree/master/examples) - Production patterns
- [Argo Events Documentation](https://argoproj.github.io/argo-events/) - Integration guidance

## Key Points to Remember

- GitHub/GitLab webhooks are the most common CI/CD integration pattern
- Resource watching enables reactive automation based on Kubernetes state changes
- Calendar event sources provide cron-like scheduling with event-driven context
- Multiple event dependencies enable complex coordination patterns
- Webhook validation using filters prevents unauthorized trigger execution
- Container registry webhooks enable automated deployment on image push
- Kafka and message queue integrations enable processing of streaming data
- Slack integration allows ChatOps-style automation
- AWS SNS/SQS integration connects cloud events to Kubernetes automation
- Resource watching can monitor any Kubernetes object (pods, deployments, configmaps, etc.)
- Calendar triggers are better than CronWorkflow when you need event coordination
- Multi-dependency sensors wait for ALL dependencies before triggering
- Event filters should be used to validate event sources and prevent false triggers
- ConfigMap changes can trigger application reloads without code changes
- Pod failure detection can trigger auto-remediation workflows
- Business hours automation can optimize resource usage

## Hands-On Practice

- [Lab 03: Triggers](../../labs/04-argo-events/lab-03-triggers.md) - Implement webhook automation and calendar triggers
- [Lab 04: Integration with Argo Workflows](../../labs/04-argo-events/lab-04-integration.md) - Build a complete CI/CD pipeline with GitHub webhooks and Argo Workflows
