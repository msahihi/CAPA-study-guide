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

## Retry and Timeout Strategies

Retry and timeout strategies ensure workflow resilience by handling transient failures and preventing indefinite execution. These patterns are essential for production workflows that interact with external services or handle unreliable operations.

### Retry Policies

Retry policies automatically re-execute failed steps based on configurable parameters.

#### Basic Retry Configuration

```yaml
templates:
- name: flaky-task
  retryStrategy:
    limit: 3
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["exit $((RANDOM % 2))"]  # Randomly succeeds or fails
```

#### Retry with Backoff

Exponential backoff prevents overwhelming external services during retries.

```yaml
templates:
- name: api-call
  retryStrategy:
    limit: 5
    retryPolicy: Always
    backoff:
      duration: "1"      # Initial duration in seconds
      factor: 2          # Multiplier for each retry
      maxDuration: "1m"  # Maximum backoff duration
  container:
    image: curlimages/curl:latest
    command: [sh, -c]
    args: ["curl -f https://api.example.com/data || exit 1"]
```

**Backoff Calculation:**

- Retry 1: 1s delay
- Retry 2: 2s delay (1s × 2)
- Retry 3: 4s delay (2s × 2)
- Retry 4: 8s delay (4s × 2)
- Retry 5: 16s delay (capped at maxDuration if specified)

#### Conditional Retry Policies

Control which failure conditions trigger retries.

```yaml
templates:
- name: critical-operation
  retryStrategy:
    limit: 3
    retryPolicy: OnFailure  # Options: Always, OnFailure, OnError, OnTransientError
    backoff:
      duration: "5"
      factor: 2
      maxDuration: "5m"
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        # Simulates operation with different exit codes
        STATUS=$((RANDOM % 4))
        echo "Operation status: $STATUS"
        exit $STATUS
```

**Retry Policy Options:**

- `Always`: Retry on any error or failure
- `OnFailure`: Retry on non-zero exit codes
- `OnError`: Retry on workflow errors (e.g., image pull failures)
- `OnTransientError`: Retry only on transient errors (network issues, temporary resource unavailability)

#### Expression-Based Retry

Use expressions to determine retry eligibility based on step outputs.

```yaml
templates:
- name: smart-retry
  retryStrategy:
    limit: 3
    expression: "asInt(lastRetry.exitCode) != 2"  # Don't retry if exit code is 2
    backoff:
      duration: "10"
  script:
    image: python:3.9
    command: [python]
    source: |
      import sys
      import random

      # Exit with code 2 for unrecoverable errors
      if random.random() < 0.2:
          print("Unrecoverable error")
          sys.exit(2)

      # Exit with code 1 for retryable errors
      if random.random() < 0.5:
          print("Retryable error")
          sys.exit(1)

      print("Success")
      sys.exit(0)
```

### Timeout Strategies

Timeouts prevent workflows from running indefinitely and ensure predictable execution.

#### Step-Level Timeouts

Set maximum execution time for individual steps.

```yaml
templates:
- name: time-limited-task
  timeout: "5m"  # Step times out after 5 minutes
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Starting long-running task..."
        sleep 300  # 5 minutes
        echo "Task completed"
```

#### Workflow-Level Timeouts

Control maximum execution time for the entire workflow.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: timeout-workflow-
spec:
  activeDeadlineSeconds: 600  # Workflow times out after 10 minutes
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: step-1
        template: task
    - - name: step-2
        template: task
    - - name: step-3
        template: task

  - name: task
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["echo 'Processing...' && sleep 60"]
```

#### Combined Retry and Timeout

Use both strategies together for robust error handling.

```yaml
templates:
- name: resilient-operation
  timeout: "2m"      # Each attempt times out after 2 minutes
  retryStrategy:
    limit: 3
    retryPolicy: OnError
    backoff:
      duration: "10"
      factor: 2
      maxDuration: "1m"
  container:
    image: curlimages/curl:latest
    command: [sh, -c]
    args:
      - |
        # This will timeout if curl takes > 2 minutes
        # Then retry up to 3 times with exponential backoff
        curl -m 120 -f https://api.example.com/slow-endpoint || exit 1
```

### Practical Patterns

#### Database Connection with Retry

```yaml
templates:
- name: db-operation
  retryStrategy:
    limit: 5
    retryPolicy: OnTransientError
    backoff:
      duration: "2"
      factor: 2
      maxDuration: "30"
  timeout: "1m"
  script:
    image: postgres:14
    command: [bash]
    source: |
      #!/bin/bash

      # Attempt database connection
      psql -h db.example.com -U user -d database -c "SELECT 1;" > /dev/null 2>&1

      if [ $? -ne 0 ]; then
        echo "Database connection failed"
        exit 1
      fi

      echo "Database operation successful"
      exit 0
```

#### API Call with Circuit Breaker Pattern

```yaml
templates:
- name: api-with-circuit-breaker
  inputs:
    parameters:
    - name: endpoint
  retryStrategy:
    limit: 3
    expression: "asInt(lastRetry.exitCode) != 3"  # Exit code 3 = circuit open
    backoff:
      duration: "5"
      factor: 2
  timeout: "30s"
  script:
    image: python:3.9
    command: [python]
    source: |
      import requests
      import sys
      import os

      endpoint = "{{inputs.parameters.endpoint}}"

      try:
          response = requests.get(endpoint, timeout=25)

          if response.status_code >= 500:
              # Server error - retryable
              print(f"Server error: {response.status_code}")
              sys.exit(1)
          elif response.status_code == 429:
              # Rate limited - circuit breaker triggered
              print("Rate limit exceeded - circuit breaker open")
              sys.exit(3)
          elif response.status_code >= 400:
              # Client error - not retryable
              print(f"Client error: {response.status_code}")
              sys.exit(2)
          else:
              print("API call successful")
              sys.exit(0)

      except requests.Timeout:
          print("Request timeout")
          sys.exit(1)  # Retryable
      except requests.RequestException as e:
          print(f"Request failed: {e}")
          sys.exit(1)  # Retryable
```

#### File Download with Progress Tracking

```yaml
templates:
- name: download-with-retry
  inputs:
    parameters:
    - name: url
    - name: destination
  retryStrategy:
    limit: 5
    retryPolicy: OnFailure
    backoff:
      duration: "5"
      factor: 2
  timeout: "10m"
  script:
    image: alpine:latest
    command: [sh]
    source: |
      #!/bin/sh

      URL="{{inputs.parameters.url}}"
      DEST="{{inputs.parameters.destination}}"

      echo "Downloading from $URL..."

      # Use wget with retry and progress tracking
      wget --tries=1 --timeout=60 --progress=dot:giga -O "$DEST" "$URL"

      if [ $? -ne 0 ]; then
        echo "Download failed"
        exit 1
      fi

      echo "Download completed successfully"
      exit 0
  outputs:
    artifacts:
    - name: downloaded-file
      path: "{{inputs.parameters.destination}}"
```

### Best Practices

#### 1. Set Appropriate Timeout Values

```yaml
# Short-lived operations (API calls)
timeout: "30s"

# Medium operations (data processing)
timeout: "5m"

# Long operations (large file transfers)
timeout: "30m"

# Workflow-level timeout (sum of all steps + buffer)
activeDeadlineSeconds: 3600  # 1 hour
```

#### 2. Use Exponential Backoff

Always use backoff for external service calls to avoid overwhelming services during outages.

```yaml
retryStrategy:
  limit: 5
  backoff:
    duration: "1"
    factor: 2
    maxDuration: "5m"
```

#### 3. Distinguish Transient from Permanent Failures

Use exit codes to indicate failure types:

- Exit code 0: Success
- Exit code 1: Transient failure (network, temporary unavailability)
- Exit code 2: Permanent failure (invalid input, authentication)
- Exit code 3+: Custom failure types (circuit breaker, rate limit)

#### 4. Combine Timeout with Retry

```yaml
timeout: "2m"       # Prevent individual attempts from hanging
retryStrategy:
  limit: 3          # Retry failed attempts
  backoff:
    duration: "10"
```

#### 5. Monitor Retry Metrics

Track retry behavior to identify:

- Frequently retried steps (may need reliability improvements)
- Steps that exhaust retry limits (may need increased limits or fixes)
- Average retry counts (indicates external service health)

## Hands-On Practice

- [Lab 02: Templates and Steps](../../labs/02-argo-workflows/lab-02-templates-steps.md) - Practice creating different template types, passing parameters and artifacts, and building multi-step workflows
