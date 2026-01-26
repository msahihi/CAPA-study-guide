# Lab 04: Artifacts

**Duration**: 35 minutes

## Objectives

By the end of this lab, you will be able to:

- Understand artifact concepts in Argo Workflows
- Configure artifact repositories (MinIO)
- Create and pass artifacts between workflow steps
- Use input and output artifacts
- Work with different artifact sources (Git, S3, HTTP)
- Implement artifact archiving strategies
- Handle large files in workflows
- Debug artifact-related issues

## Prerequisites

- Completed [Lab 03: DAG Workflows](lab-03-dag-workflows.md)
- Argo Workflows installed and running
- Understanding of workflow templates and parameters

## Lab Environment Verification

```bash
kubectl get pods -n argo
argo version
```

## Introduction to Artifacts

Artifacts in Argo Workflows are files or directories that are passed between workflow steps. Unlike parameters (which are strings), artifacts can handle binary data, large files, and complex file structures.

**Key Concepts:**

- **Input Artifacts**: Files consumed by a template
- **Output Artifacts**: Files produced by a template
- **Artifact Repository**: Storage backend for artifacts (S3, GCS, MinIO, etc.)
- **Artifact Passing**: Automatic transfer between steps

## Step 1: Setup Artifact Repository - MinIO (8 minutes)

Argo Workflows needs an artifact repository to store files between steps. We'll use MinIO, an S3-compatible storage server.

### 1.1 Install MinIO

Create `minio-deployment.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: argo
type: Opaque
stringData:
  accesskey: minio
  secretkey: minio123
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: argo
spec:
  ports:
  - port: 9000
    targetPort: 9000
    protocol: TCP
  selector:
    app: minio
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: argo
spec:
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        args:
        - server
        - /data
        env:
        - name: MINIO_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: accesskey
        - name: MINIO_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: minio-credentials
              key: secretkey
        ports:
        - containerPort: 9000
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir: {}
```

Deploy MinIO:

```bash
kubectl apply -f minio-deployment.yaml
kubectl wait --for=condition=ready pod -l app=minio -n argo --timeout=120s
```

Verify MinIO is running:

```bash
kubectl get pods -n argo -l app=minio
```

### 1.2 Configure Argo to Use MinIO

Create a ConfigMap with artifact repository configuration:

```bash
kubectl create configmap workflow-controller-configmap -n argo --from-literal=config="
artifactRepository:
  archiveLogs: true
  s3:
    bucket: argo-artifacts
    endpoint: minio.argo.svc.cluster.local:9000
    insecure: true
    accessKeySecret:
      name: minio-credentials
      key: accesskey
    secretKeySecret:
      name: minio-credentials
      key: secretkey
" --dry-run=client -o yaml | kubectl apply -f -
```

Restart the workflow controller to pick up the new configuration:

```bash
kubectl rollout restart deployment workflow-controller -n argo
kubectl wait --for=condition=ready pod -l app=workflow-controller -n argo --timeout=120s
```

### 1.3 Create MinIO Bucket

Create a job to initialize the bucket:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: minio-create-bucket
  namespace: argo
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: minio-mc
        image: minio/mc:latest
        command:
        - /bin/sh
        - -c
        - |
          mc alias set minio http://minio.argo.svc.cluster.local:9000 minio minio123
          mc mb minio/argo-artifacts || true
          mc policy set download minio/argo-artifacts
          echo "Bucket created successfully"
```

Apply and wait:

```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: minio-create-bucket
  namespace: argo
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
      - name: minio-mc
        image: minio/mc:latest
        command:
        - /bin/sh
        - -c
        - |
          mc alias set minio http://minio.argo.svc.cluster.local:9000 minio minio123
          mc mb minio/argo-artifacts || true
          mc policy set download minio/argo-artifacts
          echo "Bucket created successfully"
EOF

kubectl wait --for=condition=complete job/minio-create-bucket -n argo --timeout=60s
kubectl logs -n argo job/minio-create-bucket
```

## Step 2: Basic Artifact Passing (7 minutes)

### 2.1 Simple Output Artifact

Create `artifact-output.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-output-
spec:
  entrypoint: main
  templates:
  - name: main
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Creating artifact file..."
          echo "Hello from Argo Workflows" > /tmp/hello.txt
          echo "Timestamp: $(date)" >> /tmp/hello.txt
          echo "Hostname: $(hostname)" >> /tmp/hello.txt
          cat /tmp/hello.txt
    outputs:
      artifacts:
      - name: hello-artifact
        path: /tmp/hello.txt
```

Submit and verify:

```bash
argo submit -n argo artifact-output.yaml --watch
argo logs -n argo @latest
```

### 2.2 Input and Output Artifacts

Create `artifact-passing.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-passing-
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    # Step 1: Create artifact
    - - name: create
        template: create-artifact

    # Step 2: Process artifact
    - - name: process
        template: process-artifact
        arguments:
          artifacts:
          - name: input-file
            from: "{{steps.create.outputs.artifacts.data}}"

    # Step 3: Read processed artifact
    - - name: read
        template: read-artifact
        arguments:
          artifacts:
          - name: processed-file
            from: "{{steps.process.outputs.artifacts.result}}"

  - name: create-artifact
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Generating data..."
          for i in $(seq 1 10); do
            echo "Data line $i" >> /tmp/data.txt
          done
          echo "Data file created"
    outputs:
      artifacts:
      - name: data
        path: /tmp/data.txt

  - name: process-artifact
    inputs:
      artifacts:
      - name: input-file
        path: /tmp/input.txt
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Processing input file..."
          cat /tmp/input.txt
          echo "--- Processed Data ---" > /tmp/output.txt
          cat /tmp/input.txt >> /tmp/output.txt
          echo "--- End of Data ---" >> /tmp/output.txt
          echo "Processing complete"
    outputs:
      artifacts:
      - name: result
        path: /tmp/output.txt

  - name: read-artifact
    inputs:
      artifacts:
      - name: processed-file
        path: /tmp/final.txt
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Reading final artifact..."
          cat /tmp/final.txt
```

Submit:

```bash
argo submit -n argo artifact-passing.yaml --watch
argo logs -n argo @latest
```

### 2.3 Multiple Artifacts

Create `artifact-multiple.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-multiple-
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: generate
        template: generate-files

    - - name: combine
        template: combine-files
        arguments:
          artifacts:
          - name: file1
            from: "{{steps.generate.outputs.artifacts.file-a}}"
          - name: file2
            from: "{{steps.generate.outputs.artifacts.file-b}}"
          - name: file3
            from: "{{steps.generate.outputs.artifacts.file-c}}"

  - name: generate-files
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Content A" > /tmp/a.txt
          echo "Content B" > /tmp/b.txt
          echo "Content C" > /tmp/c.txt
    outputs:
      artifacts:
      - name: file-a
        path: /tmp/a.txt
      - name: file-b
        path: /tmp/b.txt
      - name: file-c
        path: /tmp/c.txt

  - name: combine-files
    inputs:
      artifacts:
      - name: file1
        path: /tmp/input/a.txt
      - name: file2
        path: /tmp/input/b.txt
      - name: file3
        path: /tmp/input/c.txt
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Combining files..."
          cat /tmp/input/a.txt /tmp/input/b.txt /tmp/input/c.txt > /tmp/combined.txt
          echo "---"
          cat /tmp/combined.txt
    outputs:
      artifacts:
      - name: combined
        path: /tmp/combined.txt
```

Submit:

```bash
argo submit -n argo artifact-multiple.yaml --watch
```

## Step 3: Artifact Sources (8 minutes)

### 3.1 Git Repository Artifact

Create `artifact-git.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-git-
spec:
  entrypoint: main
  templates:
  - name: main
    inputs:
      artifacts:
      - name: source-code
        path: /src
        git:
          repo: https://github.com/argoproj/argo-workflows.git
          revision: "master"
          depth: 1
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Cloned repository contents:"
          ls -la /src
          echo "---"
          echo "README preview:"
          head -n 20 /src/README.md
```

Submit:

```bash
argo submit -n argo artifact-git.yaml --watch
argo logs -n argo @latest
```

### 3.2 HTTP Artifact

Create `artifact-http.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-http-
spec:
  entrypoint: main
  templates:
  - name: main
    inputs:
      artifacts:
      - name: data-file
        path: /tmp/data.json
        http:
          url: https://jsonplaceholder.typicode.com/posts/1
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import json

        with open('/tmp/data.json', 'r') as f:
            data = json.load(f)

        print("Downloaded data:")
        print(json.dumps(data, indent=2))

        print("\nTitle:", data.get('title'))
        print("User ID:", data.get('userId'))
```

Submit:

```bash
argo submit -n argo artifact-http.yaml --watch
```

### 3.3 Raw Artifact (Inline Content)

Create `artifact-raw.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-raw-
spec:
  entrypoint: main
  templates:
  - name: main
    inputs:
      artifacts:
      - name: config
        path: /tmp/config.yaml
        raw:
          data: |
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: my-config
            data:
              key1: value1
              key2: value2
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Config file contents:"
          cat /tmp/config.yaml
```

Submit:

```bash
argo submit -n argo artifact-raw.yaml --watch
```

## Step 4: Artifact Processing Workflows (7 minutes)

### 4.1 Data Processing Pipeline

Create `artifact-data-pipeline.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-data-pipeline-
spec:
  entrypoint: data-pipeline
  templates:
  - name: data-pipeline
    steps:
    # Generate CSV data
    - - name: generate-data
        template: generate-csv

    # Process in parallel
    - - name: analyze
        template: analyze-csv
        arguments:
          artifacts:
          - name: input-csv
            from: "{{steps.generate-data.outputs.artifacts.data-csv}}"

      - name: transform
        template: transform-csv
        arguments:
          artifacts:
          - name: input-csv
            from: "{{steps.generate-data.outputs.artifacts.data-csv}}"

    # Combine results
    - - name: report
        template: generate-report
        arguments:
          artifacts:
          - name: analysis
            from: "{{steps.analyze.outputs.artifacts.analysis-result}}"
          - name: transformed
            from: "{{steps.transform.outputs.artifacts.transformed-data}}"

  - name: generate-csv
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import csv
        import random

        with open('/tmp/data.csv', 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['id', 'name', 'value'])
            for i in range(1, 11):
                writer.writerow([i, f'Item{i}', random.randint(10, 100)])

        print("Generated CSV data")
    outputs:
      artifacts:
      - name: data-csv
        path: /tmp/data.csv

  - name: analyze-csv
    inputs:
      artifacts:
      - name: input-csv
        path: /tmp/input.csv
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import csv
        import json

        with open('/tmp/input.csv', 'r') as f:
            reader = csv.DictReader(f)
            values = [int(row['value']) for row in reader]

        analysis = {
            'count': len(values),
            'sum': sum(values),
            'average': sum(values) / len(values),
            'min': min(values),
            'max': max(values)
        }

        print("Analysis:", json.dumps(analysis, indent=2))

        with open('/tmp/analysis.json', 'w') as f:
            json.dump(analysis, f, indent=2)
    outputs:
      artifacts:
      - name: analysis-result
        path: /tmp/analysis.json

  - name: transform-csv
    inputs:
      artifacts:
      - name: input-csv
        path: /tmp/input.csv
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import csv

        with open('/tmp/input.csv', 'r') as infile:
            reader = csv.DictReader(infile)
            with open('/tmp/output.csv', 'w', newline='') as outfile:
                writer = csv.DictWriter(outfile,
                    fieldnames=['id', 'name', 'value', 'doubled'])
                writer.writeheader()

                for row in reader:
                    row['doubled'] = int(row['value']) * 2
                    writer.writerow(row)

        print("Transformed data")
        with open('/tmp/output.csv', 'r') as f:
            print(f.read())
    outputs:
      artifacts:
      - name: transformed-data
        path: /tmp/output.csv

  - name: generate-report
    inputs:
      artifacts:
      - name: analysis
        path: /tmp/analysis.json
      - name: transformed
        path: /tmp/transformed.csv
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import json

        print("="*50)
        print("DATA PROCESSING REPORT")
        print("="*50)

        with open('/tmp/analysis.json', 'r') as f:
            analysis = json.load(f)

        print("\nStatistics:")
        for key, value in analysis.items():
            print(f"  {key}: {value}")

        print("\nTransformed Data Preview:")
        with open('/tmp/transformed.csv', 'r') as f:
            for i, line in enumerate(f):
                if i < 5:
                    print(f"  {line.rstrip()}")

        print("="*50)
```

Submit:

```bash
argo submit -n argo artifact-data-pipeline.yaml --watch
argo logs -n argo @latest
```

### 4.2 Build and Test Workflow

Create `artifact-build-test.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-build-test-
spec:
  entrypoint: build-test
  templates:
  - name: build-test
    steps:
    # Create source code
    - - name: create-source
        template: create-python-code

    # Build
    - - name: build
        template: build-package
        arguments:
          artifacts:
          - name: source
            from: "{{steps.create-source.outputs.artifacts.code}}"

    # Test
    - - name: test
        template: run-tests
        arguments:
          artifacts:
          - name: package
            from: "{{steps.build.outputs.artifacts.built-package}}"

  - name: create-python-code
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        code = '''
def add(a, b):
    return a + b

def multiply(a, b):
    return a * b

if __name__ == "__main__":
    print("Functions defined")
'''
        with open('/tmp/calculator.py', 'w') as f:
            f.write(code)
        print("Source code created")
    outputs:
      artifacts:
      - name: code
        path: /tmp/calculator.py

  - name: build-package
    inputs:
      artifacts:
      - name: source
        path: /tmp/src/calculator.py
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import os
        print("Building package...")

        # Simulate build process
        os.makedirs('/tmp/build', exist_ok=True)
        with open('/tmp/src/calculator.py', 'r') as src:
            with open('/tmp/build/calculator.py', 'w') as dst:
                dst.write(src.read())

        # Create metadata
        with open('/tmp/build/VERSION', 'w') as f:
            f.write('1.0.0')

        print("Build complete")
    outputs:
      artifacts:
      - name: built-package
        path: /tmp/build
        archive:
          none: {}

  - name: run-tests
    inputs:
      artifacts:
      - name: package
        path: /tmp/package
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import sys
        sys.path.insert(0, '/tmp/package')

        from calculator import add, multiply

        print("Running tests...")

        assert add(2, 3) == 5, "Test 1 failed"
        print("✓ Test 1: add(2, 3) == 5")

        assert multiply(4, 5) == 20, "Test 2 failed"
        print("✓ Test 2: multiply(4, 5) == 20")

        print("\nAll tests passed!")
```

Submit:

```bash
argo submit -n argo artifact-build-test.yaml --watch
```

## Step 5: Artifact Archiving and Compression (5 minutes)

### 5.1 Archive Options

Create `artifact-archive.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: artifact-archive-
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    # Default: tar.gz compression
    - - name: compressed
        template: create-compressed

    # No archiving
    - - name: uncompressed
        template: create-uncompressed

    # Read both
    - - name: read-compressed
        template: read-artifact
        arguments:
          artifacts:
          - name: data
            from: "{{steps.compressed.outputs.artifacts.files}}"

      - name: read-uncompressed
        template: read-artifact
        arguments:
          artifacts:
          - name: data
            from: "{{steps.uncompressed.outputs.artifacts.files}}"

  - name: create-compressed
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          mkdir -p /tmp/data
          echo "File 1" > /tmp/data/file1.txt
          echo "File 2" > /tmp/data/file2.txt
          echo "File 3" > /tmp/data/file3.txt
    outputs:
      artifacts:
      - name: files
        path: /tmp/data
        # Default compression with tar.gz

  - name: create-uncompressed
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          mkdir -p /tmp/data
          echo "File A" > /tmp/data/fileA.txt
          echo "File B" > /tmp/data/fileB.txt
          echo "File C" > /tmp/data/fileC.txt
    outputs:
      artifacts:
      - name: files
        path: /tmp/data
        archive:
          none: {}  # No archiving

  - name: read-artifact
    inputs:
      artifacts:
      - name: data
        path: /tmp/input
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Contents:"
          ls -la /tmp/input
          echo "---"
          find /tmp/input -type f -exec cat {} \;
```

Submit:

```bash
argo submit -n argo artifact-archive.yaml --watch
```

## Practice Exercises

### Exercise 1: Log Aggregation Workflow

Create a workflow that:

1. Generates 3 log files in parallel (with different content)
2. Aggregates all logs into a single file
3. Analyzes the aggregated logs (count lines, find errors)
4. Generates a summary report

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: log-aggregation-
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: gen-log1
        template: generate-log
        arguments:
          parameters:
          - name: service
            value: "frontend"
      - name: gen-log2
        template: generate-log
        arguments:
          parameters:
          - name: service
            value: "backend"
      - name: gen-log3
        template: generate-log
        arguments:
          parameters:
          - name: service
            value: "database"

    - - name: aggregate
        template: aggregate-logs
        arguments:
          artifacts:
          - name: log1
            from: "{{steps.gen-log1.outputs.artifacts.log}}"
          - name: log2
            from: "{{steps.gen-log2.outputs.artifacts.log}}"
          - name: log3
            from: "{{steps.gen-log3.outputs.artifacts.log}}"

    - - name: analyze
        template: analyze-logs
        arguments:
          artifacts:
          - name: logs
            from: "{{steps.aggregate.outputs.artifacts.combined}}"

  - name: generate-log
    inputs:
      parameters:
      - name: service
    script:
      image: bash:5.1
      command: [bash]
      source: |
        SERVICE="{{inputs.parameters.service}}"
        for i in {1..10}; do
          if [ $((RANDOM % 5)) -eq 0 ]; then
            echo "$(date -Iseconds) [$SERVICE] ERROR: Something went wrong" >> /tmp/service.log
          else
            echo "$(date -Iseconds) [$SERVICE] INFO: Processing request $i" >> /tmp/service.log
          fi
        done
    outputs:
      artifacts:
      - name: log
        path: /tmp/service.log

  - name: aggregate-logs
    inputs:
      artifacts:
      - name: log1
        path: /tmp/logs/frontend.log
      - name: log2
        path: /tmp/logs/backend.log
      - name: log3
        path: /tmp/logs/database.log
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          cat /tmp/logs/*.log | sort > /tmp/combined.log
          echo "Aggregated $(wc -l < /tmp/combined.log) log lines"
    outputs:
      artifacts:
      - name: combined
        path: /tmp/combined.log

  - name: analyze-logs
    inputs:
      artifacts:
      - name: logs
        path: /tmp/logs.txt
    script:
      image: bash:5.1
      command: [bash]
      source: |
        echo "=== LOG ANALYSIS REPORT ==="
        echo "Total lines: $(wc -l < /tmp/logs.txt)"
        echo "Error count: $(grep -c ERROR /tmp/logs.txt || echo 0)"
        echo "Info count: $(grep -c INFO /tmp/logs.txt || echo 0)"
        echo ""
        echo "Errors:"
        grep ERROR /tmp/logs.txt || echo "No errors found"
```

</details>

### Exercise 2: Image Processing Pipeline

Create a workflow that:

1. Creates a text file with image metadata
2. Simulates image processing (resize, watermark, thumbnail)
3. Collects all processed outputs
4. Creates a manifest file listing all processed images

<details>
<summary>Solution</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: image-pipeline-
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: create-image
        template: create-metadata

    - - name: resize
        template: process-image
        arguments:
          parameters:
          - name: operation
            value: "resize"
          artifacts:
          - name: image
            from: "{{steps.create-image.outputs.artifacts.metadata}}"
      - name: watermark
        template: process-image
        arguments:
          parameters:
          - name: operation
            value: "watermark"
          artifacts:
          - name: image
            from: "{{steps.create-image.outputs.artifacts.metadata}}"
      - name: thumbnail
        template: process-image
        arguments:
          parameters:
          - name: operation
            value: "thumbnail"
          artifacts:
          - name: image
            from: "{{steps.create-image.outputs.artifacts.metadata}}"

    - - name: manifest
        template: create-manifest
        arguments:
          artifacts:
          - name: resized
            from: "{{steps.resize.outputs.artifacts.processed}}"
          - name: watermarked
            from: "{{steps.watermark.outputs.artifacts.processed}}"
          - name: thumb
            from: "{{steps.thumbnail.outputs.artifacts.processed}}"

  - name: create-metadata
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import json
        metadata = {
            "filename": "photo.jpg",
            "width": 1920,
            "height": 1080,
            "format": "JPEG"
        }
        with open('/tmp/image.json', 'w') as f:
            json.dump(metadata, f)
        print("Created image metadata")
    outputs:
      artifacts:
      - name: metadata
        path: /tmp/image.json

  - name: process-image
    inputs:
      parameters:
      - name: operation
      artifacts:
      - name: image
        path: /tmp/input.json
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import json

        operation = "{{inputs.parameters.operation}}"

        with open('/tmp/input.json', 'r') as f:
            metadata = json.load(f)

        print(f"Processing: {operation}")

        result = {
            "operation": operation,
            "input": metadata,
            "output": f"{metadata['filename']}.{operation}.jpg"
        }

        with open('/tmp/processed.json', 'w') as f:
            json.dump(result, f)
    outputs:
      artifacts:
      - name: processed
        path: /tmp/processed.json

  - name: create-manifest
    inputs:
      artifacts:
      - name: resized
        path: /tmp/resize.json
      - name: watermarked
        path: /tmp/watermark.json
      - name: thumb
        path: /tmp/thumbnail.json
    script:
      image: python:3.9-slim
      command: [python]
      source: |
        import json

        files = ['/tmp/resize.json', '/tmp/watermark.json', '/tmp/thumbnail.json']
        manifest = []

        for f in files:
            with open(f, 'r') as file:
                manifest.append(json.load(file))

        print("=== PROCESSING MANIFEST ===")
        print(json.dumps(manifest, indent=2))
```

</details>

## Verification Steps

```bash
# View workflow artifacts
argo get -n argo <workflow-name>

# Download artifact
argo logs -n argo <workflow-name> <step-name>

# Check MinIO bucket
kubectl port-forward svc/minio 9000:9000 -n argo
# Visit http://localhost:9000 (minio/minio123)

# Clean up
argo delete -n argo --all
```

## Troubleshooting

### Issue: Artifact Not Found

**Symptom**: Error: "artifact not found"

**Solution**: Verify artifact repository is configured correctly

```bash
kubectl get configmap workflow-controller-configmap -n argo -o yaml
kubectl logs -n argo deployment/workflow-controller
```

### Issue: MinIO Connection Failed

**Symptom**: Cannot upload/download artifacts

**Solution**: Check MinIO pod and service

```bash
kubectl get pods -n argo -l app=minio
kubectl logs -n argo deployment/minio
kubectl get svc minio -n argo
```

### Issue: Large Artifacts Timeout

**Symptom**: Workflow times out during artifact transfer

**Solution**: Increase timeout or use streaming

```yaml
outputs:
  artifacts:
  - name: large-file
    path: /tmp/large.dat
    archive:
      none: {}  # Don't compress large files
```

## Key Takeaways

- Artifacts are files/directories passed between workflow steps
- Artifact repository (MinIO/S3) required for artifact storage
- Input artifacts consumed by templates, output artifacts produced
- Multiple artifact sources: Git, HTTP, S3, raw data
- Artifacts can be compressed or stored uncompressed
- Parallel steps can consume the same artifact
- Archive options affect storage size and transfer speed
- Proper artifact management critical for data pipelines

## Next Steps

Continue to [Lab 05: Workflow Templates](lab-05-workflow-templates.md) to learn about reusable templates, ClusterWorkflowTemplates, and CronWorkflows.

## Additional Resources

- [Artifact Documentation](https://argoproj.github.io/argo-workflows/walk-through/artifacts/)
- [Artifact Repository Configuration](https://argoproj.github.io/argo-workflows/configure-artifact-repository/)
- [MinIO Setup](https://github.com/minio/minio)
