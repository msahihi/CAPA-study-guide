# Lab 02: Deploying Your First Application with Argo CD

## Objectives

- Deploy your first application to Kubernetes using Argo CD
- Understand the relationship between Git repositories and deployed applications
- Explore the Argo CD UI to monitor application status and health
- Make changes to application manifests and observe Argo CD's sync behavior
- Learn about application sync status, health status, and revision history
- Perform manual and automatic synchronization

## Prerequisites

- Completed Lab 01 (Argo CD installation)
- Argo CD running and accessible via CLI and UI
- Basic understanding of Kubernetes manifests (Deployment, Service)
- Git repository access (GitHub account for forking examples)
- kubectl CLI configured

## Estimated Time

30 minutes

---

## Part 1: Preparing Your Application Repository

### Task 1.1: Fork the Sample Application Repository

For this lab, we'll use a sample guestbook application. You have two options:

**Option A: Use the official Argo CD example repository (Read-only)**

```bash
# We'll use the official example repository
# Repository: https://github.com/argoproj/argocd-example-apps
# No forking needed for this option, but you won't be able to make changes
```

**Option B: Fork the repository to your GitHub account (Recommended)**

1. Go to: https://github.com/argoproj/argocd-example-apps
2. Click "Fork" in the top-right corner
3. Select your GitHub account as the destination
4. Wait for the fork to complete

```bash
# Set your GitHub username as a variable for easy reference
export GITHUB_USER="your-github-username"

# Verify the repository exists
curl -I https://github.com/$GITHUB_USER/argocd-example-apps
```

### Task 1.2: Explore the Application Manifests

```bash
# Clone the repository locally to explore its structure
git clone https://github.com/argoproj/argocd-example-apps.git
cd argocd-example-apps

# Explore the guestbook application structure
ls -R guestbook/

# View the deployment manifest
cat guestbook/guestbook-ui-deployment.yaml

# View the service manifest
cat guestbook/guestbook-ui-svc.yaml
```

**Expected Output (directory structure):**

```
guestbook/:
guestbook-ui-deployment.yaml
guestbook-ui-svc.yaml
```

**Question:** What container image is used for the guestbook application? What port does it expose?

---

## Part 2: Creating Your First Argo CD Application

### Task 2.1: Create an Application Using the CLI

```bash
# Create a new application called 'guestbook'
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Verify the application was created
argocd app list
```

**Expected Output:**

```
NAME       CLUSTER                         NAMESPACE  PROJECT  STATUS     HEALTH   SYNCPOLICY  CONDITIONS
guestbook  https://kubernetes.default.svc  default    default  OutOfSync  Missing  <none>      <none>
```

**Understanding the Command Parameters:**

- `--repo`: Git repository URL containing your application manifests
- `--path`: Directory path within the repository
- `--dest-server`: Kubernetes cluster API server URL (default means current cluster)
- `--dest-namespace`: Target namespace for deployment

### Task 2.2: View Application Details

```bash
# Get detailed information about the application
argocd app get guestbook

# View application status in a more compact format
argocd app get guestbook --show-params
```

**Expected Output:**

```
Name:               guestbook
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          default
URL:                https://localhost:8080/applications/guestbook
Repo:               https://github.com/argoproj/argocd-example-apps.git
Target:             HEAD
Path:               guestbook
SyncWindow:         Sync Allowed
Sync Policy:        <none>
Sync Status:        OutOfSync from HEAD (53e28ff)
Health Status:      Missing

GROUP  KIND        NAMESPACE  NAME          STATUS     HEALTH   HOOK  MESSAGE
       Service     default    guestbook-ui  OutOfSync  Missing
apps   Deployment  default    guestbook-ui  OutOfSync  Missing
```

**Question:** What does "OutOfSync" status mean? Why is the health status "Missing"?

---

## Part 3: Exploring the Argo CD UI

### Task 3.1: View the Application in the UI

1. Open the Argo CD UI in your browser (`https://localhost:8080`)
2. Login with your admin credentials
3. You should see the `guestbook` application card on the main dashboard
4. Click on the `guestbook` application card

**Observations:**

- Notice the sync status (OutOfSync)
- Notice the health status (Missing)
- The application shows desired resources but nothing deployed yet

### Task 3.2: Explore the Application Details View

In the application detail view, observe:

1. **Top Bar:** Shows sync status, health status, and action buttons
2. **Resource Tree:** Displays all Kubernetes resources managed by this application
3. **Summary Tab:** Shows application metadata and configuration
4. **Parameters Tab:** Shows any parameters defined for the application
5. **Manifest Tab:** Shows the actual Kubernetes manifests

**Question:** How many resources are part of this application? What types are they?

### Task 3.3: Inspect Resource Manifests

```bash
# View the manifests that Argo CD wants to deploy
argocd app manifests guestbook

# View diff between desired and live state (empty since nothing is deployed)
argocd app diff guestbook
```

---

## Part 4: Synchronizing Your Application

### Task 4.1: Manually Sync the Application (CLI)

```bash
# Sync the application (deploy it)
argocd app sync guestbook

# Watch the sync progress
argocd app wait guestbook --timeout 300

# Check the application status
argocd app get guestbook
```

**Expected Output:**

```
Name:               guestbook
...
Sync Status:        Synced to HEAD (53e28ff)
Health Status:      Healthy
...
GROUP  KIND        NAMESPACE  NAME          STATUS  HEALTH   HOOK  MESSAGE
       Service     default    guestbook-ui  Synced  Healthy        service/guestbook-ui created
apps   Deployment  default    guestbook-ui  Synced  Healthy        deployment.apps/guestbook-ui created
```

### Task 4.2: Verify Deployment with kubectl

```bash
# Check the deployed resources
kubectl get all -n default -l app=guestbook-ui

# Check deployment details
kubectl describe deployment guestbook-ui -n default

# Check pod logs
kubectl logs -l app=guestbook-ui -n default --tail=20
```

**Expected Output:**

```
NAME                               READY   STATUS    RESTARTS   AGE
pod/guestbook-ui-6c4f9f5d8-xxxxx   1/1     Running   0          2m

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/guestbook-ui   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    2m

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/guestbook-ui   1/1     1            1           2m
```

### Task 4.3: Access the Application

```bash
# Port-forward to access the guestbook application
kubectl port-forward svc/guestbook-ui -n default 8081:80 &

# Test the application
curl http://localhost:8081

# Or open in browser: http://localhost:8081
```

**Expected Output:**

```html
<!DOCTYPE html>
<html>
<head>
  <title>Guestbook</title>
...
```

**Question:** What happens in the UI when you complete the sync? What does the "Synced" status mean?

---

## Part 5: Making Changes and Observing Sync Behavior

### Task 5.1: Understanding Out-of-Sync Detection

If you're using the official repository (read-only), we'll simulate changes. If you forked it, you can make real changes.

**For forked repository users:**

```bash
# Clone your fork
cd /tmp
git clone https://github.com/$GITHUB_USER/argocd-example-apps.git
cd argocd-example-apps/guestbook

# Edit the deployment to increase replicas
sed -i '' 's/replicas: 1/replicas: 2/' guestbook-ui-deployment.yaml

# Or use your preferred editor
# Change: replicas: 1
# To: replicas: 2

# Commit and push changes
git add guestbook-ui-deployment.yaml
git commit -m "Scale guestbook to 2 replicas"
git push origin main

# Update Argo CD application to use your fork
argocd app set guestbook --repo https://github.com/$GITHUB_USER/argocd-example-apps.git
```

**For users using the official repository (simulation):**

```bash
# Manually scale the deployment outside of Argo CD
kubectl scale deployment guestbook-ui -n default --replicas=2

# Check Argo CD status (it will detect drift)
argocd app get guestbook
```

### Task 5.2: Observe the Out-of-Sync Status

```bash
# Wait a moment for Argo CD to detect the change (default: 3 minutes)
# You can force a refresh
argocd app get guestbook --refresh

# Check the diff
argocd app diff guestbook
```

**Expected Output:**

```
===== apps/Deployment default/guestbook-ui ======
...
spec:
-  replicas: 1
+  replicas: 2
...
```

**In the UI:**

1. Notice the application status changes to "OutOfSync"
2. The deployment resource shows a yellow warning icon
3. Click on the deployment to see the diff

**Question:** How long did it take for Argo CD to detect the change? (Default polling interval is 3 minutes)

### Task 5.3: Sync to Apply Changes

```bash
# Sync the application to apply Git changes (if using fork)
argocd app sync guestbook

# Or reset to Git state (if you manually scaled)
argocd app sync guestbook --prune

# Verify the replicas
kubectl get deployment guestbook-ui -n default
argocd app get guestbook
```

**Expected Output:**

```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
guestbook-ui   2/2     2            2           10m
```

---

## Part 6: Application Sync Options and History

### Task 6.1: View Sync History

```bash
# View application sync history
argocd app history guestbook

# Get detailed information about a specific revision
argocd app history guestbook --revision 1
```

**Expected Output:**

```
ID  DATE                           REVISION
0   2024-01-26 10:30:00 +0000 UTC  53e28ff (HEAD)
1   2024-01-26 10:35:00 +0000 UTC  a1b2c3d
```

### Task 6.2: Explore Sync Options

```bash
# Sync with pruning (removes resources not in Git)
argocd app sync guestbook --prune

# Dry run sync (preview without applying)
argocd app sync guestbook --dry-run

# Sync specific resources only
argocd app sync guestbook --resource apps:Deployment:default:guestbook-ui
```

**Understanding Sync Options:**

- `--prune`: Deletes resources that exist in the cluster but not in Git
- `--dry-run`: Shows what would be synced without actually syncing
- `--force`: Forces sync even if there are no changes
- `--resource`: Syncs only specific resources

### Task 6.3: Rollback to a Previous Revision

```bash
# View history to see available revisions
argocd app history guestbook

# Rollback to the first revision (if you made changes)
argocd app rollback guestbook 0

# Verify the rollback
argocd app get guestbook
kubectl get deployment guestbook-ui -n default
```

**Question:** What happens to the replica count after rollback?

---

## Challenge Exercise

**Scenario:** Your team wants to deploy a custom application to the cluster. You need to:

1. **Create a Git repository** with a simple Kubernetes application containing:
   - A Deployment running nginx with 3 replicas
   - A Service exposing the deployment
   - A ConfigMap with a custom index.html

2. **Deploy the application** using Argo CD with the following requirements:
   - Application name: `my-web-app`
   - Namespace: `web-apps` (create if needed)
   - Add labels to track the application

3. **Make changes** and observe sync behavior:
   - Update the nginx version in the deployment
   - Change the ConfigMap content
   - Scale the replicas to 5

4. **Document** the following:
   - Time taken for Argo CD to detect changes
   - Steps to rollback changes
   - How to view sync history

**Acceptance Criteria:**

- Application deploys successfully
- You can access the custom index.html through the service
- Changes trigger OutOfSync status
- You can sync and rollback changes

**No step-by-step provided - try to solve this on your own!**

---

## Cleanup

```bash
# Stop port-forwarding processes
pkill -f "port-forward"

# Delete the guestbook application from Argo CD
argocd app delete guestbook --yes

# Verify deletion
argocd app list

# Optional: Delete any remaining resources
kubectl delete all -l app=guestbook-ui -n default

# If you created a web-apps namespace for the challenge
kubectl delete namespace web-apps --ignore-not-found
```

---

## Summary

Excellent work! You've successfully deployed and managed your first application with Argo CD. Here are the key takeaways:

- **Application Creation:** You learned how to create Argo CD applications pointing to Git repositories
- **Sync Status:** You understand the difference between "Synced" and "OutOfSync" states
- **Health Status:** You can interpret health statuses (Healthy, Progressing, Degraded, Missing)
- **Manual Sync:** You performed manual synchronization using both CLI and UI
- **Change Detection:** You observed how Argo CD detects drift between Git and cluster state
- **Rollback:** You learned how to view history and rollback to previous revisions

**Key Commands to Remember:**

```bash
# Create application
argocd app create <name> --repo <repo-url> --path <path> --dest-server <server> --dest-namespace <ns>

# Sync application
argocd app sync <name>

# Get application status
argocd app get <name>

# View diff
argocd app diff <name>

# View history
argocd app history <name>

# Rollback
argocd app rollback <name> <revision>

# Delete application
argocd app delete <name>
```

**GitOps Principles Learned:**

1. Git is the single source of truth
2. Automated sync keeps cluster in sync with Git
3. Changes should be made in Git, not directly in the cluster
4. Full audit trail through Git history

---

## Additional Practice

To reinforce your learning, try these additional exercises:

1. **Multi-Environment Deployment:**
   - Create separate directories in your Git repo for `dev`, `staging`, `prod`
   - Deploy the same application to different namespaces
   - Use Kustomize overlays for environment-specific configurations

2. **Application Dependencies:**
   - Deploy a multi-tier application (frontend + backend + database)
   - Observe sync waves to control deployment order
   - Use sync hooks for database migrations

3. **Resource Tracking:**
   - Add custom labels to your applications
   - Use Argo CD to track resources across namespaces
   - Explore resource filtering options

4. **Manifest Generation:**
   - Try different manifest formats: plain YAML, Kustomize, Helm
   - Compare how Argo CD handles each type
   - Understand when to use each format

5. **Monitoring and Alerts:**
   - Explore application metrics in the UI
   - Set up notifications for sync failures
   - Monitor application health over time

6. **App-of-Apps Pattern:**
   - Create an application that deploys other applications
   - Use this pattern for managing multiple microservices
   - Understand the benefits and use cases

**Helpful Resources:**

- Application Specification: https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/
- Sync Options: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/
- Health Assessment: https://argo-cd.readthedocs.io/en/stable/operator-manual/health/
- Best Practices: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/

---

## Solutions

<details>
<summary>Click to expand Challenge Exercise solutions</summary>

### Solution to Challenge Exercise

#### Step 1: Create Git Repository with Application Manifests

```bash
# Create a new directory for your application
mkdir -p ~/my-web-app
cd ~/my-web-app

# Initialize Git repository
git init

# Create namespace manifest
cat <<EOF > namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: web-apps
EOF

# Create ConfigMap with custom HTML
cat <<EOF > configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
  namespace: web-apps
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
      <title>My Custom Web App</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          margin: 0;
        }
        .container {
          text-align: center;
          padding: 50px;
          background: rgba(255,255,255,0.1);
          border-radius: 10px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Welcome to My Custom Web App</h1>
        <p>Deployed with Argo CD - GitOps in Action!</p>
        <p>Version: 1.0</p>
      </div>
    </body>
    </html>
EOF

# Create Deployment
cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-web-app
  namespace: web-apps
  labels:
    app: my-web-app
    team: platform
    environment: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-web-app
  template:
    metadata:
      labels:
        app: my-web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: http
        volumeMounts:
        - name: web-content
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      volumes:
      - name: web-content
        configMap:
          name: web-content
EOF

# Create Service
cat <<EOF > service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-web-app
  namespace: web-apps
  labels:
    app: my-web-app
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: my-web-app
EOF

# Commit files
git add .
git commit -m "Initial commit: my-web-app"

# Create a GitHub repository and push
# (Replace with your GitHub username)
gh repo create my-web-app --public --source=. --remote=origin --push
# Or manually create the repo on GitHub and push
```

#### Step 2: Deploy with Argo CD

```bash
# Create the namespace first
kubectl create namespace web-apps

# Create Argo CD application
argocd app create my-web-app \
  --repo https://github.com/$GITHUB_USER/my-web-app.git \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace web-apps \
  --sync-policy none \
  --label team=platform \
  --label environment=dev

# Sync the application
argocd app sync my-web-app

# Wait for sync to complete
argocd app wait my-web-app --timeout 300

# Verify deployment
kubectl get all -n web-apps
argocd app get my-web-app
```

**Expected Output:**

```
NAME                              READY   STATUS    RESTARTS   AGE
pod/my-web-app-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
pod/my-web-app-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
pod/my-web-app-xxxxxxxxxx-xxxxx   1/1     Running   0          1m

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/my-web-app   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    1m

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/my-web-app   3/3     3            3           1m
```

#### Step 3: Test Access to the Application

```bash
# Port-forward the service
kubectl port-forward svc/my-web-app -n web-apps 8082:80 &

# Test with curl
curl http://localhost:8082

# Or open in browser
open http://localhost:8082
```

#### Step 4: Make Changes and Observe Sync

```bash
# Change 1: Update nginx version
cd ~/my-web-app
sed -i '' 's/nginx:1.25/nginx:1.26/' deployment.yaml
git add deployment.yaml
git commit -m "Update nginx to 1.26"
git push

# Change 2: Update ConfigMap
sed -i '' 's/Version: 1.0/Version: 2.0/' configmap.yaml
git add configmap.yaml
git commit -m "Update version to 2.0"
git push

# Change 3: Scale replicas
sed -i '' 's/replicas: 3/replicas: 5/' deployment.yaml
git add deployment.yaml
git commit -m "Scale to 5 replicas"
git push

# Note the time before Argo CD detects changes
date

# Wait for Argo CD to detect changes (default 3 minutes)
# Or force refresh
argocd app get my-web-app --refresh

# Check when OutOfSync is detected
argocd app get my-web-app

# Note the time after detection
date

# View the diff
argocd app diff my-web-app

# Sync the changes
argocd app sync my-web-app

# Verify changes
kubectl get deployment my-web-app -n web-apps
kubectl get pods -n web-apps | grep my-web-app
```

#### Step 5: Documentation

**Change Detection Time:**

```
Time of Git Push: 10:30:00
Time of Detection: 10:33:00
Detection Latency: 3 minutes (default polling interval)

Note: You can reduce this by:
1. Using webhooks (instant notification)
2. Reducing refresh interval in ConfigMap
3. Manual refresh with: argocd app get <app> --refresh
```

**Rollback Steps:**

```bash
# View sync history
argocd app history my-web-app

# Output:
# ID  DATE                           REVISION
# 0   2024-01-26 10:30:00 +0000 UTC  abc123 (Initial commit)
# 1   2024-01-26 10:31:00 +0000 UTC  def456 (Update nginx)
# 2   2024-01-26 10:32:00 +0000 UTC  ghi789 (Update version)
# 3   2024-01-26 10:33:00 +0000 UTC  jkl012 (Scale to 5)

# Rollback to revision 1
argocd app rollback my-web-app 1

# Verify rollback
argocd app get my-web-app
kubectl get deployment my-web-app -n web-apps -o yaml | grep -A5 "spec:"
```

**Sync History View:**

```bash
# Detailed history view
argocd app history my-web-app --output wide

# View specific revision details
argocd app manifests my-web-app --revision 2

# Compare two revisions
argocd app diff my-web-app --revision 1 --revision 2
```

#### Cleanup

```bash
# Delete the application
argocd app delete my-web-app --yes

# Delete namespace
kubectl delete namespace web-apps

# Stop port-forward
pkill -f "port-forward.*web-apps"

# Optional: Remove local repository
rm -rf ~/my-web-app
```

</details>
