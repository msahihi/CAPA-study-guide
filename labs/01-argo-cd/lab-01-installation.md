# Lab 01: Installing Argo CD

## Objectives

- Install Argo CD on a local Kubernetes cluster (minikube or kind)
- Verify the Argo CD installation and check all components are running
- Access the Argo CD Web UI and perform initial login
- Install and configure the Argo CD CLI tool
- Understand the Argo CD architecture and core components

## Prerequisites

- Basic knowledge of Kubernetes concepts (pods, services, deployments)
- One of the following local Kubernetes clusters installed:
  - minikube (v1.25.0 or later) OR
  - kind (v0.11.0 or later)
- kubectl CLI installed and configured
- At least 4GB of RAM available for the cluster
- Internet connection for downloading images and packages

## Estimated Time

20 minutes

---

## Part 1: Preparing Your Kubernetes Cluster

### Task 1.1: Start Your Local Kubernetes Cluster

**For minikube users:**

```bash
# Start minikube with sufficient resources
minikube start --cpus=2 --memory=4096 --driver=docker

# Verify the cluster is running
kubectl cluster-info
```

**For kind users:**

```bash
# Create a kind cluster
cat <<EOF | kind create cluster --name argocd-lab --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
EOF

# Verify the cluster is running
kubectl cluster-info --context kind-argocd-lab
```

**Expected Output:**

```
Kubernetes control plane is running at https://...
CoreDNS is running at https://...
```

**Question:** What is the purpose of the `extraPortMappings` in the kind configuration?

### Task 1.2: Verify Cluster Connectivity

```bash
# Check that kubectl can communicate with the cluster
kubectl get nodes

# Check available namespaces
kubectl get namespaces
```

**Expected Output:**

For `kubectl get nodes`:

```
NAME                       STATUS   ROLES           AGE   VERSION
argocd-lab-control-plane   Ready    control-plane   1m    v1.27.3
```

For `kubectl get namespaces`:

```
NAME              STATUS   AGE
default           Active   26s
kube-node-lease   Active   26s
kube-public       Active   26s
kube-system       Active   26s
```

---

## Part 2: Installing Argo CD

### Task 2.1: Create the Argo CD Namespace

```bash
# Create a dedicated namespace for Argo CD
kubectl create namespace argocd

# Verify the namespace was created
kubectl get namespaces | grep argocd
```

**Expected Output:**

```
argocd            Active   5s
```

### Task 2.2: Install Argo CD

```bash
# Install Argo CD using the stable manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for the installation to complete (this may take 2-3 minutes)
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

**Expected Output:**

```
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created
serviceaccount/argocd-application-controller created
...
```

### Task 2.3: Verify Argo CD Installation

```bash
# Check all Argo CD deployments, pods, and services
kubectl get deploy,pods,svc -n argocd
```

**Expected Output:**

```
NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/argocd-applicationset-controller   1/1     1            1           53s
deployment.apps/argocd-dex-server                  1/1     1            1           52s
deployment.apps/argocd-notifications-controller    1/1     1            1           52s
deployment.apps/argocd-redis                       1/1     1            1           52s
deployment.apps/argocd-repo-server                 1/1     1            1           52s
deployment.apps/argocd-server                      1/1     1            1           52s

NAME                                                   READY   STATUS    RESTARTS   AGE
pod/argocd-application-controller-0                    1/1     Running   0          52s
pod/argocd-applicationset-controller-967c7df85-kh55c   1/1     Running   0          52s
pod/argocd-dex-server-7655cd44b9-pb6kl                 1/1     Running   0          52s
pod/argocd-notifications-controller-dc89756cd-crqn5    1/1     Running   0          52s
pod/argocd-redis-5b98c94768-qmjt2                      1/1     Running   0          52s
pod/argocd-repo-server-7f8c748c4c-fftl9                1/1     Running   0          52s
pod/argocd-server-74b7b9c7cc-bv5jk                     1/1     Running   0          52s

NAME                                              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/argocd-applicationset-controller          ClusterIP   10.96.145.212   <none>        7000/TCP,8080/TCP            53s
service/argocd-dex-server                         ClusterIP   10.108.4.6      <none>        5556/TCP,5557/TCP,5558/TCP   53s
service/argocd-metrics                            ClusterIP   10.101.38.38    <none>        8082/TCP                     53s
service/argocd-notifications-controller-metrics   ClusterIP   10.100.51.181   <none>        9001/TCP                     53s
service/argocd-redis                              ClusterIP   10.99.251.189   <none>        6379/TCP                     53s
service/argocd-repo-server                        ClusterIP   10.111.44.35    <none>        8081/TCP,8084/TCP            53s
service/argocd-server                             ClusterIP   10.105.63.43    <none>        80/TCP,443/TCP               53s
service/argocd-server-metrics                     ClusterIP   10.101.31.116   <none>        8083/TCP                     53s
```

**Note:** All pods should show `READY 1/1` and `STATUS Running`. The deployments should show `READY 1/1` and `AVAILABLE 1`.

**Question:** What is the role of each Argo CD component? (Hint: Look up the documentation or observe the component names)

---

## Part 3: Accessing the Argo CD UI

### Task 3.1: Expose the Argo CD Server

**Method 1: Using kubectl port-forward (Recommended for local development)**

```bash
# Port forward the Argo CD server to your local machine
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Note: The & runs this in the background. To bring it to foreground, use 'fg'
```

**Method 2: Using NodePort (For kind/minikube with LoadBalancer support)**

```bash
# Patch the service to use NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Get the NodePort
kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}'

# For minikube, get the URL
minikube service argocd-server -n argocd --url
```

### Task 3.2: Retrieve the Initial Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Save this password for login
```

**Expected Output:**

```
aB3dEfGh1JkLmN0pQrStUvW  (example password)
```

### Task 3.3: Login to the Argo CD UI

1. Open your web browser and navigate to `https://localhost:8080`
2. Accept the self-signed certificate warning (click "Advanced" and "Proceed")
3. Enter the credentials:
   - **Username:** `admin`
   - **Password:** (the password you retrieved in Task 3.2)
4. Click "Sign In"

**Question:** What do you see on the main dashboard after logging in?

---

## Part 4: Installing and Configuring the Argo CD CLI

### Task 4.1: Download and Install the CLI

**For macOS:**

```bash
# Download the latest Argo CD CLI
brew install argocd

# Verify installation
argocd version --client
```

**For Linux:**

```bash
# Download the latest Argo CD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Install the CLI
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Verify installation
argocd version --client
```

**For Windows (PowerShell):**

```powershell
# Download the latest Argo CD CLI
$url = "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe"
$output = "$env:USERPROFILE\argocd.exe"
Invoke-WebRequest -Uri $url -OutFile $output

# Add to PATH or move to a directory in PATH
# Verify installation
argocd version --client
```

**Expected Output:**

```
argocd: v3.2.6+7d4f3e8
  BuildDate: 2026-02-01T10:30:00Z
  GitCommit: 7d4f3e8ed9c7c90d7b9e5e0e0e6d8a9f3d7c2c0a
  GoVersion: go1.23.0
  Compiler: gc
  Platform: darwin/amd64
```

### Task 4.2: Login Using the CLI

```bash
# Login to Argo CD (using port-forward endpoint)
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --insecure

# Verify login by checking server version
argocd version
```

**Expected Output:**

```
'admin:login' logged in successfully
Context 'localhost:8080' updated

argocd: v3.2.6+7d4f3e8
  BuildDate: 2026-02-01T10:30:00Z
  ...
argocd-server: v3.3.0+a1b2c3d
  ...
```

### Task 4.3: Change the Admin Password (Recommended)

```bash
# Update the admin password to something you'll remember
argocd account update-password --current-password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --new-password 'NewSecurePassword123!'

# Test login with new password
argocd logout localhost:8080
argocd login localhost:8080 --username admin --password 'NewSecurePassword123!' --insecure
```

### Task 4.4: Explore CLI Commands

```bash
# List available commands
argocd --help

# Get cluster information
argocd cluster list

# Get current context
argocd context
```

**Question:** What clusters are currently registered with Argo CD?

---

## Challenge Exercise

**Scenario:** You've been asked to set up Argo CD for a new development team. They need:

1. Argo CD installed on a fresh Kubernetes cluster
2. The admin password changed to a secure password of your choice
3. A way to access the UI without using port-forwarding (configure Ingress or LoadBalancer)
4. Documentation of all Argo CD components and their resource usage

**Tasks:**

- Install Argo CD on a new cluster
- Configure permanent access to the UI
- Document the resource requests and limits for each component
- Change the admin password and verify CLI and UI access

**Hint:** You may need to look into Kubernetes Ingress controllers or LoadBalancer services for permanent access.

---

## Cleanup

If you want to remove Argo CD and start fresh:

```bash
# Delete Argo CD and all its resources
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Delete the namespace
kubectl delete namespace argocd

# Stop port-forwarding if running
pkill -f "port-forward svc/argocd-server"

# Optional: Delete the entire cluster
# For minikube:
minikube delete

# For kind:
kind delete cluster --name argocd-lab
```

---

## Summary

Congratulations! You've successfully completed the Argo CD installation lab. Here are the key takeaways:

- **Argo CD Components:** You learned about the core components including the API server, repository server, application controller, and Dex (for SSO)
- **Installation Methods:** You installed Argo CD using kubectl and the official manifests
- **Access Methods:** You explored multiple ways to access the Argo CD UI (port-forward, NodePort)
- **CLI Tools:** You installed and configured the Argo CD CLI for command-line management
- **Security:** You learned how to retrieve and change the initial admin password

**Key Commands to Remember:**

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd login <server> --username admin --password <password>
argocd version
```

---

## Additional Practice

To deepen your understanding, try these additional exercises:

1. **High Availability Setup:** Research and configure Argo CD in HA mode with multiple replicas
2. **Ingress Configuration:** Set up an Ingress controller (like nginx-ingress) and expose Argo CD through a proper domain name
3. **Metrics and Monitoring:** Install Prometheus and Grafana, then configure Argo CD metrics collection
4. **Resource Tuning:** Adjust the CPU and memory limits for Argo CD components based on your cluster size
5. **Custom Branding:** Explore how to customize the Argo CD UI with your organization's branding
6. **SSO Integration:** Research how to integrate Argo CD with an identity provider (GitHub, GitLab, LDAP, etc.)

**Helpful Resources:**

- Official Documentation: https://argo-cd.readthedocs.io/en/stable/
- Getting Started Guide: https://argo-cd.readthedocs.io/en/stable/getting_started/
- Operator Manual: https://argo-cd.readthedocs.io/en/stable/operator-manual/

---

## Solutions

<details>
<summary>Click to expand Challenge Exercise solutions</summary>

### Solution to Challenge Exercise

#### 1. Install Argo CD on a Fresh Cluster

```bash
# Start a new cluster
kind create cluster --name argocd-challenge

# Create namespace and install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

#### 2. Configure Permanent Access (Using LoadBalancer)

```bash
# Patch the service to LoadBalancer type
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# For cloud providers, get the external IP
kubectl get svc argocd-server -n argocd

# For local clusters with MetalLB or similar
# Install MetalLB first, then the LoadBalancer will get an IP
```

#### 3. Document Resource Usage

```bash
# Get resource requests and limits for all Argo CD components
kubectl get deployments -n argocd -o custom-columns=NAME:.metadata.name,CPU_REQUEST:.spec.template.spec.containers[0].resources.requests.cpu,MEMORY_REQUEST:.spec.template.spec.containers[0].resources.requests.memory,CPU_LIMIT:.spec.template.spec.containers[0].resources.limits.cpu,MEMORY_LIMIT:.spec.template.spec.containers[0].resources.limits.memory

# Get actual resource usage
kubectl top pods -n argocd
```

**Sample Output:**

```
NAME                                    CPU_REQUEST   MEMORY_REQUEST   CPU_LIMIT   MEMORY_LIMIT
argocd-applicationset-controller        <none>        <none>           <none>      <none>
argocd-dex-server                       <none>        <none>           <none>      <none>
argocd-notifications-controller         <none>        <none>           <none>      <none>
argocd-redis                            <none>        <none>           <none>      <none>
argocd-repo-server                      <none>        <none>           <none>      <none>
argocd-server                           <none>        <none>           <none>      <none>
```

#### 4. Change Admin Password

```bash
# Install CLI and login
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --insecure

# Change password
argocd account update-password --current-password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --new-password 'SecureDevTeamPass2024!'

# Verify CLI access
argocd logout localhost:8080
argocd login localhost:8080 --username admin --password 'SecureDevTeamPass2024!' --insecure
argocd cluster list

# Verify UI access by logging in through the browser
```

**Documentation Template:**

```markdown
# Argo CD Installation Documentation

## Cluster Information
- Cluster Name: argocd-challenge
- Kubernetes Version: v1.27.3
- Provider: kind (local)

## Argo CD Components

### 1. Application Controller (StatefulSet)
- Purpose: Monitors applications and compares desired vs live state
- Resources: No limits set (default)
- Actual Usage: ~50m CPU, ~100Mi Memory

### 2. API Server (Deployment)
- Purpose: Exposes gRPC/REST API consumed by UI, CLI
- Resources: No limits set (default)
- Actual Usage: ~20m CPU, ~80Mi Memory

### 3. Repository Server (Deployment)
- Purpose: Maintains local cache of Git repos
- Resources: No limits set (default)
- Actual Usage: ~10m CPU, ~60Mi Memory

### 4. Dex Server (Deployment)
- Purpose: Identity service for SSO integration
- Resources: No limits set (default)
- Actual Usage: ~5m CPU, ~30Mi Memory

### 5. Redis (Deployment)
- Purpose: Caching for application state
- Resources: No limits set (default)
- Actual Usage: ~5m CPU, ~20Mi Memory

## Access Information
- UI URL: https://localhost:8080 (or LoadBalancer IP)
- Admin Username: admin
- Admin Password: SecureDevTeamPass2024!

## Installation Date
- Installed: 2026-01-26
- Version: v2.9.3
```

</details>
