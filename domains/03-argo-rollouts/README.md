# Argo Rollouts - Progressive Delivery (18%)

Argo Rollouts is a Kubernetes controller and set of CRDs that provide advanced deployment capabilities such as blue-green, canary, canary analysis, experimentation, and progressive delivery features. It enables safe and gradual rollout of application changes while maintaining high availability and reducing risk.

## Topics

### [Rollout Strategies Overview](rollout-strategies.md)

Understanding Rollout resources, comparison with standard Kubernetes Deployments, rollout strategy types (blue-green and canary), rollout status phases, and traffic management integration with ingress controllers (NGINX, Istio) and service meshes.

### [Blue-Green Deployments](blue-green.md)

Implementing Blue-Green deployment strategy with active and preview services, promotion processes, and rollback procedures.

### [Canary Deployments](canary.md)

Implementing Canary deployment strategy with traffic splitting, progressive steps, pause duration configuration, and automated promotion.

### [Analysis and Metrics](analysis-metrics.md)

Configuring AnalysisTemplates, integrating metric providers (Prometheus, Datadog, CloudWatch), defining success and failure conditions, and running analysis.

## Related Labs

Practice these hands-on labs to reinforce your understanding:

- [Lab 01: Installation and Basics](../../labs/03-argo-rollouts/lab-01-installation-basics.md) - 20 minutes
- [Deployment Strategies](../../labs/03-argo-rollouts/lab-02-deployment-strategies.md) - 60 minutes (covers both blue-green and canary)
- [Lab 04: Analysis and Metrics](../../labs/03-argo-rollouts/lab-04-analysis.md) - 45 minutes
- [Lab 05: Traffic Management](../../labs/03-argo-rollouts/lab-05-traffic-management.md) - 40 minutes

## Study Resources

- [Argo Rollouts Official Documentation](https://argoproj.github.io/argo-rollouts/) - Complete reference guide
- [Argo Rollouts Getting Started](https://argoproj.github.io/argo-rollouts/getting-started/) - Quick start guide
- [Argo Rollouts Best Practices](https://argoproj.github.io/argo-rollouts/best-practices/) - Production deployment guidance
- [Canary Deployments Guide](https://argoproj.github.io/argo-rollouts/features/canary/) - Detailed canary strategy documentation

## Key Exam Topics

Focus on these critical areas for the exam:

- Differences between Rollouts and Deployments
- Blue-Green vs Canary deployment strategies
- Rollout status phases and meanings
- AnalysisTemplate structure and configuration
- Metric provider integration
- Traffic routing with ingress controllers
- Service mesh integration patterns
- Promotion and rollback procedures
- Progressive delivery best practices
- Analysis run interpretation
