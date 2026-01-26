# Lab 03: Advanced Sync Management in Argo CD

## Objectives

- Configure automated sync policies for continuous deployment
- Understand and implement prune and self-heal options
- Use sync waves to control resource deployment order
- Implement pre-sync and post-sync hooks for advanced workflows
- Handle sync failures and conflicts
- Configure selective resource synchronization
- Understand sync windows and maintenance periods

## Prerequisites

- Completed Lab 01 and Lab 02
- Argo CD running and accessible
- At least one application deployed in Argo CD
- Git repository access for making changes
- Understanding of Kubernetes resource dependencies

## Estimated Time

30 minutes

---

## Part 1: Automated Sync Policies

### Task 1.1: Understanding Sync Policies

Argo CD supports three sync approaches:

- **Manual:** User must trigger sync (default)
- **Automated:** Argo CD automatically syncs when Git changes are detected
- **Automated with Prune:** Also removes resources deleted from Git
- **Automated with Self-Heal:** Also reverts manual changes to the cluster

Let's explore each option.

### Task 1.2: Enable Automated Sync

```bash
# First, create a new test application
argocd app create sync-demo \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy none

# Sync it once to deploy
argocd app sync sync-demo

# Check current sync policy
argocd app get sync-demo | grep "Sync Policy"
```

**Expected Output:**

```
Sync Policy:        <none>
```

Now enable automated sync:

```bash
# Enable automated sync
argocd app set sync-demo --sync-policy automated

# Verify the change
argocd app get sync-demo | grep "Sync Policy"
```

**Expected Output:**

```
Sync Policy:        Automated
```

### Task 1.3: Test Automated Sync Behavior

```bash
# Make a change directly in the cluster (this simulates drift)
kubectl scale deployment guestbook-ui -n default --replicas=3

# Check the application status
argocd app get sync-demo

# Wait and observe - without self-heal, the app remains "OutOfSync"
# Argo CD won't automatically revert manual changes yet
```

**Expected Output:**

```
Sync Status:        OutOfSync from HEAD (53e28ff)
Health Status:      Healthy
...
```

**Question:** Why is the application marked as "OutOfSync" even with automated sync enabled?

---

## Part 2: Prune and Self-Heal Options

### Task 2.1: Understanding Prune Option

The prune option tells Argo CD to delete resources that exist in the cluster but not in Git.

```bash
# Enable prune option
argocd app set sync-demo --sync-option Prune=true

# Alternative: Set prune in sync policy
argocd app set sync-demo --sync-policy automated --auto-prune

# Verify
argocd app get sync-demo | grep -A3 "Sync Policy"
```

**Expected Output:**

```
Sync Policy:        Automated (Prune)
```

### Task 2.2: Test Prune Behavior

```bash
# Create an extra resource manually (not in Git)
kubectl create deployment test-prune --image=nginx -n default
kubectl label deployment test-prune app.kubernetes.io/instance=sync-demo

# Wait a moment and check - Argo CD should NOT delete it
# because it's not tracked in the application manifest
kubectl get deployment test-prune -n default

# Manually delete it for cleanup
kubectl delete deployment test-prune -n default
```

**Important Note:** Prune only removes resources that Argo CD previously created. It doesn't delete arbitrary resources.

### Task 2.3: Enable Self-Heal

Self-heal automatically reverts manual changes to match Git state.

```bash
# Enable self-heal
argocd app set sync-demo --self-heal

# Verify
argocd app get sync-demo | grep -A3 "Sync Policy"
```

**Expected Output:**

```
Sync Policy:        Automated (Prune, Self-Heal)
```

### Task 2.4: Test Self-Heal Behavior

```bash
# Make a manual change
kubectl scale deployment guestbook-ui -n default --replicas=5

# Check immediately
kubectl get deployment guestbook-ui -n default

# Wait 5 seconds and check again
sleep 5
kubectl get deployment guestbook-ui -n default

# Argo CD should have reverted it back to 1 replica
```

**Expected Output (after self-heal):**

```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
guestbook-ui   1/1     1            1           10m
```

**Question:** How quickly did self-heal revert the change? What are the implications for production systems?

---

## Part 3: Sync Waves

Sync waves control the order in which resources are deployed. Lower wave numbers are deployed first.

### Task 3.1: Create an Application with Dependencies

```bash
# Create a directory for our sync wave example
mkdir -p ~/sync-waves-demo
cd ~/sync-waves-demo

# Create a namespace (wave 0)
cat <<EOF > namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: wave-demo
  annotations:
    argocd.argoproj.io/sync-wave: "0"
EOF

# Create a ConfigMap (wave 1)
cat <<EOF > configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"
data:
  database_url: "postgres://db:5432/myapp"
  log_level: "info"
EOF

# Create a Secret (wave 1)
cat <<EOF > secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"
type: Opaque
stringData:
  db-password: "supersecret"
EOF

# Create a Deployment (wave 2)
cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_url
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: db-password
EOF

# Create a Service (wave 3)
cat <<EOF > service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Initialize git repo and commit
git init
git add .
git commit -m "Initial commit with sync waves"

# Create GitHub repo and push (replace with your username)
# Option 1: Using GitHub CLI
gh repo create sync-waves-demo --public --source=. --remote=origin --push

# Option 2: Manual
# Create repo on GitHub, then:
# git remote add origin https://github.com/$GITHUB_USER/sync-waves-demo.git
# git branch -M main
# git push -u origin main
```

### Task 3.2: Deploy Application with Sync Waves

```bash
# Create Argo CD application
argocd app create sync-waves \
  --repo https://github.com/$GITHUB_USER/sync-waves-demo.git \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace wave-demo \
  --sync-policy automated

# Sync and watch the order of resource creation
argocd app sync sync-waves --async

# Watch the sync progress
watch -n 1 'argocd app get sync-waves'
# Press Ctrl+C when complete

# Check the resources
kubectl get all -n wave-demo
```

**Expected Sync Order:**

1. Wave 0: Namespace
2. Wave 1: ConfigMap, Secret (in parallel)
3. Wave 2: Deployment
4. Wave 3: Service

**Question:** What happens if the ConfigMap is not created before the Deployment tries to reference it?

### Task 3.3: View Sync Waves in UI

1. Open Argo CD UI
2. Navigate to the `sync-waves` application
3. Click "Sync"
4. Observe the sync waves indicator showing deployment progress
5. Notice resources are grouped by wave number

---

## Part 4: Sync Hooks

Sync hooks allow you to run jobs at specific points in the sync process.

### Task 4.1: Understanding Hook Types

Available hook types:

- `PreSync`: Runs before the sync operation
- `Sync`: Runs during sync (normal resource)
- `PostSync`: Runs after all sync resources complete
- `SyncFail`: Runs when sync fails
- `Skip`: Resource is ignored

### Task 4.2: Create Pre-Sync Hook (Database Migration)

```bash
# Navigate to your sync-waves-demo directory
cd ~/sync-waves-demo

# Create a pre-sync job (runs before deployment)
cat <<EOF > presync-migration.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "1"
spec:
  template:
    spec:
      containers:
      - name: migration
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo "Running database migrations..."
          sleep 5
          echo "Migration completed successfully!"
      restartPolicy: Never
  backoffLimit: 2
EOF

# Commit and push
git add presync-migration.yaml
git commit -m "Add pre-sync database migration hook"
git push
```

### Task 4.3: Create Post-Sync Hook (Smoke Test)

```bash
# Create a post-sync job
cat <<EOF > postsync-test.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "2"
spec:
  template:
    spec:
      containers:
      - name: test
        image: curlimages/curl:7.85.0
        command:
        - sh
        - -c
        - |
          echo "Running smoke tests..."
          # Test service connectivity
          if curl -f http://web-app.wave-demo.svc.cluster.local; then
            echo "Smoke test passed!"
            exit 0
          else
            echo "Smoke test failed!"
            exit 1
          fi
      restartPolicy: Never
  backoffLimit: 3
EOF

# Commit and push
git add postsync-test.yaml
git commit -m "Add post-sync smoke test hook"
git push
```

### Task 4.4: Test Hooks

```bash
# Trigger a sync to see hooks in action
argocd app sync sync-waves

# Watch the progress
argocd app get sync-waves --refresh

# Check job execution
kubectl get jobs -n wave-demo
kubectl logs job/db-migration -n wave-demo
kubectl logs job/smoke-test -n wave-demo
```

**Expected Output:**

```
NAME           COMPLETIONS   DURATION   AGE
db-migration   1/1           5s         1m
smoke-test     1/1           3s         45s
```

**Question:** What is the purpose of `hook-delete-policy: HookSucceeded`? What other options are available?

---

## Part 5: Selective Resource Sync

### Task 5.1: Sync Specific Resources

```bash
# List all resources in an application
argocd app resources sync-waves

# Sync only a specific resource
argocd app sync sync-waves --resource apps:Deployment:wave-demo:web-app

# Sync multiple specific resources
argocd app sync sync-waves \
  --resource :ConfigMap:wave-demo:app-config \
  --resource apps:Deployment:wave-demo:web-app
```

### Task 5.2: Skip Resource Sync

```bash
# Add sync skip annotation to a resource
cd ~/sync-waves-demo

# Edit the secret to skip sync
cat <<EOF > secret-skip.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret-manual
  namespace: wave-demo
  annotations:
    argocd.argoproj.io/sync-options: Sync=false
type: Opaque
stringData:
  manual-key: "this-wont-sync"
EOF

# Commit and push
git add secret-skip.yaml
git commit -m "Add secret with sync skip"
git push

# Sync application - the secret won't be created
argocd app sync sync-waves
kubectl get secret app-secret-manual -n wave-demo
# Should return "not found"
```

---

## Part 6: Sync Windows

Sync windows allow you to restrict when syncs can occur (e.g., during maintenance windows).

### Task 6.1: Configure a Sync Window

```bash
# Create a sync window in the default project
# Allow syncs only during business hours (9 AM - 5 PM, Mon-Fri)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  application.sync-windows: |
    - kind: allow
      schedule: '0 9-17 * * 1-5'
      duration: 8h
      applications:
      - sync-waves
      clusters:
      - https://kubernetes.default.svc
      namespaces:
      - wave-demo
EOF

# Restart Argo CD server to pick up changes
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd

# Check sync windows
argocd proj windows list default
```

### Task 6.2: Test Sync Window (Optional)

```bash
# Try to sync outside the window (if current time is outside 9-5 Mon-Fri)
argocd app sync sync-waves

# You should see a message about sync window
# Check application status
argocd app get sync-waves | grep "Sync Window"
```

**Note:** For testing purposes, you might want to create a sync window that's currently active.

---

## Challenge Exercise

**Scenario:** You're deploying a complex microservices application that requires:

1. **Database Setup:**
   - Deploy a PostgreSQL database (wave 0)
   - Run database initialization script as PreSync hook
   - Create database credentials in a Secret (wave 1)

2. **Backend Service:**
   - Deploy backend API (wave 2)
   - Requires database to be ready
   - Run database migration as PreSync hook
   - Expose via Service

3. **Frontend Service:**
   - Deploy frontend (wave 3)
   - Requires backend API to be ready
   - Configure with backend URL in ConfigMap

4. **Post-Deployment:**
   - Run integration tests as PostSync hook
   - Send deployment notification (simulate with a simple job)

5. **Sync Configuration:**
   - Enable automated sync with self-heal
   - Configure prune to clean up old resources
   - Set sync window to allow syncs only between 8 AM - 8 PM

**Requirements:**

- Use sync waves appropriately
- Implement both PreSync and PostSync hooks
- Ensure proper dependency order
- Test that changes are auto-synced
- Test that manual changes are reverted (self-heal)
- Verify hooks execute in correct order

**Deliverables:**

- Git repository with all manifests
- Argo CD application configured with proper sync policies
- Documentation of sync wave strategy
- Test results showing hooks execution

---

## Cleanup

```bash
# Delete the applications
argocd app delete sync-demo --yes
argocd app delete sync-waves --yes

# Delete namespaces
kubectl delete namespace wave-demo --ignore-not-found

# Remove sync window configuration
kubectl delete configmap argocd-cm -n argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Clean up local repositories
rm -rf ~/sync-waves-demo
```

---

## Summary

Excellent work! You've mastered advanced sync management in Argo CD. Here are the key takeaways:

- **Automated Sync:** Enables continuous deployment when Git changes are detected
- **Prune:** Automatically removes resources deleted from Git
- **Self-Heal:** Automatically reverts manual cluster changes to match Git state
- **Sync Waves:** Control deployment order using annotations (lower numbers deploy first)
- **Sync Hooks:** Run jobs at specific points (PreSync, PostSync, SyncFail)
- **Hook Deletion Policies:** Control when hook resources are deleted (BeforeHookCreation, HookSucceeded, HookFailed)
- **Selective Sync:** Sync only specific resources when needed
- **Sync Windows:** Restrict when syncs can occur (maintenance windows)

**Key Annotations:**

```yaml
# Sync wave (controls order)
argocd.argoproj.io/sync-wave: "1"

# Hook type
argocd.argoproj.io/hook: PreSync

# Hook deletion policy
argocd.argoproj.io/hook-delete-policy: HookSucceeded

# Skip sync
argocd.argoproj.io/sync-options: Sync=false
```

**Key Commands:**

```bash
# Set sync policy
argocd app set <app> --sync-policy automated
argocd app set <app> --auto-prune
argocd app set <app> --self-heal

# Selective sync
argocd app sync <app> --resource <group:kind:namespace:name>

# View sync windows
argocd proj windows list <project>
```

**Best Practices:**

1. Use automated sync with self-heal only after testing
2. Always use sync waves for resources with dependencies
3. Implement PreSync hooks for migrations
4. Implement PostSync hooks for verification
5. Use meaningful wave numbers (0, 10, 20) to allow insertions
6. Test hooks thoroughly in non-production environments
7. Use sync windows to prevent syncs during critical periods

---

## Additional Practice

To reinforce your learning, try these additional exercises:

1. **Complex Sync Wave Scenario:**
   - Deploy a full stack application: database, cache, backend, frontend
   - Use sync waves to ensure proper startup order
   - Add health checks between waves

2. **Advanced Hooks:**
   - Implement a SyncFail hook to rollback changes
   - Create a notification hook using Slack/email
   - Use hooks to backup data before deployment

3. **Conditional Sync:**
   - Use sync options to skip resources conditionally
   - Implement dry-run hooks to validate before deployment
   - Create approval gates using manual sync

4. **Multi-App Dependencies:**
   - Deploy multiple applications with dependencies
   - Use sync waves across applications
   - Implement app-of-apps pattern with proper ordering

5. **Sync Performance:**
   - Measure sync time for large applications
   - Optimize using resource tracking and sync options
   - Implement parallel syncs where possible

6. **Production Patterns:**
   - Implement blue-green deployment using sync waves
   - Create canary deployments with manual promotion
   - Use sync windows for maintenance schedules

**Helpful Resources:**

- Sync Options: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/
- Sync Waves: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/
- Resource Hooks: https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/
- Sync Windows: https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/

---

## Solutions

<details>
<summary>Click to expand Challenge Exercise solutions</summary>

### Solution to Challenge Exercise

#### Step 1: Create Repository Structure

```bash
# Create project directory
mkdir -p ~/microservices-sync-challenge
cd ~/microservices-sync-challenge

# Create namespace
cat <<EOF > 00-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "0"
EOF

# Create PostgreSQL database
cat <<EOF > 10-database.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: myapp
        - name: POSTGRES_USER
          value: appuser
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
  clusterIP: None
EOF

# Create database credentials
cat <<EOF > 05-db-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "5"
type: Opaque
stringData:
  password: "postgres123"
  connection-string: "postgresql://appuser:postgres123@postgres:5432/myapp"
EOF

# Create PreSync hook for database initialization
cat <<EOF > hook-presync-db-init.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-init
  namespace: microservices
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    argocd.argoproj.io/sync-wave: "15"
spec:
  template:
    spec:
      containers:
      - name: init
        image: postgres:15
        env:
        - name: PGPASSWORD
          value: "postgres123"
        command:
        - sh
        - -c
        - |
          echo "Waiting for database to be ready..."
          until pg_isready -h postgres -p 5432 -U appuser; do
            sleep 2
          done
          echo "Database is ready!"
          echo "Creating initial schema..."
          psql -h postgres -U appuser -d myapp -c "
            CREATE TABLE IF NOT EXISTS users (
              id SERIAL PRIMARY KEY,
              username VARCHAR(50) UNIQUE NOT NULL,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
          "
          echo "Database initialization complete!"
      restartPolicy: Never
  backoffLimit: 3
EOF

# Create PreSync hook for backend migration
cat <<EOF > hook-presync-migration.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: backend-migration
  namespace: microservices
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "25"
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: postgres:15
        env:
        - name: PGPASSWORD
          value: "postgres123"
        command:
        - sh
        - -c
        - |
          echo "Running database migrations..."
          psql -h postgres -U appuser -d myapp -c "
            ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(100);
            CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
          "
          echo "Migrations completed successfully!"
      restartPolicy: Never
  backoffLimit: 2
EOF

# Create backend API
cat <<EOF > 30-backend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "30"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:0.2.3
        args:
        - "-text=Backend API v1.0"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: connection-string
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: backend-api
  namespace: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "30"
spec:
  selector:
    app: backend-api
  ports:
  - port: 8080
    targetPort: 8080
EOF

# Create frontend config
cat <<EOF > 35-frontend-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "35"
data:
  backend-url: "http://backend-api:8080"
  app-name: "Microservices Demo"
EOF

# Create frontend
cat <<EOF > 40-frontend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "40"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.25
        ports:
        - containerPort: 80
        env:
        - name: BACKEND_URL
          valueFrom:
            configMapKeyRef:
              name: frontend-config
              key: backend-url
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config
        configMap:
          name: frontend-config
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: microservices
  annotations:
    argocd.argoproj.io/sync-wave: "40"
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Create PostSync integration test
cat <<EOF > hook-postsync-test.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: integration-test
  namespace: microservices
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "50"
spec:
  template:
    spec:
      containers:
      - name: test
        image: curlimages/curl:7.85.0
        command:
        - sh
        - -c
        - |
          echo "Running integration tests..."

          # Test backend API
          if ! curl -f http://backend-api.microservices.svc.cluster.local:8080; then
            echo "Backend API test failed!"
            exit 1
          fi
          echo "Backend API test passed!"

          # Test frontend
          if ! curl -f http://frontend.microservices.svc.cluster.local; then
            echo "Frontend test failed!"
            exit 1
          fi
          echo "Frontend test passed!"

          echo "All integration tests passed!"
      restartPolicy: Never
  backoffLimit: 3
EOF

# Create PostSync notification
cat <<EOF > hook-postsync-notification.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: deployment-notification
  namespace: microservices
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "60"
spec:
  template:
    spec:
      containers:
      - name: notify
        image: busybox:1.35
        command:
        - sh
        - -c
        - |
          echo "========================================="
          echo "Deployment Notification"
          echo "========================================="
          echo "Application: Microservices"
          echo "Status: Successfully Deployed"
          echo "Timestamp: $(date)"
          echo "Components:"
          echo "  - Database (PostgreSQL)"
          echo "  - Backend API"
          echo "  - Frontend"
          echo "========================================="
          # In production, this would send to Slack/email
      restartPolicy: Never
  backoffLimit: 1
EOF

# Initialize Git
git init
git add .
git commit -m "Initial microservices application with sync waves and hooks"

# Create GitHub repo
gh repo create microservices-sync-challenge --public --source=. --remote=origin --push
```

#### Step 2: Create Argo CD Application

```bash
# Create application with automated sync, prune, and self-heal
argocd app create microservices \
  --repo https://github.com/$GITHUB_USER/microservices-sync-challenge.git \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace microservices \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Sync the application
argocd app sync microservices

# Watch deployment progress
watch -n 2 'argocd app get microservices'
```

#### Step 3: Configure Sync Window

```bash
# Create a project with sync window
argocd proj create microservices-proj

# Add sync window (8 AM - 8 PM daily)
argocd proj windows add microservices-proj \
  --kind allow \
  --schedule "0 8-20 * * *" \
  --duration 12h \
  --applications "*"

# Update application to use the project
argocd app set microservices --project microservices-proj

# Add destination and source to project
argocd proj add-destination microservices-proj \
  https://kubernetes.default.svc microservices

argocd proj add-source microservices-proj \
  "https://github.com/$GITHUB_USER/microservices-sync-challenge.git"
```

#### Step 4: Test Automated Sync

```bash
# Make a change to trigger auto-sync
cd ~/microservices-sync-challenge
sed -i '' 's/replicas: 2/replicas: 3/' 30-backend.yaml
git add 30-backend.yaml
git commit -m "Scale backend to 3 replicas"
git push

# Wait and observe auto-sync (within 3 minutes)
watch -n 5 'argocd app get microservices | head -20'

# Verify scaling
kubectl get deployment backend-api -n microservices
```

#### Step 5: Test Self-Heal

```bash
# Make manual change
kubectl scale deployment frontend -n microservices --replicas=5

# Check immediately
kubectl get deployment frontend -n microservices

# Wait 5-10 seconds
sleep 10

# Verify self-heal reverted it
kubectl get deployment frontend -n microservices
# Should be back to 2 replicas
```

#### Step 6: Verify Hook Execution

```bash
# Check all jobs
kubectl get jobs -n microservices

# Check logs for each hook
echo "=== DB Init Hook ==="
kubectl logs job/db-init -n microservices

echo "=== Migration Hook ==="
kubectl logs job/backend-migration -n microservices

echo "=== Integration Test Hook ==="
kubectl logs job/integration-test -n microservices

echo "=== Notification Hook ==="
kubectl logs job/deployment-notification -n microservices
```

#### Step 7: Documentation

Create a `SYNC-STRATEGY.md` file:

```markdown
# Sync Strategy Documentation

## Sync Wave Strategy

| Wave | Resources | Purpose |
|------|-----------|---------|
| 0 | Namespace | Foundation |
| 5 | Secrets | Credentials before DB |
| 10 | Database | Data layer |
| 15 | DB Init Hook (PreSync) | Initialize schema |
| 25 | Migration Hook (PreSync) | Run migrations |
| 30 | Backend API | Application layer |
| 35 | Frontend Config | Configuration for frontend |
| 40 | Frontend | Presentation layer |
| 50 | Integration Test (PostSync) | Verify deployment |
| 60 | Notification (PostSync) | Alert team |

## Hook Strategy

### PreSync Hooks
1. **db-init** (Wave 15): Creates initial database schema
2. **backend-migration** (Wave 25): Runs database migrations

### PostSync Hooks
1. **integration-test** (Wave 50): Validates all services are working
2. **deployment-notification** (Wave 60): Sends deployment notification

## Sync Policies

- **Automated Sync**: Enabled - changes pushed to Git trigger automatic deployment
- **Prune**: Enabled - resources deleted from Git are removed from cluster
- **Self-Heal**: Enabled - manual changes are automatically reverted
- **Sync Window**: 8 AM - 8 PM daily

## Testing Results

✅ Automated sync: Verified - changes deployed within 3 minutes
✅ Self-heal: Verified - manual scaling reverted in <10 seconds
✅ Sync waves: Verified - resources deployed in correct order
✅ PreSync hooks: Verified - DB initialized before application deployment
✅ PostSync hooks: Verified - Tests run after deployment
```

#### Cleanup

```bash
# Delete application
argocd app delete microservices --yes

# Delete project
argocd proj delete microservices-proj

# Delete namespace
kubectl delete namespace microservices

# Clean up local files
rm -rf ~/microservices-sync-challenge
```

</details>
