# Variables and Artifacts

## Overview

Variables and artifacts are essential mechanisms for passing data between workflow steps and templates in Argo Workflows. Understanding how to use workflow variables, parameters, and artifacts effectively enables you to build dynamic, data-driven workflows that can handle complex data processing pipelines.

## Key Topics

### Workflow Variables

Argo Workflows provides various built-in variables that can be referenced throughout your workflow definitions.

#### Workflow-Level Variables

**Common Workflow Variables:**

```yaml
{{workflow.name}}              # Workflow name
{{workflow.namespace}}          # Workflow namespace
{{workflow.uid}}                # Workflow unique ID
{{workflow.status}}             # Current workflow status
{{workflow.creationTimestamp}}  # When workflow was created
{{workflow.priority}}           # Workflow priority
```

**Example Usage:**

```yaml
templates:
- name: print-workflow-info
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Workflow Name: {{workflow.name}}"
        echo "Namespace: {{workflow.namespace}}"
        echo "UID: {{workflow.uid}}"
        echo "Created: {{workflow.creationTimestamp}}"
```

#### Task and Step Variables

Reference outputs and status from previous steps or tasks.

**Steps Variables:**

```yaml
{{steps.step-name.outputs.result}}                    # Script output
{{steps.step-name.outputs.parameters.param-name}}     # Output parameter
{{steps.step-name.outputs.artifacts.artifact-name}}   # Output artifact
{{steps.step-name.status}}                            # Step status
{{steps.step-name.exitCode}}                          # Exit code
```

**DAG Task Variables:**

```yaml
{{tasks.task-name.outputs.result}}                    # Script output
{{tasks.task-name.outputs.parameters.param-name}}     # Output parameter
{{tasks.task-name.outputs.artifacts.artifact-name}}   # Output artifact
{{tasks.task-name.status}}                            # Task status
{{tasks.task-name.exitCode}}                          # Exit code
```

**Example:**

```yaml
templates:
- name: workflow-with-variables
  steps:
  - - name: generate-value
      template: generator

  - - name: use-value
      template: consumer
      arguments:
        parameters:
        - name: input-value
          value: "{{steps.generate-value.outputs.result}}"
      when: "{{steps.generate-value.status}} == Succeeded"

- name: generator
  script:
    image: python:3.9
    command: [python]
    source: |
      import random
      print(random.randint(1, 100))

- name: consumer
  inputs:
    parameters:
    - name: input-value
  container:
    image: alpine:latest
    command: [echo]
    args: ["Received value: {{inputs.parameters.input-value}}"]
```

#### Pod-Level Variables

Access information about the pod running the template.

```yaml
{{pod.name}}          # Pod name
{{pod.name}}          # Pod namespace
```

**Example:**

```yaml
templates:
- name: pod-info
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Pod Name: {{pod.name}}"
        echo "Pod IP: $POD_IP"
    env:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
```

### Parameters

Parameters allow you to pass scalar values (strings, numbers, booleans) between workflow components.

#### Workflow Parameters

Define parameters at the workflow level that can be overridden at submission.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: parameterized-workflow-
spec:
  entrypoint: main
  arguments:
    parameters:
    - name: environment
      value: "development"
    - name: version
      value: "1.0.0"
    - name: replicas
      value: "3"

  templates:
  - name: main
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Environment: {{workflow.parameters.environment}}"
          echo "Version: {{workflow.parameters.version}}"
          echo "Replicas: {{workflow.parameters.replicas}}"
```

**Submitting with Custom Parameters:**

```bash
argo submit workflow.yaml \
  -p environment=production \
  -p version=2.0.0 \
  -p replicas=5
```

#### Template Input Parameters

Templates can define input parameters with optional default values.

```yaml
templates:
- name: greet
  inputs:
    parameters:
    - name: greeting
      value: "Hello"         # Default value
    - name: name              # Required, no default
  container:
    image: alpine:latest
    command: [echo]
    args: ["{{inputs.parameters.greeting}} {{inputs.parameters.name}}"]
```

#### Template Output Parameters

Templates can produce output parameters from container outputs.

**From File Path:**

```yaml
templates:
- name: generate-id
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'generated-id-12345' > /tmp/id.txt"]
  outputs:
    parameters:
    - name: id
      valueFrom:
        path: /tmp/id.txt

- name: use-id
  inputs:
    parameters:
    - name: generated-id
  container:
    image: alpine:latest
    command: [echo]
    args: ["Using ID: {{inputs.parameters.generated-id}}"]
```

**From Script Result:**

```yaml
templates:
- name: calculate
  script:
    image: python:3.9
    command: [python]
    source: |
      result = 42 * 2
      print(result)  # Output becomes the result
  outputs:
    parameters:
    - name: calculation-result
      valueFrom:
        path: /tmp/result  # Captures stdout by default
```

#### Parameter Value Extraction

Extract values from JSON outputs using JSONPath.

```yaml
templates:
- name: json-producer
  script:
    image: python:3.9
    command: [python]
    source: |
      import json
      data = {
          "status": "success",
          "count": 42,
          "items": ["a", "b", "c"]
      }
      print(json.dumps(data))
  outputs:
    parameters:
    - name: status
      valueFrom:
        path: /tmp/result
        jsonPath: '{.status}'
    - name: count
      valueFrom:
        path: /tmp/result
        jsonPath: '{.count}'
    - name: first-item
      valueFrom:
        path: /tmp/result
        jsonPath: '{.items[0]}'
```

### Artifacts

Artifacts represent files or directories that are passed between workflow steps.

#### Input Artifacts

Templates can receive artifacts as inputs from various sources.

**From Previous Step:**

```yaml
templates:
- name: workflow-with-artifacts
  steps:
  - - name: create-file
      template: file-creator

  - - name: process-file
      template: file-processor
      arguments:
        artifacts:
        - name: input-file
          from: "{{steps.create-file.outputs.artifacts.output-file}}"

- name: file-creator
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'Hello World' > /tmp/output.txt"]
  outputs:
    artifacts:
    - name: output-file
      path: /tmp/output.txt

- name: file-processor
  inputs:
    artifacts:
    - name: input-file
      path: /workspace/input.txt
  container:
    image: alpine:latest
    command: [cat, /workspace/input.txt]
```

**From Git Repository:**

```yaml
templates:
- name: git-artifact
  inputs:
    artifacts:
    - name: source-code
      path: /src
      git:
        repo: https://github.com/example/repository.git
        revision: "main"
        singleBranch: true
        depth: 1
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["ls -la /src"]
```

**From HTTP URL:**

```yaml
templates:
- name: http-artifact
  inputs:
    artifacts:
    - name: data-file
      path: /data/file.json
      http:
        url: https://example.com/data.json
  container:
    image: alpine:latest
    command: [cat, /data/file.json]
```

**From S3:**

```yaml
templates:
- name: s3-artifact
  inputs:
    artifacts:
    - name: dataset
      path: /data/dataset.csv
      s3:
        endpoint: s3.amazonaws.com
        bucket: my-bucket
        key: datasets/data.csv
        accessKeySecret:
          name: aws-credentials
          key: accessKey
        secretKeySecret:
          name: aws-credentials
          key: secretKey
  container:
    image: alpine:latest
    command: [head, -n, "10", /data/dataset.csv]
```

#### Output Artifacts

Templates can produce artifacts for use by subsequent steps.

**Basic Output Artifact:**

```yaml
templates:
- name: artifact-producer
  container:
    image: alpine:latest
    command: [sh, -c]
    args:
      - |
        echo "Creating artifacts..."
        echo "Log entry 1" > /tmp/logs/app.log
        echo "Result data" > /tmp/results/data.txt
  outputs:
    artifacts:
    - name: logs
      path: /tmp/logs
    - name: results
      path: /tmp/results/data.txt
```

**Artifact with Archive Options:**

```yaml
templates:
- name: unarchived-output
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["mkdir -p /output && echo 'data' > /output/file.txt"]
  outputs:
    artifacts:
    - name: raw-output
      path: /output
      archive:
        none: {}  # Don't compress/tar the artifact
```

**Optional Artifacts:**

```yaml
templates:
- name: optional-artifact
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'May or may not create artifact'"]
  outputs:
    artifacts:
    - name: maybe-exists
      path: /tmp/optional-file.txt
      optional: true
```

### Artifact Repositories

Artifact repositories store artifacts between workflow steps.

#### Default Artifact Repository

Configure a default artifact repository for the entire namespace.

**ConfigMap Configuration:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-controller-configmap
  namespace: argo
data:
  artifactRepository: |
    s3:
      bucket: my-workflow-artifacts
      endpoint: s3.amazonaws.com
      region: us-west-2
      accessKeySecret:
        name: aws-credentials
        key: accessKey
      secretKeySecret:
        name: aws-credentials
        key: secretKey
```

#### Per-Workflow Artifact Repository

Override the default repository for a specific workflow.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: custom-artifact-repo-
spec:
  entrypoint: main
  artifactRepositoryRef:
    configMap: custom-artifact-repo-config
    key: artifactRepository

  templates:
  - name: main
    container:
      image: alpine:latest
      command: [echo, "Using custom artifact repository"]
```

#### Artifact Repository Types

**S3 Repository:**

```yaml
artifactRepository:
  s3:
    bucket: workflow-artifacts
    endpoint: s3.amazonaws.com
    region: us-east-1
    accessKeySecret:
      name: aws-credentials
      key: accessKey
    secretKeySecret:
      name: aws-credentials
      key: secretKey
```

**GCS Repository:**

```yaml
artifactRepository:
  gcs:
    bucket: workflow-artifacts
    keyFormat: "{{workflow.name}}/{{pod.name}}"
    serviceAccountKeySecret:
      name: gcs-credentials
      key: serviceAccountKey
```

**MinIO Repository:**

```yaml
artifactRepository:
  s3:
    bucket: workflow-artifacts
    endpoint: minio.example.com:9000
    insecure: true
    accessKeySecret:
      name: minio-credentials
      key: accesskey
    secretKeySecret:
      name: minio-credentials
      key: secretkey
```

### Volume Claims

Persistent Volume Claims (PVCs) provide shared storage for workflows.

#### Dynamic Volume Claims

Create PVCs automatically with the workflow.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: volume-workflow-
spec:
  entrypoint: main
  volumeClaimTemplates:
  - metadata:
      name: workspace
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 1Gi

  templates:
  - name: main
    steps:
    - - name: write-data
        template: writer

    - - name: read-data
        template: reader

  - name: writer
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["echo 'Shared data' > /workspace/data.txt"]
      volumeMounts:
      - name: workspace
        mountPath: /workspace

  - name: reader
    container:
      image: alpine:latest
      command: [cat, /workspace/data.txt]
      volumeMounts:
      - name: workspace
        mountPath: /workspace
```

#### Existing PVC

Use an existing Persistent Volume Claim.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: existing-pvc-
spec:
  entrypoint: main
  volumes:
  - name: existing-storage
    persistentVolumeClaim:
      claimName: my-existing-pvc

  templates:
  - name: main
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["ls -la /data"]
      volumeMounts:
      - name: existing-storage
        mountPath: /data
```

#### EmptyDir Volumes

Share data within a single workflow pod.

```yaml
templates:
- name: share-data
  volumes:
  - name: temp-storage
    emptyDir: {}

  steps:
  - - name: create-data
      template: creator

  - - name: use-data
      template: consumer

- name: creator
  container:
    image: alpine:latest
    command: [sh, -c]
    args: ["echo 'Temporary data' > /temp/data.txt"]
    volumeMounts:
    - name: temp-storage
      mountPath: /temp

- name: consumer
  container:
    image: alpine:latest
    command: [cat, /temp/data.txt]
    volumeMounts:
    - name: temp-storage
      mountPath: /temp
```

## Practice Examples

### Complete Example with Variables and Artifacts

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: data-pipeline-
spec:
  entrypoint: data-pipeline
  arguments:
    parameters:
    - name: dataset-name
      value: "customer-data"
    - name: processing-mode
      value: "batch"

  artifactRepositoryRef:
    configMap: artifact-repository
    key: config

  volumeClaimTemplates:
  - metadata:
      name: workspace
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 2Gi

  templates:
  - name: data-pipeline
    steps:
    # Step 1: Download data
    - - name: download
        template: download-data
        arguments:
          parameters:
          - name: dataset
            value: "{{workflow.parameters.dataset-name}}"

    # Step 2: Parallel processing
    - - name: process-batch-1
        template: process-batch
        arguments:
          parameters:
          - name: batch-id
            value: "1"
          artifacts:
          - name: input-data
            from: "{{steps.download.outputs.artifacts.dataset}}"

      - name: process-batch-2
        template: process-batch
        arguments:
          parameters:
          - name: batch-id
            value: "2"
          artifacts:
          - name: input-data
            from: "{{steps.download.outputs.artifacts.dataset}}"

    # Step 3: Merge results
    - - name: merge
        template: merge-results
        arguments:
          artifacts:
          - name: batch-1
            from: "{{steps.process-batch-1.outputs.artifacts.result}}"
          - name: batch-2
            from: "{{steps.process-batch-2.outputs.artifacts.result}}"

    # Step 4: Generate report
    - - name: report
        template: generate-report
        arguments:
          parameters:
          - name: workflow-name
            value: "{{workflow.name}}"
          - name: record-count
            value: "{{steps.merge.outputs.parameters.count}}"
          artifacts:
          - name: merged-data
            from: "{{steps.merge.outputs.artifacts.merged}}"

  - name: download-data
    inputs:
      parameters:
      - name: dataset
    script:
      image: python:3.9
      command: [python]
      source: |
        import json
        dataset = "{{inputs.parameters.dataset}}"
        data = {"dataset": dataset, "records": 1000}
        with open('/tmp/dataset.json', 'w') as f:
            json.dump(data, f)
        print(f"Downloaded dataset: {dataset}")
    outputs:
      artifacts:
      - name: dataset
        path: /tmp/dataset.json

  - name: process-batch
    inputs:
      parameters:
      - name: batch-id
      artifacts:
      - name: input-data
        path: /input/data.json
    script:
      image: python:3.9
      command: [python]
      source: |
        import json
        with open('/input/data.json', 'r') as f:
            data = json.load(f)

        batch_id = "{{inputs.parameters.batch-id}}"
        result = {
            "batch": batch_id,
            "processed": True,
            "count": 500
        }

        with open('/tmp/result.json', 'w') as f:
            json.dump(result, f)

        print(f"Processed batch {batch_id}")
    outputs:
      artifacts:
      - name: result
        path: /tmp/result.json
    volumeMounts:
    - name: workspace
      mountPath: /workspace

  - name: merge-results
    inputs:
      artifacts:
      - name: batch-1
        path: /input/batch-1.json
      - name: batch-2
        path: /input/batch-2.json
    script:
      image: python:3.9
      command: [python]
      source: |
        import json

        with open('/input/batch-1.json', 'r') as f:
            batch1 = json.load(f)
        with open('/input/batch-2.json', 'r') as f:
            batch2 = json.load(f)

        merged = {
            "batches": [batch1, batch2],
            "total_count": batch1.get("count", 0) + batch2.get("count", 0)
        }

        with open('/tmp/merged.json', 'w') as f:
            json.dump(merged, f)

        # Output total count as parameter
        print(merged["total_count"])
    outputs:
      artifacts:
      - name: merged
        path: /tmp/merged.json
      parameters:
      - name: count
        valueFrom:
          path: /tmp/count.txt
          default: "0"

  - name: generate-report
    inputs:
      parameters:
      - name: workflow-name
      - name: record-count
      artifacts:
      - name: merged-data
        path: /data/merged.json
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Data Pipeline Report"
          echo "===================="
          echo "Workflow: {{inputs.parameters.workflow-name}}"
          echo "Records Processed: {{inputs.parameters.record-count}}"
          echo "Timestamp: $(date)"
          echo ""
          echo "Merged Data:"
          cat /data/merged.json
```

## Study Resources

- [Workflow Variables](https://argoproj.github.io/argo-workflows/variables/) - Complete variable reference
- [Parameters Documentation](https://argoproj.github.io/argo-workflows/walk-through/parameters/) - Parameter usage guide
- [Artifacts Documentation](https://argoproj.github.io/argo-workflows/walk-through/artifacts/) - Artifact management guide
- [Artifact Repository Config](https://argoproj.github.io/argo-workflows/configure-artifact-repository/) - Repository configuration

## Key Points to Remember

- Workflow variables use double curly brace syntax: `{{variable}}`
- Access workflow-level info with `{{workflow.name}}`, `{{workflow.namespace}}`, etc.
- Reference step outputs with `{{steps.step-name.outputs.parameters.param-name}}`
- Parameters are scalar values (strings, numbers, booleans)
- Artifacts are files or directories passed between steps
- Artifacts are automatically stored in the configured artifact repository
- Use `from:` to pass artifacts from one step to another
- Volume claims provide shared persistent storage across steps
- `volumeClaimTemplates` create dynamic PVCs with the workflow
- JSONPath extracts specific values from JSON output parameters
- Output parameters can come from file paths or script stdout
- Artifacts support S3, GCS, HTTP, and Git sources
- Use `archive.none` to disable artifact compression
- Optional artifacts won't fail if the file doesn't exist
- EmptyDir volumes share data within a single pod only

## Hands-On Practice

- [Lab 04: Managing Artifacts](../../labs/02-argo-workflows/lab-04-artifacts.md) - Practice working with parameters, artifacts, artifact repositories, and volume claims in workflows
