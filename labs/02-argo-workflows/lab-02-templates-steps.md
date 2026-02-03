# Lab 02: Templates and Steps

**Duration**: 35 minutes

## Objectives

By the end of this lab, you will be able to:

- Create and use different template types (container, script, resource)
- Build workflows with sequential steps
- Implement parallel step execution
- Pass parameters between templates
- Work with input and output parameters
- Use loops and conditionals in workflows
- Handle artifacts between steps

## Prerequisites

- Completed [Lab 01: Installation and Basics](lab-01-installation-basics.md)
- Argo Workflows installed and running
- Argo CLI configured
- Basic understanding of workflow structure

## Lab Environment Verification

Verify Argo Workflows is running:

```bash
kubectl get pods -n argo
argo version
```

## Step 1: Container Templates (7 minutes)

Container templates are the most common template type, running Docker containers with specified commands.

### 1.1 Basic Container Template

Create `container-basic.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: container-basic-
spec:
  serviceAccountName: argo
  entrypoint: main
  templates:
  - name: main
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Container started at: $(date)"
          echo "Hostname: $(hostname)"
          echo "User: $(whoami)"
          sleep 2
          echo "Container completed successfully"
```

Submit and observe:

**Using kubectl:**

```bash
kubectl create -n argo -f container-basic.yaml
kubectl get workflow -n argo -w  # Watch execution, Ctrl+C to stop
kubectl logs -n argo <workflow-name> -c main
```

**Using Argo CLI:**

```bash
argo submit -n argo container-basic.yaml --watch
argo logs -n argo @latest
```

### 1.2 Container with Environment Variables

Create `container-env.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: container-env-
spec:
  serviceAccountName: argo
  entrypoint: env-demo
  arguments:
    parameters:
    - name: environment
      value: "production"
    - name: app-version
      value: "v1.2.3"
  templates:
  - name: env-demo
    inputs:
      parameters:
      - name: environment
      - name: app-version
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["env | grep -E '(APP_|ENV_|WORKFLOW_)' | sort"]
      env:
      - name: APP_VERSION
        value: "{{inputs.parameters.app-version}}"
      - name: ENV_NAME
        value: "{{inputs.parameters.environment}}"
      - name: WORKFLOW_NAME
        value: "{{workflow.name}}"
      - name: WORKFLOW_NAMESPACE
        value: "{{workflow.namespace}}"
      - name: WORKFLOW_UID
        value: "{{workflow.uid}}"
```

Submit with custom parameters:

```bash
argo submit -n argo container-env.yaml \
  --parameter environment="staging" \
  --parameter app-version="v2.0.0" \
  --watch
```

### 1.3 Container with Resource Limits

Create `container-resources.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: container-resources-
spec:
  serviceAccountName: argo
  entrypoint: resource-demo
  templates:
  - name: resource-demo
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Checking resource limits..."
          cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo "Memory limit info not available"
          cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null || echo "CPU quota info not available"
          echo "Running task with constrained resources"
          sleep 5
      resources:
        requests:
          memory: "64Mi"
          cpu: "100m"
        limits:
          memory: "128Mi"
          cpu: "200m"
```

Submit and check resources:

```bash
argo submit -n argo container-resources.yaml --watch
kubectl get pod -n argo -l workflows.argoproj.io/workflow --show-labels
```

## Step 2: Script Templates (7 minutes)

Script templates allow you to write inline code in various languages.

### 2.1 Python Script Template

Create `script-python.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: script-python-
spec:
  serviceAccountName: argo
  entrypoint: python-script
  arguments:
    parameters:
    - name: numbers
      value: "[10, 20, 30, 40, 50]"
  templates:
  - name: python-script
    inputs:
      parameters:
      - name: numbers
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        import statistics

        # Parse input
        numbers = {{inputs.parameters.numbers}}

        # Calculate statistics
        total = sum(numbers)
        average = statistics.mean(numbers)
        median = statistics.median(numbers)

        # Output results
        print(f"Numbers: {numbers}")
        print(f"Sum: {total}")
        print(f"Average: {average:.2f}")
        print(f"Median: {median}")

        # Save results to file
        results = {
            "sum": total,
            "average": average,
            "median": median
        }

        with open('/tmp/results.json', 'w') as f:
            json.dump(results, f, indent=2)

        print("\nResults saved to /tmp/results.json")
```

Submit:

```bash
kubectl create -n argo -f script-python.yaml

# Check status
kubectl get workflow -n argo -w

# View logs
kubectl logs -n argo <workflow-name> -c main
```

Expected output:

```
Numbers: [10, 20, 30, 40, 50]
Sum: 150
Average: 30.00
Median: 30

Results saved to /tmp/results.json
```

### 2.2 Bash Script Template

Create `script-bash.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: script-bash-
spec:
  serviceAccountName: argo
  entrypoint: bash-script
  arguments:
    parameters:
    - name: filename
      value: "data.txt"
    - name: content
      value: "Hello from Argo Workflows"
  templates:
  - name: bash-script
    inputs:
      parameters:
      - name: filename
      - name: content
    script:
      image: bash:5.2
      command: [bash]
      source: |
        #!/bin/bash
        set -e

        FILENAME="{{inputs.parameters.filename}}"
        CONTENT="{{inputs.parameters.content}}"

        echo "Creating file: $FILENAME"
        echo "$CONTENT" > /tmp/$FILENAME

        echo "File contents:"
        cat /tmp/$FILENAME

        echo ""
        echo "File info:"
        ls -lh /tmp/$FILENAME

        echo ""
        echo "Word count:"
        wc /tmp/$FILENAME
```

Submit:

```bash
kubectl create -n argo -f script-bash.yaml
kubectl get workflow -n argo -w
```

### 2.3 Script with Output Parameter

Create `script-output.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: script-output-
spec:
  serviceAccountName: argo
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: generate
        template: generate-value
    - - name: display
        template: display-value
        arguments:
          parameters:
          - name: value
            value: "{{steps.generate.outputs.parameters.random-number}}"

  - name: generate-value
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import random
        number = random.randint(1, 100)
        print(f"Generated number: {number}")
        with open('/tmp/number.txt', 'w') as f:
            f.write(str(number))
    outputs:
      parameters:
      - name: random-number
        valueFrom:
          path: /tmp/number.txt

  - name: display-value
    inputs:
      parameters:
      - name: value
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'Received value: {{inputs.parameters.value}}'"]
```

Submit and observe the parameter passing:

```bash
kubectl create -n argo -f script-output.yaml
kubectl get workflow -n argo -w
argo logs -n argo @latest
```

## Step 3: Sequential Steps (6 minutes)

Sequential steps execute one after another in order.

### 3.1 Simple Sequential Workflow

Create `steps-sequential.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: steps-sequential-
spec:
  serviceAccountName: argo
  entrypoint: sequential-workflow
  templates:
  - name: sequential-workflow
    steps:
    # Step 1: Initialization
    - - name: init
        template: echo-step
        arguments:
          parameters:
          - name: message
            value: "Step 1: Initializing workflow"

    # Step 2: Data preparation
    - - name: prepare
        template: echo-step
        arguments:
          parameters:
          - name: message
            value: "Step 2: Preparing data"

    # Step 3: Processing
    - - name: process
        template: echo-step
        arguments:
          parameters:
          - name: message
            value: "Step 3: Processing data"

    # Step 4: Finalization
    - - name: finalize
        template: echo-step
        arguments:
          parameters:
          - name: message
            value: "Step 4: Finalizing and cleanup"

  - name: echo-step
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "{{inputs.parameters.message}}"
          echo "Timestamp: $(date)"
          sleep 2
```

Submit and watch the sequential execution:

```bash
kubectl create -n argo -f steps-sequential.yaml
kubectl get workflow -n argo -w
```

Notice how each step waits for the previous to complete.

### 3.2 Sequential Steps with Data Flow

Create `steps-dataflow.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: steps-dataflow-
spec:
  serviceAccountName: argo
  entrypoint: dataflow-pipeline
  templates:
  - name: dataflow-pipeline
    steps:
    # Step 1: Generate data
    - - name: generate
        template: generate-data

    # Step 2: Transform data (uses output from step 1)
    - - name: transform
        template: transform-data
        arguments:
          parameters:
          - name: input-data
            value: "{{steps.generate.outputs.parameters.data}}"

    # Step 3: Validate data (uses output from step 2)
    - - name: validate
        template: validate-data
        arguments:
          parameters:
          - name: processed-data
            value: "{{steps.transform.outputs.parameters.result}}"

  - name: generate-data
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        data = {"values": [1, 2, 3, 4, 5], "source": "generator"}
        output = json.dumps(data)
        print(f"Generated: {output}")
        with open('/tmp/data.json', 'w') as f:
            f.write(output)
    outputs:
      parameters:
      - name: data
        valueFrom:
          path: /tmp/data.json

  - name: transform-data
    inputs:
      parameters:
      - name: input-data
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        input_data = json.loads('''{{inputs.parameters.input-data}}''')
        values = input_data["values"]
        transformed = [x * 2 for x in values]
        result = {"values": transformed, "operation": "doubled"}
        output = json.dumps(result)
        print(f"Transformed: {output}")
        with open('/tmp/result.json', 'w') as f:
            f.write(output)
    outputs:
      parameters:
      - name: result
        valueFrom:
          path: /tmp/result.json

  - name: validate-data
    inputs:
      parameters:
      - name: processed-data
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        data = json.loads('''{{inputs.parameters.processed-data}}''')
        print(f"Validating: {data}")
        assert all(x > 0 for x in data["values"]), "All values must be positive"
        print("Validation passed!")
```

Submit:

```bash
kubectl create -n argo -f steps-dataflow.yaml
kubectl get workflow -n argo -w
```

## Step 4: Parallel Steps (6 minutes)

Parallel steps execute simultaneously, improving workflow efficiency.

### 4.1 Basic Parallel Execution

Create `steps-parallel.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: steps-parallel-
spec:
  serviceAccountName: argo
  entrypoint: parallel-workflow
  templates:
  - name: parallel-workflow
    steps:
    # Single initialization step
    - - name: init
        template: echo-message
        arguments:
          parameters:
          - name: message
            value: "Initializing parallel tasks"

    # Three parallel steps
    - - name: task-a
        template: worker-task
        arguments:
          parameters:
          - name: task-id
            value: "A"
          - name: duration
            value: "3"

      - name: task-b
        template: worker-task
        arguments:
          parameters:
          - name: task-id
            value: "B"
          - name: duration
            value: "5"

      - name: task-c
        template: worker-task
        arguments:
          parameters:
          - name: task-id
            value: "C"
          - name: duration
            value: "4"

    # Single finalization step (waits for all parallel tasks)
    - - name: finalize
        template: echo-message
        arguments:
          parameters:
          - name: message
            value: "All parallel tasks completed"

  - name: echo-message
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:3.23
      command: [echo]
      args: ["{{inputs.parameters.message}}"]

  - name: worker-task
    inputs:
      parameters:
      - name: task-id
      - name: duration
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Task {{inputs.parameters.task-id}} started at $(date +%H:%M:%S)"
          sleep {{inputs.parameters.duration}}
          echo "Task {{inputs.parameters.task-id}} completed at $(date +%H:%M:%S)"
```

Submit and observe parallel execution:

```bash
kubectl create -n argo -f steps-parallel.yaml
kubectl get workflow -n argo -w
```

Notice how tasks A, B, and C run simultaneously.

### 4.2 Mixed Sequential and Parallel Steps

Create `steps-mixed.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: steps-mixed-
spec:
  serviceAccountName: argo
  entrypoint: mixed-workflow
  templates:
  - name: mixed-workflow
    steps:
    # Sequential: Preparation
    - - name: prepare
        template: log-step
        arguments:
          parameters:
          - name: stage
            value: "Preparation"

    # Parallel: Build stage
    - - name: build-frontend
        template: build-task
        arguments:
          parameters:
          - name: component
            value: "Frontend"

      - name: build-backend
        template: build-task
        arguments:
          parameters:
          - name: component
            value: "Backend"

      - name: build-worker
        template: build-task
        arguments:
          parameters:
          - name: component
            value: "Worker"

    # Parallel: Test stage
    - - name: unit-tests
        template: test-task
        arguments:
          parameters:
          - name: test-type
            value: "Unit Tests"

      - name: integration-tests
        template: test-task
        arguments:
          parameters:
          - name: test-type
            value: "Integration Tests"

    # Sequential: Deploy
    - - name: deploy
        template: log-step
        arguments:
          parameters:
          - name: stage
            value: "Deployment"

  - name: log-step
    inputs:
      parameters:
      - name: stage
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo '[{{inputs.parameters.stage}}] Started at $(date)'"]

  - name: build-task
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

  - name: test-task
    inputs:
      parameters:
      - name: test-type
    container:
      image: alpine:3.23
      command: [sh, -c]
      args:
        - |
          echo "Running {{inputs.parameters.test-type}}..."
          sleep 2
          echo "{{inputs.parameters.test-type}} passed"
```

Submit:

```bash
kubectl create -n argo -f steps-mixed.yaml
kubectl get workflow -n argo -w
```

## Step 5: Loops and Conditionals (5 minutes)

### 5.1 Loops with withItems

Create `steps-loop.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: steps-loop-
spec:
  serviceAccountName: argo
  entrypoint: loop-workflow
  templates:
  - name: loop-workflow
    steps:
    - - name: process-items
        template: process-item
        arguments:
          parameters:
          - name: item
            value: "{{item}}"
        withItems:
        - { name: "apple", color: "red", price: 1.20 }
        - { name: "banana", color: "yellow", price: 0.80 }
        - { name: "cherry", color: "red", price: 2.50 }
        - { name: "date", color: "brown", price: 3.00 }

  - name: process-item
    inputs:
      parameters:
      - name: item
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        item = json.loads('''{{inputs.parameters.item}}''')
        print(f"Processing: {item['name']}")
        print(f"  Color: {item['color']}")
        print(f"  Price: ${item['price']}")
        print(f"  Total for 10: ${item['price'] * 10:.2f}")
```

Submit:

```bash
kubectl create -n argo -f steps-loop.yaml
kubectl get workflow -n argo -w
```

### 5.2 Conditional Execution

Create `steps-conditional.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: steps-conditional-
spec:
  serviceAccountName: argo
  entrypoint: conditional-workflow
  arguments:
    parameters:
    - name: environment
      value: "production"
    - name: run-tests
      value: "true"
  templates:
  - name: conditional-workflow
    steps:
    # Always runs
    - - name: build
        template: log-task
        arguments:
          parameters:
          - name: message
            value: "Building application"

    # Conditional: Only if run-tests is true
    - - name: test
        template: log-task
        arguments:
          parameters:
          - name: message
            value: "Running tests"
        when: "{{workflow.parameters.run-tests}} == true"

    # Conditional: Production deployment
    - - name: deploy-prod
        template: log-task
        arguments:
          parameters:
          - name: message
            value: "Deploying to production"
        when: "{{workflow.parameters.environment}} == production"

    # Conditional: Staging deployment
    - - name: deploy-staging
        template: log-task
        arguments:
          parameters:
          - name: message
            value: "Deploying to staging"
        when: "{{workflow.parameters.environment}} == staging"

  - name: log-task
    inputs:
      parameters:
      - name: message
    container:
      image: alpine:3.23
      command: [echo]
      args: ["{{inputs.parameters.message}}"]
```

Test with different parameters:

```bash
# Production with tests
argo submit -n argo steps-conditional.yaml --watch

# Staging without tests
argo submit -n argo steps-conditional.yaml \
  --parameter environment="staging" \
  --parameter run-tests="false" \
  --watch
```

## Step 6: Resource Templates (4 minutes)

Resource templates manage Kubernetes resources as part of workflows.

**Note**: This step requires additional RBAC permissions. The `argo` service account needs permission to create and delete ConfigMaps. If you encounter permission errors, you can either:

1. Skip this step (it's optional for learning core concepts)
2. Add the required RBAC permissions (see troubleshooting below)

### 6.1 Create ConfigMap Resource

Create `resource-configmap.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: resource-configmap-
spec:
  serviceAccountName: argo
  entrypoint: manage-configmap
  templates:
  - name: manage-configmap
    steps:
    # Create ConfigMap
    - - name: create
        template: create-configmap

    # Use ConfigMap
    - - name: use
        template: use-configmap

    # Delete ConfigMap
    - - name: delete
        template: delete-configmap

  - name: create-configmap
    resource:
      action: create
      manifest: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: workflow-config
          namespace: argo
        data:
          app.name: "Argo Workflow Demo"
          app.version: "1.0.0"
          environment: "development"

  - name: use-configmap
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo 'ConfigMap created successfully'"]

  - name: delete-configmap
    resource:
      action: delete
      manifest: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: workflow-config
          namespace: argo
```

Submit:

```bash
kubectl create -n argo -f resource-configmap.yaml
kubectl get workflow -n argo -w
```

## Practice Exercises

### Exercise 1: Multi-Language Pipeline

Create a workflow that runs scripts in three different languages in parallel:

1. Python script that calculates factorial of 10
2. Bash script that lists system information
3. Node.js script that generates a random UUID

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: multi-language-
spec:
  serviceAccountName: argo
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: python-task
        template: python-factorial
      - name: bash-task
        template: bash-sysinfo
      - name: node-task
        template: node-uuid

  - name: python-factorial
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import math
        result = math.factorial(10)
        print(f"Factorial of 10 is: {result}")

  - name: bash-sysinfo
    script:
      image: bash:5.2
      command: [bash]
      source: |
        echo "System Information:"
        echo "Hostname: $(hostname)"
        echo "Date: $(date)"
        echo "Uptime: $(uptime)"

  - name: node-uuid
    script:
      image: node:24-slim
      command: [node]
      source: |
        const crypto = require('crypto');
        const uuid = crypto.randomUUID();
        console.log(`Generated UUID: ${uuid}`);
```

</details>

### Exercise 2: CI/CD Pipeline Simulation

Create a workflow that simulates a CI/CD pipeline with:

1. Sequential: Checkout code
2. Parallel: Build frontend and backend
3. Sequential: Run integration tests
4. Conditional: Deploy only if tests pass

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: cicd-pipeline-
spec:
  serviceAccountName: argo
  entrypoint: cicd
  templates:
  - name: cicd
    steps:
    - - name: checkout
        template: stage
        arguments:
          parameters:
          - name: stage
            value: "Checkout"

    - - name: build-frontend
        template: stage
        arguments:
          parameters:
          - name: stage
            value: "Build Frontend"
      - name: build-backend
        template: stage
        arguments:
          parameters:
          - name: stage
            value: "Build Backend"

    - - name: integration-tests
        template: test-stage

    - - name: deploy
        template: stage
        arguments:
          parameters:
          - name: stage
            value: "Deploy"
        when: "{{steps.integration-tests.outputs.parameters.status}} == passed"

  - name: stage
    inputs:
      parameters:
      - name: stage
    container:
      image: alpine:3.23
      command: [sh, -c]
      args: ["echo '[{{inputs.parameters.stage}}] Running...'; sleep 2"]

  - name: test-stage
    script:
      image: alpine:3.23
      command: [sh]
      source: |
        echo "Running integration tests..."
        sleep 2
        echo "passed" > /tmp/status.txt
    outputs:
      parameters:
      - name: status
        valueFrom:
          path: /tmp/status.txt
```

</details>

### Exercise 3: Data Processing Pipeline

Create a workflow with:

1. Generate 10 random numbers (Python)
2. Calculate sum, average, min, max (Python)
3. Create a report showing the results

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: data-pipeline-
spec:
  serviceAccountName: argo
  entrypoint: pipeline
  templates:
  - name: pipeline
    steps:
    - - name: generate
        template: generate-numbers

    - - name: analyze
        template: analyze-numbers
        arguments:
          parameters:
          - name: numbers
            value: "{{steps.generate.outputs.parameters.numbers}}"

    - - name: report
        template: create-report
        arguments:
          parameters:
          - name: stats
            value: "{{steps.analyze.outputs.parameters.stats}}"

  - name: generate-numbers
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        import random
        numbers = [random.randint(1, 100) for _ in range(10)]
        print(f"Generated: {numbers}")
        with open('/tmp/numbers.json', 'w') as f:
            json.dump(numbers, f)
    outputs:
      parameters:
      - name: numbers
        valueFrom:
          path: /tmp/numbers.json

  - name: analyze-numbers
    inputs:
      parameters:
      - name: numbers
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        numbers = {{inputs.parameters.numbers}}
        stats = {
            "sum": sum(numbers),
            "average": sum(numbers) / len(numbers),
            "min": min(numbers),
            "max": max(numbers)
        }
        print(f"Statistics: {stats}")
        with open('/tmp/stats.json', 'w') as f:
            json.dump(stats, f)
    outputs:
      parameters:
      - name: stats
        valueFrom:
          path: /tmp/stats.json

  - name: create-report
    inputs:
      parameters:
      - name: stats
    script:
      image: python:3.14-slim
      command: [python]
      source: |
        import json
        stats = json.loads('''{{inputs.parameters.stats}}''')
        print("="*50)
        print("DATA PROCESSING REPORT")
        print("="*50)
        print(f"Sum:     {stats['sum']}")
        print(f"Average: {stats['average']:.2f}")
        print(f"Min:     {stats['min']}")
        print(f"Max:     {stats['max']}")
        print("="*50)
```

</details>

## Verification Steps

```bash
# List all workflows created in this lab
kubectl get workflow -n argo

# Check logs for a specific workflow
kubectl logs -n argo <workflow-name> -c main

# Get workflow details
kubectl get workflow -n argo <workflow-name> -o yaml

# View workflow status
kubectl describe workflow -n argo <workflow-name>

# Clean up
kubectl delete workflow -n argo --all
```

Using Argo CLI (alternative):

```bash
# List workflows
argo list -n argo

# Check logs
argo logs -n argo <workflow-name>

# Get workflow details
argo get -n argo <workflow-name>

# Clean up
argo delete -n argo --all
```

## Troubleshooting

### Issue: Parameters Not Passing

**Symptom**: Template shows `{{inputs.parameters.xxx}}` literally

**Solution**: Check parameter syntax and escaping in scripts:

```yaml
# Wrong
source: "echo {{inputs.parameters.value}}"

# Correct
source: |
  echo "{{inputs.parameters.value}}"
```

### Issue: Parallel Steps Running Sequentially

**Symptom**: Steps that should be parallel run one after another

**Solution**: Ensure steps are in the same array level:

```yaml
# Wrong (sequential)
steps:
- - name: task1
    template: task
- - name: task2
    template: task

# Correct (parallel)
steps:
- - name: task1
    template: task
  - name: task2
    template: task
```

### Issue: Resource Template Permission Errors

**Symptom**: Resource template workflows fail with "forbidden" or "cannot create resource" errors

**Error Example**:

```
configmaps is forbidden: User "system:serviceaccount:argo:argo"
cannot create resource "configmaps"
```

**Cause**: The `argo` service account lacks RBAC permissions for the resources being managed.

**Solution**: Add required permissions to the argo service account:

```bash
# Create Role with ConfigMap permissions
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argo-resource-permissions
  namespace: argo
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create", "get", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argo-resource-binding
  namespace: argo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argo-resource-permissions
subjects:
- kind: ServiceAccount
  name: argo
  namespace: argo
EOF
```

After applying these permissions, resubmit the resource template workflow.

## Key Takeaways

- Container templates run Docker images with commands
- Script templates enable inline code in multiple languages
- Resource templates manage Kubernetes resources
- Sequential steps use separate array elements
- Parallel steps use the same array element
- Parameters flow between templates via inputs/outputs
- Loops iterate over items with `withItems`
- Conditionals use `when` expressions
- Data can flow through the entire workflow pipeline

## Next Steps

Continue to [Lab 03: DAG Workflows](lab-03-dag-workflows.md) to learn about Directed Acyclic Graph patterns and complex dependencies.

## Additional Resources

- [Template Types](https://argoproj.github.io/argo-workflows/workflow-concepts/#template-types)
- [Steps vs DAG](https://argoproj.github.io/argo-workflows/walk-through/steps/)
- [Variables Reference](https://argoproj.github.io/argo-workflows/variables/)
