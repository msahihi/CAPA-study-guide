# Argo Events Labs

Hands-on labs for mastering Argo Events - Event-Based Automation (12% of CAPA exam).

## Overview

These labs provide practical experience with Argo Events, covering event-driven workflow automation, reactive systems, and GitOps integration. Each lab builds upon the previous one, culminating in a complete CI/CD pipeline.

## Lab Structure

### [Lab 01: Installation and Basics](lab-01-installation-basics.md)

**Duration**: 25 minutes | **Difficulty**: Beginner

Learn the fundamentals of Argo Events:

- Installing Argo Events in Kubernetes
- Setting up NATS-based Event Bus
- Creating your first webhook EventSource
- Building a basic Sensor to trigger workflows
- Understanding event flow from source to trigger

**Key Skills**: Installation, Event Bus configuration, webhook EventSources, basic Sensors

---

### [Lab 02: Event Source Types](lab-02-event-sources.md)

**Duration**: 35 minutes | **Difficulty**: Intermediate

Explore different EventSource types:

- Calendar EventSources for time-based automation
- Resource EventSources to watch Kubernetes objects
- Advanced event filtering techniques
- Working with multiple event dependencies
- Event data transformation with jq

**Key Skills**: Calendar events, resource watching, filtering, multi-dependency sensors

---

### [Lab 03: Triggers and Actions](lab-03-triggers.md)

**Duration**: 35 minutes | **Difficulty**: Intermediate

Master various trigger types and actions:

- Parameterized Argo Workflow triggers
- Dynamic Kubernetes resource creation
- HTTP triggers for external systems
- Conditional trigger execution
- Retry policies and error handling

**Key Skills**: Workflow parameterization, K8s triggers, HTTP triggers, conditional logic

---

### [Lab 04: End-to-End CI/CD Integration](lab-04-integration.md)

**Duration**: 40 minutes | **Difficulty**: Advanced

Build a complete event-driven CI/CD pipeline:

- GitHub webhook integration
- Multi-stage CI/CD workflows
- Environment-specific deployments
- Approval gates for production
- Argo CD integration for GitOps

**Key Skills**: GitHub events, CI/CD automation, multi-environment deployment, GitOps integration

---

## Prerequisites

### Required Knowledge

- Basic Kubernetes concepts (pods, deployments, services)
- YAML syntax and Kubernetes manifests
- Git and version control basics
- Understanding of CI/CD principles
- Command-line interface proficiency

### Required Tools

- **Kubernetes Cluster**: Minikube, Kind, or cloud provider (minimum 4 CPUs, 8GB RAM)
- **kubectl**: Kubernetes CLI tool
- **curl**: For testing webhooks
- **Argo Workflows**: Should be installed (from previous labs)
- **Argo CD**: Required for Lab 04 integration
- **Git**: For version control operations

### Optional Tools

- **Argo CLI**: For easier workflow management
- **jq**: For JSON processing and debugging
- **Postman**: Alternative to curl for API testing

## Learning Path

### Recommended Approach

1. **Sequential Learning**: Complete labs in order (Lab 01 → Lab 04)
2. **Hands-On Practice**: Type commands manually rather than copy-paste
3. **Experimentation**: Try modifications and explore edge cases
4. **Troubleshooting**: Use the troubleshooting sections when stuck
5. **Additional Exercises**: Complete optional exercises for deeper understanding

### Time Commitment

- **Fast Track**: 2-3 hours (core content only)
- **Standard**: 4-5 hours (including exercises)
- **Comprehensive**: 6-8 hours (with additional experiments)

### Study Tips

- Take breaks between labs to absorb concepts
- Keep notes on key commands and patterns
- Reference official Argo Events documentation
- Join the Argo community Slack for questions
- Review domain content before starting labs

## Lab Environment Setup

### Option 1: Minikube (Recommended for Labs)

```bash
# Install minikube
brew install minikube  # macOS
# or download from https://minikube.sigs.k8s.io/

# Start with sufficient resources
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Verify cluster
kubectl get nodes
```

### Option 2: Kind (Kubernetes in Docker)

```bash
# Install kind
brew install kind  # macOS
# or download from https://kind.sigs.k8s.io/

# Create cluster
kind create cluster --name argo-events-labs

# Verify cluster
kubectl cluster-info --context kind-argo-events-labs
```

### Option 3: Cloud Provider (GKE, EKS, AKS)

```bash
# Ensure kubectl is configured for your cluster
kubectl config current-context

# Verify access
kubectl get nodes
```

### Install Core Dependencies

```bash
# Install Argo Workflows (if not already installed)
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.0/install.yaml

# Install Argo CD (required for Lab 04)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify installations
kubectl get pods -n argo
kubectl get pods -n argocd
```

## What You'll Learn

### Core Concepts

- **EventSource CRD**: Capturing events from various sources
- **Event Bus**: NATS-based message broker architecture
- **Sensor CRD**: Defining event dependencies and triggers
- **Event Filtering**: Data, context, and expression-based filters
- **Trigger Types**: Workflows, K8s resources, HTTP requests
- **Event Parameterization**: Extracting and passing event data

### Practical Skills

- Setting up event-driven automation
- Building reactive Kubernetes systems
- Implementing CI/CD with events
- Integrating external systems via webhooks
- Creating approval workflows
- Monitoring event-driven pipelines

### Integration Patterns

- **GitOps**: Git events → Build → Deploy with Argo CD
- **Scheduled Tasks**: Calendar events → Maintenance workflows
- **Resource Watching**: K8s changes → Automated responses
- **Webhook Automation**: External events → Internal actions
- **Approval Gates**: Multi-dependency triggers

## Common Use Cases

After completing these labs, you'll be able to implement:

1. **Automated CI/CD Pipelines**
   - Git push triggers build and test
   - Automatic deployment to dev/staging
   - Manual approval for production

2. **Infrastructure Automation**
   - React to resource changes
   - Auto-scaling based on events
   - Self-healing systems

3. **Scheduled Operations**
   - Backup and maintenance tasks
   - Report generation
   - Cleanup operations

4. **Integration Workflows**
   - Webhook receivers for external systems
   - Event forwarding and routing
   - Multi-system coordination

## Troubleshooting Resources

### Common Issues

#### Event Bus Not Starting

```bash
# Check event bus status
kubectl get eventbus -n argo-events
kubectl describe eventbus default -n argo-events

# Check NATS pods
kubectl get pods -n argo-events | grep eventbus

# View logs
kubectl logs -n argo-events -l app.kubernetes.io/component=eventbus
```

#### EventSource Pod Crashes

```bash
# Check EventSource status
kubectl get eventsource -n argo-events
kubectl describe eventsource <name> -n argo-events

# View logs
kubectl logs -n argo-events -l eventsource-name=<name>

# Common fixes:
# - Verify event bus is running
# - Check port conflicts
# - Validate YAML syntax
```

#### Sensor Not Triggering

```bash
# Check sensor status
kubectl get sensor -n argo-events
kubectl describe sensor <name> -n argo-events

# View sensor logs
kubectl logs -n argo-events -l sensor-name=<name>

# Verify event flow:
# 1. EventSource receiving events
# 2. Events published to bus
# 3. Sensor receiving from bus
# 4. Dependencies satisfied
# 5. Triggers executing
```

#### Webhook Not Responding

```bash
# Verify service is running
kubectl get svc -n argo-events

# Test connectivity
kubectl run curl-test --image=curlimages/curl -it --rm -- \
  curl -v http://<service-name>.argo-events.svc.cluster.local:<port>

# Check port forwarding
lsof -i :<local-port>
```

### Getting Help

- **Argo Events Documentation**: https://argoproj.github.io/argo-events/
- **Argo Community Slack**: https://argoproj.github.io/community/join-slack/
- **GitHub Issues**: https://github.com/argoproj/argo-events/issues
- **Stack Overflow**: Tag questions with `argo-events`

## Lab Cleanup

### After Each Lab

```bash
# Clean up workflows
kubectl delete workflows --all -n argo-events

# Clean up test resources
kubectl delete pods,deployments,services -n default -l managed-by=argo-events
```

### Complete Cleanup

```bash
# Remove all Argo Events resources
kubectl delete eventsource --all -n argo-events
kubectl delete sensor --all -n argo-events
kubectl delete eventbus --all -n argo-events

# Remove Argo Events installation
kubectl delete -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml

# Remove namespace
kubectl delete namespace argo-events
```

## Verification and Assessment

### Lab Completion Checklist

After completing all labs, you should be able to:

- [ ] Install and configure Argo Events
- [ ] Set up Event Bus with NATS
- [ ] Create webhook EventSources
- [ ] Create calendar EventSources
- [ ] Create resource EventSources
- [ ] Build Sensors with single dependencies
- [ ] Build Sensors with multiple dependencies
- [ ] Implement event filtering
- [ ] Transform event data
- [ ] Trigger Argo Workflows with parameters
- [ ] Create Kubernetes resources dynamically
- [ ] Send HTTP requests from triggers
- [ ] Use conditional triggers
- [ ] Implement approval workflows
- [ ] Integrate with GitHub webhooks
- [ ] Build CI/CD pipelines
- [ ] Deploy with Argo CD from events

### Practice Scenarios

Test your knowledge with these scenarios:

1. **Scenario 1**: Create an EventSource that watches ConfigMaps and triggers a workflow when a specific config changes.

2. **Scenario 2**: Build a sensor that waits for two different webhooks before triggering a deployment.

3. **Scenario 3**: Implement a calendar-based backup workflow that runs every night at 2 AM.

4. **Scenario 4**: Create a complete PR validation workflow triggered by GitHub pull request events.

## Additional Resources

### Official Documentation

- [Argo Events Getting Started](https://argoproj.github.io/argo-events/quick_start/)
- [EventSource Catalog](https://argoproj.github.io/argo-events/concepts/event_source/)
- [Sensor Specification](https://argoproj.github.io/argo-events/concepts/sensor/)
- [Trigger Types](https://argoproj.github.io/argo-events/concepts/trigger/)

### Examples and Tutorials

- [Official Examples Repository](https://github.com/argoproj/argo-events/tree/master/examples)
- [Argo Events Documentation](https://argoproj.github.io/argo-events/)
- [Event Source Examples](https://github.com/argoproj/argo-events/tree/master/examples/event-sources)

### Community Resources

- [CNCF Webinars](https://www.cncf.io/webinars/)
- [Awesome Argo](https://github.com/terrytangyuan/awesome-argo)

## Exam Preparation

These labs cover approximately 12% of the CAPA exam content. Focus on:

### Key Exam Topics

- EventSource CRD structure and types
- Event Bus architecture and NATS
- Sensor CRD and dependencies
- Event filtering techniques
- Trigger types and operations
- Event data extraction
- Integration with Argo Workflows
- Common event-driven patterns

### Hands-On Skills

- Creating EventSources quickly
- Debugging event flow issues
- Writing event filters
- Parameterizing triggers
- Troubleshooting common problems

### Study Recommendations

1. Complete all labs at least once
2. Revisit troubleshooting sections
3. Practice creating resources without examples
4. Review official documentation
5. Join community discussions

## Next Steps

After completing these labs:

1. **Review Theory**: Read the [domain content](../../domains/04-argo-events/README.md)
2. **Practice More**: Try the additional exercises in each lab
3. **Integration**: Combine with Argo CD and Rollouts labs
4. **Mock Exam**: Test your knowledge with practice questions
5. **Real Projects**: Apply skills to actual use cases

## Feedback and Contributions

Found an issue or have suggestions? Please contribute:

- Open an issue on GitHub
- Submit a pull request with improvements
- Share your experience in community Slack
