# CAPA Mock Exam - Set 2

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

Which component in Argo CD is responsible for generating manifests from Helm charts?

A. Application Controller  
B. Repo Server  
C. API Server  
D. Dex

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The Repo Server is responsible for cloning Git repositories and generating manifests from various sources including Helm, Kustomize, Jsonnet, and plain YAML/JSON.

**Why others are wrong:**

- **A:** Application Controller performs reconciliation, not manifest generation
- **C:** API Server handles API requests and serves the UI
- **D:** Dex handles authentication

</details>

### Question 2

What does the `Replace=true` sync option do?

A. Replaces all resources in the namespace  
B. Uses kubectl replace instead of kubectl apply  
C. Replaces only changed resources  
D. Replaces the Application definition

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `Replace=true` sync option tells Argo CD to use `kubectl replace` instead of the default `kubectl apply` command when syncing resources. This is useful for resources that don't support patch operations.

**Why others are wrong:**

- **A:** It only affects how resources are applied, not which resources
- **C:** The behavior is about the kubectl command used, not selectivity
- **D:** It affects resource synchronization, not the Application CRD itself

</details>

### Question 3

How can you prevent Argo CD from pruning resources that are no longer in Git?

A. Set `syncPolicy.automated.prune: false`  
B. Add annotation `argocd.argoproj.io/prune: false`  
C. Remove automated sync policy  
D. Both A and B

**Correct Answer: D**

<details>
<summary>Explanation</summary>

**Why D is correct:**
You can prevent pruning globally for an application with `syncPolicy.automated.prune: false`, or for specific resources using the `argocd.argoproj.io/sync-options: Prune=false` annotation.

**Why others are wrong:**
Both A and B are correct approaches at different scopes, so D is the most complete answer.
</details>

### Question 4

What is the purpose of the `argocd app sync --dry-run` command?

A. To test Git connectivity  
B. To preview what changes would be made without applying them  
C. To validate YAML syntax  
D. To check application health

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `--dry-run` flag performs a sync operation preview, showing what resources would be created, updated, or deleted without actually making changes to the cluster.

**Why others are wrong:**

- **A:** Git connectivity is tested automatically during normal operations
- **C:** YAML validation happens during manifest generation
- **D:** Health checking is separate from sync preview

</details>

### Question 5

Which Argo CD health status indicates that an application is fully operational?

A. Synced  
B. Healthy  
C. Running  
D. Ready

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
"Healthy" status indicates all resources are running and passing their health checks. This is the desired operational state.

**Why others are wrong:**

- **A:** "Synced" refers to sync status (Git matches cluster), not health
- **C:** "Running" is not a standard Argo CD health status
- **D:** "Ready" is not a standard Argo CD health status (though pods may be ready)

</details>

### Question 6

What happens when you set `spec.destination.namespace` to a namespace that doesn't exist and don't use CreateNamespace sync option?

A. Argo CD creates the namespace automatically  
B. The sync fails with an error  
C. Resources are created in the default namespace  
D. The application enters Progressing state indefinitely

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Without the `CreateNamespace=true` sync option, attempting to sync to a non-existent namespace will cause the sync to fail with an error about the namespace not existing.

**Why others are wrong:**

- **A:** Automatic creation only happens with the CreateNamespace sync option
- **C:** Argo CD doesn't fall back to default namespace
- **D:** The sync fails rather than entering Progressing indefinitely

</details>

### Question 7

Which field in an Application allows you to ignore differences in specific resource fields?

A. `spec.ignoreFields`  
B. `spec.ignoreDifferences`  
C. `spec.compareOptions`  
D. `spec.diffOptions`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`spec.ignoreDifferences` allows you to specify JSON paths or fields to ignore when comparing desired state vs live state. This is useful for fields managed by controllers or operators.

**Why others are wrong:**

- **A, C, D:** These are not valid Application spec fields

</details>

### Question 8

What is an ApplicationSet?

A. A group of related applications  
B. A template for generating multiple Argo CD Applications  
C. A collection of AppProjects  
D. A set of sync policies

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
ApplicationSet is a CRD that uses generators (list, cluster, git, etc.) to template and create multiple Argo CD Applications from a single definition, enabling multi-tenancy and cluster management at scale.

**Why others are wrong:**

- **A:** While it does create multiple apps, it's specifically a templating/generation mechanism
- **C:** AppProjects are managed separately
- **D:** Sync policies are configured within Applications

</details>

### Question 9

Which ApplicationSet generator creates applications from directories in a Git repository?

A. Directory Generator  
B. Git Generator  
C. List Generator  
D. Cluster Generator

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The Git Generator (specifically the Git Directory generator variant) scans directories in a Git repository and creates applications for each directory matching specified patterns.

**Why others are wrong:**

- **A:** "Directory Generator" is not the official name
- **C:** List Generator creates apps from a static list
- **D:** Cluster Generator creates apps based on registered clusters

</details>

### Question 10

What does the refresh operation do in Argo CD?

A. Restarts the Argo CD pods  
B. Forces a comparison between Git and the live cluster state  
C. Updates the Application manifest  
D. Clears the cache

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Refresh forces Argo CD to re-fetch from Git and re-compare with the cluster immediately, rather than waiting for the next automatic reconciliation cycle.

**Why others are wrong:**

- **A:** Pod restarts are done through standard Kubernetes operations
- **C:** Application manifests are updated through Git or API calls
- **D:** While cache may be refreshed as part of this, the primary purpose is state comparison

</details>

### Question 11

Which annotation prevents Argo CD from trying to delete a resource?

A. `argocd.argoproj.io/sync-options: Delete=false`  
B. `argocd.argoproj.io/sync-options: Prune=false`  
C. `argocd.argoproj.io/protected: "true"`  
D. `kubectl.kubernetes.io/prune: "false"`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `Prune=false` sync option prevents Argo CD from deleting (pruning) a resource when it's removed from Git or no longer tracked.

**Why others are wrong:**

- **A:** `Delete=false` is not a valid sync option
- **C:** This is not a recognized Argo CD annotation
- **D:** This is a Kubernetes annotation, not Argo CD-specific

</details>

### Question 12

What is the purpose of sync waves in Argo CD?

A. To group applications for batch operations  
B. To control the order of resource creation during sync  
C. To define retry attempts  
D. To set sync frequency

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Sync waves (defined with `argocd.argoproj.io/sync-wave` annotation) control resource creation order. Lower wave numbers are created first, allowing you to ensure dependencies are satisfied.

**Why others are wrong:**

- **A:** While they group resources, the primary purpose is ordering
- **C:** Retry is controlled by sync policy
- **D:** Sync frequency is controlled by reconciliation timeout

</details>

### Question 13

Which command shows detailed information about an Argo CD Application, including sync status and health?

A. `argocd app list myapp`  
B. `argocd app get myapp`  
C. `argocd app describe myapp`  
D. `argocd app info myapp`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`argocd app get` provides comprehensive information about an application including sync status, health status, parameters, and recent sync operations.

**Why others are wrong:**

- **A:** `list` shows multiple apps in summary format
- **C, D:** These are not valid argocd commands

</details>

### Question 14

What does the `ServerSideApply=true` sync option do?

A. Applies manifests on the server side instead of client side  
B. Uses kubectl server-side apply feature  
C. Applies changes using the API server directly  
D. Enables server-side validation

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
This sync option enables Kubernetes server-side apply (SSA), which provides better conflict resolution and field management compared to client-side apply.

**Why others are wrong:**

- **A:** While technically true, this doesn't explain the specific Kubernetes SSA feature
- **C:** All kubectl commands use the API server
- **D:** Validation is separate from apply strategy

</details>

### Question 15

How can you temporarily suspend auto-sync for an Application?

A. Delete the syncPolicy section  
B. Set `syncPolicy.automated: null`  
C. Use `argocd app set myapp --sync-policy none`  
D. All of the above

**Correct Answer: D**

<details>
<summary>Explanation</summary>

**Why D is correct:**
All three methods effectively disable auto-sync: removing the syncPolicy section, setting automated to null, or using the CLI to set sync policy to none.

**Why others are wrong:**
Each option is valid, making D the most complete answer.
</details>

### Question 16

What is the purpose of the `argocd-cm` ConfigMap?

A. To store Application manifests  
B. To configure Argo CD system settings  
C. To store Git credentials  
D. To cache manifest data

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The `argocd-cm` ConfigMap contains system-wide configuration for Argo CD, including repository credentials templates, resource customizations, and other global settings.

**Why others are wrong:**

- **A:** Applications are stored as CRDs, not in ConfigMaps
- **C:** Credentials are stored in Secrets, not this ConfigMap
- **D:** Redis handles caching

</details>

### Question 17

Which sync option forces a sync even if the application is already synced?

A. `Force=true`  
B. `Retry=true`  
C. `Refresh=true`  
D. Syncing always forces regardless of status

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
The `Force=true` sync option (or `--force` flag in CLI) forces a sync operation even if Argo CD believes the application is already synced.

**Why others are wrong:**

- **B:** `Retry=true` is not a valid sync option
- **C:** Refresh updates comparison, doesn't force sync
- **D:** Normal sync operations respect current sync status

</details>

### Question 18

What happens when an Application's source Git repository is deleted?

A. The Application automatically deletes  
B. The Application shows ComparisonError status  
C. Argo CD continues using cached manifests  
D. The Application is suspended

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
When Argo CD cannot access the source repository (deleted, unreachable, or credentials invalid), the Application enters ComparisonError status indicating it cannot compare states.

**Why others are wrong:**

- **A:** Applications don't auto-delete; manual cleanup is needed
- **C:** Cache expires; long-term unavailability causes errors
- **D:** Suspension is manual, not automatic on repo issues

</details>

### Question 19

Which AppProject field restricts which resource types can be deployed?

A. `spec.resourceWhitelist`  
B. `spec.clusterResourceWhitelist`  
C. `spec.allowedResources`  
D. Both A and B

**Correct Answer: D**

<details>
<summary>Explanation</summary>

**Why D is correct:**
AppProjects use both `clusterResourceWhitelist` (for cluster-scoped resources like ClusterRole) and `namespaceResourceWhitelist` (for namespaced resources) to restrict allowed resource types.

**Why others are wrong:**

- **A:** The field is `namespaceResourceWhitelist`, not just `resourceWhitelist`
- **B:** This is correct but incomplete
- **C:** `allowedResources` is not a valid field

</details>

### Question 20

What does the `PruneLast=true` sync option do?

A. Prunes resources at the end of sync instead of the beginning  
B. Prunes only the last deployed resources  
C. Delays pruning by one sync cycle  
D. Prevents pruning of the most recent resources

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`PruneLast=true` ensures that resources marked for deletion are pruned at the end of the sync operation, after new/updated resources are created. This helps avoid downtime.

**Why others are wrong:**

- **B:** It affects timing, not which resources are pruned
- **C:** Pruning happens during the same sync, just at the end
- **D:** All resources marked for pruning are still pruned

</details>

### Question 21

Which Argo CD component handles user authentication?

A. Application Controller  
B. API Server with Dex  
C. Repo Server  
D. Redis

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The Argo CD API Server handles authentication, often integrating with Dex for SSO (OIDC, SAML, LDAP, etc.). It also supports built-in users and tokens.

**Why others are wrong:**

- **A:** Application Controller manages application reconciliation
- **C:** Repo Server handles Git operations
- **D:** Redis is used for caching

</details>

## Section 2: Argo Workflows (Questions 22-36)

### Question 22

What is the purpose of a Container template in Argo Workflows?

A. To pull container images  
B. To define a single container to execute  
C. To build container images  
D. To manage container registries

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
A Container template is the most basic template type that defines a single container to run, including the image, commands, arguments, and environment variables.

**Why others are wrong:**

- **A:** Image pulling is automatic based on image specification
- **C:** Building images requires specific tools/steps, not a template type
- **D:** Registry management is external to workflows

</details>

### Question 23

Which artifact location must be configured before using artifacts in Workflows?

A. S3, GCS, or other supported artifact repository  
B. Local filesystem  
C. Docker registry  
D. None, artifacts work without configuration

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
Artifacts require configuration of an artifact repository (S3, GCS, Azure Blob, etc.) in the workflow controller ConfigMap or namespace-level configuration.

**Why others are wrong:**

- **B:** Local filesystem is not persistent across pods
- **C:** Docker registries are for images, not workflow artifacts
- **D:** Artifact repository configuration is required

</details>

### Question 24

What does the `outputs.parameters` field do in a Workflow template?

A. Sends parameters to external systems  
B. Defines parameters that can be used by subsequent steps  
C. Outputs parameters to logs  
D. Validates input parameters

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Output parameters capture data from a step (from stdout, files, or JSON paths) and make it available for use by subsequent steps via variable substitution.

**Why others are wrong:**

- **A:** External system integration is separate
- **C:** Logging is automatic for all output
- **D:** Validation is for inputs, not outputs

</details>

### Question 25

Which command deletes a completed Workflow?

A. `argo delete workflow-name`  
B. `argo remove workflow-name`  
C. `kubectl delete workflow workflow-name`  
D. Both A and C

**Correct Answer: D**

<details>
<summary>Explanation</summary>

**Why D is correct:**
Both `argo delete` and `kubectl delete workflow` can delete workflow resources. Argo CLI provides additional features like bulk deletion.

**Why others are wrong:**

- **B:** `remove` is not a valid argo command

</details>

### Question 26

What is the purpose of the `withItems` field in a Workflow?

A. To iterate over a list and execute a template for each item  
B. To include multiple templates in a step  
C. To attach items to artifacts  
D. To list workflow parameters

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`withItems` allows you to iterate over a list (either static or dynamic from parameters) and execute the template once for each item, enabling fan-out parallelism.

**Why others are wrong:**

- **B:** Multiple templates use different mechanisms
- **C:** Artifacts have separate attachment mechanisms
- **D:** Parameters are defined elsewhere

</details>

### Question 27

What does the `memoization` feature do in Argo Workflows?

A. Stores workflow history  
B. Caches step outputs to skip re-execution of identical steps  
C. Improves memory usage  
D. Creates workflow backups

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Memoization caches the outputs of steps based on input parameters and template, allowing Argo to skip re-execution when the same step is encountered with identical inputs.

**Why others are wrong:**

- **A:** History is maintained separately
- **C:** While it may indirectly help, the purpose is execution optimization
- **D:** Backups are a separate concern

</details>

### Question 28

Which template type runs a Kubernetes resource to completion?

A. Container  
B. Resource  
C. Script  
D. Suspend

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Resource templates create, monitor, and wait for Kubernetes resources (like Jobs or Pods) to complete. They're useful for integrating with other Kubernetes workloads.

**Why others are wrong:**

- **A:** Container templates run containers, not arbitrary K8s resources
- **C:** Script templates run scripts in containers
- **D:** Suspend templates pause execution

</details>

### Question 29

What is the purpose of a WorkflowEventBinding?

A. To bind workflows to specific namespaces  
B. To trigger workflows based on workflow events  
C. To bind events to workflow steps  
D. To connect workflows to external event systems

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
WorkflowEventBindings (when used with Argo Events) allow workflows to trigger other workflows based on workflow lifecycle events (success, failure, etc.).

**Why others are wrong:**

- **A:** Namespace binding is through resource namespace field
- **C:** Steps are bound through template structure
- **D:** External events use Argo Events EventSources

</details>

### Question 30

Which field limits the number of parallel pods at the template level?

A. `parallelism`  
B. `limit`  
C. `concurrency`  
D. Template-level parallelism is not supported

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`parallelism` can be set at both workflow and template level to limit concurrent pod execution. Template-level settings override workflow-level settings.

**Why others are wrong:**

- **B, C:** These are not valid fields for this purpose
- **D:** Template-level parallelism is supported

</details>

### Question 31

What does the `exitCode` output parameter represent?

A. The workflow exit status  
B. The exit code of a container execution  
C. The error code from Kubernetes  
D. The sync status code

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`exitCode` is an automatic output parameter that captures the exit code of the container execution, useful for conditional logic based on success/failure.

**Why others are wrong:**

- **A:** Workflow status is tracked separately
- **C:** Kubernetes errors are separate
- **D:** Sync status is an Argo CD concept

</details>

### Question 32

Which workflow submission option allows you to override parameters?

A. `--parameter` or `-p`  
B. `--param`  
C. `--override`  
D. `--set`

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
When submitting workflows, you can override parameters defined in the workflow using `--parameter key=value` or `-p key=value`.

**Why others are wrong:**

- **B, C, D:** These are not the correct flags for argo submit

</details>

### Question 33

What is the purpose of the `archive` feature in Argo Workflows?

A. To compress workflow logs  
B. To store completed workflow data in a database for long-term access  
C. To backup workflows to external storage  
D. To reduce workflow memory usage

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The archive feature stores completed workflow metadata and status in a PostgreSQL or MySQL database, allowing long-term retention and queries even after workflows are deleted from Kubernetes.

**Why others are wrong:**

- **A:** Log compression is separate
- **C:** While it stores data, the purpose is queryable history, not backup
- **D:** Memory reduction is a side effect, not the primary purpose

</details>

### Question 34

Which expression syntax is used for parameter substitution in Argo Workflows?

A. `${parameter}`  
B. `{{inputs.parameters.name}}`  
C. `#{parameter}`  
D. `$parameter`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Argo Workflows uses double curly brace syntax for variable substitution, accessing parameters, artifacts, and outputs (e.g., `{{inputs.parameters.name}}`).

**Why others are wrong:**

- **A, C, D:** These are not the correct Argo Workflows syntax

</details>

### Question 35

What happens when a step in a DAG template fails?

A. The entire workflow fails immediately  
B. Dependent tasks are skipped, but independent tasks continue  
C. The workflow retries automatically  
D. The workflow pauses for manual intervention

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
In DAG templates, when a task fails, tasks that depend on it (via dependencies field) are skipped, but tasks without that dependency continue executing.

**Why others are wrong:**

- **A:** The workflow continues for independent tasks
- **C:** Retry requires explicit retryStrategy configuration
- **D:** Pause requires suspend template or manual action

</details>

### Question 36

Which field in a CronWorkflow specifies the schedule?

A. `spec.schedule`  
B. `spec.cron`  
C. `spec.cronExpression`  
D. `spec.timing`

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`spec.schedule` in a CronWorkflow uses standard cron syntax to define when workflows should be created and executed.

**Why others are wrong:**

- **B, C, D:** These are not valid CronWorkflow fields

</details>

## Section 3: Argo Rollouts (Questions 37-51)

### Question 37

What Kubernetes resource does an Argo Rollout replace?

A. StatefulSet  
B. Deployment  
C. DaemonSet  
D. Job

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Argo Rollouts is a drop-in replacement for Kubernetes Deployments, providing advanced deployment strategies while maintaining similar API structure.

**Why others are wrong:**

- **A, C, D:** These resources have different purposes and are not replaced by Rollouts

</details>

### Question 38

In a canary deployment, what does `maxSurge` control?

A. Maximum traffic percentage to canary  
B. Maximum number of additional pods during rollout  
C. Maximum time for canary evaluation  
D. Maximum number of canary steps

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`maxSurge` defines how many pods can be created above the desired replica count during an update, controlling resource usage during rollout.

**Why others are wrong:**

- **A:** Traffic percentage is controlled by setWeight
- **C:** Time is controlled by pause durations
- **D:** Steps are defined in the strategy, not limited by maxSurge

</details>

### Question 39

Which command aborts an ongoing Rollout and reverts to the previous version?

A. `kubectl argo rollouts abort rollout-name`  
B. `kubectl argo rollouts undo rollout-name`  
C. `kubectl argo rollouts revert rollout-name`  
D. `kubectl argo rollouts retry rollout-name`

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`kubectl argo rollouts abort` (or `argo rollouts abort`) immediately aborts the current rollout and scales down the new ReplicaSet, reverting to the stable version.

**Why others are wrong:**

- **B, C, D:** These are not valid Argo Rollouts commands

</details>

### Question 40

What is an AnalysisTemplate?

A. A template for defining metrics and success criteria  
B. A template for workflow analysis  
C. A template for cluster analysis  
D. A template for generating rollout strategies

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
AnalysisTemplate defines which metrics to query, from which provider (Prometheus, Datadog, etc.), and what thresholds determine success or failure.

**Why others are wrong:**

- **B, C, D:** AnalysisTemplate is specific to Rollout metric evaluation

</details>

### Question 41

Which traffic management provider requires `VirtualService` configuration?

A. Nginx Ingress  
B. AWS ALB  
C. Istio  
D. Traefik

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
Istio uses VirtualService resources for traffic splitting. Argo Rollouts integrates with Istio by modifying VirtualService weights during canary deployments.

**Why others are wrong:**

- **A:** Nginx uses Ingress annotations
- **B:** ALB uses Ingress annotations or ALB-specific resources
- **D:** Traefik uses Ingress or TraefikService resources

</details>

### Question 42

What does the `autoPromotionSeconds` field do?

A. Automatically promotes after specified seconds if analysis passes  
B. Automatically promotes regardless of analysis after specified seconds  
C. Sets the timeout for promotion  
D. Delays promotion by specified seconds

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`autoPromotionSeconds` automatically promotes the rollout after the specified duration if no analysis fails and no manual intervention occurs.

**Why others are wrong:**

- **B:** Promotion still respects analysis results
- **C:** It triggers promotion, not timeout
- **D:** It's a trigger duration, not a delay

</details>

### Question 43

Which command shows the detailed steps and current progress of a Rollout?

A. `kubectl argo rollouts status rollout-name`  
B. `kubectl argo rollouts get rollout rollout-name`  
C. `kubectl argo rollouts describe rollout-name`  
D. `kubectl get rollout rollout-name -o yaml`

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`kubectl argo rollouts get rollout` provides detailed rollout information including current step, traffic weights, replica counts, and revision history in a readable format.

**Why others are wrong:**

- **A:** `status` is not a valid subcommand
- **C:** `describe` is not a valid subcommand
- **D:** This shows raw YAML, not formatted rollout status

</details>

### Question 44

What is the purpose of `analysis.args` in a Rollout strategy?

A. To pass arguments to analysis containers  
B. To pass values to AnalysisTemplate parameters  
C. To configure analysis frequency  
D. To set analysis timeout

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`analysis.args` allows passing dynamic values (like pod hash, service name, etc.) to AnalysisTemplate parameters, enabling reusable templates.

**Why others are wrong:**

- **A:** Analysis doesn't run containers (unless using Job provider)
- **C:** Frequency is controlled by interval setting
- **D:** Timeout is a separate configuration

</details>

### Question 45

In blue-green deployment, which service receives production traffic?

A. Both active and preview services  
B. The active service  
C. The preview service  
D. A separate production service

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The active service always points to the stable, production version and receives all production traffic. The preview service points to the new version during testing.

**Why others are wrong:**

- **A:** Only active receives production traffic
- **C:** Preview is for testing, not production traffic
- **D:** Active service is the production service

</details>

### Question 46

What does the `pause: {}` step do (empty pause)?

A. Pauses indefinitely until manually promoted  
B. Skips the pause  
C. Pauses for default duration  
D. Invalid configuration

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
An empty pause step (`pause: {}` without duration) creates an indefinite pause requiring manual promotion via CLI or API.

**Why others are wrong:**

- **B:** Empty pause does pause execution
- **C:** There's no default duration; it's indefinite
- **D:** This is valid syntax

</details>

### Question 47

Which metric provider uses Kubernetes Jobs for analysis?

A. Prometheus  
B. Job Provider  
C. Kubernetes Provider  
D. Custom Provider

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The Job provider in AnalysisTemplate runs Kubernetes Jobs to perform custom analysis logic, useful for complex validation that doesn't fit other providers.

**Why others are wrong:**

- **A:** Prometheus queries Prometheus servers
- **C, D:** These are not correct provider names

</details>

### Question 48

What is the purpose of `minPodsPerReplicaSet` in a Rollout strategy?

A. Sets minimum pods for the Rollout  
B. Ensures a minimum number of pods in each ReplicaSet during rollout  
C. Sets the minimum replica count  
D. Validates pod count

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
`minPodsPerReplicaSet` ensures both old and new ReplicaSets maintain at least this many pods during rollout, preventing complete drain of either version.

**Why others are wrong:**

- **A:** Total pod count is controlled by replicas
- **C:** Replicas are set separately
- **D:** It enforces minimums, not validates

</details>

### Question 49

Which command restarts a Rollout (equivalent to kubectl rollout restart)?

A. `kubectl argo rollouts restart rollout-name`  
B. `kubectl argo rollouts retry rollout-name`  
C. `kubectl rollout restart rollout rollout-name`  
D. `kubectl argo rollouts promote rollout-name --full`

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`kubectl argo rollouts restart` triggers a restart of the Rollout, similar to kubectl rollout restart for Deployments.

**Why others are wrong:**

- **B:** `retry` retries a failed rollout
- **C:** `rollout` doesn't directly work with Rollout CRDs
- **D:** `promote` advances through steps, doesn't restart

</details>

### Question 50

What happens when you change the Rollout spec without changing the pod template?

A. Nothing, no rollout is triggered  
B. A new rollout starts immediately  
C. The Rollout enters error state  
D. Pods are restarted

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
Rollouts, like Deployments, only trigger when the pod template spec changes. Changes to strategy, service names, or other non-template fields don't trigger rollouts.

**Why others are wrong:**

- **B:** Rollout only triggers on template changes
- **C:** Valid config changes don't cause errors
- **D:** Pods aren't restarted without template changes

</details>

### Question 51

Which field specifies how long to wait before considering an AnalysisRun failed due to timeout?

A. `spec.timeout`  
B. `spec.metrics[].failureLimit`  
C. `spec.metrics[].timeout`  
D. `spec.deadline`

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`spec.timeout` in an AnalysisTemplate or AnalysisRun defines the maximum duration for the analysis to complete before it's considered failed.

**Why others are wrong:**

- **B:** `failureLimit` sets how many metric failures are tolerated
- **C:** Individual metric timeout is separate from overall timeout
- **D:** `deadline` is not a valid field

</details>

## Section 4: Argo Events (Questions 52-60)

### Question 52

What does the EventBus resource do in Argo Events?

A. Routes events between components  
B. Provides messaging infrastructure for event transport  
C. Filters events  
D. Stores event history

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
EventBus provides the underlying messaging infrastructure (NATS, Jetstream, or Kafka) that transports events from EventSources to Sensors.

**Why others are wrong:**

- **A:** While events flow through it, it's specifically the messaging infrastructure
- **C:** Filtering happens in Sensors
- **D:** History is stored elsewhere if needed

</details>

### Question 53

Which EventSource type monitors Kubernetes resources for changes?

A. K8s EventSource  
B. Resource EventSource  
C. Kubernetes EventSource  
D. Watcher EventSource

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Resource EventSource watches Kubernetes resources (like Pods, Deployments, ConfigMaps) and generates events when they change, allowing event-driven automation based on cluster state.

**Why others are wrong:**

- **A, C, D:** These are not the official names

</details>

### Question 54

What is the purpose of `dependencyLogic` in a Sensor?

A. To define AND/OR logic for event dependencies  
B. To set dependency order  
C. To create dependency graphs  
D. To validate dependencies

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
`dependencyLogic` allows you to specify custom boolean logic (AND, OR, combinations) for when triggers should fire based on which dependencies are satisfied.

**Why others are wrong:**

- **B:** Order is implicit in the logic expression
- **C:** Graphs are not created by this field
- **D:** Validation is automatic

</details>

### Question 55

Which trigger type creates arbitrary Kubernetes resources?

A. Kubernetes Resource Trigger  
B. K8s Trigger  
C. HTTP Trigger  
D. Custom Trigger

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
The "K8s" trigger type (also called Kubernetes trigger) can create any Kubernetes resource when sensor events are received, not just workflows.

**Why others are wrong:**

- **A:** The type is abbreviated as "K8s"
- **C:** HTTP trigger sends HTTP requests
- **D:** Custom triggers are for user-defined actions

</details>

### Question 56

What does the `calendar` EventSource do?

A. Monitors calendar applications  
B. Generates events on a schedule or at specific times  
C. Syncs with external calendars  
D. Manages event timestamps

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Calendar EventSource generates events based on cron schedules or interval timers, useful for scheduled workflows or periodic triggers.

**Why others are wrong:**

- **A, C:** It doesn't integrate with calendar apps
- **D:** Timestamping is automatic for all events

</details>

### Question 57

Which EventSource type receives events from AWS SNS?

A. SNS EventSource  
B. AWS EventSource  
C. Amazon EventSource  
D. PubSub EventSource

**Correct Answer: A**

<details>
<summary>Explanation</summary>

**Why A is correct:**
The SNS EventSource subscribes to AWS SNS topics and receives notifications, commonly used with S3 events, CloudWatch alarms, and other AWS services.

**Why others are wrong:**

- **B, C:** The specific type is "SNS"
- **D:** PubSub is for Google Cloud Pub/Sub

</details>

### Question 58

What is the purpose of event data filters in Sensors?

A. To block unwanted events  
B. To transform event data  
C. To conditionally process events based on payload content  
D. To validate event schema

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
Data filters (using JSONPath) allow Sensors to conditionally process events based on specific field values in the event payload, enabling selective triggering.

**Why others are wrong:**

- **A:** While blocking is a result, the mechanism is conditional processing
- **B:** Transformation is done in triggers, not filters
- **D:** Schema validation is separate

</details>

### Question 59

Which protocol does the Webhook EventSource use?

A. HTTPS only  
B. HTTP only  
C. Both HTTP and HTTPS  
D. WebSocket

**Correct Answer: C**

<details>
<summary>Explanation</summary>

**Why C is correct:**
Webhook EventSource can expose both HTTP and HTTPS endpoints to receive webhook payloads. HTTPS support requires certificate configuration.

**Why others are wrong:**

- **A, B:** Both protocols are supported
- **D:** WebSocket is a different protocol, not used for webhook EventSource

</details>

### Question 60

What happens when a Sensor receives an event but its trigger fails?

A. The event is lost  
B. The event is retried based on retry configuration  
C. The Sensor stops processing events  
D. The EventSource is notified

**Correct Answer: B**

<details>
<summary>Explanation</summary>

**Why B is correct:**
Sensors support retry configuration for trigger execution. If a trigger fails (e.g., failed to create workflow), it can be retried based on the retry policy.

**Why others are wrong:**

- **A:** Events can be retried
- **C:** The Sensor continues processing new events
- **D:** EventSources are independent of trigger results

</details>

## Answer Key

### Argo CD (Questions 1-21)

| Question | Answer | Question | Answer | Question | Answer |
|----------|--------|----------|--------|----------|--------|
| 1 | B | 8 | B | 15 | D |
| 2 | B | 9 | B | 16 | B |
| 3 | D | 10 | B | 17 | A |
| 4 | B | 11 | B | 18 | B |
| 5 | B | 12 | B | 19 | D |
| 6 | B | 13 | B | 20 | A |
| 7 | B | 14 | B | 21 | B |

**Argo CD Score: _____ / 21**

### Argo Workflows (Questions 22-36)

| Question | Answer | Question | Answer | Question | Answer |
|----------|--------|----------|--------|----------|--------|
| 22 | B | 27 | B | 32 | A |
| 23 | A | 28 | B | 33 | B |
| 24 | B | 29 | B | 34 | B |
| 25 | D | 30 | A | 35 | B |
| 26 | A | 31 | B | 36 | A |

**Argo Workflows Score: _____ / 15**

### Argo Rollouts (Questions 37-51)

| Question | Answer | Question | Answer | Question | Answer |
|----------|--------|----------|--------|----------|--------|
| 37 | B | 42 | A | 47 | B |
| 38 | B | 43 | B | 48 | B |
| 39 | A | 44 | B | 49 | A |
| 40 | A | 45 | B | 50 | A |
| 41 | C | 46 | A | 51 | A |

**Argo Rollouts Score: _____ / 15**

### Argo Events (Questions 52-60)

| Question | Answer | Question | Answer |
|----------|--------|----------|--------|
| 52 | B | 57 | A |
| 53 | B | 58 | C |
| 54 | A | 59 | C |
| 55 | B | 60 | B |
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
2. Compare scores with Mock Exam Set 1 to measure improvement
3. Identify weak domains and focus study efforts
4. Retake both exams after additional preparation
5. Complete all hands-on labs for weak areas
6. Continue practice until consistently scoring 75%+
