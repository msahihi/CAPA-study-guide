# Argo Workflows - Workflow Engine (36%)

Argo Workflows is a container-native workflow engine for orchestrating parallel jobs on Kubernetes. It is implemented as a Kubernetes CRD (Custom Resource Definition) and provides a powerful way to define complex workflows, manage dependencies between tasks, and handle artifacts across workflow steps.

## Topics

### [Workflow Fundamentals](workflow-fundamentals.md)

Understanding the core concepts of Argo Workflows including the Workflow CRD structure, workflow specifications, entrypoints, workflow phases, basic workflow patterns, and workflow variables deep-dive (global variables, parameter passing, conditional expressions).

### [Templates and Steps](templates-steps.md)

Exploring different template types such as container, script, and resource templates, along with step templates, template invocation patterns, managing inputs and outputs, and retry/timeout strategies for resilient workflows.

### [DAG and Parallel Execution](dag-parallel.md)

Learning how to create DAG (Directed Acyclic Graph) workflows, define dependencies between tasks, implement parallel execution, and use fan-out/fan-in patterns for complex workflow orchestration.

### [Variables and Artifacts](variables-artifacts.md)

Working with workflow variables, parameters, artifacts including inputs and outputs, configuring artifact repositories, and managing volume claims for data persistence.

### [CI/CD Integration](cicd-integration.md)

Understanding CI/CD use cases for Argo Workflows, triggering workflows programmatically, differences between Workflow Templates and Cluster Workflow Templates, and implementing cron workflows for scheduled execution.

## Related Labs

Practice these hands-on labs to reinforce your understanding:

### Core Labs

- [Lab 01: Installation and Basics](../../labs/02-argo-workflows/lab-01-installation-basics.md) - 20 minutes
- [Lab 02: Templates and Steps](../../labs/02-argo-workflows/lab-02-templates-steps.md) - 30 minutes
- [Lab 03: Building DAG Workflows](../../labs/02-argo-workflows/lab-03-dag-workflows.md) - 35 minutes
- [Lab 04: Managing Artifacts](../../labs/02-argo-workflows/lab-04-artifacts.md) - 30 minutes
- [Lab 05: Workflow Templates](../../labs/02-argo-workflows/lab-05-workflow-templates.md) - 45 minutes

### Advanced Topics

- [Workflow Artifacts](../../labs/02-argo-workflows/lab-06-artifacts-advanced.md) - Advanced artifact patterns and data sharing
- [Workflow Cron](../../labs/02-argo-workflows/lab-07-cron-schedules.md) - Scheduled workflows with CronWorkflow
- [Workflow Security](../../labs/02-argo-workflows/lab-08-security-rbac.md) - RBAC, ServiceAccounts, and secret management

## Study Resources

- [Argo Workflows Official Documentation](https://argoproj.github.io/argo-workflows/) - Complete reference guide
- [Argo Workflows Getting Started](https://argoproj.github.io/argo-workflows/quick-start/) - Quick start guide
- [Workflow Examples](https://github.com/argoproj/argo-workflows/tree/master/examples) - Official example workflows
- [Argo Workflows Best Practices](https://argo-workflows.readthedocs.io/en/latest/running-at-massive-scale/) - Production deployment guidance

## Key Exam Topics

Focus on these critical areas for the exam:

- Workflow CRD structure and core components
- Template types and their use cases
- DAG vs Steps workflow patterns
- Workflow parameter passing and variable substitution
- Artifact management and repositories
- WorkflowTemplate vs ClusterWorkflowTemplate
- Workflow lifecycle and phases
- CronWorkflow for scheduled execution
- Error handling and retry strategies
- Resource management and limits
