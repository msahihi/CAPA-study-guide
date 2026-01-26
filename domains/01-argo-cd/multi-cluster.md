# Multi-Cluster Management

## Overview

Multi-cluster management is a powerful feature of Argo CD that enables deploying and managing applications across multiple Kubernetes clusters from a single control plane. This section covers adding external clusters, managing cluster credentials, cluster management operations, and implementing cross-cluster deployment strategies.

Understanding multi-cluster management is essential for the CAPA exam, as it demonstrates advanced Argo CD capabilities for managing complex, distributed Kubernetes environments across development, staging, production, and multiple regions or cloud providers.

## Key Topics

### Adding External Clusters

Argo CD can manage applications in the cluster where it's installed (in-cluster) and in external clusters.

#### In-Cluster vs External Clusters

**In-Cluster** (where Argo CD is installed):

- Referred to as the local cluster
- Uses internal Kubernetes API: `https://kubernetes.default.svc`
- No additional configuration required
- Default destination for applications

**External Clusters**:

- Separate Kubernetes clusters
- Require explicit registration
- Need cluster credentials (kubeconfig)
- Can be in different clouds/regions/data centers

#### Adding Clusters via CLI

**Prerequisites**:

- kubeconfig with access to target cluster
- Sufficient permissions in target cluster
- Network connectivity between Argo CD and target cluster

**Basic Cluster Addition**:

```bash
# Add cluster using current kubeconfig context
argocd cluster add <context-name>

# Add cluster with specific kubeconfig file
argocd cluster add <context-name> --kubeconfig /path/to/kubeconfig

# Add cluster with custom name
argocd cluster add <context-name> --name production-cluster

# Add cluster with specific namespace
argocd cluster add <context-name> --namespace argocd

# Add cluster with in-cluster flag (for cluster where Argo CD runs)
argocd cluster add <context-name> --in-cluster

# Add cluster with labels
argocd cluster add <context-name> \
  --label environment=production \
  --label region=us-east-1

# Add cluster with annotations
argocd cluster add <context-name> \
  --annotation team=platform \
  --annotation cost-center=engineering
```

**Example: Adding Multiple Clusters**:

```bash
# Add production cluster
argocd cluster add prod-cluster \
  --name production \
  --label environment=production \
  --label region=us-west-2

# Add staging cluster
argocd cluster add staging-cluster \
  --name staging \
  --label environment=staging \
  --label region=us-west-2

# Add development cluster
argocd cluster add dev-cluster \
  --name development \
  --label environment=development \
  --label region=us-east-1

# List all clusters
argocd cluster list

# Get cluster details
argocd cluster get https://prod-cluster.example.com
```

#### What Happens When Adding a Cluster

1. **Service Account Creation**: Creates `argocd-manager` ServiceAccount in target cluster
2. **RBAC Setup**: Creates ClusterRole and ClusterRoleBinding for the ServiceAccount
3. **Token Extraction**: Extracts ServiceAccount token for authentication
4. **Secret Creation**: Stores cluster credentials as Secret in Argo CD namespace
5. **Registration**: Registers cluster in Argo CD's cluster list

**ServiceAccount Created in Target Cluster**:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-manager-role
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-manager-role
subjects:
- kind: ServiceAccount
  name: argocd-manager
  namespace: kube-system
```

#### Adding Clusters Declaratively

Create cluster secret manually:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: production-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: production
    region: us-west-2
  annotations:
    managed-by: argocd
type: Opaque
stringData:
  name: production
  server: https://prod-cluster.example.com
  config: |
    {
      "bearerToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9...",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "LS0tLS1CRUdJTi..."
      }
    }
```

**Generate Config from Kubeconfig**:

```bash
# Extract server URL
kubectl config view -o jsonpath='{.clusters[0].cluster.server}'

# Extract CA data
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'

# Get ServiceAccount token
kubectl get secret -n kube-system \
  $(kubectl get sa argocd-manager -n kube-system -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d
```

### Cluster Credentials

#### Credential Types

**1. ServiceAccount Token** (Recommended):

```yaml
config: |
  {
    "bearerToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9...",
    "tlsClientConfig": {
      "insecure": false,
      "caData": "LS0tLS1CRUdJTi..."
    }
  }
```

**2. Client Certificate**:

```yaml
config: |
  {
    "tlsClientConfig": {
      "insecure": false,
      "caData": "LS0tLS1CRUdJTi...",
      "certData": "LS0tLS1CRUdJTi...",
      "keyData": "LS0tLS1CRUdJTi..."
    }
  }
```

**3. External Auth Provider** (AWS EKS, GKE, AKS):

```yaml
config: |
  {
    "execProviderConfig": {
      "command": "aws",
      "args": [
        "eks",
        "get-token",
        "--cluster-name",
        "my-cluster"
      ],
      "apiVersion": "client.authentication.k8s.io/v1beta1"
    },
    "tlsClientConfig": {
      "insecure": false,
      "caData": "LS0tLS1CRUdJTi..."
    }
  }
```

#### AWS EKS Cluster

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: eks-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: production
    cloud: aws
type: Opaque
stringData:
  name: eks-production
  server: https://ABC123.gr7.us-west-2.eks.amazonaws.com
  config: |
    {
      "awsAuthConfig": {
        "clusterName": "production-cluster"
      },
      "tlsClientConfig": {
        "insecure": false,
        "caData": "LS0tLS1CRUdJTi..."
      }
    }
```

**IAM Role for Argo CD**:

```yaml
# ServiceAccount for AWS IRSA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-application-controller
  namespace: argocd
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/argocd-controller-role

# IAM Role Trust Policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:argocd:argocd-application-controller"
        }
      }
    }
  ]
}
```

#### GCP GKE Cluster

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gke-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: production
    cloud: gcp
type: Opaque
stringData:
  name: gke-production
  server: https://34.82.123.45
  config: |
    {
      "execProviderConfig": {
        "command": "gke-gcloud-auth-plugin",
        "args": [],
        "apiVersion": "client.authentication.k8s.io/v1beta1",
        "installHint": "Install gke-gcloud-auth-plugin",
        "provideClusterInfo": true
      },
      "tlsClientConfig": {
        "insecure": false,
        "caData": "LS0tLS1CRUdJTi..."
      }
    }
```

#### Azure AKS Cluster

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aks-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: production
    cloud: azure
type: Opaque
stringData:
  name: aks-production
  server: https://myaks-dns-12345678.hcp.eastus.azmk8s.io:443
  config: |
    {
      "execProviderConfig": {
        "command": "kubelogin",
        "args": [
          "get-token",
          "--login",
          "spn",
          "--environment",
          "AzurePublicCloud",
          "--tenant-id",
          "tenant-id",
          "--server-id",
          "server-id"
        ],
        "apiVersion": "client.authentication.k8s.io/v1beta1"
      },
      "tlsClientConfig": {
        "insecure": false,
        "caData": "LS0tLS1CRUdJTi..."
      }
    }
```

### Cluster Management

#### Cluster Operations

**List Clusters**:

```bash
# List all clusters
argocd cluster list

# List clusters with specific label
argocd cluster list -l environment=production

# Get cluster details in YAML
argocd cluster get <cluster-url> -o yaml

# Get cluster details in JSON
argocd cluster get <cluster-url> -o json
```

**Update Cluster**:

```bash
# Update cluster name
argocd cluster set <cluster-url> --name new-name

# Add/update labels
argocd cluster set <cluster-url> \
  --label newlabel=value

# Add/update annotations
argocd cluster set <cluster-url> \
  --annotation key=value

# Update cluster credentials
argocd cluster set <cluster-url> \
  --kubeconfig /path/to/new/kubeconfig
```

**Remove Cluster**:

```bash
# Remove cluster
argocd cluster rm <cluster-url>

# Remove cluster with cascading delete
argocd cluster rm <cluster-url> --cascade
```

#### Cluster Labels and Selectors

Labels enable targeted deployments using ApplicationSets:

```bash
# Add labels during cluster addition
argocd cluster add prod-cluster \
  --label environment=production \
  --label region=us-west-2 \
  --label team=platform \
  --label cost-center=engineering

# Update labels on existing cluster
argocd cluster set https://prod-cluster.example.com \
  --label tier=critical
```

**Use Labels in ApplicationSet**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-apps
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production
            region: us-west-2

  template:
    metadata:
      name: '{{name}}-myapp'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/app.git
        targetRevision: main
        path: kubernetes
      destination:
        server: '{{server}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

#### Cluster Namespaces

Restrict Argo CD to specific namespaces in target clusters:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: restricted-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: restricted
  server: https://restricted-cluster.example.com
  namespaces: app-namespace,monitoring,logging
  config: |
    {
      "bearerToken": "...",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "..."
      }
    }
```

### Cross-Cluster Deployments

#### Single Application Across Clusters

Deploy same application to multiple clusters:

**Method 1: Multiple Application Definitions**:

```yaml
# Production cluster application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/app.git
    targetRevision: v1.0.0
    path: kubernetes/production
  destination:
    server: https://prod-cluster.example.com
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

---
# Staging cluster application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/app.git
    targetRevision: main
    path: kubernetes/staging
  destination:
    server: https://staging-cluster.example.com
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Method 2: ApplicationSet with Cluster Generator**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-multicluster
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            argocd.argoproj.io/secret-type: cluster

  template:
    metadata:
      name: 'myapp-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/app.git
        targetRevision: main
        path: kubernetes
      destination:
        server: '{{server}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

#### Environment-Specific Deployments

Deploy different configurations per environment:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: env-specific-deployment
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: production
            url: https://prod-cluster.example.com
            revision: v1.0.0
            replicas: "5"
            resources: "high"
          - cluster: staging
            url: https://staging-cluster.example.com
            revision: main
            replicas: "2"
            resources: "medium"
          - cluster: development
            url: https://dev-cluster.example.com
            revision: develop
            replicas: "1"
            resources: "low"

  template:
    metadata:
      name: 'myapp-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/app.git
        targetRevision: '{{revision}}'
        path: kubernetes
        helm:
          parameters:
            - name: replicaCount
              value: '{{replicas}}'
            - name: resources.preset
              value: '{{resources}}'
      destination:
        server: '{{url}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

#### Multi-Region Deployment

Deploy to clusters across different regions:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-region-app
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production
        values:
          imageTag: v1.0.0
          minReplicas: "3"

  template:
    metadata:
      name: '{{name}}-myapp'
      labels:
        region: '{{metadata.labels.region}}'
    spec:
      project: production
      source:
        repoURL: https://github.com/example/app.git
        targetRevision: main
        path: kubernetes/production
        helm:
          parameters:
            - name: image.tag
              value: '{{values.imageTag}}'
            - name: autoscaling.minReplicas
              value: '{{values.minReplicas}}'
            - name: region
              value: '{{metadata.labels.region}}'
      destination:
        server: '{{server}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

#### Progressive Rollout Across Clusters

Deploy to clusters in sequence:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: progressive-rollout
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: canary
            url: https://canary-cluster.example.com
            stage: "1"
          - cluster: staging
            url: https://staging-cluster.example.com
            stage: "2"
          - cluster: prod-us-west
            url: https://prod-us-west.example.com
            stage: "3"
          - cluster: prod-us-east
            url: https://prod-us-east.example.com
            stage: "4"
          - cluster: prod-eu-west
            url: https://prod-eu-west.example.com
            stage: "5"

  strategy:
    type: RollingSync
    rollingSync:
      steps:
        - matchExpressions:
            - key: stage
              operator: In
              values:
                - "1"
        - matchExpressions:
            - key: stage
              operator: In
              values:
                - "2"
        - matchExpressions:
            - key: stage
              operator: In
              values:
                - "3"
                - "4"
                - "5"

  template:
    metadata:
      name: 'myapp-{{cluster}}'
      labels:
        stage: '{{stage}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/app.git
        targetRevision: main
        path: kubernetes
      destination:
        server: '{{url}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

#### Hub-and-Spoke Architecture

Central Argo CD managing multiple clusters:

```yaml
# Hub cluster (where Argo CD runs)
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: hub-and-spoke
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchExpressions:
            - key: cluster-type
              operator: In
              values:
                - spoke

  template:
    metadata:
      name: 'platform-{{name}}'
    spec:
      project: platform
      source:
        repoURL: https://github.com/example/platform.git
        targetRevision: main
        path: 'clusters/{{name}}'
      destination:
        server: '{{server}}'
        namespace: platform
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true

---
# Spoke clusters configuration
apiVersion: v1
kind: Secret
metadata:
  name: spoke-cluster-1
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    cluster-type: spoke
    region: us-west-2
type: Opaque
stringData:
  name: spoke-1
  server: https://spoke1.example.com
  config: |
    {
      "bearerToken": "...",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "..."
      }
    }
```

## Practice Examples

### Example 1: Complete Multi-Cluster Setup

```bash
#!/bin/bash

# Add production cluster
argocd cluster add prod-cluster \
  --name production \
  --label environment=production \
  --label region=us-west-2 \
  --label tier=critical

# Add staging cluster
argocd cluster add staging-cluster \
  --name staging \
  --label environment=staging \
  --label region=us-west-2 \
  --label tier=standard

# Add development cluster
argocd cluster add dev-cluster \
  --name development \
  --label environment=development \
  --label region=us-east-1 \
  --label tier=standard

# List all clusters
argocd cluster list

# Verify clusters
argocd cluster get https://prod-cluster.example.com
argocd cluster get https://staging-cluster.example.com
argocd cluster get https://dev-cluster.example.com
```

### Example 2: Multi-Cluster ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-multicluster
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - clusters:
              selector:
                matchLabels:
                  argocd.argoproj.io/secret-type: cluster
          - list:
              elements:
                - app: frontend
                  path: guestbook/frontend
                - app: backend
                  path: guestbook/backend

  template:
    metadata:
      name: '{{app}}-{{name}}'
      labels:
        app: '{{app}}'
        cluster: '{{name}}'
        environment: '{{metadata.labels.environment}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/apps.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: '{{server}}'
        namespace: '{{app}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
```

### Example 3: Regional Deployment with Config Overrides

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: regional-app
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production
  template:
    metadata:
      name: 'myapp-{{metadata.labels.region}}'
    spec:
      project: production
      sources:
        - repoURL: https://github.com/example/app.git
          targetRevision: v1.0.0
          path: helm
          helm:
            releaseName: myapp
            valueFiles:
              - $values/environments/production/values.yaml
              - $values/regions/{{metadata.labels.region}}/values.yaml
        - repoURL: https://github.com/example/config.git
          targetRevision: main
          ref: values
      destination:
        server: '{{server}}'
        namespace: myapp
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

## Study Resources

- [Cluster Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)
- [ApplicationSet Cluster Generator](https://argocd-applicationset.readthedocs.io/en/stable/Generators-Cluster/)
- [Cluster Registration](https://argo-cd.readthedocs.io/en/stable/getting_started/#5-register-a-cluster-to-deploy-apps-to-optional)

## Key Points to Remember

- Argo CD can manage applications in local (in-cluster) and external clusters
- External clusters registered via `argocd cluster add` command
- Cluster registration creates ServiceAccount and RBAC in target cluster
- Cluster credentials stored as Secrets with label `argocd.argoproj.io/secret-type: cluster`
- Cluster Secret contains server URL, name, and config (token, certificates)
- In-cluster uses `https://kubernetes.default.svc` as server URL
- Cloud-managed clusters (EKS, GKE, AKS) require exec provider config
- Cluster labels enable targeted deployments with ApplicationSets
- ApplicationSet cluster generator creates apps for matching clusters
- Matrix generator combines cluster generator with others for complex scenarios
- Hub-and-spoke architecture: central Argo CD manages multiple spoke clusters
- Progressive rollout deploys to clusters sequentially
- Cluster namespaces can be restricted in cluster Secret
- Remove clusters with `argocd cluster rm` command
- Cluster credentials should be rotated periodically for security

## Hands-On Practice

For practical exercises and labs on multi-cluster management, see:

- [Lab 06: Multi-Cluster Setup](../../labs/01-argo-cd/lab-06-multi-cluster.md)
