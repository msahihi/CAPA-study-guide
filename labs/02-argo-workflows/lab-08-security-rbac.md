# Lab 08: Argo Workflows Security - RBAC and Secrets

**Duration:** 40 minutes
**Difficulty:** Intermediate

## Learning Objectives

By the end of this lab, you will be able to:

- Configure ServiceAccounts for workflow execution
- Implement RBAC roles with least privilege principles
- Use Kubernetes secrets in workflows via environment variables
- Mount secrets as volumes in workflow containers
- Apply security best practices for production workflows

## Prerequisites

- Running Kubernetes cluster with Argo Workflows installed
- kubectl configured to access your cluster
- Basic understanding of Kubernetes RBAC and Secrets

## Exercise 1: ServiceAccount Configuration (10 minutes)

### Overview

Workflows execute under a specified ServiceAccount. By default, they use the `default` ServiceAccount, which is **not recommended for production** as it may accumulate unintended permissions over time.

### Task

Create a dedicated ServiceAccount for workflow execution and configure minimum required permissions.

1. Create a ServiceAccount:

```bash
kubectl create serviceaccount workflow-executor -n argo
```

2. Create the minimum required Role (v3.4+):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-executor-role
  namespace: argo
rules:
  - apiGroups:
      - argoproj.io
    resources:
      - workflowtaskresults
    verbs:
      - create
      - patch
```

Save as `workflow-executor-role.yaml` and apply:

```bash
kubectl apply -f workflow-executor-role.yaml
```

3. Create RoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-executor-binding
  namespace: argo
subjects:
  - kind: ServiceAccount
    name: workflow-executor
    namespace: argo
roleRef:
  kind: Role
  name: workflow-executor-role
  apiGroup: rbac.authorization.k8s.io
```

Save as `workflow-executor-binding.yaml` and apply:

```bash
kubectl apply -f workflow-executor-binding.yaml
```

4. Create a workflow using the ServiceAccount:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: rbac-test-
  namespace: argo
spec:
  serviceAccountName: workflow-executor
  entrypoint: main
  templates:
  - name: main
    container:
      image: alpine:latest
      command: [sh, -c]
      args: ["echo 'Running with dedicated ServiceAccount'; whoami"]
```

Save as `rbac-workflow.yaml` and submit:

```bash
argo submit rbac-workflow.yaml -n argo --watch
```

### Verification

Check that the workflow completed successfully with the dedicated ServiceAccount:

```bash
argo logs @latest -n argo
```

### Key Concepts

- **Principle of Least Privilege**: Grant only necessary permissions
- **Dedicated ServiceAccounts**: Avoid using the default ServiceAccount
- **Minimum Permissions**: v3.4+ requires only `workflowtaskresults` access

## Exercise 2: RBAC for Resource Creation (10 minutes)

### Overview

If your workflow needs to create Kubernetes resources (e.g., ConfigMaps, Deployments), you must grant additional permissions.

### Task

Create a workflow that creates a ConfigMap, requiring expanded RBAC permissions.

1. Update the Role to include ConfigMap permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-executor-role
  namespace: argo
rules:
  - apiGroups:
      - argoproj.io
    resources:
      - workflowtaskresults
    verbs:
      - create
      - patch
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - create
      - get
      - list
```

Apply the updated role:

```bash
kubectl apply -f workflow-executor-role.yaml
```

2. Create a workflow that creates a ConfigMap:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: create-configmap-
  namespace: argo
spec:
  serviceAccountName: workflow-executor
  entrypoint: main
  templates:
  - name: main
    container:
      image: bitnami/kubectl:latest
      command: [sh, -c]
      args:
        - |
          kubectl create configmap workflow-generated-config \
            --from-literal=key1=value1 \
            --from-literal=key2=value2 \
            -n argo || true
          kubectl get configmap workflow-generated-config -n argo -o yaml
```

Submit and verify:

```bash
argo submit create-configmap-workflow.yaml -n argo --watch
```

### Verification

Check that the ConfigMap was created:

```bash
kubectl get configmap workflow-generated-config -n argo
```

### Key Concepts

- **Dynamic Permission Scoping**: Permissions scale with workflow complexity
- **Resource-Specific Permissions**: Grant access only to required resource types
- **Verb Restriction**: Use specific verbs (create, get, list) instead of wildcards

## Exercise 3: Using Secrets as Environment Variables (10 minutes)

### Overview

Argo Workflows uses Kubernetes' native secrets mechanism to expose sensitive data as environment variables.

### Task

Create a secret and use it in a workflow via environment variables.

1. Create a Kubernetes secret:

```bash
kubectl create secret generic my-secret \
  --from-literal=mypassword=S00perS3cretPa55word \
  --from-literal=api-key=abc123xyz789 \
  -n argo
```

2. Create a workflow that uses the secret:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: secret-env-
  namespace: argo
spec:
  serviceAccountName: workflow-executor
  entrypoint: main
  templates:
  - name: main
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "Password length: ${#MYSECRETPASSWORD}"
          echo "API Key prefix: ${APIKEY:0:3}..."
          echo "Secret values are available but not displayed"
      env:
      - name: MYSECRETPASSWORD
        valueFrom:
          secretKeyRef:
            name: my-secret
            key: mypassword
      - name: APIKEY
        valueFrom:
          secretKeyRef:
            name: my-secret
            key: api-key
```

Save as `secret-env-workflow.yaml` and submit:

```bash
argo submit secret-env-workflow.yaml -n argo --watch
```

### Verification

Check the logs to see that environment variables were set (but values are not exposed):

```bash
argo logs @latest -n argo
```

### Key Concepts

- **secretKeyRef**: References existing Kubernetes secret by name and key
- **Environment Variable Injection**: Secrets available as standard env vars
- **Security**: Never log or echo actual secret values

## Exercise 4: Mounting Secrets as Volumes (10 minutes)

### Overview

For file-based access to secrets (e.g., certificates, keys, config files), mount secrets as volumes.

### Task

Mount a secret as a volume and read files from it.

1. Create a secret with multiple files:

```bash
kubectl create secret generic my-cert-secret \
  --from-literal=tls.crt="-----BEGIN CERTIFICATE-----
MIICljCCAX4CCQC..." \
  --from-literal=tls.key="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBg..." \
  --from-literal=ca.crt="-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAw..." \
  -n argo
```

2. Create a workflow that mounts the secret:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: secret-volume-
  namespace: argo
spec:
  serviceAccountName: workflow-executor
  entrypoint: main
  volumes:
  - name: my-secret-vol
    secret:
      secretName: my-cert-secret
  templates:
  - name: main
    container:
      image: alpine:latest
      command: [sh, -c]
      args:
        - |
          echo "=== Mounted Secret Files ==="
          ls -la /secret/mountpath/
          echo ""
          echo "=== Certificate Info ==="
          head -n 2 /secret/mountpath/tls.crt
          echo "..."
          echo ""
          echo "=== File Sizes ==="
          wc -c /secret/mountpath/*
      volumeMounts:
      - name: my-secret-vol
        mountPath: "/secret/mountpath"
        readOnly: true
```

Save as `secret-volume-workflow.yaml` and submit:

```bash
argo submit secret-volume-workflow.yaml -n argo --watch
```

### Verification

Check that files were successfully mounted:

```bash
argo logs @latest -n argo
```

### Key Concepts

- **Volume Mounts**: Secrets exposed as files in the container filesystem
- **Read-Only Mounts**: Best practice to prevent accidental modification
- **Multiple Files**: Each secret key becomes a separate file

## Summary

In this lab, you learned:

✅ How to create dedicated ServiceAccounts for workflows
✅ Implementing RBAC roles with minimum required permissions
✅ Expanding permissions for resource creation workflows
✅ Using secrets as environment variables with `secretKeyRef`
✅ Mounting secrets as volumes for file-based access
✅ Security best practices for production workflows

## Best Practices

1. **Never use the default ServiceAccount in production**
2. **Follow the Principle of Least Privilege** - grant only necessary permissions
3. **Use dedicated ServiceAccounts per workflow type** or application
4. **Never log or expose secret values** in workflow outputs
5. **Use read-only volume mounts** for secrets
6. **Rotate secrets regularly** using Kubernetes secret management
7. **Audit RBAC permissions** periodically to remove unnecessary access

## Cleanup

Remove all resources created in this lab:

```bash
# Delete workflows
argo delete -n argo --all

# Delete ConfigMap
kubectl delete configmap workflow-generated-config -n argo

# Delete secrets
kubectl delete secret my-secret my-cert-secret -n argo

# Delete RBAC resources
kubectl delete rolebinding workflow-executor-binding -n argo
kubectl delete role workflow-executor-role -n argo
kubectl delete serviceaccount workflow-executor -n argo
```

## Additional Resources

- [Argo Workflows RBAC Documentation](https://argo-workflows.readthedocs.io/en/latest/workflow-rbac/)
- [Argo Workflows Secrets Walk-through](https://argo-workflows.readthedocs.io/en/latest/walk-through/secrets/)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
