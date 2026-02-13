# Argo Rollouts Labs

Hands-on labs for mastering Argo Rollouts progressive delivery, covering 18% of the CAPA certification exam.

## Lab Overview

These labs provide practical experience with Argo Rollouts deployment strategies through executable examples. Each lab includes complete, tested commands for blue-green and canary deployments.

### Prerequisites

- Kubernetes cluster (Minikube, Kind, or cloud-based)
- kubectl configured and connected to your cluster
- Argo Rollouts controller installed (covered in Lab 01)
- kubectl Argo Rollouts plugin installed
- Basic understanding of Kubernetes Deployments and Services

## Labs

### Core Concepts

1. **[Lab 01: Installation and Basics](lab-01-installation-basics.md)**
   - Installing Argo Rollouts controller
   - Installing kubectl plugin
   - Creating first rollout
   - Understanding Rollout vs Deployment
   - Basic rollout operations

2. **[Deployment Strategies](lab-02-deployment-strategies.md)**
   - Blue-Green deployment strategy
   - Canary deployment strategy  
   - Traffic management patterns
   - Manual and automatic promotion
   - Rollback operations
   - Strategy selection guide

### Advanced Topics

3. **[Lab 04: Analysis and Metrics](lab-04-analysis.md)**
   - Metrics-based canary analysis
   - AnalysisTemplate configuration
   - Prometheus integration
   - Automated rollback on failure
   - Success rate metrics

4. **[Lab 05: Traffic Management](lab-05-traffic-management.md)**
   - NGINX Ingress integration
   - Istio service mesh integration
   - Weighted traffic splitting
   - Header-based routing
   - Traffic mirroring

## Learning Path

### Beginner (Labs 1-2)

Start with installation and deployment strategies. Learn blue-green and canary patterns.

**Estimated time**: 2-3 hours

### Advanced (Labs 3-4)

Master analysis, metrics-based validation, and traffic management integrations.

**Estimated time**: 3-4 hours

## Lab Format

Each lab follows this structure:

1. **Learning Objectives**: What you'll learn
2. **Prerequisites**: Required setup and knowledge
3. **Hands-On Exercises**: Step-by-step instructions with commands
4. **Validation**: How to verify each step worked
5. **Cleanup**: Commands to reset your environment
6. **Key Takeaways**: Summary of important concepts

## Deployment Strategy Comparison

| Aspect | Blue-Green | Canary |
|--------|-----------|--------|
| **Traffic Switch** | Instant (0% → 100%) | Gradual (progressive steps) |
| **Risk** | Higher | Lower |
| **Rollback** | Instant | Abort and scale down |
| **Use Case** | Low-risk updates | High-risk updates |

## Tips for Success

- **Run commands sequentially**: Each lab builds on previous steps
- **Verify each step**: Use validation commands to confirm success
- **Clean up after each lab**: Prevents resource conflicts
- **Experiment**: Modify examples to deepen understanding
- **Monitor rollouts**: Use `kubectl argo rollouts get rollout <name> --watch`

## Common Issues

### Rollout Stuck in Paused State

```bash
# Check rollout status
kubectl argo rollouts get rollout <rollout-name>

# Manually promote if needed
kubectl argo rollouts promote <rollout-name>

# Or abort if issues detected
kubectl argo rollouts abort <rollout-name>
```

### Traffic Not Splitting Correctly

```bash
# Verify services exist
kubectl get services

# Check rollout strategy configuration
kubectl get rollout <rollout-name> -o yaml | grep -A 10 strategy

# Verify ingress/service mesh integration
kubectl describe ingress <ingress-name>
```

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check rollout controller logs
kubectl logs -n argo-rollouts deployment/argo-rollouts

# Verify images are accessible
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'
```

## Additional Resources

- [Argo Rollouts Official Documentation](https://argoproj.github.io/argo-rollouts/)
- [Argo Rollouts Examples Repository](https://github.com/argoproj/argo-rollouts/tree/master/examples)
- [Domain Documentation](../../domains/03-argo-rollouts/README.md)
- [CAPA Cheatsheet](../../CAPA_CHEATSHEET.md)

## Contributing

Found an issue or have an improvement? See [Contributing Guidelines](../../README.md#contributing).

## Exam Coverage

These labs cover the following CAPA exam competencies:

- Understand Argo Rollouts architecture and components
- Implement blue-green deployment strategy
- Implement canary deployment strategy with progressive delivery
- Configure traffic management with ingress controllers and service meshes
- Perform rollback operations
- Configure automated analysis with metrics
- Integrate Argo Rollouts with CI/CD pipelines

**Exam Weight**: 18% of CAPA certification exam
