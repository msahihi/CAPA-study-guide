# Lab 06: Workflow Artifacts - Passing Data Between Steps

**Duration**: 35 minutes
**Difficulty**: Intermediate
**Prerequisites**:

- Completed [Lab 01: Installation and Basics](lab-01-installation-basics.md)
- Completed [Lab 02: Templates and Steps](lab-02-templates-steps.md)
- Kubernetes cluster with Argo Workflows installed
- Artifact repository configured (S3, MinIO, GCS, or Artifactory)
- `kubectl` and `argo` CLI tools installed

## Overview

This lab covers the **"Generating and Consuming Artifacts"** CAPA exam competency. You'll learn how to pass data between workflow steps using artifacts, configure artifact repositories, and control artifact compression and permissions.

**Learning Objectives**:

- Generate artifacts in one workflow step
- Consume artifacts in subsequent steps
- Configure artifact archiving options
- Set file permissions on artifacts
- Use artifacts in both Steps and DAG templates

## Concepts

### What are Workflow Artifacts?

Artifacts enable data passing between workflow steps. The pattern:

1. **Producer step**: Writes files to a path, declares them as `outputs.artifacts`
2. **Consumer step**: Declares `inputs.artifacts`, receives files at specified path
3. **Artifact repository**: Stores artifacts between steps (S3, MinIO, etc.)

### Key Syntax

**Output Artifacts**:

```yaml
outputs:
  artifacts:
  - name: result-data
    path: /tmp/output.txt
```

**Input Artifacts**:

```yaml
inputs:
  artifacts:
  - name: source-data
    path: /tmp/input.txt
```

**Artifact Passing (Steps template)**:

```yaml
from: "{{steps.generate-step.outputs.artifacts.result-data}}"
```

**Artifact Passing (DAG template)**:

```yaml
from: "{{tasks.generate-task.outputs.artifacts.result-data}}"
```

---

## Lab Exercises

### Exercise 1: Basic Artifact Passing (Steps Template)

**Objective**: Create a workflow where one step generates a file and another step reads it.

**Step 1.1**: Create the basic artifact workflow

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-passing-
spec:
  entrypoint: artifact-example
  templates:
  - name: artifact-example
    steps:
    - - name: generate-artifact
        template: hello-world-to-file
    - - name: consume-artifact
        template: print-message-from-file
        arguments:
          artifacts:
          - name: message
            from: "{{steps.generate-artifact.outputs.artifacts.hello-art}}"

  - name: hello-world-to-file
    container:
      image: busybox
      command: [sh, -c]
      args: ["echo 'Hello from Argo Workflows!' | tee /tmp/hello_world.txt"]
    outputs:
      artifacts:
      - name: hello-art
        path: /tmp/hello_world.txt

  - name: print-message-from-file
    inputs:
      artifacts:
      - name: message
        path: /tmp/message
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["cat /tmp/message"]
EOF
```

**Step 1.2**: Monitor the workflow

```bash
# Get the workflow name
WORKFLOW_NAME=$(argo list -o name | head -1)

# Watch the workflow progress
argo watch $WORKFLOW_NAME

# View logs from both steps
argo logs $WORKFLOW_NAME
```

**Expected Output**:

```
artifact-passing-xxxxx: Hello from Argo Workflows!
```

**Step 1.3**: Verify artifact storage

```bash
# Get workflow details showing artifact location
argo get $WORKFLOW_NAME -o yaml | grep -A 5 "archiveLocation"
```

You should see the S3/MinIO path where the artifact was stored.

---

### Exercise 2: Multiple Artifacts

**Objective**: Pass multiple artifacts between steps for data processing pipelines.

**Step 2.1**: Create a workflow with multiple artifacts

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: multi-artifact-
spec:
  entrypoint: multi-artifact-example
  templates:
  - name: multi-artifact-example
    steps:
    - - name: generate-data
        template: create-files
    - - name: process-data
        template: combine-files
        arguments:
          artifacts:
          - name: file1
            from: "{{steps.generate-data.outputs.artifacts.data1}}"
          - name: file2
            from: "{{steps.generate-data.outputs.artifacts.data2}}"

  - name: create-files
    container:
      image: busybox
      command: [sh, -c]
      args: |
        - |
          echo "Data from file 1" > /tmp/data1.txt
          echo "Data from file 2" > /tmp/data2.txt
          echo "Files created successfully"
    outputs:
      artifacts:
      - name: data1
        path: /tmp/data1.txt
      - name: data2
        path: /tmp/data2.txt

  - name: combine-files
    inputs:
      artifacts:
      - name: file1
        path: /tmp/input1.txt
      - name: file2
        path: /tmp/input2.txt
    container:
      image: alpine:latest
      command: [sh, -c]
      args: |
        - |
          echo "=== Combined Output ===" > /tmp/combined.txt
          cat /tmp/input1.txt >> /tmp/combined.txt
          cat /tmp/input2.txt >> /tmp/combined.txt
          cat /tmp/combined.txt
    outputs:
      artifacts:
      - name: combined
        path: /tmp/combined.txt
EOF
```

**Step 2.2**: Check the output

```bash
WORKFLOW_NAME=$(argo list -o name | head -1)
argo logs $WORKFLOW_NAME --follow
```

---

### Exercise 3: Artifact Passing in DAG Templates

**Objective**: Use artifacts in DAG-based workflows with parallel execution.

**Step 3.1**: Create a DAG workflow with artifacts

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: dag-artifact-
spec:
  entrypoint: dag-example
  templates:
  - name: dag-example
    dag:
      tasks:
      - name: generate-data
        template: create-data

      - name: process-a
        dependencies: [generate-data]
        template: processor
        arguments:
          artifacts:
          - name: input-data
            from: "{{tasks.generate-data.outputs.artifacts.dataset}}"
          parameters:
          - name: processor-name
            value: "Processor-A"

      - name: process-b
        dependencies: [generate-data]
        template: processor
        arguments:
          artifacts:
          - name: input-data
            from: "{{tasks.generate-data.outputs.artifacts.dataset}}"
          parameters:
          - name: processor-name
            value: "Processor-B"

      - name: aggregate
        dependencies: [process-a, process-b]
        template: aggregator
        arguments:
          artifacts:
          - name: result-a
            from: "{{tasks.process-a.outputs.artifacts.result}}"
          - name: result-b
            from: "{{tasks.process-b.outputs.artifacts.result}}"

  - name: create-data
    container:
      image: busybox
      command: [sh, -c]
      args: ["echo 'Raw dataset content' > /tmp/dataset.txt"]
    outputs:
      artifacts:
      - name: dataset
        path: /tmp/dataset.txt

  - name: processor
    inputs:
      artifacts:
      - name: input-data
        path: /tmp/input.txt
      parameters:
      - name: processor-name
    container:
      image: alpine:latest
      command: [sh, -c]
      args: |
        - |
          echo "{{inputs.parameters.processor-name}} processed:" > /tmp/result.txt
          cat /tmp/input.txt >> /tmp/result.txt
    outputs:
      artifacts:
      - name: result
        path: /tmp/result.txt

  - name: aggregator
    inputs:
      artifacts:
      - name: result-a
        path: /tmp/a.txt
      - name: result-b
        path: /tmp/b.txt
    container:
      image: alpine:latest
      command: [sh, -c]
      args: |
        - |
          echo "=== Aggregated Results ===" > /tmp/final.txt
          echo "--- Result A ---" >> /tmp/final.txt
          cat /tmp/a.txt >> /tmp/final.txt
          echo "--- Result B ---" >> /tmp/final.txt
          cat /tmp/b.txt >> /tmp/final.txt
          cat /tmp/final.txt
EOF
```

**Step 3.2**: Observe parallel execution

```bash
WORKFLOW_NAME=$(argo list -o name | head -1)
argo watch $WORKFLOW_NAME
```

Notice that `process-a` and `process-b` run in parallel after `generate-data` completes.

---

### Exercise 4: Archive Options and File Permissions

**Objective**: Control artifact compression and set executable permissions.

**Step 4.1**: Create workflow with custom archive settings

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-options-
spec:
  entrypoint: archive-example
  templates:
  - name: archive-example
    steps:
    - - name: create-script
        template: generate-script
    - - name: execute-script
        template: run-script
        arguments:
          artifacts:
          - name: script
            from: "{{steps.create-script.outputs.artifacts.executable}}"

  - name: generate-script
    container:
      image: busybox
      command: [sh, -c]
      args: |
        - |
          cat > /tmp/script.sh <<'SCRIPT'
          #!/bin/sh
          echo "Script executed successfully!"
          echo "Current date: $(date)"
          SCRIPT
          chmod +x /tmp/script.sh
    outputs:
      artifacts:
      - name: executable
        path: /tmp/script.sh
        archive:
          none: {}  # Upload without compression

  - name: run-script
    inputs:
      artifacts:
      - name: script
        path: /tmp/script.sh
        mode: 0755  # Ensure executable permissions
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["/tmp/script.sh"]
EOF
```

**Step 4.2**: Verify execution

```bash
WORKFLOW_NAME=$(argo list -o name | head -1)
argo logs $WORKFLOW_NAME
```

---

## Validation

Check your understanding:

1. **Artifact Generation Test**:

```bash
# Create a workflow that generates a JSON file
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: validation-artifact-
spec:
  entrypoint: test
  templates:
  - name: test
    steps:
    - - name: generate
        template: create-json
    - - name: validate
        template: parse-json
        arguments:
          artifacts:
          - name: data
            from: "{{steps.generate.outputs.artifacts.json-data}}"

  - name: create-json
    container:
      image: busybox
      command: [sh, -c]
      args: ['echo ''{"status": "success", "count": 42}'' > /tmp/data.json']
    outputs:
      artifacts:
      - name: json-data
        path: /tmp/data.json

  - name: parse-json
    inputs:
      artifacts:
      - name: data
        path: /tmp/input.json
    container:
      image: alpine:latest
      command: [sh, -c]
      args: |
        - |
          apk add --no-cache jq
          jq . /tmp/input.json
          echo "Validation: JSON parsed successfully"
EOF
```

2. **Verify the workflow completed successfully**:

```bash
WORKFLOW_NAME=$(argo list -o name | head -1)
argo wait $WORKFLOW_NAME
argo logs $WORKFLOW_NAME | grep "Validation:"
```

Expected: `Validation: JSON parsed successfully`

---

## Troubleshooting

### Issue: "Failed to save artifact"

**Cause**: Artifact repository not configured

**Solution**: Configure artifact repository in ConfigMap:

```bash
kubectl edit configmap workflow-controller-configmap -n argo
```

Add artifact repository configuration (example for MinIO):

```yaml
data:
  artifactRepository: |
    s3:
      bucket: my-bucket
      endpoint: minio:9000
      insecure: true
      accessKeySecret:
        name: my-minio-cred
        key: accesskey
      secretKeySecret:
        name: my-minio-cred
        key: secretkey
```

### Issue: "Permission denied" when executing artifact

**Cause**: File permissions not preserved

**Solution**: Use `mode` field on input artifact:

```yaml
inputs:
  artifacts:
  - name: script
    path: /tmp/script.sh
    mode: 0755
```

### Issue: Large artifacts causing slow workflows

**Cause**: Default gzip compression

**Solution**: Disable compression for already-compressed files:

```yaml
outputs:
  artifacts:
  - name: compressed-data
    path: /tmp/data.tar.gz
    archive:
      none: {}
```

---

## Cleanup

```bash
# Delete all workflows from this lab
argo delete --all

# Verify cleanup
argo list
```

---

## Key Takeaways

1. **Artifacts enable data sharing**: Use `outputs.artifacts` and `inputs.artifacts` to pass files between steps
2. **Syntax differs by template type**: Steps use `{{steps.name.outputs.artifacts.name}}`, DAGs use `{{tasks.name.outputs.artifacts.name}}`
3. **Artifact repository required**: Configure S3, MinIO, GCS, or Artifactory before using artifacts
4. **Control compression**: Use `archive.none: {}` to skip compression
5. **Set permissions**: Use `mode: 0755` for executable artifacts
6. **Multiple artifacts supported**: Pass multiple files between steps for complex data processing

---

## Next Steps

- [Lab 03: DAG and Parallel Execution](lab-03-dag-workflows.md) - Advanced DAG patterns
- [Lab 05: Workflow Templates](lab-05-workflow-templates.md) - Reusable workflow patterns
- **Documentation**: [Variables and Artifacts](../../domains/02-argo-workflows/variables-artifacts.md)

---

**Official Reference**: [Argo Workflows - Artifacts](https://argo-workflows.readthedocs.io/en/latest/walk-through/artifacts/)
