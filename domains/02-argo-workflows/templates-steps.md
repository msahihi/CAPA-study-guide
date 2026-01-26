# Templates and Steps

## Overview

Templates are the fundamental building blocks of Argo Workflows. They define what work should be done and how it should be executed. Understanding the different template types and how to use step templates effectively is crucial for building complex, maintainable workflows.

## Key Topics

### Template Types

Argo Workflows supports several template types, each serving different purposes in workflow orchestration.

#### 1. Container Template

The most common template type that runs a container with specified image and commands.

**Basic Container Template:**

```yaml
templates:
- name: whalesay
  container:
    image: docker/whalesay:latest
    command: [cowsay]
    args: ["hello workflow"]
```

**Container with Resources:**

```yaml
templates:
- name: resource-limited
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'Running with resource limits'"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

**Container with Environment Variables:**

```yaml
templates:
- name: with-env
  inputs:
    parameters:
    - name: environment
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo $ENV_VAR"]
    env:
    - name: ENV_VAR
      value: "{{inputs.parameters.environment}}"
    - name: WORKFLOW_NAME
      value: "{{workflow.name}}"
```

#### 2. Script Template

Executes a script within a container, ideal for inline code execution.

**Basic Script Template:**

```yaml
templates:
- name: generate-data
  script:
    image: python:3.9
    command: [python]
    source: |
      import random
      print("Generated number:", random.randint(1, 100))
```

**Script with Input Parameters:**

```yaml
templates:
- name: process-data
  inputs:
    parameters:
    - name: input-data
    - name: operation
  script:
    image: python:3.9
    command: [python]
    source: |
      import sys
      import json

      data = {{inputs.parameters.input-data}}
      operation = "{{inputs.parameters.operation}}"

      if operation == "sum":
          result = sum(data)
      elif operation == "average":
          result = sum(data) / len(data)
      else:
          result = len(data)

      print(json.dumps({"result": result}))
```

**Script with Artifact Output:**

```yaml
templates:
- name: create-report
  script:
    image: python:3.9
    command: [python]
    source: |
      with open('/tmp/report.txt', 'w') as f:
          f.write('Workflow Report\n')
          f.write('Status: Success\n')
  outputs:
    artifacts:
    - name: report
      path: /tmp/report.txt
```

#### 3. Resource Template

Creates, updates, or deletes Kubernetes resources as part of the workflow.

**Create Resource:**

```yaml
templates:
- name: create-configmap
  resource:
    action: create
    manifest: |
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: workflow-config
      data:
        key: value
        environment: production
```

**Create with Success Condition:**

```yaml
templates:
- name: create-job
  resource:
    action: create
    successCondition: status.succeeded > 0
    failureCondition: status.failed > 3
    manifest: |
      apiVersion: batch/v1
      kind: Job
      metadata:
        generateName: workflow-job-
      spec:
        template:
          spec:
            containers:
            - name: worker
              image: alpine:latest
              command: ["echo", "Job completed"]
            restartPolicy: Never
```

**Delete Resource:**

```yaml
templates:
- name: cleanup-resources
  resource:
    action: delete
    manifest: |
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: workflow-config
```

#### 4. Suspend Template

Pauses workflow execution until manually resumed or a duration expires.

**Manual Resume:**

```yaml
templates:
- name: approval-gate
  suspend: {}
```

**Automatic Resume after Duration:**

```yaml
templates:
- name: wait-period
  suspend:
    duration: "1h"
```

#### 5. DAG Template

Defines workflows as Directed Acyclic Graphs with explicit dependencies.

```yaml
templates:
- name: dag-workflow
  dag:
    tasks:
    - name: task-a
      template: echo
      arguments:
        parameters:
        - name: message
          value: "Task A"

    - name: task-b
      dependencies: [task-a]
      template: echo
      arguments:
        parameters:
        - name: message
          value: "Task B"

    - name: task-c
      dependencies: [task-a]
      template: echo
      arguments:
        parameters:
        - name: message
          value: "Task C"

- name: echo
  inputs:
    parameters:
    - name: message
  container:
    image: alpine:latest
    command: [echo]
    args: ["{{inputs.parameters.message}}"]
```

### Step Templates

Step templates allow sequential and parallel execution of other templates using a list-based syntax.

#### Sequential Steps

Steps in different array elements execute sequentially.

```yaml
templates:
- name: sequential-steps
  steps:
  - - name: step-1
      template: task-template
      arguments:
        parameters:
        - name: message
          value: "First"

  - - name: step-2
      template: task-template
      arguments:
        parameters:
        - name: message
          value: "Second"

  - - name: step-3
      template: task-template
      arguments:
        parameters:
        - name: message
          value: "Third"
```

#### Parallel Steps

Steps in the same array element execute in parallel.

```yaml
templates:
- name: parallel-steps
  steps:
  - - name: parallel-1
      template: task-template
      arguments:
        parameters:
        - name: message
          value: "Parallel Task 1"

    - name: parallel-2
      template: task-template
      arguments:
        parameters:
        - name: message
          value: "Parallel Task 2"

    - name: parallel-3
      template: task-template
      arguments:
        parameters:
        - name: message
          value: "Parallel Task 3"
```

#### Mixed Sequential and Parallel

Combine sequential and parallel execution patterns.

```yaml
templates:
- name: mixed-steps
  steps:
  # First: Single sequential step
  - - name: initialize
      template: init-task

  # Second: Three parallel steps
  - - name: parallel-1
      template: worker-task
      arguments:
        parameters:
        - name: id
          value: "1"

    - name: parallel-2
      template: worker-task
      arguments:
        parameters:
        - name: id
          value: "2"

    - name: parallel-3
      template: worker-task
      arguments:
        parameters:
        - name: id
          value: "3"

  # Third: Single sequential step
  - - name: finalize
      template: final-task
```

### Template Invocation

Templates can be invoked in multiple ways with different argument passing mechanisms.

#### Direct Template Reference

```yaml
templates:
- name: caller
  steps:
  - - name: call-template
      template: worker
```

#### With Arguments

**Passing Parameters:**

```yaml
templates:
- name: caller
  steps:
  - - name: call-with-params
      template: worker
      arguments:
        parameters:
        - name: message
          value: "Hello from caller"
        - name: count
          value: "5"

- name: worker
  inputs:
    parameters:
    - name: message
    - name: count
  container:
    image: alpine:latest
    command: [echo]
    args: ["{{inputs.parameters.message}} - Count: {{inputs.parameters.count}}"]
```

**Passing Artifacts:**

```yaml
templates:
- name: caller
  steps:
  - - name: create-artifact
      template: create-file

  - - name: use-artifact
      template: read-file
      arguments:
        artifacts:
        - name: input-file
          from: "{{steps.create-artifact.outputs.artifacts.result}}"

- name: create-file
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'Hello World' > /tmp/output.txt"]
  outputs:
    artifacts:
    - name: result
      path: /tmp/output.txt

- name: read-file
  inputs:
    artifacts:
    - name: input-file
      path: /tmp/input.txt
  container:
    image: alpine:latest
    command: [cat]
    args: ["/tmp/input.txt"]
```

#### Template Reference with Loops

```yaml
templates:
- name: loop-caller
  steps:
  - - name: process-items
      template: processor
      arguments:
        parameters:
        - name: item
          value: "{{item}}"
      withItems:
      - value: 1
      - value: 2
      - value: 3
      - value: 4

- name: processor
  inputs:
    parameters:
    - name: item
  container:
    image: alpine:latest
    command: [echo]
    args: ["Processing item {{inputs.parameters.item}}"]
```

### Inputs and Outputs

Templates can define inputs and outputs for data flow between steps.

#### Input Parameters

```yaml
templates:
- name: greeter
  inputs:
    parameters:
    - name: name
      default: "World"
    - name: greeting
      value: "Hello"
  container:
    image: alpine:latest
    command: [echo]
    args: ["{{inputs.parameters.greeting}} {{inputs.parameters.name}}"]
```

#### Output Parameters

**From Step Output:**

```yaml
templates:
- name: generate-output
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'Generated Value' > /tmp/output.txt"]
  outputs:
    parameters:
    - name: result
      valueFrom:
        path: /tmp/output.txt

- name: consumer
  steps:
  - - name: generate
      template: generate-output

  - - name: consume
      template: print-value
      arguments:
        parameters:
        - name: value
          value: "{{steps.generate.outputs.parameters.result}}"

- name: print-value
  inputs:
    parameters:
    - name: value
  container:
    image: alpine:latest
    command: [echo]
    args: ["Received: {{inputs.parameters.value}}"]
```

#### Input Artifacts

```yaml
templates:
- name: artifact-processor
  inputs:
    artifacts:
    - name: source-code
      path: /src
      git:
        repo: https://github.com/example/repo.git
        revision: "main"
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["ls -la /src"]
```

#### Output Artifacts

```yaml
templates:
- name: build-artifact
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Building application..." > /tmp/build.log
        echo "Build successful" >> /tmp/build.log
  outputs:
    artifacts:
    - name: build-log
      path: /tmp/build.log
    - name: build-output
      path: /tmp/output
      archive:
        none: {}
```

## Practice Examples

### Complete Template Examples

**Multi-Stage Build Pipeline:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: build-pipeline-
spec:
  entrypoint: build-pipeline
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/example/app.git"
    - name: branch
      value: "main"

  templates:
  - name: build-pipeline
    steps:
    # Stage 1: Clone repository
    - - name: clone
        template: git-clone
        arguments:
          parameters:
          - name: repo
            value: "{{workflow.parameters.repo-url}}"
          - name: branch
            value: "{{workflow.parameters.branch}}"

    # Stage 2: Parallel build and test
    - - name: build
        template: build-image
        arguments:
          artifacts:
          - name: source
            from: "{{steps.clone.outputs.artifacts.source}}"

      - name: test
        template: run-tests
        arguments:
          artifacts:
          - name: source
            from: "{{steps.clone.outputs.artifacts.source}}"

    # Stage 3: Deploy if tests passed
    - - name: deploy
        template: deploy-app
        when: "{{steps.test.outputs.result}} == success"
        arguments:
          artifacts:
          - name: image
            from: "{{steps.build.outputs.artifacts.image}}"

  - name: git-clone
    inputs:
      parameters:
      - name: repo
      - name: branch
    container:
      image: alpine/git:latest
      command: [sh, -c]
      args:
        - |
          git clone {{inputs.parameters.repo}} /workspace
          cd /workspace && git checkout {{inputs.parameters.branch}}
    outputs:
      artifacts:
      - name: source
        path: /workspace

  - name: build-image
    inputs:
      artifacts:
      - name: source
        path: /src
    script:
      image: docker:20.10
      command: [sh]
      source: |
        cd /src
        echo "Building Docker image..."
        # Simulate build
        echo "Image built successfully" > /tmp/image.tar
    outputs:
      artifacts:
      - name: image
        path: /tmp/image.tar

  - name: run-tests
    inputs:
      artifacts:
      - name: source
        path: /src
    script:
      image: python:3.9
      command: [python]
      source: |
        import os
        print("Running tests...")
        # Simulate tests
        result = "success"
        with open('/tmp/test-result.txt', 'w') as f:
            f.write(result)
    outputs:
      parameters:
      - name: result
        valueFrom:
          path: /tmp/test-result.txt

  - name: deploy-app
    inputs:
      artifacts:
      - name: image
        path: /tmp/image.tar
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["echo 'Deploying application...' && cat /tmp/image.tar"]
```

## Study Resources

- [Template Types Documentation](https://argoproj.github.io/argo-workflows/workflow-templates/) - Official template reference
- [Steps vs DAG](https://argoproj.github.io/argo-workflows/walk-through/steps/) - Comparison guide
- [Variables and Parameters](https://argoproj.github.io/argo-workflows/variables/) - Variable reference guide
- [Script Templates](https://argoproj.github.io/argo-workflows/walk-through/scripts-and-results/) - Script template guide

## Key Points to Remember

- Container templates run Docker images with commands and arguments
- Script templates allow inline code execution in specified languages
- Resource templates manage Kubernetes resources within workflows
- Suspend templates pause workflow execution for approval or timing
- Steps in the same array execute in parallel
- Steps in different arrays execute sequentially
- Template inputs can include parameters and artifacts
- Template outputs can generate parameters and artifacts
- Parameters are simple values passed between templates
- Artifacts are files or directories passed between templates
- Use `{{inputs.parameters.name}}` to access input parameters
- Use `{{steps.step-name.outputs.parameters.name}}` to reference outputs
- Resource limits can be set per template
- Environment variables support parameter interpolation

## Hands-On Practice

- [Lab 02: Templates and Steps](../../labs/02-argo-workflows/lab-02-templates-steps.md) - Practice creating different template types, passing parameters and artifacts, and building multi-step workflows
