# Argo Workflows Labs

Hands-on labs for mastering Argo Workflows, covering 36% of the CAPA certification exam.

## Lab Overview

These labs provide practical experience with Argo Workflows through executable examples. Each lab builds on previous concepts and includes complete, tested commands.

### Prerequisites

- Kubernetes cluster (Minikube, Kind, or cloud-based)
- kubectl configured and connected to your cluster
- Argo Workflows installed (covered in Lab 01)
- Basic understanding of Kubernetes concepts (Pods, Deployments, Services)

## Labs

### Core Concepts

1. **[Lab 01: Installation and Basics](lab-01-installation-basics.md)**
   - Installing Argo Workflows
   - First workflow creation
   - CLI basics (argo submit, get, logs)
   - Workflow lifecycle management

2. **[Lab 02: Templates and Steps](lab-02-templates-steps.md)**
   - Template types (Container, Script, Resource)
   - Sequential and parallel steps
   - Passing parameters between steps
   - Input and output handling

3. **[Lab 03: DAG Workflows](lab-03-dag-workflows.md)**
   - Directed Acyclic Graphs (DAGs)
   - Task dependencies
   - Parallel execution patterns
   - Conditional execution with when clauses

### Data Management

4. **[Lab 04: Artifacts](lab-04-artifacts.md)**
   - Artifact passing between steps
   - Using different artifact repositories (S3, GCS, MinIO)
   - Git repository integration
   - Artifact compression and archiving

5. **[Workflow Artifacts](lab-06-artifacts-advanced.md)**
   - Advanced artifact patterns
   - Artifact repository configuration
   - Sharing data between workflow steps
   - Best practices for artifact management

### Advanced Patterns

6. **[Lab 05: Workflow Templates](lab-05-workflow-templates.md)**
   - Creating reusable WorkflowTemplates
   - ClusterWorkflowTemplates for shared templates
   - Template composition and nesting
   - Version management for templates

7. **[Workflow Cron](lab-07-cron-schedules.md)**
   - Scheduled workflows with CronWorkflow
   - Schedule syntax and patterns
   - Managing recurring workflows
   - Timezone handling
   - Concurrency policies

8. **[Workflow Security](lab-08-security-rbac.md)**
   - RBAC configuration for workflows
   - ServiceAccounts and permissions
   - Secret management in workflows
   - Pod security policies
   - Network policies for workflow pods

## Learning Path

### Beginner (Labs 1-2)

Start with installation and basic template usage. Complete these labs first to understand fundamental concepts.

**Estimated time**: 2-3 hours

### Intermediate (Labs 3-5)

Move to DAG patterns, artifacts, and workflow templates. These labs teach you to build production-ready workflows.

**Estimated time**: 3-4 hours

### Advanced (Labs 6-8)

Master scheduling, security, and advanced artifact patterns. Essential for production deployments.

**Estimated time**: 3-4 hours

## Lab Format

Each lab follows this structure:

1. **Learning Objectives**: What you'll learn
2. **Prerequisites**: Required setup and knowledge
3. **Concepts**: Theoretical background
4. **Hands-On Exercises**: Step-by-step instructions with commands
5. **Validation**: How to verify each step worked
6. **Cleanup**: Commands to reset your environment
7. **Key Takeaways**: Summary of important concepts

## Tips for Success

- **Run commands sequentially**: Each lab builds on previous steps
- **Verify each step**: Use validation commands to confirm success
- **Clean up after each lab**: Prevents resource conflicts
- **Experiment**: Modify examples to deepen understanding
- **Troubleshoot**: Check pod logs with `kubectl logs` and workflow status with `argo get`

## Common Issues

### Workflow Stuck Pending

```bash
# Check workflow status
argo get <workflow-name>

# Check pod events
kubectl describe pod <pod-name>

# Check workflow controller logs
kubectl logs -n argo deployment/workflow-controller
```

### Artifact Upload Failures

```bash
# Verify artifact repository configuration
kubectl get configmap -n argo workflow-controller-configmap -o yaml

# Check pod permissions
kubectl get serviceaccount -n argo
```

### Image Pull Errors

```bash
# Check image name and registry
kubectl describe pod <pod-name>

# Verify image pull secrets if using private registry
kubectl get secrets -n argo
```

## Additional Resources

- [Argo Workflows Official Documentation](https://argoproj.github.io/argo-workflows/)
- [Argo Workflows Examples Repository](https://github.com/argoproj/argo-workflows/tree/master/examples)
- [Domain Documentation](../../domains/02-argo-workflows/README.md)
- [CAPA Cheatsheet](../../CAPA_CHEATSHEET.md)

## Contributing

Found an issue or have an improvement? See [Contributing Guidelines](../../README.md#contributing).

## Exam Coverage

These labs cover the following CAPA exam competencies:

- Understand the architecture and components of Argo Workflows
- Create and manage workflow templates
- Implement DAG and Steps-based workflows
- Configure artifact repositories and artifact passing
- Use workflow variables and parameters
- Implement conditional execution and loops
- Configure RBAC and security for workflows
- Schedule workflows using CronWorkflow

**Exam Weight**: 36% of CAPA certification exam
