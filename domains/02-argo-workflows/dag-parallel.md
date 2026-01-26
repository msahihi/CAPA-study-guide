# DAG and Parallel Execution

## Overview

Directed Acyclic Graph (DAG) workflows provide a powerful way to define complex task dependencies and parallel execution patterns in Argo Workflows. Unlike step-based workflows where execution order is implicit, DAG workflows explicitly define task dependencies, enabling sophisticated orchestration patterns and optimal parallel execution.

## Key Topics

### DAG Workflows

DAG (Directed Acyclic Graph) templates define workflows where tasks have explicit dependencies on other tasks.

#### Basic DAG Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-example-
spec:
  entrypoint: main-dag
  templates:
  - name: main-dag
    dag:
      tasks:
      - name: task-a
        template: worker
        arguments:
          parameters:
          - name: message
            value: "Task A"

      - name: task-b
        template: worker
        arguments:
          parameters:
          - name: message
            value: "Task B"
        dependencies: [task-a]

      - name: task-c
        template: worker
        arguments:
          parameters:
          - name: message
            value: "Task C"
        dependencies: [task-a]

  - name: worker
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:latest
      command: [echo]
      args: ["{{inputs.parameters.message}}"]
```

**Execution Flow:**

- `task-a` runs first
- `task-b` and `task-c` run in parallel after `task-a` completes

#### DAG vs Steps

**Steps Approach (Sequential by default):**

```yaml
templates:
- name: steps-workflow
  steps:
  - - name: step-1
      template: task-1
  - - name: step-2
      template: task-2
  - - name: step-3
      template: task-3
```

**DAG Approach (Parallel when possible):**

```yaml
templates:
- name: dag-workflow
  dag:
    tasks:
    - name: task-1
      template: task-template

    - name: task-2
      template: task-template
      dependencies: [task-1]

    - name: task-3
      template: task-template
      dependencies: [task-1]
```

**Key Differences:**

- Steps: Implicit execution order, array-based syntax
- DAG: Explicit dependencies, more flexible, better visualization
- Steps: Simpler for linear workflows
- DAG: Better for complex workflows with multiple parallel paths

### Dependencies Between Tasks

Dependencies define which tasks must complete before others can start.

#### Single Dependency

```yaml
templates:
- name: dependency-example
  dag:
    tasks:
    - name: prepare
      template: prepare-env

    - name: build
      template: build-app
      dependencies: [prepare]

    - name: test
      template: run-tests
      dependencies: [build]
```

#### Multiple Dependencies

A task can depend on multiple other tasks - it will only start when all dependencies complete.

```yaml
templates:
- name: multi-dependency
  dag:
    tasks:
    - name: fetch-code
      template: git-clone

    - name: fetch-dependencies
      template: download-deps

    - name: build
      template: build-app
      dependencies: [fetch-code, fetch-dependencies]

    - name: unit-test
      template: run-unit-tests
      dependencies: [build]

    - name: integration-test
      template: run-integration-tests
      dependencies: [build]

    - name: deploy
      template: deploy-app
      dependencies: [unit-test, integration-test]
```

**Execution Flow:**

1. `fetch-code` and `fetch-dependencies` run in parallel
2. `build` waits for both to complete
3. `unit-test` and `integration-test` run in parallel after build
4. `deploy` waits for both tests to complete

#### Conditional Dependencies

Tasks can have conditional execution based on dependency status.

```yaml
templates:
- name: conditional-dag
  dag:
    tasks:
    - name: build
      template: build-app

    - name: test
      template: run-tests
      dependencies: [build]

    - name: deploy-prod
      template: deploy
      dependencies: [test]
      when: "{{tasks.test.status}} == Succeeded"

    - name: notify-failure
      template: send-alert
      dependencies: [test]
      when: "{{tasks.test.status}} == Failed"
```

### Parallel Execution

Parallel execution allows multiple tasks to run simultaneously, reducing overall workflow execution time.

#### Full Parallelism

All tasks without dependencies run in parallel.

```yaml
templates:
- name: parallel-tasks
  dag:
    tasks:
    - name: task-1
      template: worker
      arguments:
        parameters:
        - name: id
          value: "1"

    - name: task-2
      template: worker
      arguments:
        parameters:
        - name: id
          value: "2"

    - name: task-3
      template: worker
      arguments:
        parameters:
        - name: id
          value: "3"

    - name: task-4
      template: worker
      arguments:
        parameters:
        - name: id
          value: "4"

- name: worker
  inputs:
    parameters:
    - name: id
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'Task {{inputs.parameters.id}}' && sleep 10"]
```

All four tasks execute simultaneously.

#### Controlled Parallelism

Use `parallelism` to limit concurrent task execution.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: limited-parallel-
spec:
  entrypoint: main
  parallelism: 2  # Maximum 2 tasks run at once

  templates:
  - name: main
    dag:
      tasks:
      - name: task-1
        template: worker
      - name: task-2
        template: worker
      - name: task-3
        template: worker
      - name: task-4
        template: worker
      - name: task-5
        template: worker

  - name: worker
    container:
      image: alpine:latest
      command: [sleep, "10"]
```

Tasks execute in waves of 2 at a time.

#### Dynamic Parallel Execution

Use `withItems` or `withParam` for dynamic parallel task creation.

**With Items:**

```yaml
templates:
- name: process-list
  dag:
    tasks:
    - name: process-item
      template: processor
      arguments:
        parameters:
        - name: item
          value: "{{item}}"
      withItems:
      - apple
      - banana
      - cherry
      - date
      - elderberry

- name: processor
  inputs:
    parameters:
    - name: item
  container:
    image: alpine:latest
    command: [echo]
    args: ["Processing {{inputs.parameters.item}}"]
```

**With Parameters (JSON list):**

```yaml
templates:
- name: dynamic-parallel
  dag:
    tasks:
    - name: generate-list
      template: generate-items

    - name: process-items
      template: processor
      arguments:
        parameters:
        - name: item
          value: "{{item}}"
      withParam: "{{tasks.generate-list.outputs.result}}"
      dependencies: [generate-list]

- name: generate-items
  script:
    image: python:3.9
    command: [python]
    source: |
      import json
      items = ["item1", "item2", "item3", "item4"]
      print(json.dumps(items))

- name: processor
  inputs:
    parameters:
    - name: item
  container:
    image: alpine:latest
    command: [echo]
    args: ["Processing {{inputs.parameters.item}}"]
```

### Fan-Out/Fan-In Patterns

Fan-out/fan-in patterns distribute work across parallel tasks and then aggregate results.

#### Basic Fan-Out/Fan-In

```yaml
templates:
- name: fan-out-fan-in
  dag:
    tasks:
    # Fan-out: Generate work
    - name: prepare-work
      template: prepare

    # Fan-out: Parallel processing
    - name: process-1
      template: process-chunk
      arguments:
        parameters:
        - name: chunk-id
          value: "1"
      dependencies: [prepare-work]

    - name: process-2
      template: process-chunk
      arguments:
        parameters:
        - name: chunk-id
          value: "2"
      dependencies: [prepare-work]

    - name: process-3
      template: process-chunk
      arguments:
        parameters:
        - name: chunk-id
          value: "3"
      dependencies: [prepare-work]

    # Fan-in: Aggregate results
    - name: aggregate
      template: combine-results
      arguments:
        artifacts:
        - name: result-1
          from: "{{tasks.process-1.outputs.artifacts.result}}"
        - name: result-2
          from: "{{tasks.process-2.outputs.artifacts.result}}"
        - name: result-3
          from: "{{tasks.process-3.outputs.artifacts.result}}"
      dependencies: [process-1, process-2, process-3]

- name: prepare
  container:
    image: alpine:latest
    command: [echo, "Preparing work distribution"]

- name: process-chunk
  inputs:
    parameters:
    - name: chunk-id
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Processing chunk {{inputs.parameters.chunk-id}}" > /tmp/result.txt
  outputs:
    artifacts:
    - name: result
      path: /tmp/result.txt

- name: combine-results
  inputs:
    artifacts:
    - name: result-1
      path: /tmp/results/result-1.txt
    - name: result-2
      path: /tmp/results/result-2.txt
    - name: result-3
      path: /tmp/results/result-3.txt
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        cat /tmp/results/*.txt
        echo "All results aggregated"
```

#### Dynamic Fan-Out/Fan-In

```yaml
templates:
- name: dynamic-fan-out-fan-in
  dag:
    tasks:
    # Generate dynamic list
    - name: generate-tasks
      template: task-generator

    # Fan-out: Dynamic parallel processing
    - name: process-tasks
      template: processor
      arguments:
        parameters:
        - name: task-id
          value: "{{item.id}}"
        - name: task-data
          value: "{{item.data}}"
      withParam: "{{tasks.generate-tasks.outputs.result}}"
      dependencies: [generate-tasks]

    # Fan-in: Wait for all and aggregate
    - name: aggregate-results
      template: aggregator
      dependencies: [process-tasks]

- name: task-generator
  script:
    image: python:3.9
    command: [python]
    source: |
      import json
      tasks = [
          {"id": "1", "data": "dataset-1"},
          {"id": "2", "data": "dataset-2"},
          {"id": "3", "data": "dataset-3"},
          {"id": "4", "data": "dataset-4"},
          {"id": "5", "data": "dataset-5"}
      ]
      print(json.dumps(tasks))

- name: processor
  inputs:
    parameters:
    - name: task-id
    - name: task-data
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Task {{inputs.parameters.task-id}}: Processing {{inputs.parameters.task-data}}"
        sleep 5

- name: aggregator
  container:
    image: alpine:latest
    command: [echo, "All tasks completed, aggregating results"]
```

## Practice Examples

### Complete DAG Workflow Example

**CI/CD Pipeline with DAG:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: cicd-dag-pipeline-
spec:
  entrypoint: cicd-pipeline
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/example/app.git"
    - name: environment
      value: "staging"

  templates:
  - name: cicd-pipeline
    dag:
      tasks:
      # Stage 1: Preparation
      - name: checkout-code
        template: git-checkout
        arguments:
          parameters:
          - name: repo
            value: "{{workflow.parameters.repo-url}}"

      - name: setup-environment
        template: env-setup
        arguments:
          parameters:
          - name: env
            value: "{{workflow.parameters.environment}}"

      # Stage 2: Parallel build and analysis
      - name: build-backend
        template: build-service
        arguments:
          parameters:
          - name: service
            value: "backend"
        dependencies: [checkout-code]

      - name: build-frontend
        template: build-service
        arguments:
          parameters:
          - name: service
            value: "frontend"
        dependencies: [checkout-code]

      - name: security-scan
        template: security-check
        dependencies: [checkout-code]

      # Stage 3: Parallel testing
      - name: test-backend
        template: run-tests
        arguments:
          parameters:
          - name: service
            value: "backend"
        dependencies: [build-backend]

      - name: test-frontend
        template: run-tests
        arguments:
          parameters:
          - name: service
            value: "frontend"
        dependencies: [build-frontend]

      - name: integration-tests
        template: run-integration-tests
        dependencies: [build-backend, build-frontend]

      # Stage 4: Quality gates
      - name: quality-gate
        template: check-quality
        dependencies: [test-backend, test-frontend, integration-tests, security-scan]

      # Stage 5: Deployment
      - name: deploy-to-staging
        template: deploy
        arguments:
          parameters:
          - name: environment
            value: "{{workflow.parameters.environment}}"
        dependencies: [quality-gate]
        when: "{{tasks.quality-gate.outputs.parameters.passed}} == true"

      # Stage 6: Verification
      - name: smoke-tests
        template: smoke-test
        dependencies: [deploy-to-staging]

      - name: notify-success
        template: send-notification
        arguments:
          parameters:
          - name: status
            value: "success"
        dependencies: [smoke-tests]

  - name: git-checkout
    inputs:
      parameters:
      - name: repo
    container:
      image: alpine/git:latest
      command: [git, clone, "{{inputs.parameters.repo}}", /workspace]

  - name: env-setup
    inputs:
      parameters:
      - name: env
    container:
      image: alpine:latest
      command: [echo]
      args: ["Setting up environment: {{inputs.parameters.env}}"]

  - name: build-service
    inputs:
      parameters:
      - name: service
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Building {{inputs.parameters.service}}"
          sleep 5
          echo "Build completed"

  - name: security-check
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["echo 'Running security scan...' && sleep 3"]

  - name: run-tests
    inputs:
      parameters:
      - name: service
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Testing {{inputs.parameters.service}}"
          sleep 5
          echo "Tests passed"

  - name: run-integration-tests
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["echo 'Running integration tests...' && sleep 5"]

  - name: check-quality
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Checking quality gates..."
          echo "true" > /tmp/passed.txt
    outputs:
      parameters:
      - name: passed
        valueFrom:
          path: /tmp/passed.txt

  - name: deploy
    inputs:
      parameters:
      - name: environment
    container:
      image: alpine:latest
      command: [echo]
      args: ["Deploying to {{inputs.parameters.environment}}"]

  - name: smoke-test
    container:
      image: alpine:latest
      command: [echo, "Running smoke tests..."]

  - name: send-notification
    inputs:
      parameters:
      - name: status
    container:
      image: alpine:latest
      command: [echo]
      args: ["Notification: Deployment {{inputs.parameters.status}}"]
```

## Study Resources

- [DAG Workflows Documentation](https://argoproj.github.io/argo-workflows/walk-through/dag/) - Official DAG guide
- [Parallelism Control](https://argoproj.github.io/argo-workflows/parallelism/) - Managing parallel execution
- [Workflow Dependencies](https://argoproj.github.io/argo-workflows/walk-through/dag/) - Task dependency patterns
- [Dynamic Workflows](https://argoproj.github.io/argo-workflows/walk-through/loops/) - Dynamic task generation

## Key Points to Remember

- DAG workflows define explicit task dependencies using `dependencies` field
- Tasks without dependencies execute immediately in parallel
- Tasks with dependencies wait for all dependencies to complete
- Use `when` conditions for conditional task execution
- `parallelism` at workflow level limits concurrent task execution
- `withItems` creates parallel tasks from a static list
- `withParam` creates parallel tasks from a dynamic JSON array
- Fan-out pattern distributes work across parallel tasks
- Fan-in pattern aggregates results from parallel tasks
- DAG provides better visualization than steps for complex workflows
- Tasks can access outputs from their dependencies
- Failed dependencies prevent dependent tasks from running
- Use `continueOn` to proceed even when dependencies fail
- DAG workflows scale better for large numbers of parallel tasks
- Dependencies create an implicit execution order graph

## Hands-On Practice

- [Lab 03: Building DAG Workflows](../../labs/02-argo-workflows/lab-03-dag-workflows.md) - Practice creating DAG workflows, implementing parallel execution patterns, and building fan-out/fan-in pipelines
