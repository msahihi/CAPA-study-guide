# Hands-On Labs

Practical exercises to reinforce your learning and gain hands-on experience with the Argo Project ecosystem.

## Prerequisites

- Kubernetes cluster (minikube or kind recommended for local practice)
- kubectl CLI installed and configured
- Git installed
- Basic understanding of Kubernetes concepts
- Text editor or IDE

## Lab Structure

Each lab includes:

- Clear objectives
- Prerequisites
- Step-by-step exercises
- Questions to reinforce learning
- Challenge exercises
- Solutions

## Available Labs

### Domain 1: Argo CD - Continuous Delivery

- [Lab 01: Installing Argo CD](01-argo-cd/lab-01-installation.md) - 20 minutes
- [Lab 02: Deploying Your First Application](01-argo-cd/lab-02-first-app.md) - 30 minutes
- [Lab 03: Managing Application Sync](01-argo-cd/lab-03-sync-management.md) - 30 minutes
- [Lab 04: Implementing RBAC](01-argo-cd/lab-04-rbac.md) - 40 minutes
- [Lab 05: Working with Helm Charts](01-argo-cd/lab-05-helm.md) - 35 minutes
- [Lab 06: Multi-Cluster Setup](01-argo-cd/lab-06-multi-cluster.md) - 45 minutes

### Domain 2: Argo Workflows - Workflow Engine

- [Lab 01: Installing Argo Workflows and Basics](02-argo-workflows/lab-01-installation-basics.md) - 20 minutes
- [Lab 02: Templates and Steps](02-argo-workflows/lab-02-templates-steps.md) - 30 minutes
- [Lab 03: Working with DAGs](02-argo-workflows/lab-03-dag-workflows.md) - 35 minutes
- [Lab 04: Using Artifacts and Volumes](02-argo-workflows/lab-04-artifacts.md) - 40 minutes
- [Lab 05: Workflow Templates](02-argo-workflows/lab-05-workflow-templates.md) - 45 minutes

### Domain 3: Argo Rollouts - Progressive Delivery

- [Lab 01: Installing Argo Rollouts and Basics](03-argo-rollouts/lab-01-installation-basics.md) - 20 minutes
- [Lab 02: Blue-Green Deployments](03-argo-rollouts/lab-02-blue-green.md) - 35 minutes
- [Lab 03: Canary Deployments](03-argo-rollouts/lab-03-canary.md) - 40 minutes
- [Lab 04: Analysis and Metrics](03-argo-rollouts/lab-04-analysis.md) - 45 minutes
- [Lab 05: Traffic Management](03-argo-rollouts/lab-05-traffic-management.md) - 40 minutes

### Domain 4: Argo Events - Event-Based Automation

- [Lab 01: Installing Argo Events and Basics](04-argo-events/lab-01-installation-basics.md) - 20 minutes
- [Lab 02: Event Sources](04-argo-events/lab-02-event-sources.md) - 35 minutes
- [Lab 03: Triggers](04-argo-events/lab-03-triggers.md) - 35 minutes
- [Lab 04: Integrating with Argo Workflows](04-argo-events/lab-04-integration.md) - 40 minutes

## Tips

- Complete labs in order within each domain
- Don't skip exercises - hands-on practice is crucial
- Try challenge exercises before looking at solutions
- Clean up resources after each lab to avoid conflicts
- Take notes on commands and patterns you find useful
- Experiment beyond the lab instructions

## Setting Up Your Lab Environment

### Option 1: Minikube

```bash
# Start minikube with adequate resources
minikube start --cpus=4 --memory=8192

# Verify cluster
kubectl get nodes
```

### Option 2: Kind

```bash
# Create kind cluster
kind create cluster --name capa-labs

# Verify cluster
kubectl cluster-info --context kind-capa-labs
```

## Getting Help

If you encounter issues:

1. Check the Prerequisites section
2. Review error messages carefully
3. Consult official Argo documentation
4. Use `kubectl describe` and `kubectl logs` for troubleshooting
5. Clean up and restart the lab if needed

## Additional Resources

- [Argo CD Examples](https://github.com/argoproj/argocd-example-apps)
- [Argo Workflows Examples](https://github.com/argoproj/argo-workflows/tree/master/examples)
- [Argo Rollouts Demo](https://github.com/argoproj/rollouts-demo)
- [Argo Events Examples](https://github.com/argoproj/argo-events/tree/master/examples)
