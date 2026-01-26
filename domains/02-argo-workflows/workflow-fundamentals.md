# Workflow Fundamentals

## Overview

Argo Workflows is a container-native workflow engine for Kubernetes that allows you to orchestrate parallel jobs. Each workflow step is implemented as a container, making workflows highly portable and scalable. Understanding the fundamental concepts of workflows is essential for designing and implementing effective workflow automation.

## Key Topics

### Workflow CRD Structure

Argo Workflows extends Kubernetes using Custom Resource Definitions (CRDs). The main CRD is the Workflow resource.

**Basic Workflow Structure:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: hello-world
  namespace: argo
spec:
  entrypoint: main
  templates:
  - name: main
    container:
      image: docker/whalesay
      command: [cowsay]
      args: ["hello world"]
```

**Key Components:**

- `apiVersion`: Always `argoproj.io/v1alpha1` for Workflow resources
- `kind`: Workflow, WorkflowTemplate, or ClusterWorkflowTemplate
- `metadata`: Standard Kubernetes metadata (name, namespace, labels, annotations)
- `spec`: The workflow specification containing all workflow logic

### Workflow Spec

The workflow specification defines the workflow's behavior and includes several important fields.

**Core Spec Fields:**

- `entrypoint`: The name of the template to start execution (required)
- `templates`: Array of template definitions that make up the workflow
- `arguments`: Input parameters and artifacts for the workflow
- `serviceAccountName`: Kubernetes service account for workflow execution
- `ttlStrategy`: Time-to-live settings for completed workflows
- `activeDeadlineSeconds`: Maximum duration the workflow can run
- `podGC`: Pod garbage collection strategy
- `volumeClaimTemplates`: PVC templates for workflow storage

**Example with Common Spec Fields:**

```yaml
spec:
  entrypoint: main
  serviceAccountName: workflow-executor
  activeDeadlineSeconds: 3600  # 1 hour timeout
  ttlStrategy:
    secondsAfterCompletion: 86400  # Keep for 1 day
  arguments:
    parameters:
    - name: message
      value: "Hello Argo"
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

### Entrypoint

The entrypoint defines which template the workflow should execute first when it starts.

**Single Entrypoint:**

```yaml
spec:
  entrypoint: main
  templates:
  - name: main
    container:
      image: alpine:latest
      command: [echo, "Starting workflow"]
```

**Entrypoint with Steps:**

```yaml
spec:
  entrypoint: main-workflow
  templates:
  - name: main-workflow
    steps:
    - - name: step-1
        template: task-1
    - - name: step-2
        template: task-2

  - name: task-1
    container:
      image: alpine:latest
      command: [echo, "Task 1"]

  - name: task-2
    container:
      image: alpine:latest
      command: [echo, "Task 2"]
```

**Dynamic Entrypoint Selection:**

You can override the entrypoint when submitting a workflow:

```bash
argo submit workflow.yaml --entrypoint alternative-entry
```

### Workflow Phases

Workflows progress through several phases during their lifecycle. Understanding these phases is crucial for monitoring and troubleshooting.

**Workflow Phases:**

1. **Pending**: Workflow has been created but not yet started
2. **Running**: Workflow is currently executing
3. **Succeeded**: Workflow completed successfully
4. **Failed**: Workflow failed with errors
5. **Error**: Workflow encountered a system error
6. **Skipped**: Workflow was skipped (conditional execution)
7. **Omitted**: Step was omitted due to conditional logic

**Phase Diagram:**

```
Pending → Running → Succeeded
                 → Failed
                 → Error
```

**Checking Workflow Phase:**

```bash
# Get workflow status
argo get <workflow-name>

# Watch workflow progress
argo watch <workflow-name>

# List workflows with their phases
argo list
```

**Phase Conditions:**

```yaml
spec:
  entrypoint: conditional-workflow
  templates:
  - name: conditional-workflow
    steps:
    - - name: step-1
        template: task-1
    - - name: step-2
        template: task-2
        when: "{{steps.step-1.status}} == Succeeded"
```

### Basic Workflow Patterns

Several fundamental patterns are commonly used when building workflows.

#### 1. Sequential Execution Pattern

Execute tasks one after another in sequence.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: sequential-workflow
spec:
  entrypoint: sequential
  templates:
  - name: sequential
    steps:
    - - name: step-1
        template: task
        arguments:
          parameters:
          - name: message
            value: "First task"

    - - name: step-2
        template: task
        arguments:
          parameters:
          - name: message
            value: "Second task"

    - - name: step-3
        template: task
        arguments:
          parameters:
          - name: message
            value: "Third task"

  - name: task
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:latest
      command: [echo]
      args: ["{{inputs.parameters.message}}"]
```

#### 2. Parallel Execution Pattern

Execute multiple tasks simultaneously.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: parallel-workflow
spec:
  entrypoint: parallel
  templates:
  - name: parallel
    steps:
    - - name: task-1
        template: task
        arguments:
          parameters:
          - name: id
            value: "1"

      - name: task-2
        template: task
        arguments:
          parameters:
          - name: id
            value: "2"

      - name: task-3
        template: task
        arguments:
          parameters:
          - name: id
            value: "3"

  - name: task
    inputs:
      parameters:
      - name: id
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["echo 'Task {{inputs.parameters.id}}' && sleep 5"]
```

#### 3. Conditional Execution Pattern

Execute tasks based on conditions.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: conditional-workflow
spec:
  entrypoint: conditional
  arguments:
    parameters:
    - name: environment
      value: "production"

  templates:
  - name: conditional
    steps:
    - - name: check-env
        template: check

    - - name: prod-deployment
        template: deploy-prod
        when: "{{workflow.parameters.environment}} == production"

      - name: dev-deployment
        template: deploy-dev
        when: "{{workflow.parameters.environment}} == development"

  - name: check
    container:
      image: alpine:latest
      command: [echo, "Checking environment..."]

  - name: deploy-prod
    container:
      image: alpine:latest
      command: [echo, "Deploying to production"]

  - name: deploy-dev
    container:
      image: alpine:latest
      command: [echo, "Deploying to development"]
```

#### 4. Loop Pattern

Execute a template multiple times with different inputs.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: loop-workflow
spec:
  entrypoint: loop
  templates:
  - name: loop
    steps:
    - - name: process-items
        template: process
        arguments:
          parameters:
          - name: item
            value: "{{item}}"
        withItems:
        - apple
        - banana
        - cherry
        - date

  - name: process
    inputs:
      parameters:
      - name: item
    container:
      image: alpine:latest
      command: [echo]
      args: ["Processing {{inputs.parameters.item}}"]
```

#### 5. Retry Pattern

Automatically retry failed steps.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: retry-workflow
spec:
  entrypoint: retry-example
  templates:
  - name: retry-example
    retryStrategy:
      limit: "3"
      retryPolicy: "Always"
      backoff:
        duration: "10s"
        factor: 2
        maxDuration: "1m"
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["exit 1"]  # Simulates failure
```

## Practice Examples

### Complete Workflow Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: complete-example-
  namespace: argo
spec:
  entrypoint: main
  serviceAccountName: argo-workflow

  arguments:
    parameters:
    - name: environment
      value: "staging"
    - name: version
      value: "v1.0.0"

  templates:
  - name: main
    steps:
    # Step 1: Preparation
    - - name: prepare
        template: prepare-environment

    # Step 2: Parallel build and test
    - - name: build
        template: build-image
      - name: run-tests
        template: test-suite

    # Step 3: Deploy if tests passed
    - - name: deploy
        template: deploy-app
        when: "{{steps.run-tests.status}} == Succeeded"

    # Step 4: Verify deployment
    - - name: verify
        template: verify-deployment

  - name: prepare-environment
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Preparing environment: {{workflow.parameters.environment}}"
          echo "Version: {{workflow.parameters.version}}"

  - name: build-image
    container:
      image: alpine:latest
      command: [echo]
      args: ["Building Docker image for version {{workflow.parameters.version}}"]

  - name: test-suite
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Running test suite..."
          sleep 3
          echo "Tests passed!"

  - name: deploy-app
    container:
      image: alpine:latest
      command: [echo]
      args: ["Deploying to {{workflow.parameters.environment}}"]

  - name: verify-deployment
    container:
      image: alpine:latest
      command: [echo]
      args: ["Verifying deployment health..."]
```

## Study Resources

- [Argo Workflows Core Concepts](https://argoproj.github.io/argo-workflows/workflow-concepts/) - Official documentation
- [Workflow Specification](https://argoproj.github.io/argo-workflows/fields/) - Complete field reference
- [Workflow Examples Repository](https://github.com/argoproj/argo-workflows/tree/master/examples) - Official examples
- [Understanding Workflow Phases](https://argoproj.github.io/argo-workflows/workflow-phases/) - Phase lifecycle guide

## Key Points to Remember

- Workflows are Kubernetes CRDs that extend the cluster's API
- The `entrypoint` field determines which template starts execution
- Workflows progress through phases: Pending → Running → Succeeded/Failed
- Templates are reusable building blocks within workflows
- Use `steps` for sequential and parallel execution patterns
- Conditional execution uses the `when` field with expressions
- Retry strategies can automatically handle transient failures
- Workflow parameters enable dynamic workflow behavior
- Service accounts control workflow execution permissions
- TTL strategies manage automatic cleanup of completed workflows

## Hands-On Practice

- [Lab 01: Installation and Basics](../../labs/02-argo-workflows/lab-01-installation-basics.md) - Learn workflow fundamentals by creating and executing basic workflows, understanding phases, and monitoring execution
