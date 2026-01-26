# Certified Argo Project Associate (CAPA) - Study Guide

## Overview

The Certified Argo Project Associate (CAPA) certification demonstrates competency in understanding and working with the Argo Project ecosystem, including Argo CD, Argo Workflows, Argo Rollouts, and Argo Events. This certification is designed for DevOps engineers, platform engineers, and cloud-native practitioners who want to validate their skills in GitOps, continuous delivery, and workflow automation using Argo tools.

**Who Should Take CAPA**:

- DevOps engineers implementing GitOps practices
- Platform engineers building CI/CD pipelines
- Cloud-native practitioners working with Kubernetes
- Developers automating workflows and deployments
- SREs managing application lifecycle at scale

**About This Guide**:
This repository provides organized, easily accessible content to support CAPA exam preparation. It consolidates information from official Argo documentation, community resources, and hands-on practice into a structured learning path designed for beginners to intermediate practitioners.

## What's in This Directory

- **[CAPA_CHEATSHEET.md](CAPA_CHEATSHEET.md)**: Comprehensive study guide consolidating all domain and lab content
- **[domains](domains/)**: Exam domains with detailed theoretical content organized by topic
- **[labs](labs/)**: Hands-on practical exercises with kubectl and Argo CLI commands
- **[mock-questions](mock-questions/)**: Sample questions to simulate the exam experience

## Topics Covered

### [Argo CD - Continuous Delivery](domains/01-argo-cd/README.md) (35%)

- [Core Concepts and Architecture](domains/01-argo-cd/core-concepts.md)
- [Installation and Configuration](domains/01-argo-cd/installation-configuration.md)
- [Application Management](domains/01-argo-cd/application-management.md)
- [Sync Strategies and Options](domains/01-argo-cd/sync-strategies.md)
- [RBAC and Security](domains/01-argo-cd/rbac-security.md)
- [Multi-Cluster Management](domains/01-argo-cd/multi-cluster.md)

### [Argo Workflows - Workflow Engine](domains/02-argo-workflows/README.md) (25%)

- [Workflow Fundamentals](domains/02-argo-workflows/workflow-fundamentals.md)
- [Workflow Templates and Steps](domains/02-argo-workflows/templates-steps.md)
- [DAG and Parallel Execution](domains/02-argo-workflows/dag-parallel.md)
- [Workflow Variables and Artifacts](domains/02-argo-workflows/variables-artifacts.md)
- [CI/CD Integration](domains/02-argo-workflows/cicd-integration.md)

### [Argo Rollouts - Progressive Delivery](domains/03-argo-rollouts/README.md) (25%)

- [Rollout Strategies Overview](domains/03-argo-rollouts/rollout-strategies.md)
- [Blue-Green Deployments](domains/03-argo-rollouts/blue-green.md)
- [Canary Deployments](domains/03-argo-rollouts/canary.md)
- [Analysis and Metrics](domains/03-argo-rollouts/analysis-metrics.md)
- [Traffic Management](domains/03-argo-rollouts/traffic-management.md)

### [Argo Events - Event-Based Automation](domains/04-argo-events/README.md) (15%)

- [Event Sources and Sensors](domains/04-argo-events/event-sources-sensors.md)
- [Event Bus Configuration](domains/04-argo-events/event-bus.md)
- [Triggers and Actions](domains/04-argo-events/triggers-actions.md)
- [Integration Patterns](domains/04-argo-events/integration-patterns.md)

## External Links

- [Official CAPA Certification](https://training.linuxfoundation.org/certification/certified-argo-project-associate-capa/) - Exam details and registration
- [Argo Project Documentation](https://argoproj.github.io/) - Official documentation hub
- [Argo CD Documentation](https://argo-cd.readthedocs.io/) - Argo CD reference
- [Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/) - Argo Workflows reference
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/) - Argo Rollouts reference
- [Argo Events Documentation](https://argoproj.github.io/argo-events/) - Argo Events reference
- [CNCF Argo Project](https://www.cncf.io/projects/argo/) - CNCF project page

## Getting Started

### Prerequisites

Before starting your CAPA preparation, ensure you have:

- Basic understanding of Kubernetes concepts (pods, deployments, services)
- Familiarity with YAML manifests
- Access to a Kubernetes cluster (local or cloud)
- kubectl CLI installed
- Git and basic Git operations knowledge

### Quick Start Path

1. **Orientation**: Read this README to understand the guide structure
2. **Review Topics**: Browse the [Topics Covered](#topics-covered) section to see all exam domains
3. **Study Theory**: Start with [domains/](domains/) - read topic markdown files for theoretical knowledge
4. **Hands-On Practice**: Complete corresponding [labs/](labs/) for each topic you study
5. **Quick Reference**: Use [CAPA_CHEATSHEET.md](CAPA_CHEATSHEET.md) for consolidated review
6. **Test Knowledge**: Practice with [mock-questions/](mock-questions/) to assess readiness
7. **Track Progress**: Check off completed topics and labs as you go

### Recommended Study Approach

**Week 1-2: Argo CD - Continuous Delivery (35% of exam)**

- Study [Argo CD domain](domains/01-argo-cd/README.md)
- Complete all 6 labs in [labs/01-argo-cd/](labs/01-argo-cd/)
- Focus: Application deployment, sync strategies, GitOps principles

**Week 3: Argo Workflows - Workflow Engine (25% of exam)**

- Study [Argo Workflows domain](domains/02-argo-workflows/README.md)
- Complete all 5 labs in [labs/02-argo-workflows/](labs/02-argo-workflows/)
- Focus: Workflow creation, templates, DAG patterns

**Week 4: Argo Rollouts - Progressive Delivery (25% of exam)**

- Study [Argo Rollouts domain](domains/03-argo-rollouts/README.md)
- Complete all 5 labs in [labs/03-argo-rollouts/](labs/03-argo-rollouts/)
- Focus: Deployment strategies, canary analysis, traffic shifting

**Week 5: Argo Events - Event Automation (15% of exam)**

- Study [Argo Events domain](domains/04-argo-events/README.md)
- Complete all 4 labs in [labs/04-argo-events/](labs/04-argo-events/)
- Focus: Event-driven workflows, sensors, triggers

**Week 6: Review & Practice**

- Review [CAPA_CHEATSHEET.md](CAPA_CHEATSHEET.md)
- Revisit challenging topics
- Complete all mock exams in [mock-questions/](mock-questions/)
- Practice hands-on scenarios end-to-end
- Review official Argo documentation

### Lab Environment Setup

For hands-on practice using local Kubernetes:

**Option 1: Minikube**

```bash
# Install minikube
brew install minikube  # macOS
# or download from https://minikube.sigs.k8s.io/

# Start cluster
minikube start --cpus=4 --memory=8192

# Verify
kubectl get nodes
```

**Option 2: Kind (Kubernetes in Docker)**

```bash
# Install kind
brew install kind  # macOS
# or download from https://kind.sigs.k8s.io/

# Create cluster
kind create cluster --name capa-study

# Verify
kubectl cluster-info --context kind-capa-study
```

### Additional Resources

- [Argo Project Community](https://github.com/argoproj) - GitHub repositories
- [Argo Slack Channel](https://argoproj.github.io/community/join-slack/) - Community support
- [CNCF Webinars on Argo](https://www.cncf.io/webinars/) - Video tutorials
- [Awesome Argo](https://github.com/terrytangyuan/awesome-argo) - Curated Argo resources
- [GitOps Working Group](https://opengitops.dev/) - GitOps principles and best practices
