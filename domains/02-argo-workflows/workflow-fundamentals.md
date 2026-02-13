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

## Workflow Variables Deep-Dive

Understanding variable references is critical for building dynamic, data-driven workflows. Argo Workflows provides a rich variable system for passing data between steps, accessing workflow metadata, and implementing complex logic.

### Variable Reference Types

Argo Workflows supports multiple variable contexts depending on template type and execution stage.

#### Global Variables (Available Everywhere)

Variables in the `workflow` namespace are accessible from all templates:

```yaml
# Workflow metadata
{{workflow.name}}                    # Workflow name
{{workflow.namespace}}               # Namespace where workflow runs
{{workflow.uid}}                     # Unique workflow identifier
{{workflow.creationTimestamp}}       # When workflow was created
{{workflow.serviceAccountName}}      # Service account used
{{workflow.priority}}                # Workflow priority value
{{workflow.status}}                  # Current workflow phase (Success/Failed/Running)
{{workflow.failures}}                # Failure details (exit handlers only)

# Labels and annotations
{{workflow.labels.mylabel}}          # Specific label value
{{workflow.annotations.myannotation}}# Specific annotation value
{{workflow.labels}}                  # All labels as JSON string
{{workflow.annotations}}             # All annotations as JSON string

# Parameters
{{workflow.parameters.myParam}}      # Workflow-level parameter value
{{workflow.parameters}}              # All parameters as JSON string
```

**Example using global variables:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: global-vars-
  labels:
    environment: production
spec:
  entrypoint: main
  arguments:
    parameters:
    - name: version
      value: "v1.2.3"
  templates:
  - name: main
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Workflow: {{workflow.name}}"
          echo "Namespace: {{workflow.namespace}}"
          echo "UID: {{workflow.uid}}"
          echo "Environment: {{workflow.labels.environment}}"
          echo "Version: {{workflow.parameters.version}}"
```

#### Input and Output Variables

Templates receive data via inputs and expose data via outputs:

```yaml
# Input parameters and artifacts
{{inputs.parameters.NAME}}           # Input parameter value
{{inputs.parameters}}                # All input parameters as JSON
{{inputs.artifacts.NAME.path}}       # Path where input artifact is mounted

# Output parameters and artifacts
{{outputs.parameters.NAME.path}}     # Path to write output parameter
{{outputs.artifacts.NAME.path}}      # Path to write output artifact
{{outputs.result}}                   # Captured stdout (script templates)
```

**Example with inputs/outputs:**

```yaml
templates:
- name: producer
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'Generated data' > /tmp/output.txt"]
  outputs:
    parameters:
    - name: result
      valueFrom:
        path: /tmp/output.txt

- name: consumer
  inputs:
    parameters:
    - name: data
  container:
    image: alpine:latest
    command: [echo]
    args: ["Received: {{inputs.parameters.data}}"]
```

#### Steps Template Variables

In `steps` templates, reference previous step outputs:

```yaml
# Step outputs
{{steps.STEPNAME.outputs.result}}              # Step's stdout
{{steps.STEPNAME.outputs.parameters.NAME}}     # Specific output parameter
{{steps.STEPNAME.outputs.artifacts.NAME}}      # Output artifact reference

# Step status and metadata
{{steps.STEPNAME.status}}                      # Step phase (Succeeded/Failed)
{{steps.STEPNAME.exitCode}}                    # Container exit code
{{steps.STEPNAME.startedAt}}                   # Step start timestamp
{{steps.STEPNAME.finishedAt}}                  # Step completion timestamp
{{steps.STEPNAME.ip}}                          # Pod IP address
{{steps.STEPNAME.id}}                          # Unique step identifier
```

**Example using step variables:**

```yaml
templates:
- name: sequential-steps
  steps:
  - - name: generate-id
      template: create-id

  - - name: process-data
      template: process
      arguments:
        parameters:
        - name: id
          value: "{{steps.generate-id.outputs.result}}"

  - - name: verify
      template: check-status
      when: "{{steps.process-data.status}} == Succeeded"
      arguments:
        parameters:
        - name: exit-code
          value: "{{steps.process-data.exitCode}}"
```

#### DAG Template Variables

In `dag` templates, reference task outputs (similar to steps, but uses `tasks` instead):

```yaml
# Task outputs
{{tasks.TASKNAME.outputs.result}}              # Task's stdout
{{tasks.TASKNAME.outputs.parameters.NAME}}     # Specific output parameter
{{tasks.TASKNAME.status}}                      # Task phase
{{tasks.TASKNAME.exitCode}}                    # Container exit code
```

**Example using task variables:**

```yaml
templates:
- name: dag-example
  dag:
    tasks:
    - name: generate-config
      template: create-config

    - name: deploy-app
      dependencies: [generate-config]
      template: deploy
      arguments:
        parameters:
        - name: config
          value: "{{tasks.generate-config.outputs.parameters.config}}"

    - name: verify-deployment
      dependencies: [deploy-app]
      template: verify
      when: "{{tasks.deploy-app.status}} == Succeeded"
```

#### Loop Variables

When using `withItems` or `withParam`, access current iteration data:

```yaml
{{item}}                             # Current item (simple list)
{{item.FIELDNAME}}                   # Field from JSON/YAML object
```

**Example with loops:**

```yaml
templates:
- name: process-list
  steps:
  - - name: process-each
      template: processor
      arguments:
        parameters:
        - name: name
          value: "{{item.name}}"
        - name: value
          value: "{{item.value}}"
      withItems:
      - name: "item1"
        value: "100"
      - name: "item2"
        value: "200"
      - name: "item3"
        value: "300"

- name: processor
  inputs:
    parameters:
    - name: name
    - name: value
  container:
    image: alpine:latest
    command: [echo]
    args: ["Processing {{inputs.parameters.name}} = {{inputs.parameters.value}}"]
```

#### Container/Script-Specific Variables

Available only in container and script templates:

```yaml
{{pod.name}}                         # Pod name running the template
{{retries}}                          # Current retry attempt number

# Retry context (retryStrategy enabled)
{{lastRetry.exitCode}}               # Exit code from previous attempt (string)
{{lastRetry.status}}                 # Status from previous attempt
{{lastRetry.duration}}               # Duration of previous attempt
{{lastRetry.message}}                # Failure message from previous attempt
```

**Example with retry variables:**

```yaml
templates:
- name: retry-with-context
  retryStrategy:
    limit: "3"
    retryPolicy: "Always"
    backoff:
      duration: "10s"
      factor: 2
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Attempt {{retries}} on pod {{pod.name}}"
        if [ {{retries}} -lt 2 ]; then
          echo "Simulating failure"
          exit 1
        fi
        echo "Success on retry {{retries}}!"
```

### Expression Tags (v3.1+)

For advanced logic, use **expression tags** with the `=` prefix:

```yaml
# Simple tag (variable substitution)
{{workflow.parameters.count}}

# Expression tag (evaluated as code)
{{=workflow.parameters.count}}
{{=asInt(workflow.parameters.count) * 2}}
{{=asInt(lastRetry.exitCode) >= 2}}
```

**Expression capabilities:**

- **Type conversion**: `asInt()`, `asFloat()`, `toString()`
- **JSON operations**: `toJson()`, `jsonpath()`
- **Filtering and mapping**: Use expr-lang syntax
- **Sprig functions**: String manipulation, math operations

**Example with expressions:**

```yaml
templates:
- name: conditional-logic
  inputs:
    parameters:
    - name: threshold
      value: "5"
    - name: current
      value: "7"
  steps:
  - - name: check-threshold
      template: alert
      when: "{{=asInt(inputs.parameters.current) > asInt(inputs.parameters.threshold)}}"

  - - name: process-json
      template: extract
      arguments:
        parameters:
        - name: data
          value: '{"status": "active", "count": 42}'

- name: extract
  inputs:
    parameters:
    - name: data
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Count value: {{=jsonpath(toJson(inputs.parameters.data), '$.count')}}"
```

### Variable Scoping Rules

Understanding scope prevents common errors:

1. **Sequential Steps**: Can only access completed predecessor outputs

   ```yaml
   steps:
   - - name: step1
       template: task1
   - - name: step2
       template: task2
       arguments:
         parameters:
         - name: data
           value: "{{steps.step1.outputs.result}}"  # ✅ Valid
   ```

2. **DAG Tasks**: Can reference any previously defined task

   ```yaml
   dag:
     tasks:
     - name: task1
       template: job1
     - name: task2
       dependencies: [task1]
       template: job2
       arguments:
         parameters:
         - name: result
           value: "{{tasks.task1.outputs.result}}"  # ✅ Valid
   ```

3. **Exit Handlers**: Only access workflow-level variables

   ```yaml
   spec:
     onExit: exit-handler
   templates:
   - name: exit-handler
     container:
       image: alpine:latest
       args: ["Status: {{workflow.status}}"]  # ✅ Valid
       # Cannot access {{steps.X}} here ❌
   ```

### Parameter Passing Best Practices

**1. Use hyphenated names with bracket notation:**

```yaml
# Correct for hyphenated names
{{inputs.parameters['my-param']}}

# Incorrect (won't work)
{{inputs.parameters.my-param}}
```

**2. Avoid whitespace in brackets:**

```yaml
# Correct
{{inputs.parameters['my-param']}}

# Incorrect (interpolation issues)
{{inputs.parameters[ 'my-param' ]}}
```

**3. Cast retry variables to integers:**

```yaml
# Correct
when: "{{=asInt(lastRetry.exitCode) >= 2}}"

# Incorrect (string comparison)
when: "{{lastRetry.exitCode}} >= 2"
```

**4. Use .JSON for complete data sets:**

```yaml
# Get all parameters as JSON
{{workflow.parameters}}

# Get specific parameter
{{workflow.parameters.myParam}}
```

### Data Processing Workflow Pattern

Combining variables for data processing pipelines:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: data-pipeline-
spec:
  entrypoint: main
  arguments:
    parameters:
    - name: input-file
      value: "data.csv"
    - name: batch-size
      value: "1000"

  templates:
  - name: main
    steps:
    - - name: extract
        template: extract-data
        arguments:
          parameters:
          - name: file
            value: "{{workflow.parameters.input-file}}"

    - - name: transform
        template: transform-data
        arguments:
          parameters:
          - name: raw-data
            value: "{{steps.extract.outputs.parameters.data}}"
          artifacts:
          - name: data-file
            from: "{{steps.extract.outputs.artifacts.dataset}}"

    - - name: load
        template: load-data
        when: "{{=asInt(steps.transform.exitCode) == 0}}"
        arguments:
          parameters:
          - name: record-count
            value: "{{steps.transform.outputs.parameters.count}}"
          - name: batch-size
            value: "{{workflow.parameters.batch-size}}"

  - name: extract-data
    inputs:
      parameters:
      - name: file
    container:
      image: python:3.9-slim
      command: [python, -c]
      args:
        - |
          import json
          data = {"records": 5000, "file": "{{inputs.parameters.file}}"}
          print(json.dumps(data))
    outputs:
      parameters:
      - name: data
        valueFrom:
          path: /tmp/stdout
      artifacts:
      - name: dataset
        path: /tmp/data.csv

  - name: transform-data
    inputs:
      parameters:
      - name: raw-data
      artifacts:
      - name: data-file
        path: /tmp/input.csv
    container:
      image: python:3.9-slim
      command: [sh, -c]
      args:
        - |
          echo "Transforming data..."
          echo "5000" > /tmp/count.txt
          exit 0
    outputs:
      parameters:
      - name: count
        valueFrom:
          path: /tmp/count.txt

  - name: load-data
    inputs:
      parameters:
      - name: record-count
      - name: batch-size
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          records={{inputs.parameters.record-count}}
          batch={{inputs.parameters.batch-size}}
          batches=$((records / batch))
          echo "Loading $records records in $batches batches"
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
- [Understanding Workflow Phases](https://argo-workflows.readthedocs.io/en/latest/variables/) - Phase lifecycle guide

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
