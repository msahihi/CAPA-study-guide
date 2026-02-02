# Lab 03: DAG Workflows

**Duration**: 40 minutes

## Objectives

By the end of this lab, you will be able to:

- Understand DAG (Directed Acyclic Graph) workflow structure
- Create DAG workflows with explicit dependencies
- Implement complex parallel execution patterns
- Use task-level parameters and artifacts in DAGs
- Handle conditional tasks in DAG workflows
- Debug and visualize DAG dependencies
- Compare DAG vs Steps workflows

## Prerequisites

- Completed [Lab 02: Templates and Steps](lab-02-templates-steps.md)
- Argo Workflows installed and running
- Understanding of workflow templates and parameters

## Lab Environment Verification

```bash
kubectl get pods -n argo
argo version
```

## Introduction to DAG Workflows

DAG (Directed Acyclic Graph) workflows define tasks and their dependencies explicitly, offering more flexibility than step-based workflows. In DAG workflows:

- Tasks are defined with explicit dependencies
- Parallel execution happens automatically when dependencies allow
- The graph structure is more visible and maintainable
- Complex dependency patterns are easier to express

**Key Differences: DAG vs Steps**

| Feature | Steps | DAG |
|---------|-------|-----|
| Structure | Implicit sequential/parallel | Explicit dependencies |
| Readability | Better for simple pipelines | Better for complex graphs |
| Flexibility | Limited by array structure | Highly flexible |
| Visualization | Linear flow | Graph structure |

## Step 1: Basic DAG Workflow (8 minutes)

### 1.1 Simple DAG with Linear Dependencies

Create `dag-basic.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-basic-
spec:
  serviceAccountName: argo
  entrypoint: main
  templates:
  - name: main
    dag:
      tasks:
      - name: task-a
        template: echo-task
        arguments:
          parameters:
          - name: message
            value: "Task A: Starting workflow"

      - name: task-b
        dependencies: [task-a]
        template: echo-task
        arguments:
          parameters:
          - name: message
            value: "Task B: Depends on A"

      - name: task-c
        dependencies: [task-b]
        template: echo-task
        arguments:
          parameters:
          - name: message
            value: "Task C: Depends on B"

  - name: echo-task
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "{{inputs.parameters.message}}"
          echo "Started at: $(date)"
          sleep 2
          echo "Completed at: $(date)"
```

Submit and observe the execution order:

```bash
kubectl create -n argo -f dag-basic.yaml
kubectl get workflow -n argo -w
```

View in the UI to see the DAG visualization.

### 1.2 DAG with Parallel Branches

Create `dag-parallel.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-parallel-
spec:
  serviceAccountName: argo
  entrypoint: main
  templates:
  - name: main
    dag:
      tasks:
      # Single root task
      - name: init
        template: task
        arguments:
          parameters:
          - name: task-name
            value: "Initialize"
          - name: duration
            value: "1"

      # Three parallel branches (all depend on init)
      - name: branch-a
        dependencies: [init]
        template: task
        arguments:
          parameters:
          - name: task-name
            value: "Branch A"
          - name: duration
            value: "3"

      - name: branch-b
        dependencies: [init]
        template: task
        arguments:
          parameters:
          - name: task-name
            value: "Branch B"
          - name: duration
            value: "4"

      - name: branch-c
        dependencies: [init]
        template: task
        arguments:
          parameters:
          - name: task-name
            value: "Branch C"
          - name: duration
            value: "2"

      # Converge to single task (depends on all branches)
      - name: finalize
        dependencies: [branch-a, branch-b, branch-c]
        template: task
        arguments:
          parameters:
          - name: task-name
            value: "Finalize"
          - name: duration
            value: "1"

  - name: task
    inputs:
      parameters:
      - name: task-name
      - name: duration
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "[{{inputs.parameters.task-name}}] Starting at $(date +%H:%M:%S)"
          sleep {{inputs.parameters.duration}}
          echo "[{{inputs.parameters.task-name}}] Completed at $(date +%H:%M:%S)"
```

Submit and observe parallel execution:

```bash
kubectl create -n argo -f dag-parallel.yaml
kubectl get workflow -n argo -w
```

Notice how branches A, B, and C run in parallel, and finalize waits for all three.

### 1.3 DAG with Diamond Pattern

Create `dag-diamond.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-diamond-
spec:
  serviceAccountName: argo
  entrypoint: diamond
  templates:
  - name: diamond
    dag:
      tasks:
      # Top of diamond
      - name: start
        template: log
        arguments:
          parameters:
          - name: message
            value: "Start of diamond pattern"

      # Left and right branches (parallel)
      - name: left
        dependencies: [start]
        template: log
        arguments:
          parameters:
          - name: message
            value: "Left branch"

      - name: right
        dependencies: [start]
        template: log
        arguments:
          parameters:
          - name: message
            value: "Right branch"

      # Bottom of diamond (waits for both branches)
      - name: end
        dependencies: [left, right]
        template: log
        arguments:
          parameters:
          - name: message
            value: "End of diamond pattern"

  - name: log
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:3.23
      command: [echo]
      args: ["{{inputs.parameters.message}}"]
```

Submit:

```bash
kubectl create -n argo -f dag-diamond.yaml
kubectl get workflow -n argo -w
```

## Step 2: Complex DAG Patterns (10 minutes)

### 2.1 CI/CD Pipeline DAG

Create `dag-cicd.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-cicd-
spec:
  serviceAccountName: argo
  entrypoint: ci-cd-pipeline
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/example/app.git"
    - name: environment
      value: "staging"
  templates:
  - name: ci-cd-pipeline
    dag:
      tasks:
      # Stage 1: Source control
      - name: checkout
        template: git-checkout
        arguments:
          parameters:
          - name: repo
            value: "{{workflow.parameters.repo-url}}"

      # Stage 2: Parallel builds
      - name: build-frontend
        dependencies: [checkout]
        template: build
        arguments:
          parameters:
          - name: component
            value: "frontend"

      - name: build-backend
        dependencies: [checkout]
        template: build
        arguments:
          parameters:
          - name: component
            value: "backend"

      - name: build-worker
        dependencies: [checkout]
        template: build
        arguments:
          parameters:
          - name: component
            value: "worker"

      # Stage 3: Parallel tests
      - name: unit-tests
        dependencies: [build-frontend, build-backend, build-worker]
        template: test
        arguments:
          parameters:
          - name: test-type
            value: "unit"

      - name: integration-tests
        dependencies: [build-frontend, build-backend, build-worker]
        template: test
        arguments:
          parameters:
          - name: test-type
            value: "integration"

      - name: e2e-tests
        dependencies: [build-frontend, build-backend, build-worker]
        template: test
        arguments:
          parameters:
          - name: test-type
            value: "e2e"

      # Stage 4: Security scanning
      - name: security-scan
        dependencies: [unit-tests, integration-tests]
        template: scan
        arguments:
          parameters:
          - name: scan-type
            value: "security"

      - name: dependency-scan
        dependencies: [unit-tests, integration-tests]
        template: scan
        arguments:
          parameters:
          - name: scan-type
            value: "dependencies"

      # Stage 5: Deployment
      - name: deploy
        dependencies: [e2e-tests, security-scan, dependency-scan]
        template: deploy-app
        arguments:
          parameters:
          - name: environment
            value: "{{workflow.parameters.environment}}"

      # Stage 6: Smoke tests
      - name: smoke-tests
        dependencies: [deploy]
        template: test
        arguments:
          parameters:
          - name: test-type
            value: "smoke"

  - name: git-checkout
    inputs:
      parameters:
      - name: repo
    container:
      image: alpine/git:2.47.1
      command: [sh, -c]
      args: ["echo 'Cloning {{inputs.parameters.repo}}'; sleep 2"]

  - name: build
    inputs:
      parameters:
      - name: component
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Building {{inputs.parameters.component}}..."
          sleep 3
          echo "{{inputs.parameters.component}} build complete"

  - name: test
    inputs:
      parameters:
      - name: test-type
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Running {{inputs.parameters.test-type}} tests..."
          sleep 2
          echo "{{inputs.parameters.test-type}} tests passed"

  - name: scan
    inputs:
      parameters:
      - name: scan-type
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Running {{inputs.parameters.scan-type}} scan..."
          sleep 2
          echo "{{inputs.parameters.scan-type}} scan complete - no issues"

  - name: deploy-app
    inputs:
      parameters:
      - name: environment
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Deploying to {{inputs.parameters.environment}}..."
          sleep 3
          echo "Deployment successful"
```

Submit and observe the complex dependency graph:

```bash
kubectl create -n argo -f dag-cicd.yaml
kubectl get workflow -n argo -w
```

View the DAG in the UI to see the full pipeline visualization.

### 2.2 DAG with Data Flow

Create `dag-dataflow.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-dataflow-
spec:
  serviceAccountName: argo
  entrypoint: data-pipeline
  templates:
  - name: data-pipeline
    dag:
      tasks:
      # Generate data
      - name: generate-dataset
        template: generate-data

      # Process data in parallel using generated output
      - name: process-numbers
        dependencies: [generate-dataset]
        template: process-data
        arguments:
          parameters:
          - name: data
            value: "{{tasks.generate-dataset.outputs.parameters.numbers}}"
          - name: operation
            value: "statistics"

      - name: process-strings
        dependencies: [generate-dataset]
        template: process-data
        arguments:
          parameters:
          - name: data
            value: "{{tasks.generate-dataset.outputs.parameters.strings}}"
          - name: operation
            value: "analysis"

      # Combine results
      - name: combine-results
        dependencies: [process-numbers, process-strings]
        template: combine
        arguments:
          parameters:
          - name: numbers-result
            value: "{{tasks.process-numbers.outputs.parameters.result}}"
          - name: strings-result
            value: "{{tasks.process-strings.outputs.parameters.result}}"

      # Generate report
      - name: generate-report
        dependencies: [combine-results]
        template: report
        arguments:
          parameters:
          - name: combined-data
            value: "{{tasks.combine-results.outputs.parameters.combined}}"

  - name: generate-data
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        import random

        numbers = [random.randint(1, 100) for _ in range(10)]
        strings = ["alpha", "beta", "gamma", "delta", "epsilon"]

        print("Generated data:")
        print(f"Numbers: {numbers}")
        print(f"Strings: {strings}")

        with open('/tmp/numbers.json', 'w') as f:
            json.dump(numbers, f)

        with open('/tmp/strings.json', 'w') as f:
            json.dump(strings, f)
    outputs:
      parameters:
      - name: numbers
        valueFrom:
          path: /tmp/numbers.json
      - name: strings
        valueFrom:
          path: /tmp/strings.json

  - name: process-data
    inputs:
      parameters:
      - name: data
      - name: operation
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json

        data = {{inputs.parameters.data}}
        operation = "{{inputs.parameters.operation}}"

        print(f"Processing {operation}...")
        print(f"Input: {data}")

        if isinstance(data[0], int):
            result = {"sum": sum(data), "avg": sum(data)/len(data)}
        else:
            result = {"count": len(data), "items": data}

        print(f"Result: {result}")

        with open('/tmp/result.json', 'w') as f:
            json.dump(result, f)
    outputs:
      parameters:
      - name: result
        valueFrom:
          path: /tmp/result.json

  - name: combine
    inputs:
      parameters:
      - name: numbers-result
      - name: strings-result
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json

        numbers_result = json.loads('''{{inputs.parameters.numbers-result}}''')
        strings_result = json.loads('''{{inputs.parameters.strings-result}}''')

        combined = {
            "numbers": numbers_result,
            "strings": strings_result
        }

        print("Combined results:")
        print(json.dumps(combined, indent=2))

        with open('/tmp/combined.json', 'w') as f:
            json.dump(combined, f)
    outputs:
      parameters:
      - name: combined
        valueFrom:
          path: /tmp/combined.json

  - name: report
    inputs:
      parameters:
      - name: combined-data
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json

        data = json.loads('''{{inputs.parameters.combined-data}}''')

        print("=" * 50)
        print("DATA PROCESSING REPORT")
        print("=" * 50)
        print("\nNumbers Analysis:")
        print(f"  Sum: {data['numbers']['sum']}")
        print(f"  Average: {data['numbers']['avg']:.2f}")
        print("\nStrings Analysis:")
        print(f"  Count: {data['strings']['count']}")
        print(f"  Items: {', '.join(data['strings']['items'])}")
        print("=" * 50)
```

Submit:

```bash
kubectl create -n argo -f dag-dataflow.yaml
kubectl get workflow -n argo -w
```

## Step 3: Conditional DAG Tasks (7 minutes)

### 3.1 DAG with When Conditions

Create `dag-conditional.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-conditional-
spec:
  serviceAccountName: argo
  entrypoint: conditional-dag
  arguments:
    parameters:
    - name: environment
      value: "production"
    - name: run-tests
      value: "true"
    - name: enable-canary
      value: "false"
  templates:
  - name: conditional-dag
    dag:
      tasks:
      # Always runs
      - name: build
        template: stage
        arguments:
          parameters:
          - name: stage-name
            value: "Build"

      # Conditional: Only if run-tests is true
      - name: unit-tests
        dependencies: [build]
        when: "{{workflow.parameters.run-tests}} == true"
        template: stage
        arguments:
          parameters:
          - name: stage-name
            value: "Unit Tests"

      - name: integration-tests
        dependencies: [build]
        when: "{{workflow.parameters.run-tests}} == true"
        template: stage
        arguments:
          parameters:
          - name: stage-name
            value: "Integration Tests"

      # Deploy based on environment
      - name: deploy-production
        dependencies: [build, unit-tests, integration-tests]
        when: "{{workflow.parameters.environment}} == production"
        template: stage
        arguments:
          parameters:
          - name: stage-name
            value: "Deploy to Production"

      - name: deploy-staging
        dependencies: [build]
        when: "{{workflow.parameters.environment}} == staging"
        template: stage
        arguments:
          parameters:
          - name: stage-name
            value: "Deploy to Staging"

      # Canary deployment (only for production with canary enabled)
      - name: canary-deployment
        dependencies: [deploy-production]
        when: "{{workflow.parameters.enable-canary}} == true"
        template: stage
        arguments:
          parameters:
          - name: stage-name
            value: "Canary Deployment"

      # Always runs if any deployment completed
      - name: health-check
        dependencies: [deploy-production, deploy-staging]
        template: stage
        arguments:
          parameters:
          - name: stage-name
            value: "Health Check"

  - name: stage
    inputs:
      parameters:
      - name: stage-name
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "[{{inputs.parameters.stage-name}}] Executing..."
          sleep 2
          echo "[{{inputs.parameters.stage-name}}] Complete"
```

Test with different parameter combinations:

```bash
# Production with tests and canary
argo submit -n argo dag-conditional.yaml --watch

# Staging without tests
argo submit -n argo dag-conditional.yaml \
  --parameter environment="staging" \
  --parameter run-tests="false" \
  --watch

# Production with canary
argo submit -n argo dag-conditional.yaml \
  --parameter enable-canary="true" \
  --watch
```

### 3.2 DAG with Task Result Conditionals

Create `dag-result-conditional.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-result-conditional-
spec:
  serviceAccountName: argo
  entrypoint: result-based-dag
  templates:
  - name: result-based-dag
    dag:
      tasks:
      # Check environment health
      - name: health-check
        template: check-health

      # Path A: If healthy, do normal deployment
      - name: normal-deployment
        dependencies: [health-check]
        when: "{{tasks.health-check.outputs.parameters.status}} == healthy"
        template: deploy
        arguments:
          parameters:
          - name: deploy-type
            value: "normal"

      # Path B: If unhealthy, do maintenance
      - name: maintenance-mode
        dependencies: [health-check]
        when: "{{tasks.health-check.outputs.parameters.status}} == unhealthy"
        template: maintenance

      # Post-deployment verification (only after normal deployment)
      - name: verify-deployment
        dependencies: [normal-deployment]
        template: verify

      # Notification (runs after either path)
      - name: notify
        dependencies: [normal-deployment, maintenance-mode]
        template: send-notification

  - name: check-health
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import random
        # Simulate health check
        status = random.choice(["healthy", "healthy", "unhealthy"])
        print(f"Health check result: {status}")
        with open('/tmp/status.txt', 'w') as f:
            f.write(status)
    outputs:
      parameters:
      - name: status
        valueFrom:
          path: /tmp/status.txt

  - name: deploy
    inputs:
      parameters:
      - name: deploy-type
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Executing {{inputs.parameters.deploy-type}} deployment'; sleep 2"]

  - name: maintenance
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Entering maintenance mode'; sleep 2"]

  - name: verify
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Verifying deployment'; sleep 1"]

  - name: send-notification
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Sending notification'; sleep 1"]
```

Submit multiple times to see different execution paths:

```bash
for i in {1..3}; do
  argo submit -n argo dag-result-conditional.yaml
  sleep 2
done

argo list -n argo
```

## Step 4: Advanced DAG Features (8 minutes)

### 4.1 DAG with Failure Handling

Create `dag-failure-handling.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-failure-handling-
spec:
  serviceAccountName: argo
  entrypoint: resilient-pipeline
  templates:
  - name: resilient-pipeline
    dag:
      tasks:
      # Task that might fail
      - name: risky-task
        template: risky-operation

      # Retry wrapper for risky task
      - name: safe-task
        dependencies: [risky-task]
        template: safe-operation
        continueOn:
          failed: true

      # Cleanup always runs, even on failure
      - name: cleanup
        dependencies: [safe-task]
        template: cleanup-operation

      # Success path
      - name: success-notification
        dependencies: [safe-task]
        when: "{{tasks.safe-task.status}} == Succeeded"
        template: notify
        arguments:
          parameters:
          - name: message
            value: "Pipeline succeeded"

      # Failure path
      - name: failure-notification
        dependencies: [safe-task]
        when: "{{tasks.safe-task.status}} == Failed"
        template: notify
        arguments:
          parameters:
          - name: message
            value: "Pipeline failed, but handled gracefully"

  - name: risky-operation
    retryStrategy:
      limit: "2"
      retryPolicy: "Always"
      backoff:
        duration: "5s"
        factor: 2
    container:
      image: python:3.14-slim
      command: [python]
      args:
        - -c
        - |
          import random
          import sys
          if random.random() < 0.5:
              print("Task succeeded")
              sys.exit(0)
          else:
              print("Task failed")
              sys.exit(1)

  - name: safe-operation
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Executing safe operation'; sleep 1"]

  - name: cleanup-operation
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Cleaning up resources'; sleep 1"]

  - name: notify
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:3.23
      command: [echo]
      args: ["{{inputs.parameters.message}}"]
```

Submit multiple times to observe different outcomes:

```bash
for i in {1..3}; do
  argo submit -n argo dag-failure-handling.yaml
  sleep 2
done

argo list -n argo | head -5
```

### 4.2 DAG with Nested Workflows

Create `dag-nested.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-nested-
spec:
  serviceAccountName: argo
  entrypoint: main-dag
  templates:
  - name: main-dag
    dag:
      tasks:
      - name: prepare
        template: simple-task
        arguments:
          parameters:
          - name: message
            value: "Preparing environment"

      # Sub-workflow for data processing
      - name: data-processing
        dependencies: [prepare]
        template: data-processing-dag

      # Sub-workflow for reporting
      - name: reporting
        dependencies: [data-processing]
        template: reporting-dag

  - name: data-processing-dag
    dag:
      tasks:
      - name: extract
        template: simple-task
        arguments:
          parameters:
          - name: message
            value: "Extracting data"

      - name: transform
        dependencies: [extract]
        template: simple-task
        arguments:
          parameters:
          - name: message
            value: "Transforming data"

      - name: load
        dependencies: [transform]
        template: simple-task
        arguments:
          parameters:
          - name: message
            value: "Loading data"

  - name: reporting-dag
    dag:
      tasks:
      - name: generate-report
        template: simple-task
        arguments:
          parameters:
          - name: message
            value: "Generating report"

      - name: send-email
        dependencies: [generate-report]
        template: simple-task
        arguments:
          parameters:
          - name: message
            value: "Sending email"

      - name: archive
        dependencies: [generate-report]
        template: simple-task
        arguments:
          parameters:
          - name: message
            value: "Archiving report"

  - name: simple-task
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo '{{inputs.parameters.message}}'; sleep 1"]
```

Submit:

```bash
kubectl create -n argo -f dag-nested.yaml
kubectl get workflow -n argo -w
```

View in the UI to see the nested DAG structure.

## Step 5: DAG vs Steps Comparison (7 minutes)

### 5.1 Same Workflow in Both Styles

Create `comparison-steps.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: comparison-steps-
spec:
  serviceAccountName: argo
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: init
        template: task
        arguments:
          parameters: [{name: msg, value: "Init"}]

    - - name: parallel-1
        template: task
        arguments:
          parameters: [{name: msg, value: "Parallel 1"}]
      - name: parallel-2
        template: task
        arguments:
          parameters: [{name: msg, value: "Parallel 2"}]

    - - name: final
        template: task
        arguments:
          parameters: [{name: msg, value: "Final"}]

  - name: task
    inputs:
      parameters:
      - name: msg
    container:
      image: alpine:3.23
      command: [echo]
      args: ["{{inputs.parameters.msg}}"]
```

Create `comparison-dag.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: comparison-dag-
spec:
  serviceAccountName: argo
  entrypoint: main
  templates:
  - name: main
    dag:
      tasks:
      - name: init
        template: task
        arguments:
          parameters: [{name: msg, value: "Init"}]

      - name: parallel-1
        dependencies: [init]
        template: task
        arguments:
          parameters: [{name: msg, value: "Parallel 1"}]

      - name: parallel-2
        dependencies: [init]
        template: task
        arguments:
          parameters: [{name: msg, value: "Parallel 2"}]

      - name: final
        dependencies: [parallel-1, parallel-2]
        template: task
        arguments:
          parameters: [{name: msg, value: "Final"}]

  - name: task
    inputs:
      parameters:
      - name: msg
    container:
      image: alpine:3.23
      command: [echo]
      args: ["{{inputs.parameters.msg}}"]
```

Submit both and compare:

```bash
argo submit -n argo comparison-steps.yaml
argo submit -n argo comparison-dag.yaml

argo list -n argo | head -3
```

Compare the visualization in the UI.

## Practice Exercises

### Exercise 1: Machine Learning Pipeline

Create a DAG workflow that simulates an ML pipeline:

1. Load dataset
2. Parallel: Feature engineering, data cleaning, data augmentation
3. Split data (depends on all parallel tasks)
4. Parallel: Train model A, Train model B, Train model C
5. Evaluate models (depends on all training tasks)
6. Select best model
7. Deploy model

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ml-pipeline-
spec:
  serviceAccountName: argo
  entrypoint: ml-dag
  templates:
  - name: ml-dag
    dag:
      tasks:
      - name: load-dataset
        template: stage
        arguments:
          parameters: [{name: stage, value: "Load Dataset"}]

      - name: feature-engineering
        dependencies: [load-dataset]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Feature Engineering"}]

      - name: data-cleaning
        dependencies: [load-dataset]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Data Cleaning"}]

      - name: data-augmentation
        dependencies: [load-dataset]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Data Augmentation"}]

      - name: split-data
        dependencies: [feature-engineering, data-cleaning, data-augmentation]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Split Data"}]

      - name: train-model-a
        dependencies: [split-data]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Train Model A"}]

      - name: train-model-b
        dependencies: [split-data]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Train Model B"}]

      - name: train-model-c
        dependencies: [split-data]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Train Model C"}]

      - name: evaluate-models
        dependencies: [train-model-a, train-model-b, train-model-c]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Evaluate Models"}]

      - name: select-best-model
        dependencies: [evaluate-models]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Select Best Model"}]

      - name: deploy-model
        dependencies: [select-best-model]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Deploy Model"}]

  - name: stage
    inputs:
      parameters:
      - name: stage
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo '[{{inputs.parameters.stage}}] Running...'; sleep 2"]
```

</details>

### Exercise 2: Multi-Environment Deployment

Create a DAG that:

1. Builds application
2. Runs tests
3. Deploys to dev (if tests pass)
4. Runs smoke tests in dev
5. Conditionally deploys to staging (parameter-controlled)
6. Conditionally deploys to production (parameter-controlled)
7. Sends appropriate notifications

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: multi-env-deploy-
spec:
  serviceAccountName: argo
  entrypoint: deploy-dag
  arguments:
    parameters:
    - name: deploy-staging
      value: "true"
    - name: deploy-production
      value: "false"
  templates:
  - name: deploy-dag
    dag:
      tasks:
      - name: build
        template: stage
        arguments:
          parameters: [{name: stage, value: "Build"}]

      - name: tests
        dependencies: [build]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Tests"}]

      - name: deploy-dev
        dependencies: [tests]
        when: "{{tasks.tests.status}} == Succeeded"
        template: stage
        arguments:
          parameters: [{name: stage, value: "Deploy to Dev"}]

      - name: smoke-tests-dev
        dependencies: [deploy-dev]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Smoke Tests (Dev)"}]

      - name: deploy-staging
        dependencies: [smoke-tests-dev]
        when: "{{workflow.parameters.deploy-staging}} == true"
        template: stage
        arguments:
          parameters: [{name: stage, value: "Deploy to Staging"}]

      - name: deploy-production
        dependencies: [smoke-tests-dev]
        when: "{{workflow.parameters.deploy-production}} == true"
        template: stage
        arguments:
          parameters: [{name: stage, value: "Deploy to Production"}]

      - name: notify-success
        dependencies: [deploy-staging, deploy-production]
        template: stage
        arguments:
          parameters: [{name: stage, value: "Notify Success"}]

  - name: stage
    inputs:
      parameters:
      - name: stage
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo '[{{inputs.parameters.stage}}]'; sleep 2"]
```

</details>

## Verification Steps

```bash
# List all DAG workflows
argo list -n argo | grep dag

# View workflow details
kubectl get workflow -n argo <workflow-name> -o yaml

# Or using Argo CLI
argo get -n argo <workflow-name>

# View logs from specific task
kubectl logs -n argo <pod-name> -c main

# Or using Argo CLI
argo logs -n argo <workflow-name> <task-name>

# Clean up
argo delete -n argo --all
```

## Troubleshooting

### Issue: Tasks Not Running in Parallel

**Symptom**: Tasks that should be parallel run sequentially

**Solution**: Check dependencies - tasks only run in parallel if they don't depend on each other

```yaml
# This is parallel
- name: task-a
  dependencies: [init]
- name: task-b
  dependencies: [init]

# This is sequential
- name: task-a
  dependencies: [init]
- name: task-b
  dependencies: [task-a]
```

### Issue: Circular Dependencies

**Symptom**: Workflow fails to start with error about cycles

**Solution**: DAGs must be acyclic - no task can depend on itself directly or indirectly

```bash
# Visualize dependencies to find cycles
argo get -n argo <workflow-name>
```

## Key Takeaways

- DAG workflows use explicit dependencies between tasks
- Parallel execution happens automatically when dependencies allow
- DAG structure is more flexible than steps for complex workflows
- Tasks can conditionally execute based on `when` expressions
- Output parameters flow between tasks using `{{tasks.task-name.outputs.parameters.param-name}}`
- DAGs are better for complex pipelines; steps are better for simple sequences
- The UI provides excellent DAG visualization for debugging
- Nested DAGs enable modular workflow design

## Next Steps

Continue to [Lab 04: Artifacts](lab-04-artifacts.md) to learn about working with files and data between workflow steps.

## Additional Resources

- [DAG Documentation](https://argoproj.github.io/argo-workflows/walk-through/dag/)
- [DAG Examples](https://github.com/argoproj/argo-workflows/tree/master/examples#dag)
- [Dependencies](https://argoproj.github.io/argo-workflows/enhanced-depends-logic/)
