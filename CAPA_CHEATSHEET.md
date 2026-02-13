# CAPA Exam Cheatsheet & Study Guide

> Quick Reference for Certified Argo Project Associate

**Version**: v2.0.0 | **Validated**: 2026-02-05 against Argo CD v3.3.0, Argo Workflows v3.7.9, Argo Rollouts v1.8.3, Argo Events v1.9.10 | **Key Points Extracted**: 2026-02-13

## Table of Contents

1. [Argo Workflows - Workflow Engine (36%)](#argo-workflows)
2. [Argo CD - Continuous Delivery (34%)](#argo-cd)
3. [Argo Rollouts - Progressive Delivery (18%)](#argo-rollouts)
4. [Argo Events - Event Automation (12%)](#argo-events)
5. [Essential Commands](#essential-commands)
6. [Quick Reference Tables](#quick-reference-tables)
7. [Common Patterns & Best Practices](#common-patterns--best-practices)
8. [Exam Tips](#exam-tips)

---

## Argo CD

<details>
<summary><strong>Key Concepts Summary</strong></summary>

### Application Management

*Source: [domains/01-argo-cd/application-management.md](domains/01-argo-cd/application-management.md)*

- Applications can be created via UI, CLI, or declaratively using YAML
- Declarative approach is preferred for GitOps and version control
- App-of-Apps pattern manages multiple applications as a single unit
- Repository credentials can be stored as Secrets with label `argocd.argoproj.io/secret-type: repository`
- Repository credential templates allow reusing credentials for multiple repos
- Projects provide logical grouping and RBAC for applications
- Projects can restrict source repos, destinations, and resource types
- ApplicationSets automate application generation using templates and generators
- Common ApplicationSet generators: List, Git Directory, Git File, Cluster, Matrix
- Matrix generator combines multiple generators for complex scenarios
- Applications require finalizers for proper resource cleanup
- Source can be Git repository or Helm chart
- Destination specifies target cluster and namespace
- Multiple sources can be used for advanced scenarios (e.g., separating values)

### Core Concepts

*Source: [domains/01-argo-cd/core-concepts.md](domains/01-argo-cd/core-concepts.md)*

- Argo CD consists of three main components: API Server, Repository Server, and Application Controller
- The API Server handles all API operations, authentication, and serves the Web UI
- The Repository Server clones Git repositories and generates Kubernetes manifests
- The Application Controller monitors applications and ensures desired state matches live state
- GitOps principles: Declarative, Version Controlled, Automated, Continuously Reconciled
- The Application CRD is the core resource defining what to deploy and where
- Sync Status indicates if live state matches desired state (Synced/OutOfSync/Unknown)
- Health Status indicates operational health (Healthy/Progressing/Degraded/Suspended/Missing/Unknown)
- Applications require source (Git repo) and destination (cluster + namespace) configuration
- Default reconciliation interval is 3 minutes (polling Git and cluster state)
- Argo CD supports multiple manifest formats: plain YAML, Helm, Kustomize, Jsonnet
- Sync waves control the order of resource deployment using annotations
- Resource hooks (PreSync, Sync, PostSync, SyncFail) enable custom actions during sync
- The `resources-finalizer.argocd.argoproj.io` finalizer ensures proper resource cleanup
- Applications can use automated sync policies with prune and self-heal capabilities

### Installation and Configuration

*Source: [domains/01-argo-cd/installation-configuration.md](domains/01-argo-cd/installation-configuration.md)*

- Argo CD can be installed using kubectl (non-HA/HA), Helm, or Operator
- Non-HA installation is for development/testing; HA is for production
- Initial admin password is stored in `argocd-initial-admin-secret`
- CLI can be installed on Linux, macOS, and Windows
- Port forwarding provides quick access: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
- Argo CD can be exposed via LoadBalancer, Ingress, or OpenShift Route
- Main configuration is stored in `argocd-cm` ConfigMap
- Command parameters are in `argocd-cmd-params-cm` ConfigMap
- RBAC policies are configured in `argocd-rbac-cm` ConfigMap
- Helm installation provides most flexibility with values.YAML
- Default namespace is `argocd` but can be changed
- High Availability requires Redis HA and multiple replicas
- SSL/TLS can be terminated at ingress or passed through to Argo CD
- Resource limits and requests should be configured for production
- Argo CD UI provides visual interface for all operations

### Multi-Cluster Management

*Source: [domains/01-argo-cd/multi-cluster.md](domains/01-argo-cd/multi-cluster.md)*

- Argo CD can manage applications in local (in-cluster) and external clusters
- External clusters registered via `argocd cluster add` command
- Cluster registration creates ServiceAccount and RBAC in target cluster
- Cluster credentials stored as Secrets with label `argocd.argoproj.io/secret-type: cluster`
- Cluster Secret contains server URL, name, and config (token, certificates)
- In-cluster uses `https://kubernetes.default.svc` as server URL
- Cloud-managed clusters (EKS, GKE, AKS) require exec provider config
- Cluster labels enable targeted deployments with ApplicationSets
- ApplicationSet cluster generator creates apps for matching clusters
- Matrix generator combines cluster generator with others for complex scenarios
- Hub-and-spoke architecture: central Argo CD manages multiple spoke clusters
- Progressive rollout deploys to clusters sequentially
- Cluster namespaces can be restricted in cluster Secret
- Remove clusters with `argocd cluster rm` command
- Cluster credentials should be rotated periodically for security

### RBAC and Security

*Source: [domains/01-argo-cd/rbac-security.md](domains/01-argo-cd/rbac-security.md)*

- RBAC policies configured in `argocd-rbac-cm` ConfigMap
- Policy format: `p, subject, resource, action, object, effect`
- Resources: applications, clusters, repositories, projects, accounts
- Actions: get, create, update, delete, sync, override, action/*
- Group bindings map users/groups to roles using `g, user/group, role`
- Default policy applies to all authenticated users
- Dex enables SSO with multiple identity providers
- Direct OIDC integration available without Dex
- Local users defined in `argocd-cm` with `accounts.<name>` fields
- API tokens generated per account with optional expiration
- Repository credentials stored as Secrets with label `argocd.argoproj.io/secret-type: repository`
- Cluster credentials stored as Secrets with label `argocd.argoproj.io/secret-type: cluster`
- Webhook secrets configured for GitHub, GitLab, and Bitbucket
- External Secrets Operator can manage Argo CD secrets
- RBAC scopes control which claims are used for group mapping

### Sync Strategies

*Source: [domains/01-argo-cd/sync-strategies.md](domains/01-argo-cd/sync-strategies.md)*

- Manual sync requires explicit user action; automated sync happens automatically
- Prune deletes resources removed from Git; without prune, resources persist
- Self-heal reverts manual cluster changes within 5 seconds
- Sync options provide fine-grained control over sync behavior
- CreateNamespace=true automatically creates target namespace
- PruneLast=true prunes resources after all others are healthy
- ServerSideApply=true recommended for CRDs and large resources
- Sync waves control deployment order using annotations (lower first)
- Default sync wave is 0; can be negative
- Argo CD waits for wave N to be healthy before starting wave N+1
- Hooks execute at specific sync phases: PreSync, Sync, PostSync, SyncFail
- Hook deletion policies control when hook resources are removed
- PreSync hooks run before applying manifests (e.g., migrations)
- PostSync hooks run after successful sync (e.g., tests, warm-up)
- SyncFail hooks run when sync fails (e.g., notifications, cleanup)
- Retry strategy configures backoff for failed syncs

</details>

<details>
<summary><strong>Core Architecture & Components</strong></summary>

### Main Components

- **API Server**: Exposes API/UI, handles auth/RBAC, manages applications, listens to webhooks (Port 8080/8443)
- **Repository Server**: Clones Git repos, generates manifests (YAML/Helm/Kustomize/Jsonnet), caches data
- **Application Controller**: Monitors apps, compares live vs desired state, triggers syncs, reconciles every 3 minutes
- **Redis**: Caching and queuing operations
- **Dex** (optional): SSO/OAuth2/OIDC integration

### GitOps Principles

1. **Declarative**: Entire system state described declaratively
2. **Version Controlled**: All config stored in Git with audit trail
3. **Automated**: Argo CD automatically applies changes
4. **Continuous Reconciliation**: Detect and correct drift

</details>

<details>
<summary><strong>Application CRD</strong></summary>

### Basic Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/example/repo.git
    targetRevision: main
    path: kubernetes/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - Validate=true
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Key Fields

- **source**: Git repo URL, revision, path, and tool-specific config (Helm/Kustomize)
- **destination**: Target cluster and namespace
- **syncPolicy**: Automated sync, prune, self-heal settings
- **project**: Logical grouping for RBAC

### Multiple Sources (Advanced)

```yaml
sources:
  - repoURL: https://github.com/example/app.git
    path: helm
    helm:
      valueFiles:
        - $values/values-prod.yaml
  - repoURL: https://github.com/example/config.git
    targetRevision: main
    ref: values
```

</details>

<details>
<summary><strong>Sync Status & Health Status</strong></summary>

### Sync Status (Live vs Desired)

- **Synced**: Live state matches Git
- **OutOfSync**: Differences detected (new commits, manual changes, drift)
- **Unknown**: Unable to determine (cluster unreachable, parsing errors)

### Health Status (Operational State)

- **Healthy**: Running correctly, ready to serve
- **Progressing**: Being deployed/updated
- **Degraded**: Running with issues, some replicas not ready
- **Suspended**: Intentionally paused (0 replicas)
- **Missing**: Expected resources not present
- **Unknown**: Cannot determine health

</details>

<details>
<summary><strong>Sync Policies & Options</strong></summary>

### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true       # Delete resources removed from Git
    selfHeal: true    # Revert manual changes (5s delay)
    allowEmpty: false # Prevent deleting all resources
```

### Sync Options

```yaml
syncOptions:
  - Validate=true                      # Validate against K8s API
  - CreateNamespace=true               # Auto-create namespace
  - PrunePropagationPolicy=foreground  # Delete dependents first
  - PruneLast=true                     # Prune after all synced
  - ApplyOutOfSyncOnly=true            # Only apply changed resources
  - ServerSideApply=true               # Use server-side apply
  - RespectIgnoreDifferences=true      # Honor ignore rules
```

### Prune Propagation Policies

- **foreground**: Delete dependents before owner (recommended)
- **background**: Delete owner immediately, dependents async
- **orphan**: Delete owner, leave dependents

</details>

<details>
<summary><strong>Sync Waves & Hooks</strong></summary>

### Sync Waves (Deployment Order)

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Lower = deployed first
```

**Example Order**:

- Wave -1: Pre-deployment jobs
- Wave 0: ConfigMaps, Secrets, Namespaces
- Wave 1: Databases, StatefulSets
- Wave 2: Backend services
- Wave 3: Frontend applications
- Wave 4: Ingress/Routes
- Wave 5: Post-deployment verification

### Resource Hooks

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync  # PreSync, Sync, PostSync, SyncFail, Skip
    argocd.argoproj.io/hook-delete-policy: HookSucceeded  # Delete after success
    argocd.argoproj.io/sync-wave: "1"
```

**Hook Types**:

- **PreSync**: Before sync (e.g., DB migrations)
- **Sync**: During sync
- **PostSync**: After sync (e.g., tests, warmup)
- **SyncFail**: On failure (e.g., notifications)
- **Skip**: Skip this resource

**Delete Policies**:

- `HookSucceeded`: Delete after success
- `HookFailed`: Delete after failure
- `BeforeHookCreation`: Delete before creating new

</details>

<details>
<summary><strong>Projects (AppProject)</strong></summary>

### Project Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications
  sourceRepos:
    - 'https://github.com/myorg/*'
    - 'https://charts.bitnami.com/bitnami'
  destinations:
    - namespace: production
      server: https://kubernetes.default.svc
    - namespace: monitoring
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
  syncWindows:
    - kind: allow
      schedule: '0 9 * * 1-5'  # Weekdays 9 AM
      duration: 8h
      manualSync: true
```

### Key Features

- **sourceRepos**: Allowed Git repos
- **destinations**: Allowed clusters/namespaces
- **clusterResourceWhitelist**: Allowed cluster-scoped resources
- **namespaceResourceWhitelist**: Allowed namespaced resources
- **syncWindows**: Time-based sync restrictions

</details>

<details>
<summary><strong>ApplicationSets</strong></summary>

### List Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
spec:
  generators:
    - list:
        elements:
          - cluster: production
            url: https://prod-cluster.example.com
          - cluster: staging
            url: https://staging-cluster.example.com
  template:
    metadata:
      name: '{{cluster}}-myapp'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/app.git
        path: kubernetes
      destination:
        server: '{{url}}'
        namespace: myapp
```

### Git Directory Generator

```yaml
generators:
  - git:
      repoURL: https://github.com/example/apps.git
      revision: main
      directories:
        - path: apps/*
template:
  metadata:
    name: '{{path.basename}}'
  spec:
    source:
      path: '{{path}}'
```

### Cluster Generator

```yaml
generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
template:
  metadata:
    name: '{{name}}-guestbook'
  spec:
    destination:
      server: '{{server}}'
```

### Matrix Generator (Combine Multiple)

```yaml
generators:
  - matrix:
      generators:
        - git:
            directories:
              - path: apps/*
        - list:
            elements:
              - env: prod
              - env: staging
template:
  metadata:
    name: '{{path.basename}}-{{env}}'
```

</details>

<details>
<summary><strong>App-of-Apps Pattern</strong></summary>

### Parent Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/apps.git
    path: apps  # Directory containing child app definitions
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Repository Structure

```
apps/
├── app-of-apps.yaml
└── apps/
    ├── frontend.yaml
    ├── backend.yaml
    └── database.yaml
```

</details>

<details>
<summary><strong>Repository Management</strong></summary>

### Repository Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/example/private-repo.git
  username: myuser
  password: mytoken
```

### SSH Repository

```yaml
stringData:
  type: git
  url: git@github.com:example/repo.git
  sshPrivateKey: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----
```

### Credential Template (Reuse for Multiple Repos)

```yaml
labels:
  argocd.argoproj.io/secret-type: repo-creds
stringData:
  url: https://github.com/example  # URL prefix
  username: myuser
  password: mytoken
```

</details>

---

## Argo Workflows

<details>
<summary><strong>Key Concepts Summary</strong></summary>

### CI/CD Integration

*Source: [domains/02-argo-workflows/cicd-integration.md](domains/02-argo-workflows/cicd-integration.md)*

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

### DAG and Parallel Execution

*Source: [domains/02-argo-workflows/dag-parallel.md](domains/02-argo-workflows/dag-parallel.md)*

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

### Templates and Steps

*Source: [domains/02-argo-workflows/templates-steps.md](domains/02-argo-workflows/templates-steps.md)*

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

### Variables and Artifacts

*Source: [domains/02-argo-workflows/variables-artifacts.md](domains/02-argo-workflows/variables-artifacts.md)*

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

### Workflow Fundamentals

*Source: [domains/02-argo-workflows/workflow-fundamentals.md](domains/02-argo-workflows/workflow-fundamentals.md)*

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

</details>

<details>
<summary><strong>Workflow CRD Structure</strong></summary>

### Basic Workflow

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-world-
  namespace: argo
spec:
  entrypoint: main
  serviceAccountName: argo-workflow
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

### Key Fields

- **entrypoint**: Starting template name (required)
- **templates**: Array of template definitions
- **arguments**: Input parameters/artifacts
- **serviceAccountName**: K8s service account
- **ttlStrategy**: Cleanup after completion
- **activeDeadlineSeconds**: Max workflow duration
- **podGC**: Pod garbage collection strategy

</details>

<details>
<summary><strong>Workflow Phases</strong></summary>

1. **Pending**: Created but not started
2. **Running**: Currently executing
3. **Succeeded**: Completed successfully
4. **Failed**: Failed with errors
5. **Error**: System error encountered
6. **Skipped**: Skipped (conditional)
7. **Omitted**: Omitted (conditional logic)

</details>

<details>
<summary><strong>Template Types</strong></summary>

### Container Template

```yaml
- name: container-task
  inputs:
    parameters:
    - name: message
  container:
    image: alpine:latest
    command: [echo]
    args: ["{{inputs.parameters.message}}"]
```

### Script Template

```yaml
- name: script-task
  script:
    image: python:3.9
    command: [python]
    source: |
      print("Hello from Python")
      import sys
      sys.exit(0)
```

### Resource Template (Create K8s Resources)

```yaml
- name: create-resource
  resource:
    action: create
    manifest: |
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: my-config
      data:
        key: value
```

### Steps Template (Sequential/Parallel)

```yaml
- name: steps-example
  steps:
  - - name: step1        # Sequential
      template: task1
  - - name: step2a       # Parallel
      template: task2
    - name: step2b
      template: task2
  - - name: step3        # Sequential
      template: task3
```

### DAG Template

```yaml
- name: dag-example
  dag:
    tasks:
    - name: task-a
      template: work
    - name: task-b
      dependencies: [task-a]
      template: work
    - name: task-c
      dependencies: [task-a]
      template: work
    - name: task-d
      dependencies: [task-b, task-c]
      template: work
```

</details>

<details>
<summary><strong>Parameters & Artifacts</strong></summary>

### Parameters

```yaml
# Workflow-level parameters
arguments:
  parameters:
  - name: message
    value: "default"

# Template inputs
inputs:
  parameters:
  - name: message

# Using parameters
args: ["{{inputs.parameters.message}}"]
args: ["{{workflow.parameters.message}}"]

# Passing between templates
arguments:
  parameters:
  - name: result
    value: "{{tasks.previous.outputs.result}}"
```

### Artifacts

```yaml
# Input artifacts
inputs:
  artifacts:
  - name: source-code
    path: /src
    git:
      repo: https://github.com/example/repo.git
      revision: main

# Output artifacts
outputs:
  artifacts:
  - name: build-output
    path: /output/result.txt
    s3:
      endpoint: s3.amazonaws.com
      bucket: my-bucket
      key: result.txt

# Artifact repository (ConfigMap)
data:
  artifactRepository: |
    s3:
      bucket: my-bucket
      endpoint: s3.amazonaws.com
      accessKeySecret:
        name: my-s3-credentials
        key: accessKey
      secretKeySecret:
        name: my-s3-credentials
        key: secretKey
```

</details>

<details>
<summary><strong>Common Patterns</strong></summary>

### Sequential Execution

```yaml
templates:
- name: sequential
  steps:
  - - name: step1
      template: task
  - - name: step2
      template: task
  - - name: step3
      template: task
```

### Parallel Execution

```yaml
- name: parallel
  steps:
  - - name: task1
      template: task
    - name: task2
      template: task
    - name: task3
      template: task
```

### Conditional Execution

```yaml
- name: conditional
  steps:
  - - name: check
      template: check-env
  - - name: prod-deploy
      template: deploy
      when: "{{workflow.parameters.env}} == production"
```

### Loops (withItems)

```yaml
- name: loop
  steps:
  - - name: process
      template: process-item
      arguments:
        parameters:
        - name: item
          value: "{{item}}"
      withItems:
      - apple
      - banana
      - cherry
```

### Retry Strategy

```yaml
- name: retry-task
  retryStrategy:
    limit: "3"
    retryPolicy: "Always"  # Always, OnFailure, OnError, OnTransientError
    backoff:
      duration: "10s"
      factor: 2
      maxDuration: "1m"
  container:
    image: task:latest
```

</details>

<details>
<summary><strong>WorkflowTemplate & ClusterWorkflowTemplate</strong></summary>

### WorkflowTemplate (Namespace-scoped)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: build-template
  namespace: argo
spec:
  entrypoint: build
  templates:
  - name: build
    container:
      image: builder:latest
      command: [build]
```

### Using WorkflowTemplate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: use-template-
spec:
  workflowTemplateRef:
    name: build-template
```

### ClusterWorkflowTemplate (Cluster-wide)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ClusterWorkflowTemplate
metadata:
  name: cluster-build-template
spec:
  entrypoint: build
  templates:
  - name: build
    container:
      image: builder:latest
```

</details>

<details>
<summary><strong>CronWorkflow</strong></summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: nightly-backup
  namespace: argo
spec:
  schedule: "0 2 * * *"  # Every day at 2 AM
  timezone: "America/New_York"
  concurrencyPolicy: "Replace"  # Allow, Forbid, Replace
  startingDeadlineSeconds: 0
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  suspend: false
  workflowSpec:
    entrypoint: backup
    templates:
    - name: backup
      container:
        image: backup-tool:latest
        command: [backup]
```

</details>

---

## Argo Rollouts

<details>
<summary><strong>Key Concepts Summary</strong></summary>

### Analysis and Metrics

*Source: [domains/03-argo-rollouts/analysis-metrics.md](domains/03-argo-rollouts/analysis-metrics.md)*

- AnalysisTemplates define reusable metric queries and validation logic
- Multiple metric providers supported: Prometheus, Datadog, CloudWatch, New Relic, etc.
- Success/failure conditions use expression language for flexibility
- AnalysisRuns are instances created from templates during rollouts
- Background analysis runs throughout canary deployment
- Step-level analysis acts as validation gates
- Failure limits and inconclusive limits prevent flaky metric failures
- Initial delay allows time for metrics to stabilize
- Count parameter limits number of measurements
- Analysis failures trigger automatic rollback
- Templates can accept arguments for reusability
- Multiple metrics in single template for comprehensive validation
- Web provider enables custom metric sources via HTTP

### Blue-Green Deployments

*Source: [domains/03-argo-rollouts/blue-green.md](domains/03-argo-rollouts/blue-green.md)*

- Blue-Green requires two services: active (production) and preview (testing)
- Argo Rollouts controller automatically manages service selector updates
- Promotion switches all traffic instantly from old to new version
- AutoPromotionEnabled controls whether promotion happens automatically
- ScaleDownDelaySeconds provides a rollback window before removing old version
- Abort command immediately reverts to stable version
- Preview service allows testing new version before production promotion
- Blue-Green uses more resources as it runs two full environments
- Zero-downtime deployments with instant rollback capability
- Ideal for applications requiring thorough validation before release

### Canary Deployments

*Source: [domains/03-argo-rollouts/canary.md](domains/03-argo-rollouts/canary.md)*

- Canary deployments gradually shift traffic from old to new version
- Traffic weight controls percentage of requests to canary version
- Steps define the progression: setWeight, pause, analysis
- Pause duration can be time-based or indefinite (manual gate)
- Traffic routing requires ingress controller or service mesh integration
- Automated promotion based on analysis results
- Analysis failures trigger automatic rollback
- MaxSurge and MaxUnavailable control pod scaling during rollout
- SetCanaryScale provides fine-grained replica control
- Canary uses less resources than Blue-Green (no full duplication)
- Suitable for gradual validation with real user traffic
- Multiple validation gates reduce deployment risk

</details>

<details>
<summary><strong>Rollout vs Deployment</strong></summary>

| Feature | Deployment | Rollout |
|---------|-----------|---------|
| Update Strategy | Rolling update only | Blue-Green, Canary, Progressive |
| Traffic Control | No | Yes (ingress/service mesh) |
| Analysis | No | Yes (metrics-based) |
| Automated Rollback | No | Yes (based on metrics) |
| Manual Promotion | No | Yes |
| Pause/Resume | No | Yes |
| Weighted Traffic | No | Yes |
| Preview Environments | No | Yes (Blue-Green) |

</details>

<details>
<summary><strong>Rollout Resource</strong></summary>

### Basic Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 5
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-app:v1
        ports:
        - containerPort: 8080
  strategy:
    # canary or blueGreen
```

### Rollout Status Phases

- **Healthy**: Running and healthy
- **Progressing**: Currently transitioning
- **Degraded**: Not healthy
- **Paused**: Manually or automatically paused
- **Unknown**: Cannot determine status

</details>

<details>
<summary><strong>Blue-Green Strategy</strong></summary>

### Configuration

```yaml
strategy:
  blueGreen:
    activeService: my-app-active     # Current production
    previewService: my-app-preview   # New version preview
    autoPromotionEnabled: false      # Manual promotion
    scaleDownDelaySeconds: 30        # Delay before scaling down
    prePromotionAnalysis:            # Run before promotion
      templates:
      - templateName: smoke-tests
    postPromotionAnalysis:           # Run after promotion
      templates:
      - templateName: load-tests
```

### Services

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-active
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-preview
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

### Workflow

1. Deploy new version (green)
2. Preview service routes to green
3. Run pre-promotion analysis
4. Manual/auto promotion
5. Active service switches to green
6. Run post-promotion analysis
7. Scale down blue after delay

</details>

<details>
<summary><strong>Canary Strategy</strong></summary>

### Basic Canary

```yaml
strategy:
  canary:
    steps:
    - setWeight: 10          # 10% traffic to canary
    - pause: {duration: 2m}  # Wait 2 minutes
    - setWeight: 30          # 30% traffic
    - pause: {duration: 2m}
    - setWeight: 60          # 60% traffic
    - pause: {duration: 2m}
    # Final implicit step: 100%
```

### With Analysis

```yaml
strategy:
  canary:
    steps:
    - setWeight: 20
    - pause: {duration: 1m}
    - analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: my-app
    - setWeight: 50
    - pause: {duration: 2m}
```

### Manual Approval (Indefinite Pause)

```yaml
steps:
- setWeight: 30
- pause: {}  # Manual promotion required
- setWeight: 60
```

### Background Analysis (Continuous)

```yaml
strategy:
  canary:
    analysis:
      templates:
      - templateName: error-rate
      startingStep: 1  # Start from step 1
      args:
      - name: service-name
        value: my-app
    steps:
    - setWeight: 20
    - pause: {duration: 2m}
```

</details>

<details>
<summary><strong>AnalysisTemplate</strong></summary>

### Prometheus Metrics

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 30s
    count: 5
    successCondition: result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          sum(rate(
            http_requests_total{service="{{args.service-name}}",status=~"2.."}[1m]
          )) /
          sum(rate(
            http_requests_total{service="{{args.service-name}}"}[1m]
          ))
```

### Multiple Metrics

```yaml
spec:
  metrics:
  - name: success-rate
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        query: ...
  - name: avg-latency
    successCondition: result[0] <= 500
    provider:
      prometheus:
        query: ...
```

### Metric Providers

- **Prometheus**: Query Prometheus metrics
- **Datadog**: Query Datadog metrics
- **Wavefront**: Query Wavefront metrics
- **NewRelic**: Query New Relic metrics
- **CloudWatch**: Query AWS CloudWatch
- **Graphite**: Query Graphite metrics
- **Web**: Call HTTP endpoints
- **Job**: Run Kubernetes Job

</details>

<details>
<summary><strong>Traffic Management</strong></summary>

### NGINX Ingress

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  strategy:
    canary:
      canaryService: my-app-canary
      stableService: my-app-stable
      trafficRouting:
        nginx:
          stableIngress: my-app
          annotationPrefix: nginx.ingress.kubernetes.io
      steps:
      - setWeight: 20
      - pause: {duration: 1m}
```

### AWS ALB

```yaml
trafficRouting:
  alb:
    ingress: my-app
    servicePort: 80
```

### Istio

```yaml
trafficRouting:
  istio:
    virtualService:
      name: my-app
      routes:
      - primary
```

### SMI (Service Mesh Interface)

```yaml
trafficRouting:
  smi:
    trafficSplitName: my-app-split
    rootService: my-app
```

</details>

---

## Argo Events

<details>
<summary><strong>Key Concepts Summary</strong></summary>

### Triggers and Actions

*Source: [domains/04-argo-events/triggers-actions.md](domains/04-argo-events/triggers-actions.md)*

- Triggers define what actions to execute when event dependencies are satisfied
- Argo Workflow trigger (argoWorkflow) is a specialized trigger for submitting workflows
- Kubernetes resource trigger (k8s) can create, update, or patch any Kubernetes resource
- HTTP triggers enable integration with external REST APIs and webhooks
- Multiple triggers can be executed for a single event or set of events
- Event data can be extracted and passed to triggers using templates like `{{.Input.body.field}}`
- Trigger conditions allow conditional execution based on event data
- Triggers support retry strategies for handling transient failures
- Parameters can be used to make triggers reusable and flexible
- WorkflowTemplates can be referenced instead of defining workflows inline
- Trigger operations include create, update, patch for K8s resources; submit for workflows
- Data transformation can be applied using dataTemplate or JQ filters
- Slack, Kafka, NATS, and other integrations are supported as first-class trigger types
- Triggers execute in parallel by default unless dependencies are chained
- Log triggers are useful for debugging event flow

</details>

<details>
<summary><strong>Core Components</strong></summary>

### Architecture

1. **EventSource**: Captures events from external sources
2. **Event Bus**: Message bus (NATS/JetStream) connecting sources to sensors
3. **Sensor**: Listens to events, defines dependencies, triggers actions

### Event Flow

```
External System → EventSource → Event Bus → Sensor → Trigger Action
```

</details>

<details>
<summary><strong>EventSource CRD</strong></summary>

### Webhook EventSource

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook
  namespace: argo-events
spec:
  service:
    ports:
    - port: 12000
      targetPort: 12000
  webhook:
    example:
      port: "12000"
      endpoint: /example
      method: POST
```

### GitHub EventSource

```yaml
spec:
  github:
    example:
      owner: myorg
      repository: myrepo
      events:
        - push
        - pull_request
      webhook:
        endpoint: /push
        port: "12000"
        method: POST
      apiToken:
        name: github-access
        key: token
      webhookSecret:
        name: github-access
        key: secret
```

### Calendar EventSource (Scheduled)

```yaml
spec:
  calendar:
    daily-backup:
      schedule: "0 2 * * *"  # Every day at 2 AM
      timezone: UTC
      metadata:
        name: daily-backup
```

### Resource EventSource (Watch K8s Resources)

```yaml
spec:
  resource:
    deployment-events:
      namespace: production
      group: apps
      version: v1
      resource: deployments
      eventTypes:
        - ADD
        - UPDATE
        - DELETE
      filter:
        labels:
        - key: monitor
          operation: "=="
          value: "true"
```

### Kafka EventSource

```yaml
spec:
  kafka:
    example:
      url: kafka-broker.default.svc:9092
      topic: mytopic
      partition: "0"
      consumerGroup:
        groupName: argo-events-consumer
```

### Other Event Source Types

- **GitLab**, **Slack**, **AWS SNS/SQS**, **GCP Pub/Sub**
- **Azure Event Hubs**, **Redis**, **AMQP (RabbitMQ)**
- **NATS**, **File**, **HDFS**

</details>

<details>
<summary><strong>Sensor CRD</strong></summary>

### Basic Sensor

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-sensor
  namespace: argo-events
spec:
  dependencies:
  - name: webhook-dep
    eventSourceName: webhook
    eventName: example
  triggers:
  - template:
      name: workflow-trigger
      argoWorkflow:
        operation: submit
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: webhook-workflow-
            spec:
              entrypoint: main
              templates:
              - name: main
                container:
                  image: alpine:latest
                  command: [echo, "Event received"]
```

### Multi-Dependency Sensor

```yaml
dependencies:
- name: github-push
  eventSourceName: github
  eventName: push
  filters:
    data:
    - path: body.ref
      type: string
      value:
      - "refs/heads/main"
- name: approval
  eventSourceName: approval-webhook
  eventName: approved
```

### Event Data Extraction

```yaml
triggers:
- template:
    name: workflow-trigger
    argoWorkflow:
      operation: submit
      source:
        resource:
          spec:
            arguments:
              parameters:
              - name: repo-name
                value: "{{.Input.body.repository.name}}"
              - name: commit-sha
                value: "{{.Input.body.head_commit.id}}"
```

### Event Filtering

```yaml
dependencies:
- name: filtered-event
  eventSourceName: webhook
  eventName: example
  filters:
    data:
    - path: body.environment
      type: string
      value:
      - "production"
    - path: body.status
      type: string
      value:
      - "success"
```

### Event Transformation (JQ)

```yaml
dependencies:
- name: webhook-dep
  transform:
    jq: |
      {
        repository: .body.repository.name,
        branch: .body.ref | split("/") | .[-1],
        author: .body.head_commit.author.name
      }
```

</details>

<details>
<summary><strong>Trigger Types</strong></summary>

### Kubernetes Resource Trigger

```yaml
triggers:
- template:
    name: k8s-trigger
    k8s:
      operation: create
      source:
        resource:
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: event-config
          data:
            event: "received"
```

### Argo Workflow Trigger

```yaml
triggers:
- template:
    name: workflow-trigger
    argoWorkflow:
      operation: submit
      source:
        resource:
          # Workflow spec
```

### HTTP Trigger

```yaml
triggers:
- template:
    name: http-trigger
    http:
      url: https://api.example.com/notify
      method: POST
      payload:
      - src:
          dependencyName: webhook-dep
          dataKey: body.message
        dest: message
```

### Kafka Trigger

```yaml
triggers:
- template:
    name: kafka-trigger
    kafka:
      url: kafka-broker:9092
      topic: notifications
      payload:
      - src:
          dependencyName: webhook-dep
          dataKey: body
        dest: data
```

### Other Trigger Types

- **awsLambda**, **slack**, **nats**, **log**, **custom**

</details>

<details>
<summary><strong>Event Bus</strong></summary>

### NATS Event Bus

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    native:
      replicas: 3
      auth: token
```

### JetStream Event Bus

```yaml
spec:
  jetstream:
    version: "2.9.0"
    replicas: 3
    persistence:
      storageClassName: standard
      accessMode: ReadWriteOnce
      volumeSize: 10Gi
```

</details>

---

## Essential Commands

<details>
<summary><strong>Argo CD CLI</strong></summary>

### Login & Context

```bash
# Login
argocd login argocd-server.example.com --username admin --password password

# Change context
argocd context <context-name>
```

### Application Management

```bash
# Create application
argocd app create myapp \
  --repo https://github.com/example/repo.git \
  --path kubernetes/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production

# List applications
argocd app list

# Get application details
argocd app get myapp

# Sync application
argocd app sync myapp

# Sync and wait
argocd app sync myapp --wait

# Sync with prune
argocd app sync myapp --prune

# Sync specific resources
argocd app sync myapp --resource apps:Deployment:myapp

# Delete application
argocd app delete myapp

# Rollback
argocd app history myapp
argocd app rollback myapp <HISTORY_ID>

# Diff live vs desired
argocd app diff myapp

# View manifests
argocd app manifests myapp

# View logs
argocd app logs myapp

# Terminate sync operation
argocd app terminate-op myapp
```

### Application Settings

```bash
# Enable auto-sync
argocd app set myapp --sync-policy automated

# Enable auto-prune
argocd app set myapp --auto-prune

# Enable self-heal
argocd app set myapp --self-heal

# Set parameter
argocd app set myapp --parameter key=value
```

### Repository Management

```bash
# Add repository
argocd repo add https://github.com/example/repo.git \
  --username myuser \
  --password mytoken

# Add SSH repository
argocd repo add git@github.com:example/repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# List repositories
argocd repo list

# Remove repository
argocd repo rm https://github.com/example/repo.git
```

### Cluster Management

```bash
# Add cluster
argocd cluster add my-cluster-context

# List clusters
argocd cluster list

# Remove cluster
argocd cluster rm https://cluster-url
```

### Project Management

```bash
# Create project
argocd proj create myproject

# Add source repo to project
argocd proj add-source myproject https://github.com/example/repo.git

# Add destination
argocd proj add-destination myproject https://cluster-url namespace

# List projects
argocd proj list

# Get project details
argocd proj get myproject
```

</details>

<details>
<summary><strong>Argo Workflows CLI</strong></summary>

### Workflow Management

```bash
# Submit workflow
argo submit workflow.yaml

# Submit with parameters
argo submit workflow.yaml -p message="Hello World"

# Submit from WorkflowTemplate
argo submit --from workflowtemplate/my-template

# List workflows
argo list

# Get workflow details
argo get <workflow-name>

# Watch workflow
argo watch <workflow-name>

# View workflow logs
argo logs <workflow-name>

# Follow logs
argo logs <workflow-name> -f

# Get specific step logs
argo logs <workflow-name> <step-name>

# Delete workflow
argo delete <workflow-name>

# Terminate running workflow
argo terminate <workflow-name>

# Retry failed workflow
argo retry <workflow-name>

# Resubmit workflow
argo resubmit <workflow-name>

# Suspend workflow
argo suspend <workflow-name>

# Resume workflow
argo resume <workflow-name>
```

### WorkflowTemplate Management

```bash
# Create WorkflowTemplate
argo template create template.yaml

# List WorkflowTemplates
argo template list

# Get WorkflowTemplate
argo template get my-template

# Delete WorkflowTemplate
argo template delete my-template
```

### CronWorkflow Management

```bash
# Create CronWorkflow
argo cron create cronworkflow.yaml

# List CronWorkflows
argo cron list

# Get CronWorkflow
argo cron get my-cron

# Suspend CronWorkflow
argo cron suspend my-cron

# Resume CronWorkflow
argo cron resume my-cron

# Delete CronWorkflow
argo cron delete my-cron
```

</details>

<details>
<summary><strong>Argo Rollouts CLI</strong></summary>

### Rollout Management

```bash
# Get rollout status
kubectl argo rollouts get rollout my-app

# Watch rollout
kubectl argo rollouts get rollout my-app --watch

# List rollouts
kubectl argo rollouts list rollouts

# Promote to next step
kubectl argo rollouts promote my-app

# Promote fully (skip all steps)
kubectl argo rollouts promote my-app --full

# Abort rollout
kubectl argo rollouts abort my-app

# Pause rollout
kubectl argo rollouts pause my-app

# Continue paused rollout (use promote)
kubectl argo rollouts promote my-app

# Restart rollout (rolling restart)
kubectl argo rollouts restart my-app

# Undo rollout (rollback)
kubectl argo rollouts undo my-app

# Undo to specific revision
kubectl argo rollouts undo my-app --to-revision=3

# Set image
kubectl argo rollouts set image my-app my-container=new-image:v2
```

### Dashboard

```bash
# Start dashboard
kubectl argo rollouts dashboard

# Access at http://localhost:3100
```

</details>

<details>
<summary><strong>Kubectl for Argo Resources</strong></summary>

```bash
# Applications
kubectl get applications -n argocd
kubectl describe application myapp -n argocd
kubectl delete application myapp -n argocd

# Projects
kubectl get appprojects -n argocd

# ApplicationSets
kubectl get applicationsets -n argocd

# Workflows
kubectl get workflows -n argo
kubectl describe workflow my-workflow -n argo
kubectl logs <pod-name> -n argo

# Rollouts
kubectl get rollouts
kubectl describe rollout my-app

# EventSources
kubectl get eventsources -n argo-events

# Sensors
kubectl get sensors -n argo-events

# EventBus
kubectl get eventbus -n argo-events
```

</details>

---

## Quick Reference Tables

<details>
<summary><strong>Argo CD Sync Options</strong></summary>

| Option | Description | Values |
|--------|-------------|--------|
| Validate | Validate resources against K8s API | true/false |
| CreateNamespace | Auto-create namespace | true/false |
| PrunePropagationPolicy | Delete dependents first | foreground/background/orphan |
| PruneLast | Prune after all synced | true/false |
| ApplyOutOfSyncOnly | Only apply changed resources | true/false |
| ServerSideApply | Use server-side apply | true/false |
| Replace | Replace instead of apply | true/false |
| FailOnSharedResource | Fail if resource owned by another app | true/false |
| RespectIgnoreDifferences | Honor ignore rules | true/false |

</details>

<details>
<summary><strong>Argo Workflows Template Types</strong></summary>

| Type | Description | Use Case |
|------|-------------|----------|
| Container | Run container | Single task execution |
| Script | Run script | Python/Bash scripts |
| Resource | Create K8s resource | Dynamic resource creation |
| Steps | Sequential/parallel steps | Multi-stage pipelines |
| DAG | Directed acyclic graph | Complex dependencies |
| Suspend | Manual approval gate | Human approval |
| HTTP | HTTP request | API calls |
| Data | Data transformation | Data processing |

</details>

<details>
<summary><strong>Argo Rollouts Strategy Comparison</strong></summary>

| Feature | Blue-Green | Canary |
|---------|-----------|--------|
| Traffic Shift | Instant (0→100%) | Gradual (0→10→30→100%) |
| Resource Usage | 2x (both versions) | ~1.5x (partial canary) |
| Risk | Low (instant rollback) | Very Low (gradual validation) |
| Validation | Preview + Analysis | Progressive analysis |
| Rollback Speed | Instant | Quick |
| Complexity | Low | Medium |
| Best For | Major releases | Regular updates |

</details>

<details>
<summary><strong>Event Source Types</strong></summary>

| Type | Purpose | Example |
|------|---------|---------|
| Webhook | HTTP webhooks | GitHub, GitLab webhooks |
| Calendar | Time-based schedules | Daily backups |
| Resource | Watch K8s resources | Pod/Deployment changes |
| Kafka | Kafka messages | Message queue events |
| AWS SNS/SQS | AWS messages | Cloud notifications |
| GCP Pub/Sub | GCP messages | Cloud events |
| GitHub | GitHub events | Push, PR, Issues |
| GitLab | GitLab events | Merge requests |
| Slack | Slack events | Messages, commands |
| Redis | Redis Pub/Sub | Cache events |

</details>

---

## Common Patterns & Best Practices

<details>
<summary><strong>Argo CD Best Practices</strong></summary>

### Repository Organization

```
gitops-repo/
├── apps/
│   ├── production/
│   │   ├── app-of-apps.yaml
│   │   └── apps/
│   │       ├── frontend.yaml
│   │       └── backend.yaml
│   └── staging/
│       └── apps/
└── base/
    ├── frontend/
    └── backend/
```

### Application Structure

- Use App-of-Apps pattern for managing multiple apps
- Separate environment-specific configs (overlays)
- Use ApplicationSets for multi-cluster deployments
- Enable automated sync for dev/staging, manual for prod
- Use sync waves for ordered deployments
- Implement PreSync hooks for migrations
- Use PostSync hooks for verification

### Security

- Use Projects to isolate teams/environments
- Enable RBAC for fine-grained access control
- Store credentials in Kubernetes Secrets
- Use SSO for authentication
- Enable audit logging
- Use sealed secrets for sensitive data

### Sync Strategies

- Enable `prune: true` to maintain Git as source of truth
- Enable `selfHeal: true` for automatic drift correction
- Use `PruneLast: true` for blue-green patterns
- Use `CreateNamespace: true` for convenience
- Set appropriate retry strategies

</details>

<details>
<summary><strong>Argo Workflows Best Practices</strong></summary>

### Workflow Design

- Use WorkflowTemplates for reusability
- Use ClusterWorkflowTemplates for shared templates
- Break complex workflows into smaller templates
- Use DAG for complex dependencies
- Use Steps for sequential execution
- Implement retry strategies for flaky steps
- Set appropriate timeouts

### Resource Management

```yaml
resources:
  limits:
    memory: 256Mi
    cpu: 100m
  requests:
    memory: 128Mi
    cpu: 50m
```

### Artifact Management

- Configure artifact repository (S3, GCS, MinIO)
- Use volume claims for large artifacts
- Clean up artifacts after workflow completion
- Use artifact passing between steps

### Error Handling

- Implement retry strategies
- Use exit handlers for cleanup
- Monitor workflow failures
- Set appropriate backoff strategies

</details>

<details>
<summary><strong>Argo Rollouts Best Practices</strong></summary>

### Canary Strategy

- Start with small traffic percentages (5-10%)
- Use pause durations for observation
- Implement analysis at each step
- Monitor success rate, latency, error rate
- Use background analysis for continuous monitoring
- Set appropriate failure thresholds

### Blue-Green Strategy

- Use for major releases
- Always test preview service first
- Implement pre-promotion analysis
- Set appropriate scale-down delays
- Use post-promotion verification

### Analysis

```yaml
# Multiple metrics for comprehensive validation
metrics:
- name: success-rate
  successCondition: result[0] >= 0.95
- name: avg-latency
  successCondition: result[0] <= 500
- name: error-rate
  successCondition: result[0] <= 0.05
```

### Traffic Management

- Use ingress controller for traffic splitting
- Implement gradual traffic shift
- Monitor traffic distribution
- Use service mesh for advanced routing

</details>

<details>
<summary><strong>Argo Events Best Practices</strong></summary>

### EventSource Design

- Use separate EventSources for different event types
- Implement proper authentication (tokens, secrets)
- Use label selectors for resource watching
- Configure appropriate event filters

### Sensor Design

- Keep sensors focused (single responsibility)
- Use event filtering to reduce noise
- Implement proper error handling
- Use dependency filters for precise triggering
- Transform event data when needed

### Event Bus

- Use JetStream for persistence
- Configure appropriate replicas (3+ for HA)
- Set up proper resource limits
- Monitor event bus health

### Integration Patterns

```yaml
# GitHub → Workflow pattern
EventSource (GitHub) → Event Bus → Sensor → Argo Workflow

# Scheduled task pattern
EventSource (Calendar) → Event Bus → Sensor → K8s Job

# Resource watching pattern
EventSource (Resource) → Event Bus → Sensor → Notification
```

</details>

---

## Exam Tips

<details>
<summary><strong>Key Focus Areas by Domain</strong></summary>

### Argo CD (35%)

- Application CRD structure and fields
- Sync status vs Health status meanings
- Sync policies (prune, selfHeal, allowEmpty)
- Sync options and their effects
- Sync waves and execution order
- Resource hooks (PreSync, PostSync, SyncFail)
- Projects and RBAC
- App-of-Apps pattern
- ApplicationSet generators
- Repository credential management
- Multi-cluster management

### Argo Workflows (25%)

- Workflow CRD structure
- Template types and when to use each
- Steps vs DAG patterns
- Parameter and artifact passing
- Workflow phases and lifecycle
- WorkflowTemplate vs ClusterWorkflowTemplate
- CronWorkflow scheduling
- Retry strategies
- Conditional execution (when)
- Loop patterns (withItems)

### Argo Rollouts (25%)

- Rollout vs Deployment differences
- Blue-Green vs Canary strategies
- Rollout status phases
- Traffic splitting configuration
- AnalysisTemplate structure
- Metric providers (Prometheus, Datadog, etc.)
- Analysis success/failure conditions
- Traffic management (NGINX, ALB, Istio)
- Manual promotion and rollback
- Progressive delivery concepts

### Argo Events (15%)

- EventSource types and configuration
- Sensor dependencies and triggers
- Event Bus architecture (NATS)
- Event filtering and data extraction
- Trigger types (K8s, Workflow, HTTP)
- Integration with Argo Workflows
- Webhook automation patterns
- Calendar vs CronWorkflow comparison
- Resource watching patterns

</details>

<details>
<summary><strong>Common Pitfalls to Avoid</strong></summary>

### Argo CD

- Forgetting finalizers causes resources to not be deleted
- Not understanding difference between sync status and health status
- Confusing prune with selfHeal
- Incorrect sync wave ordering
- Missing namespace creation (use CreateNamespace=true)
- Not using PruneLast for blue-green patterns
- Incorrect hook deletion policies

### Argo Workflows

- Confusing workflow-level vs template-level parameters
- Not setting appropriate timeouts
- Forgetting artifact repository configuration
- Not understanding DAG dependency syntax
- Incorrect parameter syntax ({{inputs.}} vs {{workflow.}})
- Not cleaning up completed workflows (TTL)

### Argo Rollouts

- Using Rollout without appropriate traffic routing
- Not configuring services correctly for blue-green
- Missing canary/stable service definitions
- Incorrect analysis template conditions
- Not understanding traffic weight percentages
- Forgetting to configure ingress annotations

### Argo Events

- Not understanding EventSource vs Sensor separation
- Incorrect event dependency names
- Missing event bus configuration
- Incorrect event data extraction syntax
- Not configuring proper filters
- Confusing EventSource types

</details>

<details>
<summary><strong>Time Management</strong></summary>

### Exam Strategy

- Total time: 2 hours (120 minutes)
- Number of questions: ~60
- Time per question: ~2 minutes
- Don't spend too much time on one question
- Flag difficult questions and return later
- Review flagged questions before submitting

### Domain Time Allocation

- Argo CD (35%): ~42 minutes
- Argo Workflows (25%): ~30 minutes
- Argo Rollouts (25%): ~30 minutes
- Argo Events (15%): ~18 minutes

</details>

<details>
<summary><strong>Quick Memorization Tips</strong></summary>

### Argo CD Mnemonics

**SPADE** - Sync Status and Phases:

- **S**ynced, **P**rogressing, **A**vailable, **D**egraded, **E**rror

**PSH** - Sync Policy Options:

- **P**rune, **S**elfHeal, **H**ooks

**WAV** - Sync Waves:

- **W**aves control order, **A**nnotations define waves, **V**alues go low to high

### Argo Workflows Mnemonics

**STEP-DAG**:

- **S**equential: Steps, **T**asks: Templates, **E**ntrypoint required, **P**arameters pass data
- **D**AG for dependencies, **A**rtifacts for files, **G**enerators for loops

**PPP** - Workflow Phases:

- **P**ending → **P**rogressing → **P**assed/Failed

### Argo Rollouts Mnemonics

**BGC** - Strategies:

- **B**lue-**G**reen: Complete switch, **C**anary: Gradual shift

**STAMP** - Status:

- **S**tarted, **T**ransitioning, **A**nalyzing, **M**onitoring, **P**romoted

### Argo Events Mnemonics

**ESB-ST** - Event Flow:

- **E**ventSource → **S**ensor → **B**us → **S**ensor → **T**rigger

</details>

---

## Additional Resources

### Official Documentation

- [Argo CD Documentation](https://argo-cd.readthedocs.io/en/release-3.3/)
- [Argo Workflows Documentation](https://argo-workflows.readthedocs.io/en/release-3.7/)
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Argo Events Documentation](https://argoproj.github.io/argo-events/)

### Exam Information

- [CAPA Exam Details](https://training.linuxfoundation.org/certification/certified-argo-project-associate-capa/)
- [Exam Curriculum](https://github.com/cncf/curriculum)

### Practice Resources

- [Argo Examples Repository](https://github.com/argoproj/argocd-example-apps)
- [Argo Workflows Examples](https://github.com/argoproj/argo-workflows/tree/main/examples)
- [Killercoda Argo Scenarios](https://killercoda.com/argoproj)
