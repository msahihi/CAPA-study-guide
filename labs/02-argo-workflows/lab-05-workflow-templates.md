# Lab 05: Workflow Templates

**Duration**: 30 minutes

## Objectives

By the end of this lab, you will be able to:

- Create and use WorkflowTemplates for reusability
- Understand ClusterWorkflowTemplates for cluster-wide templates
- Submit workflows from templates
- Create CronWorkflows for scheduled execution
- Pass arguments to WorkflowTemplates
- Implement template libraries and patterns
- Version and manage workflow templates
- Use template references across workflows

## Prerequisites

- Completed [Lab 04: Artifacts](lab-04-artifacts.md)
- Argo Workflows installed and running
- Understanding of workflows, templates, and parameters

## Lab Environment Verification

```bash
kubectl get pods -n argo
argo version
```

## Introduction to Workflow Templates

Workflow templates enable reusability by separating workflow definitions from their execution. Instead of duplicating workflow definitions, you can create templates once and submit them multiple times with different parameters.

**Key Concepts:**

- **WorkflowTemplate**: Namespace-scoped reusable workflow definition
- **ClusterWorkflowTemplate**: Cluster-scoped workflow template available to all namespaces
- **CronWorkflow**: Scheduled workflow execution
- **Template Reference**: Reference templates from other workflows

**Benefits:**

- Code reusability
- Centralized management
- Consistent execution patterns
- Version control
- Easier maintenance

## Step 1: WorkflowTemplates Basics (8 minutes)

### 1.1 Create a Simple WorkflowTemplate

Create `workflowtemplate-simple.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: hello-world-template
  namespace: argo
spec:
  serviceAccountName: argo
  entrypoint: main
  templates:
  - name: main
    container:
      image: alpine:3.23
      command: [echo]
      args: ["Hello from WorkflowTemplate!"]
```

Apply the template:

```bash
kubectl apply -f workflowtemplate-simple.yaml
```

Verify:

```bash
kubectl get workflowtemplate -n argo
argo template list -n argo
```

### 1.2 Submit Workflow from Template

Submit using Argo CLI:

```bash
argo submit --from workflowtemplate/hello-world-template -n argo --watch
```

Or create a Workflow that references the template:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: from-template-
  namespace: argo
spec:
  workflowTemplateRef:
    name: hello-world-template
```

Apply and watch:

```bash
kubectl create -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: from-template-
  namespace: argo
spec:
  workflowTemplateRef:
    name: hello-world-template
EOF

argo list -n argo
```

### 1.3 Parameterized WorkflowTemplate

Create `workflowtemplate-params.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: greeting-template
  namespace: argo
spec:
  serviceAccountName: argo
  entrypoint: greet
  arguments:
    parameters:
    - name: greeting
      value: "Hello"
    - name: name
      value: "World"
    - name: times
      value: "1"
  templates:
  - name: greet
    inputs:
      parameters:
      - name: greeting
      - name: name
      - name: times
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        greeting = "{{inputs.parameters.greeting}}"
        name = "{{inputs.parameters.name}}"
        times = int("{{inputs.parameters.times}}")

        for i in range(times):
            print(f"{greeting}, {name}! (#{i+1})")
```

Apply:

```bash
kubectl apply -f workflowtemplate-params.yaml
```

Submit with different parameters:

```bash
# Use defaults
argo submit --from workflowtemplate/greeting-template -n argo --watch

# Custom parameters
argo submit --from workflowtemplate/greeting-template -n argo \
  --parameter greeting="Good morning" \
  --parameter name="DevOps Engineer" \
  --parameter times="3" \
  --watch
```

### 1.4 WorkflowTemplate with Multiple Entry Points

Create `workflowtemplate-multi.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: multi-entry-template
  namespace: argo
spec:
  serviceAccountName: argo
  entrypoint: full-pipeline
  templates:
  - name: full-pipeline
    steps:
    - - name: build
        template: build-step
    - - name: test
        template: test-step
    - - name: deploy
        template: deploy-step

  - name: quick-test
    steps:
    - - name: test
        template: test-step

  - name: deploy-only
    steps:
    - - name: deploy
        template: deploy-step

  - name: build-step
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Building application...'; sleep 2"]

  - name: test-step
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Running tests...'; sleep 2"]

  - name: deploy-step
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Deploying application...'; sleep 2"]
```

Apply:

```bash
kubectl apply -f workflowtemplate-multi.yaml
```

Submit with different entry points:

```bash
# Full pipeline (default)
argo submit --from workflowtemplate/multi-entry-template -n argo --watch

# Quick test only
argo submit --from workflowtemplate/multi-entry-template -n argo \
  --entrypoint quick-test --watch

# Deploy only
argo submit --from workflowtemplate/multi-entry-template -n argo \
  --entrypoint deploy-only --watch
```

## Step 2: ClusterWorkflowTemplates (7 minutes)

ClusterWorkflowTemplates are available across all namespaces in the cluster.

### 2.1 Create ClusterWorkflowTemplate

Create `clusterworkflowtemplate.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: common-build-template
spec:
  serviceAccountName: argo
  entrypoint: build-pipeline
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/example/repo.git"
    - name: branch
      value: "main"
    - name: environment
      value: "staging"
  templates:
  - name: build-pipeline
    inputs:
      parameters:
      - name: repo-url
      - name: branch
      - name: environment
    steps:
    - - name: checkout
        template: git-clone
        arguments:
          parameters:
          - name: repo
            value: "{{inputs.parameters.repo-url}}"
          - name: branch
            value: "{{inputs.parameters.branch}}"

    - - name: build
        template: build-image
        arguments:
          parameters:
          - name: env
            value: "{{inputs.parameters.environment}}"

    - - name: test
        template: run-tests

  - name: git-clone
    inputs:
      parameters:
      - name: repo
      - name: branch
    container:
      image: alpine/git:2.47.1
      command: [sh, -c]
      args: ["echo 'Cloning {{inputs.parameters.repo}} ({{inputs.parameters.branch}})'; sleep 1"]

  - name: build-image
    inputs:
      parameters:
      - name: env
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Building for {{inputs.parameters.env}}'; sleep 2"]

  - name: run-tests
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Running tests'; sleep 2"]
```

Apply:

```bash
kubectl apply -f clusterworkflowtemplate.yaml
```

Verify:

```bash
kubectl get clusterworkflowtemplate
argo cluster-template list
```

### 2.2 Use ClusterWorkflowTemplate

Submit from any namespace:

```bash
# From argo namespace
argo submit --from clusterworkflowtemplate/common-build-template -n argo \
  --parameter repo-url="https://github.com/myorg/myapp.git" \
  --parameter branch="develop" \
  --parameter environment="production" \
  --watch
```

Or reference in a Workflow:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: use-cluster-template-
  namespace: argo
spec:
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/myorg/frontend.git"
    - name: branch
      value: "feature/new-ui"
    - name: environment
      value: "development"
  workflowTemplateRef:
    name: common-build-template
    clusterScope: true
```

Apply:

```bash
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: use-cluster-template-
  namespace: argo
spec:
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/myorg/frontend.git"
  workflowTemplateRef:
    name: common-build-template
    clusterScope: true
EOF
```

## Step 3: Template References (6 minutes)

Templates can reference other templates, enabling modular design.

### 3.1 Template Library

Create `workflowtemplate-library.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: common-tasks
  namespace: argo
spec:
  templates:
  - name: notify-slack
    inputs:
      parameters:
      - name: message
      - name: channel
        value: "#general"
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Sending to {{inputs.parameters.channel}}: {{inputs.parameters.message}}"
          # In production: curl -X POST slack-webhook

  - name: send-email
    inputs:
      parameters:
      - name: recipient
      - name: subject
      - name: body
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "To: {{inputs.parameters.recipient}}"
          echo "Subject: {{inputs.parameters.subject}}"
          echo "Body: {{inputs.parameters.body}}"
          # In production: use sendmail or email service

  - name: create-jira-ticket
    inputs:
      parameters:
      - name: project
      - name: summary
      - name: description
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Creating JIRA ticket in {{inputs.parameters.project}}"
          echo "Summary: {{inputs.parameters.summary}}"
          echo "Description: {{inputs.parameters.description}}"
          # In production: curl to JIRA API
```

Apply:

```bash
kubectl apply -f workflowtemplate-library.yaml
```

### 3.2 Use Template References

Create `workflow-with-refs.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: deployment-workflow
  namespace: argo
spec:
  serviceAccountName: argo
  entrypoint: deploy
  arguments:
    parameters:
    - name: environment
      value: "staging"
  templates:
  - name: deploy
    steps:
    # Deploy application
    - - name: deploy-app
        template: deploy-step

    # Notify on success
    - - name: notify-slack
        templateRef:
          name: common-tasks
          template: notify-slack
        arguments:
          parameters:
          - name: message
            value: "Deployment to {{workflow.parameters.environment}} successful"
          - name: channel
            value: "#deployments"

      - name: send-email
        templateRef:
          name: common-tasks
          template: send-email
        arguments:
          parameters:
          - name: recipient
            value: "devops@example.com"
          - name: subject
            value: "Deployment Complete"
          - name: body
            value: "{{workflow.parameters.environment}} deployment finished"

  - name: deploy-step
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Deploying to {{workflow.parameters.environment}}'; sleep 2"]
```

Apply and submit:

```bash
kubectl apply -f workflow-with-refs.yaml
argo submit --from workflowtemplate/deployment-workflow -n argo --watch
```

## Step 4: CronWorkflows (6 minutes)

CronWorkflows enable scheduled workflow execution.

### 4.1 Basic CronWorkflow

Create `cronworkflow-simple.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: hello-cron
  namespace: argo
spec:
  schedule: "*/2 * * * *"  # Every 2 minutes
  timezone: "America/Los_Angeles"
  startingDeadlineSeconds: 0
  concurrencyPolicy: "Replace"  # Replace, Allow, or Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  workflowSpec:
    serviceAccountName: argo
    entrypoint: main
    templates:
    - name: main
      container:
        image: alpine:3.23
        command: [sh, -c]
        args:
          - |
            echo "CronWorkflow executed at: $(date)"
            echo "Hostname: $(hostname)"
```

Apply:

```bash
kubectl apply -f cronworkflow-simple.yaml
```

Verify:

```bash
kubectl get cronworkflow -n argo
argo cron list -n argo
```

Watch for executions:

```bash
# Wait 2 minutes, then check
sleep 120
argo list -n argo | grep hello-cron
```

### 4.2 CronWorkflow with Parameters

Create `cronworkflow-backup.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: daily-backup
  namespace: argo
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  timezone: "UTC"
  concurrencyPolicy: "Forbid"  # Don't allow overlapping runs
  successfulJobsHistoryLimit: 7  # Keep last 7 days
  failedJobsHistoryLimit: 3
  workflowSpec:
    serviceAccountName: argo
    entrypoint: backup-pipeline
    arguments:
      parameters:
      - name: backup-type
        value: "full"
      - name: retention-days
        value: "30"
    templates:
    - name: backup-pipeline
      inputs:
        parameters:
        - name: backup-type
        - name: retention-days
      steps:
      - - name: create-backup
          template: backup-task
          arguments:
            parameters:
            - name: type
              value: "{{inputs.parameters.backup-type}}"

      - - name: verify-backup
          template: verify-task

      - - name: cleanup-old
          template: cleanup-task
          arguments:
            parameters:
            - name: days
              value: "{{inputs.parameters.retention-days}}"

    - name: backup-task
      inputs:
        parameters:
        - name: type
      script:
        image: alpine:3.23
        command: [sh]
        source: |
          echo "Creating {{inputs.parameters.type}} backup at $(date)"
          echo "Backup file: backup-$(date +%Y%m%d-%H%M%S).tar.gz"
          sleep 2
          echo "Backup created successfully"

    - name: verify-task
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["echo 'Verifying backup integrity'; sleep 1; echo 'Backup verified'"]

    - name: cleanup-task
      inputs:
        parameters:
        - name: days
      container:
        image: alpine:3.23
        command: [sh, -c]
        args:
          - |
            echo "Cleaning up backups older than {{inputs.parameters.days}} days"
            echo "Cleanup complete"
```

Apply:

```bash
kubectl apply -f cronworkflow-backup.yaml
```

### 4.3 Suspend and Resume CronWorkflow

```bash
# Suspend (stop scheduling)
argo cron suspend daily-backup -n argo

# Verify suspension
argo cron get daily-backup -n argo

# Resume
argo cron resume daily-backup -n argo
```

### 4.4 Manually Trigger CronWorkflow

Create an immediate execution without waiting for schedule:

```bash
argo submit --from cronworkflow/daily-backup -n argo --watch
```

## Step 5: Advanced Template Patterns (3 minutes)

### 5.1 WorkflowTemplate with Conditionals

Create `workflowtemplate-conditional.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: conditional-deploy
  namespace: argo
spec:
  serviceAccountName: argo
  entrypoint: main
  arguments:
    parameters:
    - name: environment
      value: "staging"
    - name: run-tests
      value: "true"
    - name: auto-approve
      value: "false"
  templates:
  - name: main
    inputs:
      parameters:
      - name: environment
      - name: run-tests
      - name: auto-approve
    steps:
    - - name: build
        template: build-step

    - - name: test
        template: test-step
        when: "{{inputs.parameters.run-tests}} == true"

    - - name: approval
        template: approval-step
        when: "{{inputs.parameters.auto-approve}} == false"

    - - name: deploy
        template: deploy-step
        arguments:
          parameters:
          - name: env
            value: "{{inputs.parameters.environment}}"

  - name: build-step
    container:
      image: alpine:3.23
      command: [echo, "Building..."]

  - name: test-step
    container:
      image: alpine:3.23
      command: [echo, "Testing..."]

  - name: approval-step
    suspend: {}

  - name: deploy-step
    inputs:
      parameters:
      - name: env
    container:
      image: alpine:3.23
      command: [echo, "Deploying to {{inputs.parameters.env}}"]
```

Apply and test:

```bash
kubectl apply -f workflowtemplate-conditional.yaml

# With auto-approve
argo submit --from workflowtemplate/conditional-deploy -n argo \
  --parameter auto-approve="true" \
  --watch
```

### 5.2 Template Versioning

Create versioned templates:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: app-deploy-v1
  namespace: argo
  labels:
    version: v1
spec:
  serviceAccountName: argo
  entrypoint: deploy
  templates:
  - name: deploy
    container:
      image: myapp:v1
      command: [echo, "Deploying v1"]
---
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: app-deploy-v2
  namespace: argo
  labels:
    version: v2
spec:
  serviceAccountName: argo
  entrypoint: deploy
  templates:
  - name: deploy
    container:
      image: myapp:v2
      command: [echo, "Deploying v2"]
```

Apply:

```bash
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: app-deploy-v1
  namespace: argo
  labels:
    version: v1
spec:
  serviceAccountName: argo
  entrypoint: deploy
  templates:
  - name: deploy
    container:
      image: alpine:3.23
      command: [echo, "Deploying v1"]
---
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: app-deploy-v2
  namespace: argo
  labels:
    version: v2
spec:
  serviceAccountName: argo
  entrypoint: deploy
  templates:
  - name: deploy
    container:
      image: alpine:3.23
      command: [echo, "Deploying v2"]
EOF

# Submit specific version
argo submit --from workflowtemplate/app-deploy-v1 -n argo --watch
argo submit --from workflowtemplate/app-deploy-v2 -n argo --watch
```

## Practice Exercises

### Exercise 1: CI/CD Template Library

Create a WorkflowTemplate library with reusable CI/CD tasks:

- code-checkout
- run-linter
- run-unit-tests
- build-docker-image
- push-to-registry

Then create a WorkflowTemplate that uses these tasks to build a complete pipeline.

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: cicd-library
  namespace: argo
spec:
  templates:
  - name: code-checkout
    inputs:
      parameters:
      - name: repo
      - name: branch
    container:
      image: alpine/git:2.47.1
      command: [sh, -c]
      args: ["echo 'Cloning {{inputs.parameters.repo}} ({{inputs.parameters.branch}})'; sleep 1"]

  - name: run-linter
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Running linter'; sleep 1"]

  - name: run-unit-tests
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Running unit tests'; sleep 2"]

  - name: build-docker-image
    inputs:
      parameters:
      - name: image-tag
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Building image: {{inputs.parameters.image-tag}}'; sleep 2"]

  - name: push-to-registry
    inputs:
      parameters:
      - name: image-tag
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Pushing {{inputs.parameters.image-tag}} to registry'; sleep 1"]
---
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: complete-cicd-pipeline
  namespace: argo
spec:
  serviceAccountName: argo
  entrypoint: pipeline
  arguments:
    parameters:
    - name: repo
      value: "https://github.com/example/app.git"
    - name: branch
      value: "main"
    - name: image-tag
      value: "myapp:latest"
  templates:
  - name: pipeline
    steps:
    - - name: checkout
        templateRef:
          name: cicd-library
          template: code-checkout
        arguments:
          parameters:
          - name: repo
            value: "{{workflow.parameters.repo}}"
          - name: branch
            value: "{{workflow.parameters.branch}}"

    - - name: linter
        templateRef:
          name: cicd-library
          template: run-linter
      - name: tests
        templateRef:
          name: cicd-library
          template: run-unit-tests

    - - name: build
        templateRef:
          name: cicd-library
          template: build-docker-image
        arguments:
          parameters:
          - name: image-tag
            value: "{{workflow.parameters.image-tag}}"

    - - name: push
        templateRef:
          name: cicd-library
          template: push-to-registry
        arguments:
          parameters:
          - name: image-tag
            value: "{{workflow.parameters.image-tag}}"
```

</details>

### Exercise 2: Scheduled Health Check

Create a CronWorkflow that runs every 5 minutes and:

1. Checks application health (simulate with random success/failure)
2. If unhealthy, sends notification
3. Keeps last 10 executions

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: health-check
  namespace: argo
spec:
  schedule: "*/5 * * * *"
  timezone: "UTC"
  concurrencyPolicy: "Allow"
  successfulJobsHistoryLimit: 10
  failedJobsHistoryLimit: 10
  workflowSpec:
    serviceAccountName: argo
    entrypoint: health-check
    templates:
    - name: health-check
      steps:
      - - name: check-health
          template: health-check-task

      - - name: notify-on-failure
          template: send-alert
          when: "{{steps.check-health.status}} == Failed"

    - name: health-check-task
      script:
        image: python:3.14-slim
        command: [python]
        source: |
          import random
          import sys

          print("Checking application health...")

          # Simulate health check (80% success rate)
          if random.random() < 0.8:
              print("✓ Application is healthy")
              sys.exit(0)
          else:
              print("✗ Application is unhealthy")
              sys.exit(1)

    - name: send-alert
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["echo 'ALERT: Application health check failed at $(date)'"]
```

</details>

## Verification Steps

```bash
# List WorkflowTemplates
argo template list -n argo
kubectl get workflowtemplate -n argo

# List ClusterWorkflowTemplates
argo cluster-template list
kubectl get clusterworkflowtemplate

# List CronWorkflows
argo cron list -n argo
kubectl get cronworkflow -n argo

# Get template details
argo template get greeting-template -n argo

# Clean up
kubectl delete workflowtemplate --all -n argo
kubectl delete clusterworkflowtemplate --all
kubectl delete cronworkflow --all -n argo
```

## Troubleshooting

### Issue: Template Not Found

**Symptom**: Error: "workflowtemplate not found"

**Solution**: Verify template exists and namespace is correct

```bash
kubectl get workflowtemplate -n argo
argo template list -n argo
```

### Issue: CronWorkflow Not Triggering

**Symptom**: CronWorkflow created but no workflows are running

**Solution**: Check schedule format and workflow controller logs

```bash
kubectl get cronworkflow <name> -n argo -o yaml
kubectl logs -n argo deployment/workflow-controller | grep cron
```

### Issue: Template Reference Fails

**Symptom**: Error referencing template from another template

**Solution**: Ensure referenced template exists and is in correct namespace

```bash
kubectl get workflowtemplate -n argo
# For cluster scope
kubectl get clusterworkflowtemplate
```

## Key Takeaways

- WorkflowTemplates enable reusable workflow definitions
- ClusterWorkflowTemplates are available cluster-wide
- CronWorkflows schedule automatic workflow execution
- Template references enable modular, maintainable workflows
- Parameters make templates flexible and configurable
- Multiple entry points provide flexibility in template usage
- Versioning templates enables safe updates
- Template libraries promote code reuse across projects

## Cleanup

Remove all resources created in this lab:

```bash
# Delete workflows
argo delete -n argo --all

# Delete WorkflowTemplates
kubectl delete workflowtemplate --all -n argo

# Delete ClusterWorkflowTemplates
kubectl delete clusterworkflowtemplate --all

# Delete CronWorkflows
kubectl delete cronworkflow --all -n argo
```

## Congratulations

You have completed all Argo Workflows labs! You now have hands-on experience with:

- Installing and configuring Argo Workflows
- Creating workflows with different template types
- Building complex DAG workflows
- Managing artifacts and data flow
- Creating reusable templates and scheduled workflows

## Next Steps

- Explore [Argo Rollouts Labs](../03-argo-rollouts/) for progressive delivery patterns
- Practice with real-world CI/CD scenarios
- Integrate Argo Workflows with your existing pipelines
- Explore advanced features like workflow hooks, exit handlers, and metrics

## Additional Resources

- [WorkflowTemplate Documentation](https://argoproj.github.io/argo-workflows/workflow-templates/)
- [ClusterWorkflowTemplate Documentation](https://argoproj.github.io/argo-workflows/cluster-workflow-templates/)
- [CronWorkflow Documentation](https://argoproj.github.io/argo-workflows/cron-workflows/)
- [Template Examples](https://github.com/argoproj/argo-workflows/tree/master/examples)
