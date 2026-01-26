# CAPA Mock Exam - Set 1

## Exam Information

- **Total Questions:** 60
- **Time Limit:** 90 minutes
- **Passing Score:** 70% (42 correct answers)
- **Instructions:** Choose the BEST answer for each question

## Domain Distribution

- Argo CD: Questions 1-21 (35%)
- Argo Workflows: Questions 22-36 (25%)
- Argo Rollouts: Questions 37-51 (25%)
- Argo Events: Questions 52-60 (15%)

## Section 1: Argo CD (Questions 1-21)

### Question 1

What is the primary role of the Application Controller in Argo CD?

A. Managing user authentication and authorization  
B. Continuously monitoring Git repositories for changes.  
C. Comparing desired state in Git with live state in Kubernetes  
D. Serving the web UI and API endpoints

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
The Application Controller is the core component that continuously compares the desired application state (defined in Git) with the live state in the Kubernetes cluster. It performs reconciliation loops to detect and report drift.

**Why others are wrong:**

- **A:** User authentication is handled by the Argo CD API Server with dex integration
- **B:** The Repo Server monitors and interacts with Git repositories, not the Application Controller
- **D:** The API Server serves the web UI and API endpoints

</details>

### Question 2

Which Argo CD sync policy option will automatically sync an application when it detects drift?

A. `syncPolicy.automated.prune: true`  
B. `syncPolicy.automated.selfHeal: true`  
C. `syncPolicy.automated.allowEmpty: true`  
D. `syncPolicy.syncOptions: [AutoSync=true]`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `selfHeal: true` option under automated sync policy will automatically sync the application when Argo CD detects that the live state has drifted from the desired state in Git, even if the Git state hasn't changed.

**Why others are wrong:**

- **A:** `prune: true` enables automatic deletion of resources that no longer exist in Git, but doesn't trigger syncs on drift
- **C:** `allowEmpty: true` allows syncing when an app has no resources, not related to drift detection
- **D:** This is not valid syntax; automated sync is enabled with `syncPolicy.automated: {}`

</details>

### Question 3

You need to prevent Argo CD from deleting a specific Kubernetes Secret during a sync. Which annotation should you add to the Secret?

A. `argocd.argoproj.io/sync-options: Delete=false`  
B. `argocd.argoproj.io/compare-options: IgnoreDuringDeletion`  
C. `argocd.argoproj.io/sync-options: Prune=false`  
D. `argocd.argoproj.io/tracking-id: ignore`

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
The `Prune=false` sync option annotation prevents Argo CD from deleting (pruning) a resource when it's removed from Git or no longer tracked.

**Why others are wrong:**

- **A:** `Delete=false` is not a valid sync option
- **B:** `IgnoreDuringDeletion` is not a valid compare option
- **D:** The tracking-id annotation is used for tracking resources, not preventing deletion

</details>

### Question 4

Which command displays the difference between the desired state (Git) and live state (cluster) for an application?

A. `argocd app status myapp`  
B. `argocd app diff myapp`  
C. `argocd app get myapp --show-params`  
D. `argocd app sync myapp --dry-run`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `argocd app diff` command shows the differences between the desired state in Git and the live state in the cluster, similar to a Git diff.

**Why others are wrong:**

- **A:** `app status` shows overall sync status but not detailed differences
- **C:** `--show-params` displays parameter overrides, not state differences
- **D:** `--dry-run` previews sync actions but in a different format than diff

</details>

### Question 5

An Argo CD Application is stuck in "Progressing" state. What is the MOST likely cause?

A. The Git repository is unreachable  
B. A Kubernetes resource has not reached its ready state within the health check timeout  
C. The Application manifest has incorrect YAML syntax  
D. The sync operation was cancelled

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
"Progressing" status typically means resources have been created/updated but haven't reached a healthy/ready state yet. This is most commonly due to pods not starting, deployments not reaching ready replicas, or custom health checks timing out.

**Why others are wrong:**

- **A:** Git repository issues would show "ComparisonError" status, not "Progressing"
- **C:** YAML syntax errors would prevent sync from starting, showing "SyncError"
- **D:** Cancelled sync operations would show "Terminated" or "Failed" status

</details>

### Question 6

What is the purpose of the `project` field in an Argo CD Application manifest?

A. It specifies which Git project contains the application manifests  
B. It references an AppProject that defines RBAC and access restrictions  
C. It identifies the Kubernetes namespace where the application will be deployed  
D. It groups applications for organizational purposes only

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `project` field references an Argo CD AppProject resource, which provides multi-tenancy by restricting what Git repos can be used, which clusters can be deployed to, which namespaces/resources are allowed, and defining RBAC policies.

**Why others are wrong:**

- **A:** The Git repository is specified in the `source.repoURL` field
- **C:** The target namespace is specified in `destination.namespace`
- **D:** While projects do provide organization, their primary purpose is security and access control

</details>

### Question 7

Which sync option allows you to skip schema validation when applying manifests?

A. `Validate=false`  
B. `SkipSchemaValidation`  
C. `ServerSideApply=true`  
D. `ApplyOutOfSyncOnly=true`

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
The `Validate=false` sync option disables schema validation during sync, which can be useful for custom resources or when working with experimental API versions.

**Why others are wrong:**

- **B:** `SkipSchemaValidation` is not a valid sync option name
- **C:** `ServerSideApply=true` enables server-side apply but doesn't skip validation
- **D:** `ApplyOutOfSyncOnly=true` only syncs resources that are out of sync, doesn't affect validation

</details>

### Question 8

You want to deploy to multiple clusters from a single Git repository. What is the BEST approach?

A. Create multiple Argo CD instances, one per cluster  
B. Use Argo CD ApplicationSets with cluster generators  
C. Create separate Git repositories for each cluster  
D. Use Helm with different values files and manual syncs

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
ApplicationSets are designed specifically for managing multiple applications across multiple clusters from a single source. The cluster generator can automatically create applications for each registered cluster.

**Why others are wrong:**

- **A:** Multiple Argo CD instances creates unnecessary complexity and duplication
- **C:** Separate repositories defeat the purpose of single-source-of-truth and increase maintenance
- **D:** While Helm helps with configuration, manual syncs don't scale well and lack automation

</details>

### Question 9

What does the following Argo CD health assessment indicate?

```yaml
status:
  health:
    status: Degraded
    message: "Pod myapp-7d4f5b6c8-xyz is CrashLoopBackOff"
```

A. The application sync failed  
B. The application is partially available but has issues  
C. The Git repository is out of sync  
D. The application was pruned

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
"Degraded" status means the application is partially running but has health issues. Some pods may be running while others are failing, making the application available but not fully healthy.

**Why others are wrong:**

- **A:** Sync failures are separate from health status and would show in sync status
- **C:** Git sync status is separate from health status
- **D:** Pruned resources affect sync status, not health status

</details>

### Question 10

Which Argo CD component is responsible for generating Kubernetes manifests from Helm charts, Kustomize, or Jsonnet?

A. Application Controller  
B. API Server  
C. Repo Server  
D. Redis Cache

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
The Repo Server is responsible for cloning Git repositories and generating Kubernetes manifests from various tools like Helm, Kustomize, Jsonnet, or plain YAML. It acts as an internal service that abstracts the details of manifest generation.

**Why others are wrong:**

- **A:** The Application Controller compares and reconciles state but doesn't generate manifests
- **B:** The API Server provides the UI and API but doesn't generate manifests
- **D:** Redis is used for caching but not for manifest generation

</details>

### Question 11

You need to exclude certain files from being processed by Argo CD. Which Application field should you configure?

A. `source.path` with negation patterns  
B. `source.directory.exclude`  
C. `spec.ignoreDifferences`  
D. `spec.ignoreFiles`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `source.directory.exclude` field allows you to specify glob patterns for files/directories to exclude from application manifests when using plain directory sources.

**Why others are wrong:**

- **A:** `source.path` specifies what to include, not what to exclude
- **C:** `ignoreDifferences` ignores differences during comparison but doesn't exclude files
- **D:** `ignoreFiles` is not a valid field in the Application spec

</details>

### Question 12

What is the purpose of the `argocd app wait` command?

A. To pause an application sync operation  
B. To wait for an application to reach a synced and healthy state  
C. To delay sync by a specified time period  
D. To wait for user confirmation before syncing

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`argocd app wait` blocks until the application reaches the desired state (synced and healthy), making it useful in CI/CD pipelines or scripts where you need to wait for deployment completion.

**Why others are wrong:**

- **A:** There's no command to pause an ongoing sync
- **C:** It waits for conditions, not a time duration
- **D:** Manual confirmation is handled through sync options, not the wait command

</details>

### Question 13

Which AppProject configuration restricts an application to only deploy to specific namespaces?

A. `spec.sourceRepos`  
B. `spec.destinations`  
C. `spec.clusterResourceWhitelist`  
D. `spec.namespaceResourceBlacklist`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`spec.destinations` in an AppProject defines which clusters and namespaces applications in that project can deploy to, providing namespace-level restrictions.

**Why others are wrong:**

- **A:** `sourceRepos` restricts which Git repositories can be used, not target namespaces
- **C:** `clusterResourceWhitelist` controls which cluster-scoped resources are allowed, not namespaces
- **D:** `namespaceResourceBlacklist` blocks specific resource types within namespaces but doesn't restrict which namespaces can be used

</details>

### Question 14

You want to use a private Git repository with SSH authentication. What should you configure in Argo CD?

A. Create a Secret with SSH private key and register it as a repository credential  
B. Store the SSH key in the Application manifest under `source.sshKey`  
C. Configure the SSH key in the argocd-cm ConfigMap  
D. Use HTTPS with a token instead; SSH is not supported

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
Private repositories require credentials registered in Argo CD. For SSH, you create a Secret with the private key and register it using `argocd repo add` or through the UI. The credentials are stored in the argocd-repo-server Secret.

**Why others are wrong:**

- **B:** Application manifests don't contain credentials; they reference repositories
- **C:** The argocd-cm ConfigMap is for general settings, not credentials
- **D:** SSH is fully supported and often preferred for Git authentication

</details>

### Question 15

What does the `RespectIgnoreDifferences` sync option do?

A. Ignores all differences between Git and live state  
B. Applies the ignoreDifferences settings during a sync operation  
C. Prevents sync when differences are detected  
D. Ignores deletion of resources

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`RespectIgnoreDifferences` makes the sync operation honor the `ignoreDifferences` configuration, so fields marked as ignored won't be overwritten during sync even if they differ.

**Why others are wrong:**

- **A:** It only ignores specifically configured differences, not all differences
- **C:** It allows sync to proceed while ignoring certain fields, not preventing sync
- **D:** Resource deletion is controlled by prune settings, not ignore differences

</details>

### Question 16

Which command shows all applications managed by Argo CD across all projects?

A. `argocd app list`  
B. `argocd app get --all`  
C. `kubectl get applications -n argocd`  
D. Both A and C

**Correct Answer:** D

<details>
<summary>Explanation</summary>

**Why D is correct:**
Both commands show all applications: `argocd app list` uses the Argo CD API and provides formatted output, while `kubectl get applications -n argocd` directly queries the Application CRDs in the Kubernetes API.

**Why others are wrong:**

- **A:** This is correct but incomplete as an answer
- **B:** `--all` is not a valid flag for `argocd app get`
- **C:** This is correct but incomplete as an answer

</details>

### Question 17

An application uses Kustomize with multiple overlays. How do you specify which overlay to use?

A. Set `source.kustomize.overlay` to the overlay directory name  
B. Set `source.path` to point to the overlay directory  
C. Use `source.targetRevision` to specify the overlay  
D. Configure overlays in the AppProject

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
With Kustomize, you specify the overlay by setting `source.path` to point to the specific overlay directory (e.g., `overlays/production`). Argo CD will automatically detect and run Kustomize build.

**Why others are wrong:**

- **A:** There is no `source.kustomize.overlay` field
- **C:** `targetRevision` specifies the Git branch/tag/commit, not the overlay
- **D:** AppProjects control access and restrictions, not overlay selection

</details>

### Question 18

What is the purpose of the `argocd.argoproj.io/sync-wave` annotation?

A. To control the order in which resources are synced  
B. To group resources for batch operations  
C. To specify how many sync attempts should be made  
D. To define sync frequency for automated sync

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
The `sync-wave` annotation controls the order of resource creation during sync. Resources are applied in increasing wave order (e.g., wave 0 before wave 1), allowing you to ensure dependencies are created first.

**Why others are wrong:**

- **B:** While waves do group resources, the primary purpose is ordering, not just grouping
- **C:** Sync retry attempts are controlled by sync policy, not annotations
- **D:** Sync frequency is controlled by the reconciliation timeout setting, not annotations

</details>

### Question 19

Which Argo CD feature allows you to test changes before syncing to production?

A. Sync Preview  
B. Diff View  
C. Dry Run  
D. All of the above

**Correct Answer:** D

<details>
<summary>Explanation</summary>

**Why D is correct:**
All three features help test changes:

- **Sync Preview:** Shows what will be created/updated/deleted
- **Diff View:** Shows exact differences between desired and live state
- **Dry Run:** Simulates sync without actually applying changes

**Why others are wrong:**
Each individual option is correct but incomplete since all three can be used for testing.
</details>

### Question 20

You need to deploy an application to a namespace that doesn't exist yet. What should you configure?

A. Create the namespace manually before syncing  
B. Add `CreateNamespace=true` to sync options  
C. Set `destination.createNamespace: true`  
D. Include a Namespace manifest in your Git repository

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `CreateNamespace=true` sync option tells Argo CD to automatically create the destination namespace if it doesn't exist during sync.

**Why others are wrong:**

- **A:** This works but requires manual intervention and doesn't scale
- **C:** `destination.createNamespace` is not a valid field
- **D:** This works but adds unnecessary manifest management; sync options are cleaner

</details>

### Question 21

What does OutOfSync status mean for an Argo CD Application?

A. The sync operation failed  
B. The desired state in Git differs from the live state in the cluster  
C. The application is not healthy  
D. The Git repository is unreachable

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
OutOfSync status means Argo CD has detected differences between what's defined in Git (desired state) and what's running in the cluster (live state). This doesn't necessarily mean there's a problem, just that they differ.

**Why others are wrong:**

- **A:** Failed syncs show "SyncFailed" status, not OutOfSync
- **C:** Health status is separate from sync status
- **D:** Git repository issues show "ComparisonError" status

</details>

## Section 2: Argo Workflows (Questions 22-36)

### Question 22

What is the main purpose of Argo Workflows?

A. To provide continuous delivery for Kubernetes applications  
B. To orchestrate parallel and sequential container execution in Kubernetes  
C. To implement progressive delivery strategies  
D. To trigger workflows based on events

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Argo Workflows is a container-native workflow engine for orchestrating parallel jobs on Kubernetes. It allows you to define complex workflows with steps, DAGs (Directed Acyclic Graphs), and dependencies.

**Why others are wrong:**

- **A:** This describes Argo CD, not Workflows
- **C:** This describes Argo Rollouts, not Workflows
- **D:** This describes Argo Events, though it can trigger Workflows

</details>

### Question 23

Which Workflow template type allows you to define parallel execution with dependencies?

A. Steps  
B. DAG  
C. Container  
D. Suspend

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
DAG (Directed Acyclic Graph) templates allow you to define tasks with explicit dependencies using the `dependencies` field, enabling complex parallel execution patterns where tasks run when their dependencies complete.

**Why others are wrong:**

- **A:** Steps templates execute sequentially or in parallel groups but use a different structure
- **C:** Container templates define individual container execution, not orchestration
- **D:** Suspend templates pause workflow execution, they don't define parallelism

</details>

### Question 24

What is the purpose of the `retryStrategy` field in a Workflow template?

A. To retry the entire workflow if it fails  
B. To retry a specific step or task when it fails  
C. To schedule periodic workflow execution  
D. To implement exponential backoff for API calls

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`retryStrategy` defines how a specific step or task should be retried on failure, including retry limits, backoff settings, and retry policies (Always, OnFailure, OnError, OnTransientError).

**Why others are wrong:**

- **A:** Entire workflow retry is configured differently, using CronWorkflow or manual resubmission
- **C:** Periodic execution uses CronWorkflow, not retryStrategy
- **D:** While retry strategy can include backoff, its primary purpose is step retry on failure

</details>

### Question 25

Which command submits a Workflow from a YAML file?

A. `argo create workflow.yaml`  
B. `argo submit workflow.yaml`  
C. `argo run workflow.yaml`  
D. `kubectl apply -f workflow.yaml`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`argo submit` is the standard command to submit a Workflow for execution. It creates a Workflow resource and starts execution immediately.

**Why others are wrong:**

- **A:** `argo create` is not a valid command
- **C:** `argo run` is not the standard command (though some tools use it)
- **D:** While this creates the resource, it bypasses Argo CLI validation and features

</details>

### Question 26

What does the following Workflow specification do?

```yaml
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: step1
        template: whalesay
    - - name: step2a
        template: whalesay
      - name: step2b
        template: whalesay
```

A. Executes step1, step2a, and step2b sequentially  
B. Executes all steps in parallel  
C. Executes step1 first, then step2a and step2b in parallel  
D. Fails due to invalid syntax

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
In steps templates, each list item (marked with `-`) represents a sequential step group. Items within the same group (multiple `- name:` at the same level) execute in parallel. Here, step1 runs first, then step2a and step2b run in parallel.

**Why others are wrong:**

- **A:** step2a and step2b are in the same step group, so they run in parallel
- **B:** step1 is in a separate group and runs before the others
- **D:** The syntax is valid Argo Workflows YAML

</details>

### Question 27

Which artifact repository is NOT natively supported by Argo Workflows?

A. S3  
B. GCS (Google Cloud Storage)  
C. Artifactory  
D. Azure Blob Storage

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
Argo Workflows natively supports S3, GCS, Azure Blob Storage, and Git repositories for artifacts. Artifactory support requires custom implementation or using S3-compatible API if Artifactory supports it.

**Why others are wrong:**

- **A, B, D:** These are all natively supported artifact repositories in Argo Workflows

</details>

### Question 28

What is the purpose of the `when` expression in a Workflow?

A. To schedule when a workflow should run  
B. To conditionally execute a step based on a condition  
C. To set a timeout for step execution  
D. To define when artifacts are uploaded

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `when` expression allows conditional execution of steps or tasks based on parameters, outputs, or status of previous steps. For example: `when: "{{steps.step1.status}} == Succeeded"`.

**Why others are wrong:**

- **A:** Workflow scheduling is done with CronWorkflow
- **C:** Timeouts are set with `activeDeadlineSeconds`
- **D:** Artifact upload is controlled by artifact configuration, not when expressions

</details>

### Question 29

Which Workflow field limits the total execution time?

A. `spec.timeout`  
B. `spec.activeDeadlineSeconds`  
C. `spec.deadline`  
D. `spec.ttlStrategy.secondsAfterCompletion`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`activeDeadlineSeconds` sets the maximum duration for workflow execution. If the workflow runs longer, it's terminated.

**Why others are wrong:**

- **A:** `timeout` is not a valid workflow field
- **C:** `deadline` is not a valid workflow field
- **D:** `ttlStrategy` controls when completed workflows are deleted, not execution time

</details>

### Question 30

What is a WorkflowTemplate?

A. A reusable workflow definition that can be referenced by multiple workflows  
B. A template for generating workflows from events  
C. A container template within a workflow  
D. A Helm template for deploying Argo Workflows

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
WorkflowTemplate is a cluster-scoped or namespaced resource that defines a reusable workflow specification. It can be referenced by Workflows using `workflowTemplateRef`, promoting reusability and standardization.

**Why others are wrong:**

- **B:** Event-based workflow generation is done by Argo Events with workflow triggers
- **C:** Container templates are defined within workflows, not WorkflowTemplate resources
- **D:** WorkflowTemplate is an Argo Workflows CRD, not a Helm concept

</details>

### Question 31

How do you pass the output of one step as input to another step?

A. Using environment variables  
B. Using `{{steps.stepname.outputs.result}}`  
C. Using ConfigMaps  
D. Steps cannot share data

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Argo Workflows provides variable substitution syntax to access outputs from previous steps. `{{steps.stepname.outputs.result}}` accesses the output, and you can also use `{{steps.stepname.outputs.parameters.paramname}}` for named parameters.

**Why others are wrong:**

- **A:** While environment variables can be used within containers, cross-step communication uses outputs/parameters
- **C:** ConfigMaps can share data but are not the standard mechanism for step-to-step data flow
- **D:** Step data sharing is a core feature of Argo Workflows

</details>

### Question 32

Which template type suspends workflow execution until manually resumed?

A. Pause  
B. Suspend  
C. Wait  
D. Manual

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The Suspend template type pauses workflow execution until manually resumed using `argo resume` command or API call. This is useful for manual approval gates or waiting for external actions.

**Why others are wrong:**

- **A:** Pause is not a valid template type
- **C:** Wait is not a valid template type (though there's a duration field in suspend)
- **D:** Manual is not a valid template type

</details>

### Question 33

What is the purpose of input and output parameters in Workflow templates?

A. To configure workflow scheduling  
B. To pass data and configuration between templates  
C. To define resource requests and limits  
D. To specify artifact locations

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Input parameters allow passing data into templates, and output parameters allow templates to return data. This enables data flow between templates and parameterization of workflows.

**Why others are wrong:**

- **A:** Scheduling is configured in CronWorkflow specs
- **C:** Resources are defined in container specs
- **D:** Artifacts are defined separately in artifact Sections

</details>

### Question 34

Which command shows the logs for a specific workflow?

A. `kubectl logs workflow-name`  
B. `argo logs workflow-name`  
C. `argo workflow logs workflow-name`  
D. `argo get workflow-name --logs`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`argo logs workflow-name` retrieves and displays logs from all containers in the workflow. You can also specify a specific node with `argo logs workflow-name nodename`.

**Why others are wrong:**

- **A:** Workflows are not pods, so kubectl logs doesn't work directly
- **C:** The command is `argo logs`, not `argo workflow logs`
- **D:** `--logs` is not a valid flag for `argo get`

</details>

### Question 35

What does the `parallelism` field control in a Workflow?

A. The number of workflow replicas  
B. The maximum number of pods that can run simultaneously  
C. The number of CPU cores allocated to each pod  
D. The number of steps that can run in parallel

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`parallelism` limits the maximum number of pods that can be running at once within a workflow. This prevents resource exhaustion and allows controlling cluster load.

**Why others are wrong:**

- **A:** Workflows don't have replicas; each submission creates a new workflow instance
- **C:** CPU allocation is controlled by resource requests/limits in container specs
- **D:** Parallelism controls pod count, not step definition (which is controlled by template structure)

</details>

### Question 36

What is a CronWorkflow?

A. A workflow that executes on a schedule  
B. A workflow that uses cron containers  
C. A workflow with time-based retry strategy  
D. A workflow that monitors cron jobs

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
CronWorkflow is a resource that creates workflows on a cron schedule, similar to Kubernetes CronJobs. It uses standard cron syntax to define the schedule.

**Why others are wrong:**

- **B:** Container type is irrelevant to CronWorkflow
- **C:** Retry strategies are separate from scheduling
- **D:** CronWorkflow creates workflows, it doesn't monitor jobs

</details>

## Section 3: Argo Rollouts (Questions 37-51)

### Question 37

What is the primary purpose of Argo Rollouts?

A. To automate Kubernetes cluster updates  
B. To provide progressive delivery strategies like blue-green and canary deployments  
C. To roll back failed deployments automatically  
D. To manage workflow execution

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Argo Rollouts is a Kubernetes controller that provides advanced deployment strategies (blue-green, canary) with fine-grained control, automated progressive delivery, and integration with service meshes and ingress controllers.

**Why others are wrong:**

- **A:** Cluster updates are separate from application deployments
- **C:** While rollback is a feature, progressive delivery is the primary purpose
- **D:** Workflow execution is Argo Workflows' domain

</details>

### Question 38

In a canary deployment, what does the `setWeight` step do?

A. Sets the percentage of traffic routed to the canary version  
B. Sets the number of replicas in the canary  
C. Sets the priority of the canary pods  
D. Sets the resource limits for canary pods

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`setWeight` in a canary strategy specifies what percentage of traffic should be routed to the new (canary) version. This requires integration with a traffic manager like Istio, Nginx, or ALB.

**Why others are wrong:**

- **B:** Replica count is controlled separately by the strategy
- **C:** Pod priority is a Kubernetes concept, not related to setWeight
- **D:** Resource limits are defined in pod specs, not rollout strategy

</details>

### Question 39

Which command promotes a paused Rollout to full deployment?

A. `kubectl argo rollouts promote rollout-name`  
B. `kubectl rollout promote rollout-name`  
C. `kubectl argo rollouts continue rollout-name`  
D. Both A and C

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
The `kubectl argo rollouts promote` command (or `argo rollouts promote`) immediately promotes a paused rollout to the next step or fully promotes it, skipping remaining steps.

**Why others are wrong:**

- **B:** This mixes standard kubectl rollout with Argo Rollouts commands incorrectly
- **C:** There is no `continue` command in Argo Rollouts
- **D:** C is incorrect, so this is wrong

</details>

### Question 40

What is the purpose of the `activeService` and `previewService` in a blue-green deployment?

A. activeService routes to current version, previewService routes to new version  
B. Both route to all versions for load balancing  
C. activeService is for production, previewService is for testing  
D. They are optional and only used for monitoring

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
In blue-green deployments, `activeService` always points to the currently active (stable) version, while `previewService` points to the new version being validated. After promotion, the services switch.

**Why others are wrong:**

- **B:** They route to specific versions, not all versions
- **C:** While preview is often used for testing, the technical function is version routing
- **D:** They are required for blue-green strategy to function

</details>

### Question 41

Which analysis template metric provider can be used for custom metrics?

A. Prometheus  
B. Datadog  
C. Web (HTTP/HTTPS requests)  
D. All of the above

**Correct Answer:** D

<details>
<summary>Explanation</summary>

**Why D is correct:**
Argo Rollouts supports multiple metric providers for analysis: Prometheus, Datadog, New Relic, Wavefront, Cloudwatch, Web (for custom HTTP endpoints), Job (Kubernetes Jobs), and Kayenta (Spinnaker's canary analysis service).

**Why others are wrong:**
Each option is correct but incomplete; all are supported providers.
</details>

### Question 42

What happens when an AnalysisRun fails during a canary deployment?

A. The rollout continues automatically  
B. The rollout is paused for manual intervention  
C. The rollout is automatically aborted and rolled back  
D. The analysis is ignored

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
By default, when an AnalysisRun fails (metrics indicate the new version is problematic), the rollout is automatically aborted and the Rollout returns to the previous stable version, protecting production.

**Why others are wrong:**

- **A:** Failed analysis prevents promotion to protect against bad deployments
- **B:** The default behavior is automatic abort, though you can configure pause on inconclusive results
- **D:** Analysis results are critical decision points for progressive delivery

</details>

### Question 43

What does the `autoPromotionEnabled: false` field do in a Rollout strategy?

A. Disables automatic rollback on failure  
B. Requires manual promotion between canary steps  
C. Disables analysis runs  
D. Prevents the rollout from starting

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
When `autoPromotionEnabled` is false, the rollout will pause at the first step and require manual promotion (via CLI or API) to proceed. This is useful for requiring human approval before proceeding.

**Why others are wrong:**

- **A:** Rollback behavior is separate from promotion settings
- **C:** Analysis runs are controlled by analysis configuration, not autoPromotion
- **D:** The rollout starts but pauses at the first step

</details>

### Question 44

Which Rollout strategy is BEST when you want to test a new version with a small amount of traffic before full rollout?

A. Blue-Green  
B. Canary  
C. Rolling Update  
D. Recreate

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Canary deployments gradually shift traffic to the new version in controlled increments (e.g., 10%, 25%, 50%, 100%), allowing testing with real traffic before full deployment.

**Why others are wrong:**

- **A:** Blue-green switches traffic all at once (0% to 100%)
- **C:** Rolling update replaces pods but doesn't control traffic splitting
- **D:** Recreate terminates all old pods before starting new ones

</details>

### Question 45

What is the purpose of the `scaleDownDelaySeconds` field in a blue-green strategy?

A. Delays the start of deployment  
B. Delays scaling down the old version after promotion  
C. Sets the timeout for promotion  
D. Delays analysis runs

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`scaleDownDelaySeconds` specifies how long to wait after promoting the new version before scaling down the old (preview) version. This allows time for connection draining and rollback if issues are detected immediately.

**Why others are wrong:**

- **A:** Deployment starts immediately when the Rollout is created/updated
- **C:** Promotion happens based on manual action or autoPromotion settings
- **D:** Analysis timing is controlled in AnalysisTemplate configuration

</details>

### Question 46

Which field in a Rollout spec defines the traffic routing provider?

A. `spec.strategy.canary.trafficManagement`  
B. `spec.trafficRouting`  
C. `spec.strategy.canary.trafficRouting`  
D. `spec.networking.trafficManager`

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
The traffic routing configuration is specified under `spec.strategy.canary.trafficRouting`, where you define the provider (Istio, Nginx, ALB, etc.) and relevant resource names.

**Why others are wrong:**

- **A:** `trafficManagement` is not the correct field name
- **B:** `trafficRouting` is not a top-level spec field
- **D:** `networking.trafficManager` is not a valid Rollout field

</details>

### Question 47

What does the following Rollout step configuration do?

```yaml
steps:
- setWeight: 20
- pause: {duration: 10m}
- setWeight: 50
- pause: {duration: 10m}
```

A. Sends 20% traffic to canary, waits 10min, then 50%, waits 10min  
B. Deploys 20% of pods, waits, then 50% of pods  
C. Fails due to missing analysis  
D. Requires manual promotion at each pause

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
This canary strategy first routes 20% of traffic to the new version, waits 10 minutes, then increases to 50%, and waits another 10 minutes. After the second pause, it would proceed to 100% (unless more steps are defined).

**Why others are wrong:**

- **B:** `setWeight` controls traffic percentage, not pod count (replica management is automatic)
- **C:** Analysis is optional; this configuration is valid
- **D:** `pause: {duration: 10m}` is an automatic timed pause, not manual

</details>

### Question 48

Which command shows the current status and history of a Rollout?

A. `kubectl get rollout rollout-name`  
B. `kubectl argo rollouts get rollout rollout-name`  
C. `kubectl describe rollout rollout-name`  
D. `kubectl argo rollouts status rollout-name`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`kubectl argo rollouts get rollout <name>` (or `argo rollouts get rollout <name>`) provides detailed status including current step, traffic weight, replica counts, and revision history.

**Why others are wrong:**

- **A:** This shows basic resource info but not detailed rollout status
- **C:** Describe shows events and config but not in the rollout-specific format
- **D:** `status` is not a valid subcommand for Argo Rollouts

</details>

### Question 49

What is an Experiment in Argo Rollouts?

A. A test environment for new features  
B. A way to run parallel ReplicaSets with different configurations for comparison  
C. A type of analysis template  
D. A rollback strategy

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
An Experiment is an Argo Rollouts resource that runs multiple ReplicaSets simultaneously (e.g., baseline vs candidate versions) for A/B testing or metric comparison, typically integrated with analysis.

**Why others are wrong:**

- **A:** While used for testing, it's a specific technical implementation, not just a test environment
- **C:** AnalysisTemplate is a separate resource; Experiments can use analysis but aren't analysis templates
- **D:** Rollback is a different concept; Experiments are for parallel testing

</details>

### Question 50

Which Rollout strategy provides the fastest rollback capability?

A. Canary  
B. Blue-Green  
C. Rolling Update  
D. They all have the same rollback speed

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Blue-green deployments maintain the old version at full scale during deployment, so rollback is instant (just switch the service back). Canary and rolling updates require scaling up the old version again.

**Why others are wrong:**

- **A:** Canary requires scaling down the new version and scaling up the old
- **C:** Rolling update requires similar scaling operations
- **D:** Blue-green is distinctly faster for rollback

</details>

### Question 51

What is the purpose of the `abortScaleDownDelaySeconds` field?

A. Delays the start of rollout abort  
B. Delays scaling down the canary after automatic abort  
C. Sets abort timeout  
D. Prevents scaling operations during abort

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
When a rollout is aborted (e.g., due to failed analysis), `abortScaleDownDelaySeconds` specifies how long to wait before scaling down the canary/new version. This allows time for investigation and potential manual override.

**Why others are wrong:**

- **A:** Abort happens immediately when triggered
- **C:** There is no abort timeout; abort is a state change
- **D:** Scaling is what's being delayed, not prevented

</details>

## Section 4: Argo Events (Questions 52-60)

### Question 52

What is the primary purpose of Argo Events?

A. To monitor Kubernetes events  
B. To trigger workflows and other Kubernetes resources based on events from various sources  
C. To log events to external systems  
D. To implement event-driven microservices

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Argo Events is an event-based dependency manager for Kubernetes. It listens to events from various sources (webhooks, S3, Kafka, etc.) and triggers actions like creating Workflows, Rollouts, or any Kubernetes resource.

**Why others are wrong:**

- **A:** It does use events but the purpose is triggering actions, not just monitoring
- **C:** Logging is not the primary purpose, though events can be logged
- **D:** While it enables event-driven patterns, it's specifically for triggering Kubernetes resources

</details>

### Question 53

What are the two main components in Argo Events?

A. EventSource and Trigger  
B. EventSource and Sensor  
C. Webhook and Workflow  
D. Source and Destination

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Argo Events uses EventSources (which define where events come from) and Sensors (which define what to do when events are received, including triggers).

**Why others are wrong:**

- **A:** Triggers are part of Sensors, not a top-level component
- **C:** These are specific implementations/uses, not the core components
- **D:** These are generic terms, not Argo Events components

</details>

### Question 54

Which EventSource type receives events via HTTP POST requests?

A. Webhook  
B. HTTP  
C. API  
D. REST

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
The Webhook EventSource exposes an HTTP endpoint that receives POST requests containing event payloads, commonly used for Git webhooks, CI/CD systems, or custom integrations.

**Why others are wrong:**

- **B:** While technically HTTP-based, the component is called "Webhook"
- **C:** "API" is not a specific EventSource type
- **D:** "REST" is not a specific EventSource type

</details>

### Question 55

What does a Sensor do when its event dependencies are satisfied?

A. Logs the event  
B. Executes configured triggers  
C. Stops listening for events  
D. Creates a new EventSource

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
When a Sensor's event dependencies are met (events received from specified EventSources), it executes its configured triggers, which can create Kubernetes resources, trigger workflows, or invoke other actions.

**Why others are wrong:**

- **A:** Logging may occur but execution is the primary action
- **C:** Sensors continue listening for subsequent events
- **D:** Sensors consume from EventSources, they don't create them

</details>

### Question 56

Which trigger type is used to create an Argo Workflow when an event occurs?

A. Workflow Trigger  
B. Argo Workflow Trigger  
C. K8s Resource Trigger  
D. Custom Trigger

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The "Argo Workflow" trigger type is specifically designed to create and submit Argo Workflows when sensor events are received.

**Why others are wrong:**

- **A:** The full name includes "Argo Workflow"
- **C:** While you could use K8s Resource trigger generically, Argo Workflow trigger is specific and optimized
- **D:** Custom triggers are for user-defined actions

</details>

### Question 57

What is the purpose of event filters in a Sensor?

A. To block malicious events  
B. To conditionally process events based on event data  
C. To rate limit events  
D. To encrypt event data

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Event filters allow Sensors to conditionally process events based on the event payload content. For example, only trigger on GitHub push events to the main branch, or only process events with specific field values.

**Why others are wrong:**

- **A:** Security is a benefit but not the primary purpose
- **C:** Rate limiting is a separate concern
- **D:** Encryption is not handled by filters

</details>

### Question 58

Which EventSource type monitors S3 bucket notifications?

A. S3  
B. AWS S3  
C. Minio  
D. Both A and C

**Correct Answer:** D

<details>
<summary>Explanation</summary>

**Why D is correct:**
Argo Events supports both "AWS SNS" (which can receive S3 notifications) and "Minio" EventSources for S3-compatible bucket notifications. The specific type depends on your storage implementation.

**Why others are wrong:**

- **A, C:** Both are correct but incomplete answers
- **B:** The EventSource type is "AWS SNS" not "AWS S3"

</details>

### Question 59

What does the following Sensor dependency configuration mean?

```yaml
dependencies:
- name: webhook-dep
  eventSourceName: webhook
  eventName: example
- name: calendar-dep
  eventSourceName: calendar
  eventName: hourly
```

A. Triggers when either event occurs  
B. Triggers only when both events occur  
C. Triggers when webhook fires, then waits for calendar  
D. Invalid configuration

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
By default, multiple dependencies require ALL events to be received before triggers fire (AND logic). This creates an event dependency where both webhook and calendar events must occur.

**Why others are wrong:**

- **A:** OR logic requires specific dependencyLogic configuration
- **C:** There's no sequential waiting; both must occur (order doesn't matter)
- **D:** This is valid Sensor configuration

</details>

### Question 60

Which of the following is NOT a valid EventSource type in Argo Events?

A. Kafka  
B. Redis  
C. PostgreSQL  
D. GitHub

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
PostgreSQL is not a built-in EventSource type in Argo Events. Common sources include Webhook, Kafka, Redis, AWS SNS, GitHub, GitLab, Slack, Calendar, Resource (Kubernetes), and others.

**Why others are wrong:**

- **A:** Kafka is a supported EventSource for streaming events
- **B:** Redis is supported for pub/sub patterns
- **D:** GitHub is supported for repository webhooks

</details>

## Answer Key

### Argo CD (Questions 1-21)

| Question | Answer | Question | Answer | Question | Answer |
|----------|--------|----------|--------|----------|--------|
| 1 | C | 8 | B | 15 | B |
| 2 | B | 9 | B | 16 | D |
| 3 | C | 10 | C | 17 | B |
| 4 | B | 11 | B | 18 | A |
| 5 | B | 12 | B | 19 | D |
| 6 | B | 13 | B | 20 | B |
| 7 | A | 14 | A | 21 | B |

**Argo CD Score: _____ / 21**

### Argo Workflows (Questions 22-36)

| Question | Answer | Question | Answer | Question | Answer |
|----------|--------|----------|--------|----------|--------|
| 22 | B | 27 | C | 32 | B |
| 23 | B | 28 | B | 33 | B |
| 24 | B | 29 | B | 34 | B |
| 25 | B | 30 | A | 35 | B |
| 26 | C | 31 | B | 36 | A |

**Argo Workflows Score: _____ / 15**

### Argo Rollouts (Questions 37-51)

| Question | Answer | Question | Answer | Question | Answer |
|----------|--------|----------|--------|----------|--------|
| 37 | B | 42 | C | 47 | A |
| 38 | A | 43 | B | 48 | B |
| 39 | A | 44 | B | 49 | B |
| 40 | A | 45 | B | 50 | B |
| 41 | D | 46 | C | 51 | B |

**Argo Rollouts Score: _____ / 15**

### Argo Events (Questions 52-60)

| Question | Answer | Question | Answer |
|----------|--------|----------|--------|
| 52 | B | 57 | B |
| 53 | B | 58 | D |
| 54 | A | 59 | B |
| 55 | B | 60 | C |
| 56 | B | | |

**Argo Events Score: _____ / 9**

## Final Score Calculation

**Total Correct: _____ / 60**

**Percentage: _____ %**

**Result: [ ] PASS (70%+) [ ] FAIL (Below 70%)**

### Score Interpretation

- **54-60 (90-100%):** Excellent! You're well-prepared for the CAPA exam.
- **48-53 (80-89%):** Very good! Review weak areas and you should be ready.
- **42-47 (70-79%):** Good, passing score. More study recommended for confidence.
- **36-41 (60-69%):** Fair. Significant additional study needed.
- **Below 36 (<60%):** Needs work. Focus on fundamentals and retake this exam.

### Next Steps

1. Review all explanations, especially for incorrect answers
2. Identify weak domains (score each Section separately)
3. Study focused material for low-scoring areas
4. Take Mock Exam Set 2 after additional study
5. Continue practice until consistently scoring 75%+
