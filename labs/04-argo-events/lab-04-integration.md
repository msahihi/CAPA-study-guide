# Lab 04: End-to-End CI/CD Integration

**Duration**: 40 minutes

**Difficulty**: Advanced

## Learning Objectives

By the end of this lab, you will be able to:

- Integrate GitHub webhooks with Argo Events
- Build complete CI/CD pipelines with event-driven automation
- Trigger Argo Workflows from Git events
- Integrate Argo Events with Argo CD for deployments
- Implement multi-stage deployment pipelines
- Use event filtering for branch-based workflows
- Create approval workflows with multiple dependencies
- Monitor and troubleshoot end-to-end event flows

## Prerequisites

- Completed Labs 01, 02, and 03
- Argo Events, Argo Workflows, and Argo CD installed
- kubectl access to the cluster
- GitHub account (or GitLab/Gitea for alternatives)
- Understanding of Git workflows
- Basic knowledge of CI/CD concepts

## Lab Architecture

In this lab, you'll build:

```
GitHub Push Event
    ↓
GitHub EventSource (webhook)
    ↓
Event Bus
    ↓
Build Sensor → Argo Workflow (build & test)
    ↓
Test Results Event
    ↓
Deploy Sensor → Argo CD Application (sync)
    ↓
Deployment Complete
```

## Step 1: Setup GitHub EventSource

### Create GitHub Access Token Secret

For this lab, we'll simulate GitHub webhooks. In production, you would create a GitHub webhook pointing to your EventSource.

```bash
# Create a secret for GitHub token (can be dummy for this lab)
kubectl create secret generic github-access -n argo-events \
  --from-literal=token=dummy-token \
  --from-literal=secret=webhook-secret \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Create GitHub EventSource

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github-eventsource
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  github:
    myrepo:
      # Repository information
      owner: myorg
      repository: myapp
      # Webhook configuration
      webhook:
        endpoint: /github
        port: "12000"
        method: POST
        url: ""
      # Events to capture
      events:
        - push
        - pull_request
        - create
      # API token for GitHub API access
      apiToken:
        name: github-access
        key: token
      # Webhook secret for validation
      webhookSecret:
        name: github-access
        key: secret
      # Don't validate webhook signature in lab environment
      insecure: true
      # Activate webhook
      active: true
      contentType: json
EOF
```

### Verify GitHub EventSource

```bash
# Check EventSource
kubectl get eventsource github-eventsource -n argo-events

# View EventSource pods
kubectl get pods -n argo-events | grep github-eventsource

# Check logs
kubectl logs -n argo-events -l eventsource-name=github-eventsource --tail=20
```

## Step 2: Create Build Pipeline Workflow Template

First, let's create a WorkflowTemplate for our build pipeline.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ci-pipeline
  namespace: argo-events
spec:
  entrypoint: main
  arguments:
    parameters:
      - name: repo
      - name: branch
      - name: commit
      - name: author
      - name: message

  templates:
    - name: main
      dag:
        tasks:
          - name: checkout
            template: checkout-code

          - name: lint
            template: run-lint
            dependencies: [checkout]

          - name: test
            template: run-tests
            dependencies: [checkout]

          - name: build
            template: build-image
            dependencies: [lint, test]

          - name: scan
            template: security-scan
            dependencies: [build]

          - name: publish
            template: publish-artifacts
            dependencies: [scan]

    - name: checkout-code
      container:
        image: alpine/git:latest
        command: [sh, -c]
        args:
          - |
            echo "================================"
            echo "Checking out code"
            echo "Repository: {{workflow.parameters.repo}}"
            echo "Branch: {{workflow.parameters.branch}}"
            echo "Commit: {{workflow.parameters.commit}}"
            echo "Author: {{workflow.parameters.author}}"
            echo "Message: {{workflow.parameters.message}}"
            echo "================================"
            echo "Checkout complete"

    - name: run-lint
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Running linting checks..."
            sleep 2
            echo "✓ Code style check passed"
            echo "✓ Import check passed"
            echo "✓ Type check passed"
            echo "Linting complete!"

    - name: run-tests
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Running test suite..."
            sleep 3
            echo "✓ Unit tests: 45/45 passed"
            echo "✓ Integration tests: 12/12 passed"
            echo "✓ Code coverage: 87%"
            echo "All tests passed!"

    - name: build-image
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Building container image..."
            echo "Image: {{workflow.parameters.repo}}:{{workflow.parameters.commit}}"
            sleep 3
            echo "Build complete!"
            echo "Image size: 125MB"

    - name: security-scan
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Running security scan..."
            sleep 2
            echo "✓ CVE scan: No critical vulnerabilities"
            echo "✓ Secret scan: No secrets found"
            echo "✓ License check: All dependencies compliant"
            echo "Security scan passed!"

    - name: publish-artifacts
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Publishing artifacts..."
            echo "Image: {{workflow.parameters.repo}}:{{workflow.parameters.commit}}"
            echo "Tag: {{workflow.parameters.branch}}-latest"
            sleep 2
            echo "Artifacts published successfully!"
EOF
```

## Step 3: Create Build Sensor for GitHub Events

### Create Sensor for Push Events

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: github-build-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: github-push
      eventSourceName: github-eventsource
      eventName: myrepo
      # Filter for push events only
      filters:
        data:
          # Check event type is push
          - path: body.X-GitHub-Event
            type: string
            value:
              - "push"
          # Optional: filter specific branches
          - path: body.ref
            type: string
            value:
              - "refs/heads/main"
              - "refs/heads/develop"

  triggers:
    - template:
        name: trigger-ci-pipeline
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: ci-pipeline-
                namespace: argo-events
              spec:
                workflowTemplateRef:
                  name: ci-pipeline
                arguments:
                  parameters:
                    - name: repo
                      value: "{{.Input.body.repository.full_name}}"
                    - name: branch
                      value: "{{.Input.body.ref}}"
                    - name: commit
                      value: "{{.Input.body.after}}"
                    - name: author
                      value: "{{.Input.body.pusher.name}}"
                    - name: message
                      value: "{{.Input.body.head_commit.message}}"
EOF
```

## Step 4: Simulate GitHub Webhook Events

### Port Forward and Send Test Events

```bash
# Port forward GitHub EventSource
kubectl port-forward -n argo-events svc/github-eventsource-eventsource-svc 12000:12000 &
GITHUB_PID=$!

# Simulate GitHub push event
cat > /tmp/github-push-event.json <<'EOFDATA'
{
  "ref": "refs/heads/main",
  "after": "abc123def456",
  "repository": {
    "full_name": "myorg/myapp",
    "name": "myapp"
  },
  "pusher": {
    "name": "developer",
    "email": "dev@example.com"
  },
  "head_commit": {
    "id": "abc123def456",
    "message": "feat: add new feature",
    "timestamp": "2024-01-01T12:00:00Z",
    "author": {
      "name": "developer",
      "email": "dev@example.com"
    }
  },
  "commits": [
    {
      "id": "abc123def456",
      "message": "feat: add new feature",
      "added": ["file1.js"],
      "modified": ["file2.js"],
      "removed": []
    }
  ]
}
EOFDATA

# Send the push event
curl -X POST http://localhost:12000/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d @/tmp/github-push-event.json

echo "GitHub push event sent!"
```

### Monitor CI Pipeline Execution

```bash
# Watch for workflow creation
kubectl get workflows -n argo-events -w

# View workflow progress
WORKFLOW_NAME=$(kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d'/' -f2)

# If argo CLI is installed
argo get $WORKFLOW_NAME -n argo-events

# View logs
kubectl logs -n argo-events $WORKFLOW_NAME --follow

# Check all steps
kubectl get workflow $WORKFLOW_NAME -n argo-events -o yaml | grep -A 50 status
```

## Step 5: Create Multi-Environment Deployment Sensors

### Create Deployment Workflow Template

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: deploy-pipeline
  namespace: argo-events
spec:
  entrypoint: main
  arguments:
    parameters:
      - name: environment
      - name: application
      - name: version
      - name: namespace

  templates:
    - name: main
      steps:
        - - name: pre-deploy-check
            template: pre-deploy

        - - name: deploy-app
            template: deploy

        - - name: post-deploy-verify
            template: verify

    - name: pre-deploy
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Pre-deployment checks for {{workflow.parameters.environment}}"
            echo "Application: {{workflow.parameters.application}}"
            echo "Version: {{workflow.parameters.version}}"
            echo "Namespace: {{workflow.parameters.namespace}}"
            sleep 2
            echo "Pre-deployment checks passed!"

    - name: deploy
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Deploying to {{workflow.parameters.environment}}..."
            echo "Creating/updating resources..."
            sleep 3
            echo "Deployment complete!"

    - name: verify
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Verifying deployment..."
            echo "Checking pod status..."
            sleep 2
            echo "Checking service endpoints..."
            sleep 1
            echo "Running smoke tests..."
            sleep 2
            echo "✓ Deployment verification successful!"
EOF
```

### Create Development Environment Sensor

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: dev-deploy-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: github-push
      eventSourceName: github-eventsource
      eventName: myrepo
      filters:
        data:
          - path: body.X-GitHub-Event
            type: string
            value:
              - "push"
          # Deploy to dev on any branch push
          - path: body.ref
            type: string
            value:
              - "refs/heads/develop"
              - "refs/heads/feature/*"

  triggers:
    - template:
        name: deploy-to-dev
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: deploy-dev-
                namespace: argo-events
              spec:
                workflowTemplateRef:
                  name: deploy-pipeline
                arguments:
                  parameters:
                    - name: environment
                      value: "development"
                    - name: application
                      value: "{{.Input.body.repository.name}}"
                    - name: version
                      value: "{{.Input.body.after}}"
                    - name: namespace
                      value: "dev"
EOF
```

### Create Production Environment Sensor with Approval

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: approval-webhook
  namespace: argo-events
spec:
  service:
    ports:
      - port: 13000
        targetPort: 13000
  webhook:
    approval:
      port: "13000"
      endpoint: /approval
      method: POST
EOF
```

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: prod-deploy-sensor
  namespace: argo-events
spec:
  dependencies:
    # Dependency 1: GitHub push to main
    - name: github-main-push
      eventSourceName: github-eventsource
      eventName: myrepo
      filters:
        data:
          - path: body.X-GitHub-Event
            type: string
            value:
              - "push"
          - path: body.ref
            type: string
            value:
              - "refs/heads/main"

    # Dependency 2: Manual approval
    - name: manual-approval
      eventSourceName: approval-webhook
      eventName: approval
      filters:
        data:
          - path: body.approved
            type: bool
            value:
              - "true"

  triggers:
    - template:
        name: deploy-to-production
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: deploy-prod-
                namespace: argo-events
              spec:
                workflowTemplateRef:
                  name: deploy-pipeline
                arguments:
                  parameters:
                    - name: environment
                      value: "production"
                    - name: application
                      value: "{{.Input.github-main-push.body.repository.name}}"
                    - name: version
                      value: "{{.Input.github-main-push.body.after}}"
                    - name: namespace
                      value: "production"
EOF
```

## Step 6: Test Multi-Stage Deployment Pipeline

### Test Development Deployment

```bash
# Simulate develop branch push
cat > /tmp/github-develop-push.json <<'EOFDATA'
{
  "ref": "refs/heads/develop",
  "after": "dev123abc",
  "repository": {
    "full_name": "myorg/myapp",
    "name": "myapp"
  },
  "pusher": {
    "name": "developer"
  },
  "head_commit": {
    "id": "dev123abc",
    "message": "feat: new feature for testing"
  }
}
EOFDATA

curl -X POST http://localhost:12000/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d @/tmp/github-develop-push.json

# Watch dev deployment
kubectl get workflows -n argo-events -w
```

### Test Production Deployment with Approval

```bash
# Step 1: Simulate main branch push
cat > /tmp/github-main-push.json <<'EOFDATA'
{
  "ref": "refs/heads/main",
  "after": "prod456def",
  "repository": {
    "full_name": "myorg/myapp",
    "name": "myapp"
  },
  "pusher": {
    "name": "developer"
  },
  "head_commit": {
    "id": "prod456def",
    "message": "release: version 1.0.0"
  }
}
EOFDATA

curl -X POST http://localhost:12000/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d @/tmp/github-main-push.json

echo "Main push sent - waiting for approval..."

# Check sensor status (should be waiting for approval)
kubectl logs -n argo-events -l sensor-name=prod-deploy-sensor --tail=20

# Step 2: Port forward approval webhook
kubectl port-forward -n argo-events svc/approval-webhook-eventsource-svc 13000:13000 &
APPROVAL_PID=$!

sleep 2

# Step 3: Send approval
curl -X POST http://localhost:13000/approval \
  -H "Content-Type: application/json" \
  -d '{
    "approved": true,
    "approver": "manager@example.com",
    "timestamp": "2024-01-01T12:00:00Z"
  }'

echo "Approval sent - deployment should start now"

# Watch production deployment
kubectl get workflows -n argo-events -w
```

## Step 7: Integrate with Argo CD

### Create Argo CD Application via Sensor

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: argocd-sync-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: deploy-complete
      eventSourceName: github-eventsource
      eventName: myrepo
      filters:
        data:
          - path: body.X-GitHub-Event
            type: string
            value:
              - "push"
          - path: body.ref
            type: string
            value:
              - "refs/heads/main"

  triggers:
    # Trigger 1: Create or update Argo CD Application
    - template:
        name: create-argocd-app
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Application
              metadata:
                name: "{{.Input.body.repository.name}}"
                namespace: argocd
              spec:
                project: default
                source:
                  repoURL: "https://github.com/{{.Input.body.repository.full_name}}"
                  targetRevision: "{{.Input.body.after}}"
                  path: k8s
                destination:
                  server: https://kubernetes.default.svc
                  namespace: default
                syncPolicy:
                  automated:
                    prune: true
                    selfHeal: true

    # Trigger 2: Sync the application
    - template:
        name: sync-argocd-app
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: argocd-sync-
                namespace: argo-events
              spec:
                entrypoint: sync
                serviceAccountName: argo-events-sa
                templates:
                  - name: sync
                    container:
                      image: argoproj/argocd:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Syncing Argo CD application..."
                          echo "Application: {{workflow.parameters.app}}"
                          # In production, use argocd CLI to sync
                          # argocd app sync {{workflow.parameters.app}} --insecure
                          sleep 2
                          echo "Sync initiated!"
                arguments:
                  parameters:
                    - name: app
                      value: "{{.Input.body.repository.name}}"
EOF
```

## Step 8: Create Pull Request Workflow

### Create PR Event Sensor

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: pr-check-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: pr-opened
      eventSourceName: github-eventsource
      eventName: myrepo
      filters:
        data:
          - path: body.X-GitHub-Event
            type: string
            value:
              - "pull_request"
          - path: body.action
            type: string
            value:
              - "opened"
              - "synchronize"

  triggers:
    - template:
        name: run-pr-checks
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: pr-check-
                namespace: argo-events
              spec:
                entrypoint: pr-pipeline
                arguments:
                  parameters:
                    - name: pr-number
                      value: "{{.Input.body.pull_request.number}}"
                    - name: pr-title
                      value: "{{.Input.body.pull_request.title}}"
                    - name: source-branch
                      value: "{{.Input.body.pull_request.head.ref}}"
                    - name: target-branch
                      value: "{{.Input.body.pull_request.base.ref}}"
                    - name: author
                      value: "{{.Input.body.pull_request.user.login}}"

                templates:
                  - name: pr-pipeline
                    dag:
                      tasks:
                        - name: validate
                          template: validate-pr

                        - name: lint
                          template: lint-code
                          dependencies: [validate]

                        - name: test
                          template: run-tests
                          dependencies: [validate]

                        - name: comment
                          template: post-comment
                          dependencies: [lint, test]

                  - name: validate-pr
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Validating PR #{{workflow.parameters.pr-number}}"
                          echo "Title: {{workflow.parameters.pr-title}}"
                          echo "{{workflow.parameters.source-branch}} → {{workflow.parameters.target-branch}}"
                          echo "Author: {{workflow.parameters.author}}"
                          echo "Validation complete!"

                  - name: lint-code
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Running lint checks..."
                          sleep 2
                          echo "✓ All lint checks passed"

                  - name: run-tests
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Running test suite..."
                          sleep 3
                          echo "✓ All tests passed"

                  - name: post-comment
                    container:
                      image: alpine:latest
                      command: [sh, -c]
                      args:
                        - |
                          echo "Posting results to PR..."
                          echo "✓ Lint: Passed"
                          echo "✓ Tests: Passed"
                          echo "PR #{{workflow.parameters.pr-number}} is ready for review!"
EOF
```

### Test PR Workflow

```bash
# Simulate PR opened event
cat > /tmp/github-pr-event.json <<'EOFDATA'
{
  "action": "opened",
  "pull_request": {
    "number": 42,
    "title": "Add new feature",
    "user": {
      "login": "developer"
    },
    "head": {
      "ref": "feature/new-feature"
    },
    "base": {
      "ref": "main"
    }
  },
  "repository": {
    "full_name": "myorg/myapp",
    "name": "myapp"
  }
}
EOFDATA

curl -X POST http://localhost:12000/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: pull_request" \
  -d @/tmp/github-pr-event.json

# Watch PR check workflow
kubectl get workflows -n argo-events -w
```

## Step 9: Monitoring and Observability

### Create Monitoring Dashboard Workflow

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: event-monitor
  namespace: argo-events
spec:
  entrypoint: monitor
  templates:
    - name: monitor
      steps:
        - - name: check-eventsources
            template: check-eventsources

        - - name: check-sensors
            template: check-sensors

        - - name: check-workflows
            template: check-workflows

        - - name: generate-report
            template: generate-report

    - name: check-eventsources
      script:
        image: bitnami/kubectl:latest
        command: [bash]
        source: |
          echo "=== EventSources Status ==="
          kubectl get eventsources -n argo-events
          echo ""

    - name: check-sensors
      script:
        image: bitnami/kubectl:latest
        command: [bash]
        source: |
          echo "=== Sensors Status ==="
          kubectl get sensors -n argo-events
          echo ""

    - name: check-workflows
      script:
        image: bitnami/kubectl:latest
        command: [bash]
        source: |
          echo "=== Recent Workflows ==="
          kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp | tail -10
          echo ""

    - name: generate-report
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "=== Event-Driven CI/CD Report ==="
            echo "Timestamp: $(date)"
            echo "System is operational"
            echo "=============================="
EOF
```

### Run Monitoring Workflow

```bash
# Execute monitoring workflow
kubectl create -f <(kubectl get workflow event-monitor -n argo-events -o yaml | sed 's/name: event-monitor/generateName: event-monitor-/')

# View results
MONITOR_WORKFLOW=$(kubectl get workflows -n argo-events -l workflows.argoproj.io/phase=Succeeded --sort-by=.metadata.creationTimestamp -o name | grep event-monitor | tail -1 | cut -d'/' -f2)
kubectl logs -n argo-events $MONITOR_WORKFLOW
```

## Step 10: Complete End-to-End Test

### Run Complete CI/CD Flow

```bash
echo "=== Starting Complete CI/CD Flow ==="

# 1. Simulate feature branch push (triggers dev deployment)
echo "Step 1: Feature branch push..."
curl -X POST http://localhost:12000/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{
    "ref": "refs/heads/develop",
    "after": "feature123",
    "repository": {"full_name": "myorg/myapp", "name": "myapp"},
    "pusher": {"name": "developer"},
    "head_commit": {"id": "feature123", "message": "feat: complete feature"}
  }'

sleep 5

# 2. Simulate PR creation
echo "Step 2: Creating pull request..."
curl -X POST http://localhost:12000/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: pull_request" \
  -d '{
    "action": "opened",
    "pull_request": {
      "number": 100,
      "title": "Complete feature implementation",
      "user": {"login": "developer"},
      "head": {"ref": "develop"},
      "base": {"ref": "main"}
    },
    "repository": {"full_name": "myorg/myapp", "name": "myapp"}
  }'

sleep 5

# 3. Simulate merge to main
echo "Step 3: Merging to main..."
curl -X POST http://localhost:12000/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{
    "ref": "refs/heads/main",
    "after": "release123",
    "repository": {"full_name": "myorg/myapp", "name": "myapp"},
    "pusher": {"name": "developer"},
    "head_commit": {"id": "release123", "message": "release: v1.0.0"}
  }'

sleep 3

# 4. Send approval for production
echo "Step 4: Sending production approval..."
curl -X POST http://localhost:13000/approval \
  -H "Content-Type: application/json" \
  -d '{
    "approved": true,
    "approver": "release-manager@example.com"
  }'

echo ""
echo "=== Complete flow triggered! ==="
echo "Watch workflows with: kubectl get workflows -n argo-events -w"
```

### Monitor Complete Flow

```bash
# Watch all workflows
watch -n 2 'kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp | tail -15'

# View sensor activity
kubectl get sensors -n argo-events

# Check individual sensor logs
for sensor in $(kubectl get sensors -n argo-events -o name); do
  echo "=== $sensor ==="
  kubectl logs -n argo-events -l sensor-name=$(basename $sensor) --tail=5
  echo ""
done
```

## Step 11: Cleanup

### Stop Port Forwarding

```bash
# Kill all port forwards
kill $GITHUB_PID $APPROVAL_PID 2>/dev/null || true
pkill -f "port-forward.*eventsource"
```

### Cleanup Resources

```bash
# Clean up workflows
kubectl delete workflows --all -n argo-events

# Clean up test files
rm -f /tmp/github-*.json

# Optional: Remove all sensors and eventsources
# (Skip if you want to keep the setup)
# kubectl delete sensor --all -n argo-events
# kubectl delete eventsource --all -n argo-events
# kubectl delete workflowtemplate --all -n argo-events
```

### View Final State

```bash
echo "=== Final Resource State ==="
echo ""
echo "EventSources:"
kubectl get eventsources -n argo-events
echo ""
echo "Sensors:"
kubectl get sensors -n argo-events
echo ""
echo "WorkflowTemplates:"
kubectl get workflowtemplates -n argo-events
echo ""
echo "Recent Workflows:"
kubectl get workflows -n argo-events --sort-by=.metadata.creationTimestamp | tail -10
```

## Verification Checklist

Ensure you have completed:

- [ ] Created GitHub EventSource for webhook events
- [ ] Built CI pipeline with WorkflowTemplate
- [ ] Triggered builds from GitHub push events
- [ ] Implemented multi-environment deployments
- [ ] Created approval workflow for production
- [ ] Tested multi-dependency sensor (push + approval)
- [ ] Integrated with Argo CD for GitOps
- [ ] Created PR validation workflow
- [ ] Ran complete end-to-end CI/CD flow
- [ ] Monitored event flow through all stages

## Troubleshooting

### GitHub Events Not Triggering

```bash
# Check EventSource logs
kubectl logs -n argo-events -l eventsource-name=github-eventsource

# Verify webhook payload format
# Check sensor filters
kubectl get sensor github-build-sensor -n argo-events -o yaml | grep -A 20 filters

# Test with minimal payload
curl -X POST http://localhost:12000/github \
  -H "X-GitHub-Event: push" \
  -d '{"ref":"refs/heads/main"}'
```

### Multi-Dependency Not Working

```bash
# Check sensor dependency status
kubectl describe sensor prod-deploy-sensor -n argo-events

# View sensor logs to see which dependencies are satisfied
kubectl logs -n argo-events -l sensor-name=prod-deploy-sensor --tail=50

# Verify both events were sent
# Resend if needed
```

### Workflow Template Not Found

```bash
# List available templates
kubectl get workflowtemplates -n argo-events

# Check template reference in sensor
kubectl get sensor github-build-sensor -n argo-events -o yaml | grep -A 5 workflowTemplateRef

# Verify namespace matches
```

### Argo CD Integration Failed

```bash
# Check if Argo CD is installed
kubectl get pods -n argocd

# Verify sensor permissions for creating Applications
kubectl auth can-i create applications --as=system:serviceaccount:argo-events:argo-events-sa -n argocd

# Check Application CRD
kubectl get crd applications.argoproj.io
```

## Key Concepts Review

### Event-Driven CI/CD

- Git events trigger automated builds
- Branch-based deployment strategies
- Approval gates for production
- Integration with GitOps tools

### GitHub EventSource

- Capture push, PR, and release events
- Filter by branch, event type, action
- Extract commit info and metadata
- Webhook validation and security

### Multi-Stage Pipelines

- Build → Test → Deploy workflow
- Environment-specific triggers
- Manual approval dependencies
- Parallel and sequential stages

### Integration Patterns

- Argo Events → Argo Workflows (CI)
- Argo Workflows → Argo CD (CD)
- Event chaining and dependencies
- External system webhooks

### Production Considerations

- Webhook security and validation
- Event filtering and routing
- Error handling and retries
- Monitoring and observability
- RBAC and permissions

## Additional Exercises

### Exercise 1: Slack Notifications

Add Slack notifications at each stage of the pipeline using HTTP triggers.

### Exercise 2: Rollback Workflow

Create a sensor that triggers rollback when deployment health checks fail.

### Exercise 3: Release Automation

Implement automatic GitHub release creation when main branch build succeeds.

### Exercise 4: Multi-Cluster Deployment

Extend the pipeline to deploy to multiple clusters based on event data.

## Real-World Applications

### Use Case 1: Microservices CI/CD

```
GitHub Push → Build Each Service → Integration Tests → Deploy to Staging → Manual Approval → Production
```

### Use Case 2: Infrastructure as Code

```
Git Push (Terraform) → Plan Workflow → Approval → Apply Workflow → Notify
```

### Use Case 3: Scheduled Maintenance

```
Calendar Event → Backup Workflow → Maintenance Workflow → Restore Workflow → Verification
```

### Use Case 4: Incident Response

```
Alert Event → Create Incident Ticket → Run Diagnostics → Notify On-Call → Auto-Remediation
```

## Summary

In this lab, you:

- Built a complete event-driven CI/CD pipeline
- Integrated GitHub webhooks with Argo Events
- Created multi-stage deployment workflows
- Implemented approval gates for production
- Combined Argo Events, Workflows, and CD
- Tested end-to-end automation flows
- Monitored event-driven systems
- Applied best practices for production

You now have the skills to build sophisticated event-driven automation systems using the Argo Project ecosystem!

## Next Steps

To continue your learning:

- Review the [Argo Events Documentation](https://argoproj.github.io/argo-events/)
- Explore [Integration Examples](https://github.com/argoproj/argo-events/tree/master/examples)
- Practice with real Git repositories
- Implement monitoring with Prometheus
- Study production deployment patterns
- Take the CAPA certification exam

Congratulations on completing all Argo Events labs!
