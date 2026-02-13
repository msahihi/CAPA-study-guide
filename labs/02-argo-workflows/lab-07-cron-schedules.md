# Lab 07: CronWorkflows - Scheduled Workflow Execution

**Duration**: 30 minutes
**Difficulty**: Intermediate
**Prerequisites**:

- Completed [Lab 01: Installation and Basics](lab-01-installation-basics.md)
- Completed [Lab 02: Templates and Steps](lab-02-templates-steps.md)
- Kubernetes cluster with Argo Workflows v2.5+ installed
- `kubectl` and `argo` CLI tools installed

## Overview

This lab covers scheduled workflow execution using CronWorkflows. You'll learn how to create recurring workflows, manage concurrency, handle timezone considerations, and implement auto-stop conditions.

**Learning Objectives**:

- Create CronWorkflows with cron schedule syntax
- Configure timezone handling for scheduled execution
- Control concurrent workflow execution
- Implement auto-stop strategies
- Manage CronWorkflow lifecycle (suspend/resume)

## Concepts

### What is a CronWorkflow?

A CronWorkflow wraps a standard Workflow spec and adds scheduling parameters. It automatically creates Workflow instances based on cron expressions, similar to Kubernetes CronJobs.

**Key Features**:

- Recurring workflow execution on schedule
- Configurable concurrency policies
- Timezone-aware scheduling
- Conditional auto-stop based on success/failure counts
- Suspension capability without deletion

---

## Lab Exercises

### Exercise 1: Basic CronWorkflow

**Objective**: Create a simple recurring workflow that runs every minute.

**Step 1.1**: Create basic CronWorkflow

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: hello-cron
spec:
  schedule: "* * * * *"
  timezone: "America/Los_Angeles"
  workflowSpec:
    entrypoint: whalesay
    templates:
    - name: whalesay
      container:
        image: docker/whalesay:latest
        command: [cowsay]
        args: ["Hello from CronWorkflow! Executed at: $(date)"]
EOF
```

**Step 1.2**: Monitor CronWorkflow execution

```bash
# View CronWorkflow details
argo cron get hello-cron

# List workflows created by this CronWorkflow
argo list | grep hello-cron

# Watch for new workflow creation (wait 1-2 minutes)
watch -n 5 'argo list | head -5'
```

**Step 1.3**: View generated workflow logs

```bash
# Get latest workflow from this CronWorkflow
WORKFLOW_NAME=$(argo list -o name | grep hello-cron | head -1)

# View logs
argo logs $WORKFLOW_NAME
```

---

### Exercise 2: Concurrency Control

**Objective**: Test different concurrency policies to control overlapping executions.

**Step 2.1**: Create CronWorkflow with "Replace" policy

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: concurrency-replace
spec:
  schedule: "*/2 * * * *"
  concurrencyPolicy: "Replace"
  workflowSpec:
    entrypoint: long-running
    templates:
    - name: long-running
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Started at: $(date)"
            sleep 180  # 3 minutes - overlaps with next schedule
            echo "Finished at: $(date)"
EOF
```

**Step 2.2**: Create CronWorkflow with "Forbid" policy

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: concurrency-forbid
spec:
  schedule: "*/2 * * * *"
  concurrencyPolicy: "Forbid"
  workflowSpec:
    entrypoint: quick-task
    templates:
    - name: quick-task
      container:
        image: alpine:latest
        command: [sh, -c]
        args: ["echo 'Task executed'; sleep 10"]
EOF
```

**Step 2.3**: Observe concurrency behavior

```bash
# Watch CronWorkflow executions
watch -n 10 'argo list | grep concurrency'
```

**Expected Behavior**:

- **Replace**: New workflow replaces running one when schedule triggers
- **Forbid**: New workflow skipped if previous one still running
- **Allow** (default): Multiple workflows can run concurrently

---

### Exercise 3: Auto-Stop Strategy

**Objective**: Implement CronWorkflow that stops after achieving success condition.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: auto-stop-on-success
spec:
  schedule: "*/1 * * * *"
  timezone: "UTC"
  stopStrategy:
    expression: "cronworkflow.succeeded >= 3"
  workflowSpec:
    entrypoint: task-with-status
    templates:
    - name: task-with-status
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "Execution count check"
            # Succeed after running
            exit 0
EOF
```

**Monitor auto-stop**:

```bash
# Watch CronWorkflow status
watch -n 5 'argo cron get auto-stop-on-success | grep -A 5 "Status:"'

# After 3 successful runs, CronWorkflow should stop scheduling
argo cron get auto-stop-on-success
```

---

### Exercise 4: Timezone Handling and DST

**Objective**: Understand timezone behavior during Daylight Saving Time transitions.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: timezone-aware
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  timezone: "America/New_York"
  workflowSpec:
    entrypoint: timestamp-check
    templates:
    - name: timestamp-check
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            apk add --no-cache tzdata
            export TZ=America/New_York
            echo "Scheduled execution time (EST/EDT): $(date)"
            echo "UTC time: $(date -u)"
EOF
```

**Add DST duplicate prevention**:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: dst-safe-cron
spec:
  schedule: "0 1 * * *"  # 1 AM daily
  timezone: "America/New_York"
  workflowSpec:
    entrypoint: dst-aware-task
    templates:
    - name: dst-aware-task
      steps:
      - - name: check-duplicate
          template: duplicate-check
      - - name: main-task
          template: actual-work
          when: "{{steps.check-duplicate.outputs.result}} == 'proceed'"

    - name: duplicate-check
      script:
        image: alpine:latest
        command: [sh]
        source: |
          # Prevent duplicate runs during DST fall-back
          if [ "{{workflow.scheduledTime}}" != "" ]; then
            last_scheduled="{{cronworkflow.lastScheduledTime}}"
            if [ -n "$last_scheduled" ]; then
              time_diff=$(($(date +%s) - $(date -d "$last_scheduled" +%s)))
              if [ $time_diff -lt 3600 ]; then
                echo "skip"
                exit 0
              fi
            fi
          fi
          echo "proceed"

    - name: actual-work
      container:
        image: alpine:latest
        command: [echo]
        args: ["Task executed successfully"]
EOF
```

---

### Exercise 5: Suspend and Resume

**Objective**: Learn to pause and resume CronWorkflow scheduling.

```bash
# Create CronWorkflow
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: suspendable-cron
spec:
  schedule: "*/1 * * * *"
  workflowSpec:
    entrypoint: simple-task
    templates:
    - name: simple-task
      container:
        image: alpine:latest
        command: [echo]
        args: ["Running..."]
EOF

# Let it run for 2-3 minutes
sleep 120

# Suspend the CronWorkflow
argo cron suspend suspendable-cron

# Verify suspension
argo cron get suspendable-cron | grep Suspended

# Wait and confirm no new workflows created
sleep 60
argo list | grep suspendable-cron | wc -l

# Resume scheduling
argo cron resume suspendable-cron

# Verify resumption
argo cron get suspendable-cron | grep Suspended
```

---

## Validation

Test your understanding:

```bash
# Create a validation CronWorkflow
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: validation-cron
spec:
  schedule: "*/2 * * * *"
  timezone: "UTC"
  concurrencyPolicy: "Forbid"
  startingDeadlineSeconds: 60
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  workflowSpec:
    entrypoint: validation-task
    templates:
    - name: validation-task
      container:
        image: alpine:latest
        command: [sh, -c]
        args:
          - |
            echo "CronWorkflow validation task"
            echo "Schedule time: {{workflow.scheduledTime}}"
            echo "Actual start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            exit 0
EOF

# Monitor for successful execution
sleep 150
WORKFLOW_NAME=$(argo list -o name | grep validation-cron | head -1)
argo logs $WORKFLOW_NAME | grep "CronWorkflow validation task"
```

Expected: Workflow executes every 2 minutes with schedule information logged.

---

## Troubleshooting

### Issue: CronWorkflow not creating workflows

**Check CronWorkflow status**:

```bash
argo cron get <cronworkflow-name>
kubectl describe cronworkflow <cronworkflow-name>
```

**Common causes**:

- Invalid cron syntax
- CronWorkflow suspended
- Controller errors (check logs: `kubectl logs -n argo deploy/workflow-controller`)

### Issue: Workflows created at wrong time

**Solution**: Verify timezone setting

```bash
argo cron get <cronworkflow-name> -o yaml | grep timezone
```

Use IANA timezone format (e.g., "America/Los_Angeles", not "PST")

---

## Cleanup

```bash
# Delete CronWorkflows
argo cron delete hello-cron concurrency-replace concurrency-forbid \
  auto-stop-on-success timezone-aware dst-safe-cron \
  suspendable-cron validation-cron

# Delete associated workflows
argo delete --all

# Verify cleanup
argo cron list
```

---

## Key Takeaways

1. **CronWorkflows schedule recurring executions** using cron syntax
2. **Concurrency policies** control overlapping runs (Allow, Replace, Forbid)
3. **Timezone-aware scheduling** handles DST transitions automatically
4. **Auto-stop strategies** enable conditional scheduling termination
5. **Suspend/resume** allows temporary pause without deletion
6. **Management tools**: CLI (`argo cron`), kubectl, UI, and Argo CD

---

## Next Steps

- [Lab: Workflow Artifacts](lab-06-artifacts-advanced.md) - Data passing between steps
- **Documentation**: [CI/CD Integration](../../domains/02-argo-workflows/cicd-integration.md)

---

**Official Reference**: [Argo Workflows - CronWorkflows](https://argo-workflows.readthedocs.io/en/latest/cron-workflows/)
