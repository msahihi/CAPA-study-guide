# CI/CD Integration

## Overview

Argo Workflows excels at CI/CD automation, providing powerful capabilities for building, testing, and deploying applications. Understanding how to integrate workflows into CI/CD pipelines, use workflow templates effectively, and schedule workflows with CronWorkflows is essential for production-grade automation.

## Key Topics

### CI/CD Use Cases

Argo Workflows addresses numerous CI/CD scenarios with its flexible workflow orchestration capabilities.

#### 1. Build Pipelines

Automate application builds with multi-stage pipelines.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: build-pipeline-
spec:
  entrypoint: build
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/example/app.git"
    - name: branch
      value: "main"
    - name: image-tag
      value: "latest"

  templates:
  - name: build
    dag:
      tasks:
      - name: checkout
        template: git-clone
        arguments:
          parameters:
          - name: repo
            value: "{{workflow.parameters.repo-url}}"
          - name: branch
            value: "{{workflow.parameters.branch}}"

      - name: install-deps
        template: npm-install
        dependencies: [checkout]
        arguments:
          artifacts:
          - name: source
            from: "{{tasks.checkout.outputs.artifacts.source}}"

      - name: build-app
        template: npm-build
        dependencies: [install-deps]
        arguments:
          artifacts:
          - name: source
            from: "{{tasks.checkout.outputs.artifacts.source}}"

      - name: docker-build
        template: docker-build-push
        dependencies: [build-app]
        arguments:
          parameters:
          - name: tag
            value: "{{workflow.parameters.image-tag}}"
          artifacts:
          - name: build-output
            from: "{{tasks.build-app.outputs.artifacts.dist}}"

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

  - name: npm-install
    inputs:
      artifacts:
      - name: source
        path: /src
    container:
      image: node:16
      command: [sh, -c]
      args: ["cd /src && npm install"]
      volumeMounts:
      - name: node-modules
        mountPath: /src/node_modules
    volumes:
    - name: node-modules
      emptyDir: {}

  - name: npm-build
    inputs:
      artifacts:
      - name: source
        path: /src
    container:
      image: node:16
      command: [sh, -c]
      args: ["cd /src && npm run build"]
    outputs:
      artifacts:
      - name: dist
        path: /src/dist

  - name: docker-build-push
    inputs:
      parameters:
      - name: tag
      artifacts:
      - name: build-output
        path: /build
    container:
      image: gcr.io/kaniko-project/executor:latest
      command: [/kaniko/executor]
      args:
        - "--dockerfile=/build/Dockerfile"
        - "--context=/build"
        - "--destination=myregistry/myapp:{{inputs.parameters.tag}}"
```

#### 2. Test Automation

Run comprehensive test suites with parallel execution.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: test-suite-
spec:
  entrypoint: test-pipeline
  arguments:
    parameters:
    - name: test-environment
      value: "staging"

  templates:
  - name: test-pipeline
    dag:
      tasks:
      - name: setup-environment
        template: env-setup
        arguments:
          parameters:
          - name: environment
            value: "{{workflow.parameters.test-environment}}"

      - name: unit-tests
        template: run-tests
        dependencies: [setup-environment]
        arguments:
          parameters:
          - name: test-type
            value: "unit"

      - name: integration-tests
        template: run-tests
        dependencies: [setup-environment]
        arguments:
          parameters:
          - name: test-type
            value: "integration"

      - name: e2e-tests
        template: run-tests
        dependencies: [setup-environment]
        arguments:
          parameters:
          - name: test-type
            value: "e2e"

      - name: generate-report
        template: test-report
        dependencies: [unit-tests, integration-tests, e2e-tests]
        arguments:
          parameters:
          - name: unit-result
            value: "{{tasks.unit-tests.outputs.parameters.result}}"
          - name: integration-result
            value: "{{tasks.integration-tests.outputs.parameters.result}}"
          - name: e2e-result
            value: "{{tasks.e2e-tests.outputs.parameters.result}}"

  - name: env-setup
    inputs:
      parameters:
      - name: environment
    container:
      image: alpine:latest
      command: [echo]
      args: ["Setting up {{inputs.parameters.environment}} environment"]

  - name: run-tests
    inputs:
      parameters:
      - name: test-type
    script:
      image: node:16
      command: [sh]
      source: |
        echo "Running {{inputs.parameters.test-type}} tests..."
        # Simulate test execution
        sleep 5
        echo "passed" > /tmp/result.txt
    outputs:
      parameters:
      - name: result
        valueFrom:
          path: /tmp/result.txt

  - name: test-report
    inputs:
      parameters:
      - name: unit-result
      - name: integration-result
      - name: e2e-result
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Test Results Summary"
          echo "===================="
          echo "Unit Tests: {{inputs.parameters.unit-result}}"
          echo "Integration Tests: {{inputs.parameters.integration-result}}"
          echo "E2E Tests: {{inputs.parameters.e2e-result}}"
```

#### 3. Deployment Automation

Automate application deployments with approval gates.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: deploy-pipeline-
spec:
  entrypoint: deployment
  arguments:
    parameters:
    - name: environment
      value: "production"
    - name: version
      value: "v1.2.3"

  templates:
  - name: deployment
    steps:
    # Pre-deployment checks
    - - name: validate-config
        template: validate
        arguments:
          parameters:
          - name: env
            value: "{{workflow.parameters.environment}}"

    # Manual approval for production
    - - name: approval-gate
        template: approval
        when: "{{workflow.parameters.environment}} == production"

    # Deployment
    - - name: deploy-app
        template: deploy
        arguments:
          parameters:
          - name: environment
            value: "{{workflow.parameters.environment}}"
          - name: version
            value: "{{workflow.parameters.version}}"

    # Post-deployment verification
    - - name: health-check
        template: verify-health

    - - name: smoke-tests
        template: smoke-test

  - name: validate
    inputs:
      parameters:
      - name: env
    container:
      image: alpine:latest
      command: [echo]
      args: ["Validating configuration for {{inputs.parameters.env}}"]

  - name: approval
    suspend: {}

  - name: deploy
    inputs:
      parameters:
      - name: environment
      - name: version
    resource:
      action: apply
      manifest: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: myapp
          namespace: {{inputs.parameters.environment}}
        spec:
          replicas: 3
          selector:
            matchLabels:
              app: myapp
          template:
            metadata:
              labels:
                app: myapp
                version: {{inputs.parameters.version}}
            spec:
              containers:
              - name: myapp
                image: myregistry/myapp:{{inputs.parameters.version}}
                ports:
                - containerPort: 8080

  - name: verify-health
    container:
      image: curlimages/curl:latest
      command: [sh, -c]
      args: ["curl -f http://myapp:8080/health || exit 1"]

  - name: smoke-test
    container:
      image: alpine:latest
      command: [echo, "Running smoke tests..."]
```

### Triggering Workflows

Multiple methods exist for triggering workflow execution programmatically.

#### 1. Argo CLI

Submit workflows using the command-line interface.

```bash
# Submit a workflow from file
argo submit workflow.yaml

# Submit with parameters
argo submit workflow.yaml \
  -p environment=production \
  -p version=v2.0.0

# Submit and watch
argo submit --watch workflow.yaml

# Submit from URL
argo submit https://raw.githubusercontent.com/example/workflows/main/build.yaml

# Generate workflow name
argo submit --generate-name workflow-

# Submit from WorkflowTemplate
argo submit --from workflowtemplate/build-template \
  -p repo-url=https://github.com/example/app.git
```

#### 2. Kubernetes API

Create workflows using kubectl or Kubernetes API.

```bash
# Create workflow directly
kubectl create -f workflow.yaml

# Apply workflow
kubectl apply -f workflow.yaml

# Create from WorkflowTemplate
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: from-template-
spec:
  workflowTemplateRef:
    name: build-template
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/example/app.git"
EOF
```

#### 3. HTTP API

Trigger workflows via REST API.

```bash
# Submit workflow via API
curl -X POST \
  https://argo-server:2746/api/v1/workflows/argo \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @workflow.json

# Submit from WorkflowTemplate
curl -X POST \
  https://argo-server:2746/api/v1/workflows/argo/submit \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceKind": "WorkflowTemplate",
    "resourceName": "build-template",
    "submitOptions": {
      "parameters": [
        "repo-url=https://github.com/example/app.git"
      ]
    }
  }'
```

#### 4. Argo Events Integration

Trigger workflows based on events.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-sensor
spec:
  template:
    serviceAccountName: argo-events-sa
  dependencies:
  - name: webhook-dep
    eventSourceName: webhook
    eventName: example

  triggers:
  - template:
      name: workflow-trigger
      k8s:
        operation: create
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: triggered-workflow-
            spec:
              entrypoint: main
              arguments:
                parameters:
                - name: message
                  value: "Triggered by webhook"
              templates:
              - name: main
                container:
                  image: alpine:latest
                  command: [echo]
                  args: ["{{workflow.parameters.message}}"]
```

### Workflow Templates vs Cluster Workflow Templates

Reusable workflow definitions that can be instantiated multiple times.

#### WorkflowTemplate (Namespaced)

Workflow templates are namespace-scoped and can only be used within their namespace.

**Create WorkflowTemplate:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: build-template
  namespace: argo
spec:
  entrypoint: build-pipeline
  arguments:
    parameters:
    - name: repo-url
    - name: branch
      value: "main"
    - name: image-name

  templates:
  - name: build-pipeline
    steps:
    - - name: clone
        template: git-clone

    - - name: build
        template: build-image

    - - name: push
        template: push-image

  - name: git-clone
    container:
      image: alpine/git:latest
      command: [git, clone]
      args:
        - "{{workflow.parameters.repo-url}}"
        - "-b"
        - "{{workflow.parameters.branch}}"
        - "/workspace"
    outputs:
      artifacts:
      - name: source
        path: /workspace

  - name: build-image
    container:
      image: docker:20.10
      command: [docker, build]
      args: ["-t", "{{workflow.parameters.image-name}}", "."]

  - name: push-image
    container:
      image: docker:20.10
      command: [docker, push]
      args: ["{{workflow.parameters.image-name}}"]
```

**Use WorkflowTemplate:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: build-from-template-
spec:
  workflowTemplateRef:
    name: build-template
  arguments:
    parameters:
    - name: repo-url
      value: "https://github.com/example/app.git"
    - name: branch
      value: "develop"
    - name: image-name
      value: "myregistry/myapp:v1.0.0"
```

**Submit via CLI:**

```bash
argo submit --from workflowtemplate/build-template \
  -p repo-url=https://github.com/example/app.git \
  -p image-name=myregistry/myapp:v1.0.0
```

#### ClusterWorkflowTemplate (Cluster-Scoped)

Cluster workflow templates are available across all namespaces.

**Create ClusterWorkflowTemplate:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: common-tests
spec:
  entrypoint: test-suite
  arguments:
    parameters:
    - name: test-type
      value: "unit"

  templates:
  - name: test-suite
    container:
      image: node:16
      command: [npm, test]
      args: ["--", "--type={{workflow.parameters.test-type}}"]
```

**Use ClusterWorkflowTemplate:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: test-
  namespace: dev
spec:
  workflowTemplateRef:
    name: common-tests
    clusterScope: true
  arguments:
    parameters:
    - name: test-type
      value: "integration"
```

#### Template Reference in Workflows

Reference templates within a workflow for reusability.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: multi-env-deploy-
spec:
  entrypoint: deploy-all
  templates:
  - name: deploy-all
    steps:
    - - name: deploy-dev
        templateRef:
          name: deploy-template
          template: deploy
        arguments:
          parameters:
          - name: environment
            value: "development"

    - - name: deploy-staging
        templateRef:
          name: deploy-template
          template: deploy
        arguments:
          parameters:
          - name: environment
            value: "staging"

      - name: deploy-prod
        templateRef:
          name: deploy-template
          template: deploy
        arguments:
          parameters:
          - name: environment
            value: "production"
```

### Cron Workflows

Schedule recurring workflow executions using CronWorkflow resources.

#### Basic CronWorkflow

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: nightly-build
  namespace: argo
spec:
  schedule: "0 2 * * *"  # Run at 2:00 AM daily
  timezone: "America/Los_Angeles"
  startingDeadlineSeconds: 0
  concurrencyPolicy: "Replace"  # Replace, Allow, or Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3

  workflowSpec:
    entrypoint: build
    arguments:
      parameters:
      - name: branch
        value: "main"

    templates:
    - name: build
      steps:
      - - name: checkout
          template: git-clone

      - - name: build-app
          template: build

      - - name: run-tests
          template: test

    - name: git-clone
      container:
        image: alpine/git:latest
        command: [git, clone]
        args: ["https://github.com/example/app.git", "/workspace"]

    - name: build
      container:
        image: node:16
        command: [sh, -c]
        args: ["cd /workspace && npm install && npm run build"]

    - name: test
      container:
        image: node:16
        command: [sh, -c]
        args: ["cd /workspace && npm test"]
```

#### Schedule Syntax

CronWorkflows use standard cron syntax:

```
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
# │ │ │ │ │
# * * * * *
```

**Common Schedules:**

```yaml
# Every hour
schedule: "0 * * * *"

# Every day at midnight
schedule: "0 0 * * *"

# Every Monday at 9 AM
schedule: "0 9 * * 1"

# Every 15 minutes
schedule: "*/15 * * * *"

# First day of every month
schedule: "0 0 1 * *"

# Weekdays at 6 PM
schedule: "0 18 * * 1-5"
```

#### Concurrency Policy

Control how concurrent executions are handled.

```yaml
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: "Allow"  # Options: Allow, Replace, Forbid

  # Allow: Multiple workflows can run concurrently
  # Replace: Cancel running workflow and start new one
  # Forbid: Skip new execution if one is running
```

#### CronWorkflow with WorkflowTemplate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: scheduled-cleanup
spec:
  schedule: "0 3 * * *"  # Daily at 3 AM
  timezone: "UTC"
  concurrencyPolicy: "Forbid"

  workflowSpec:
    workflowTemplateRef:
      name: cleanup-template
    arguments:
      parameters:
      - name: retention-days
        value: "30"
```

#### Suspend CronWorkflow

Temporarily disable a CronWorkflow.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: backup-workflow
spec:
  schedule: "0 1 * * *"
  suspend: true  # Prevents new workflow executions

  workflowSpec:
    entrypoint: backup
    templates:
    - name: backup
      container:
        image: backup-tool:latest
        command: [/backup.sh]
```

**Via CLI:**

```bash
# Suspend CronWorkflow
argo cron suspend nightly-build

# Resume CronWorkflow
argo cron resume nightly-build

# List CronWorkflows
argo cron list
```

## Practice Examples

### Complete CI/CD Pipeline Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: complete-cicd-pipeline
spec:
  entrypoint: cicd-pipeline
  arguments:
    parameters:
    - name: repo-url
    - name: branch
      value: "main"
    - name: environment
      value: "staging"
    - name: image-registry
      value: "myregistry.io"

  templates:
  - name: cicd-pipeline
    dag:
      tasks:
      # Source Stage
      - name: clone-repo
        template: git-clone
        arguments:
          parameters:
          - name: repo
            value: "{{workflow.parameters.repo-url}}"
          - name: branch
            value: "{{workflow.parameters.branch}}"

      # Build Stage
      - name: install-dependencies
        template: npm-install
        dependencies: [clone-repo]
        arguments:
          artifacts:
          - name: source
            from: "{{tasks.clone-repo.outputs.artifacts.source}}"

      - name: lint-code
        template: npm-lint
        dependencies: [install-dependencies]
        arguments:
          artifacts:
          - name: source
            from: "{{tasks.clone-repo.outputs.artifacts.source}}"

      - name: build-application
        template: npm-build
        dependencies: [lint-code]
        arguments:
          artifacts:
          - name: source
            from: "{{tasks.clone-repo.outputs.artifacts.source}}"

      # Test Stage
      - name: unit-tests
        template: npm-test
        dependencies: [build-application]
        arguments:
          parameters:
          - name: test-type
            value: "unit"
          artifacts:
          - name: source
            from: "{{tasks.clone-repo.outputs.artifacts.source}}"

      - name: integration-tests
        template: npm-test
        dependencies: [build-application]
        arguments:
          parameters:
          - name: test-type
            value: "integration"
          artifacts:
          - name: source
            from: "{{tasks.clone-repo.outputs.artifacts.source}}"

      # Security Stage
      - name: security-scan
        template: trivy-scan
        dependencies: [build-application]
        arguments:
          artifacts:
          - name: source
            from: "{{tasks.clone-repo.outputs.artifacts.source}}"

      # Package Stage
      - name: build-docker-image
        template: docker-build
        dependencies: [unit-tests, integration-tests, security-scan]
        arguments:
          parameters:
          - name: image-tag
            value: "{{workflow.parameters.image-registry}}/myapp:{{workflow.parameters.branch}}-{{workflow.creationTimestamp}}"
          artifacts:
          - name: build-output
            from: "{{tasks.build-application.outputs.artifacts.dist}}"

      # Deploy Stage
      - name: deploy-application
        template: kubectl-deploy
        dependencies: [build-docker-image]
        arguments:
          parameters:
          - name: environment
            value: "{{workflow.parameters.environment}}"
          - name: image
            value: "{{tasks.build-docker-image.outputs.parameters.image-name}}"

      # Verify Stage
      - name: health-check
        template: verify-deployment
        dependencies: [deploy-application]
        arguments:
          parameters:
          - name: environment
            value: "{{workflow.parameters.environment}}"

      - name: smoke-tests
        template: run-smoke-tests
        dependencies: [health-check]
        arguments:
          parameters:
          - name: environment
            value: "{{workflow.parameters.environment}}"

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

  - name: npm-install
    inputs:
      artifacts:
      - name: source
        path: /src
    container:
      image: node:16
      command: [sh, -c]
      args: ["cd /src && npm ci"]

  - name: npm-lint
    inputs:
      artifacts:
      - name: source
        path: /src
    container:
      image: node:16
      command: [sh, -c]
      args: ["cd /src && npm run lint"]

  - name: npm-build
    inputs:
      artifacts:
      - name: source
        path: /src
    container:
      image: node:16
      command: [sh, -c]
      args: ["cd /src && npm run build"]
    outputs:
      artifacts:
      - name: dist
        path: /src/dist

  - name: npm-test
    inputs:
      parameters:
      - name: test-type
      artifacts:
      - name: source
        path: /src
    container:
      image: node:16
      command: [sh, -c]
      args: ["cd /src && npm run test:{{inputs.parameters.test-type}}"]

  - name: trivy-scan
    inputs:
      artifacts:
      - name: source
        path: /src
    container:
      image: aquasec/trivy:latest
      command: [trivy]
      args: ["fs", "--severity", "HIGH,CRITICAL", "/src"]

  - name: docker-build
    inputs:
      parameters:
      - name: image-tag
      artifacts:
      - name: build-output
        path: /workspace
    container:
      image: gcr.io/kaniko-project/executor:latest
      command: [/kaniko/executor]
      args:
        - "--dockerfile=/workspace/Dockerfile"
        - "--context=/workspace"
        - "--destination={{inputs.parameters.image-tag}}"
    outputs:
      parameters:
      - name: image-name
        value: "{{inputs.parameters.image-tag}}"

  - name: kubectl-deploy
    inputs:
      parameters:
      - name: environment
      - name: image
    resource:
      action: apply
      manifest: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: myapp
          namespace: {{inputs.parameters.environment}}
        spec:
          replicas: 3
          selector:
            matchLabels:
              app: myapp
          template:
            metadata:
              labels:
                app: myapp
            spec:
              containers:
              - name: myapp
                image: {{inputs.parameters.image}}
                ports:
                - containerPort: 8080

  - name: verify-deployment
    inputs:
      parameters:
      - name: environment
    container:
      image: bitnami/kubectl:latest
      command: [sh, -c]
      args:
        - |
          kubectl rollout status deployment/myapp -n {{inputs.parameters.environment}}

  - name: run-smoke-tests
    inputs:
      parameters:
      - name: environment
    container:
      image: curlimages/curl:latest
      command: [sh, -c]
      args:
        - |
          curl -f http://myapp.{{inputs.parameters.environment}}.svc.cluster.local:8080/health
```

## Study Resources

- [CI/CD with Argo Workflows](https://argo-workflows.readthedocs.io/en/latest/use-cases/ci-cd/) - Use cases documentation
- [WorkflowTemplates](https://argoproj.github.io/argo-workflows/workflow-templates/) - Template reference
- [CronWorkflows](https://argoproj.github.io/argo-workflows/cron-workflows/) - Scheduled workflows guide
- [Triggering Workflows](https://argoproj.github.io/argo-workflows/rest-api/) - API documentation

## Key Points to Remember

- WorkflowTemplates are namespace-scoped and reusable workflow definitions
- ClusterWorkflowTemplates are cluster-scoped and available across all namespaces
- CronWorkflows schedule recurring workflow executions using cron syntax
- Concurrency policies control how overlapping executions are handled
- Workflows can be triggered via CLI, Kubernetes API, HTTP API, or events
- Use `suspend` templates for manual approval gates in pipelines
- `workflowTemplateRef` references a template for instantiation
- `templateRef` references a specific template within a WorkflowTemplate
- CronWorkflows support timezone configuration
- Use `successfulJobsHistoryLimit` and `failedJobsHistoryLimit` to manage history
- Suspend CronWorkflows to temporarily disable scheduled executions
- DAG workflows are ideal for complex CI/CD pipelines with parallel stages
- Argo Events can trigger workflows based on external events
- Artifact repositories are essential for passing build artifacts between stages
- Resource templates enable Kubernetes resource management within workflows

## Hands-On Practice

- [Lab 05: Workflow Templates](../../labs/02-argo-workflows/lab-05-workflow-templates.md) - Build a complete CI/CD pipeline with WorkflowTemplates, implement scheduled workflows with CronWorkflows, and integrate with external systems
