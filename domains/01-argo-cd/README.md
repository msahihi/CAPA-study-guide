# Argo CD - Continuous Delivery (35%)

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of applications by synchronizing the desired application state from Git repositories with the actual state in Kubernetes clusters.

## Topics

### [Core Concepts and Architecture](core-concepts.md)

Understanding Argo CD architecture, components, and GitOps principles that form the foundation of continuous delivery.

### [Installation and Configuration](installation-configuration.md)

Installing Argo CD on Kubernetes clusters and configuring essential settings for different deployment scenarios.

### [Application Management](application-management.md)

Creating, managing, and organizing applications in Argo CD, including projects, repositories, and application resources.

### [Sync Strategies and Options](sync-strategies.md)

Understanding different sync strategies, automated sync policies, and sync options for managing application deployments.

### [RBAC and Security](rbac-security.md)

Implementing role-based access control, securing Argo CD installations, and managing authentication and authorization.

### [Multi-Cluster Management](multi-cluster.md)

Managing multiple Kubernetes clusters from a single Argo CD instance and implementing multi-cluster deployment strategies.

## Related Labs

Practice these hands-on labs to reinforce your understanding:

- [Lab 01: Installing Argo CD](../../labs/01-argo-cd/lab-01-installation.md) - 20 minutes
- [Lab 02: Deploying Your First Application](../../labs/01-argo-cd/lab-02-first-app.md) - 30 minutes
- [Lab 03: Managing Application Sync](../../labs/01-argo-cd/lab-03-sync-management.md) - 30 minutes
- [Lab 04: Implementing RBAC](../../labs/01-argo-cd/lab-04-rbac.md) - 40 minutes
- [Lab 05: Working with Helm Charts](../../labs/01-argo-cd/lab-05-helm.md) - 35 minutes
- [Lab 06: Multi-Cluster Setup](../../labs/01-argo-cd/lab-06-multi-cluster.md) - 45 minutes

## Study Resources

- [Argo CD Official Documentation](https://argo-cd.readthedocs.io/) - Complete reference guide
- [Argo CD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/) - Quick start guide
- [GitOps Principles](https://opengitops.dev/) - Understanding GitOps methodology
- [Argo CD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/) - Production deployment guidance

## Key Exam Topics

Focus on these critical areas for the exam:

- Understanding the GitOps workflow and principles
- Application resource structure and components
- Sync phases and their meanings
- Health status assessment
- Repository connection and management
- Application project isolation
- SSO and authentication mechanisms
- Cluster credential management
