# Lab 04: RBAC and Multi-Tenancy in Argo CD

## Objectives

- Understand Argo CD's RBAC (Role-Based Access Control) model
- Create and configure Argo CD Projects for multi-tenancy
- Define RBAC policies and bind them to users and groups
- Create local users and assign appropriate permissions
- Implement least-privilege access patterns
- Test access controls and verify security boundaries
- Configure SSO integration basics (optional)

## Prerequisites

- Completed Labs 01, 02, and 03
- Argo CD running and accessible
- Admin access to Argo CD
- Understanding of RBAC concepts
- Multiple terminal windows for testing different users

## Estimated Time

40 minutes

---

## Part 1: Understanding Argo CD Projects

### Task 1.1: Understanding the Default Project

```bash
# View the default project
argocd proj get default

# List all projects
argocd proj list

# View project details including RBAC
kubectl get appproject default -n argocd -o yaml
```

**Expected Output:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: default
  namespace: argocd
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  destinations:
  - namespace: '*'
    server: '*'
  sourceRepos:
  - '*'
```

**Question:** What does the default project allow? Is this appropriate for production environments?

### Task 1.2: Understanding Project Components

Projects in Argo CD control:

- **Source Repositories:** Which Git repos can be used
- **Destinations:** Which clusters and namespaces can be deployed to
- **Resource Whitelist/Blacklist:** Which Kubernetes resource types are allowed
- **Roles:** Custom roles with specific permissions

---

## Part 2: Creating Projects for Multi-Tenancy

### Task 2.1: Create a Development Team Project

```bash
# Create a project for the development team
argocd proj create dev-team \
  --description "Development team project" \
  --dest https://kubernetes.default.svc,dev-* \
  --src https://github.com/*

# View the created project
argocd proj get dev-team
```

**Expected Output:**

```
Name:                        dev-team
Description:                 Development team project
Source Repositories:         https://github.com/*
Destinations:                https://kubernetes.default.svc,dev-*
Signature keys:              -
Orphaned Resources:          disabled
```

### Task 2.2: Configure Resource Whitelist

```bash
# Allow only specific resource types
argocd proj allow-cluster-resource dev-team "" Namespace
argocd proj allow-cluster-resource dev-team apps Deployment
argocd proj allow-cluster-resource dev-team "" Service
argocd proj allow-cluster-resource dev-team "" ConfigMap
argocd proj allow-cluster-resource dev-team "" Secret

# View updated project
argocd proj get dev-team
```

### Task 2.3: Create a Production Team Project

```bash
# Create production project with stricter controls
argocd proj create prod-team \
  --description "Production team project - restricted" \
  --dest https://kubernetes.default.svc,prod-* \
  --src https://github.com/yourorg/prod-apps.git

# Add specific allowed resources for production
argocd proj allow-cluster-resource prod-team apps Deployment
argocd proj allow-cluster-resource prod-team apps StatefulSet
argocd proj allow-cluster-resource prod-team "" Service
argocd proj allow-cluster-resource prod-team "" ConfigMap
argocd proj allow-cluster-resource prod-team "" Secret
argocd proj allow-cluster-resource prod-team "" PersistentVolumeClaim

# Deny certain dangerous operations
argocd proj deny-cluster-resource prod-team "" Namespace
argocd proj deny-cluster-resource prod-team "rbac.authorization.k8s.io" "*"
```

### Task 2.4: Create Test Namespaces

```bash
# Create namespaces for testing
kubectl create namespace dev-app1
kubectl create namespace dev-app2
kubectl create namespace prod-app1

# Label namespaces for identification
kubectl label namespace dev-app1 team=dev-team
kubectl label namespace dev-app2 team=dev-team
kubectl label namespace prod-app1 team=prod-team
```

---

## Part 3: Configuring RBAC Policies

### Task 3.1: Understanding Argo CD RBAC Policy Format

RBAC policies in Argo CD use this format:

```
p, <subject>, <resource>, <action>, <object>, <effect>
```

Where:

- **subject:** User or group (e.g., `role:dev-admin`, `admin@example.com`)
- **resource:** Argo CD resource type (applications, clusters, projects, etc.)
- **action:** Operation (get, create, update, delete, sync, override, action/*)
- **object:** Specific resource path (project/app-name or wildcard)
- **effect:** allow or deny

### Task 3.2: Create Project-Specific Roles

```bash
# Add a developer role to dev-team project
argocd proj role create dev-team developer \
  --description "Developer role with full access to dev project"

# Add permissions to the developer role
argocd proj role add-policy dev-team developer \
  --action get \
  --permission allow \
  --object '*'

argocd proj role add-policy dev-team developer \
  --action create \
  --permission allow \
  --object '*'

argocd proj role add-policy dev-team developer \
  --action update \
  --permission allow \
  --object '*'

argocd proj role add-policy dev-team developer \
  --action sync \
  --permission allow \
  --object '*'

# Add a read-only role
argocd proj role create dev-team viewer \
  --description "Read-only access to dev project"

argocd proj role add-policy dev-team viewer \
  --action get \
  --permission allow \
  --object '*'

# View project roles
argocd proj role list dev-team
```

**Expected Output:**

```
ROLE-NAME   DESCRIPTION
developer   Developer role with full access to dev project
viewer      Read-only access to dev project
```

### Task 3.3: Create Production Team Roles

```bash
# Create prod-admin role (can sync and update)
argocd proj role create prod-team prod-admin \
  --description "Production admin with sync permissions"

argocd proj role add-policy prod-team prod-admin \
  --action get --permission allow --object '*'

argocd proj role add-policy prod-team prod-admin \
  --action sync --permission allow --object '*'

argocd proj role add-policy prod-team prod-admin \
  --action override --permission allow --object '*'

# Create prod-viewer role (read-only)
argocd proj role create prod-team prod-viewer \
  --description "Production read-only access"

argocd proj role add-policy prod-team prod-viewer \
  --action get --permission allow --object '*'

# Note: No create/update/delete permissions for production
```

### Task 3.4: Configure Global RBAC Policies

```bash
# Edit the RBAC ConfigMap
kubectl edit configmap argocd-rbac-cm -n argocd
```

Add the following policies to the ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Global read-only role
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, projects, get, *, allow

    # Dev team lead role
    p, role:dev-lead, applications, *, dev-team/*, allow
    p, role:dev-lead, projects, get, dev-team, allow
    p, role:dev-lead, repositories, *, *, allow

    # Prod team lead role
    p, role:prod-lead, applications, get, prod-team/*, allow
    p, role:prod-lead, applications, sync, prod-team/*, allow
    p, role:prod-lead, projects, get, prod-team, allow

    # Platform admin role (not full admin)
    p, role:platform-admin, applications, *, */*, allow
    p, role:platform-admin, projects, *, *, allow
    p, role:platform-admin, repositories, *, *, allow
    p, role:platform-admin, clusters, get, *, allow

    # Deny dangerous operations for non-admin users
    p, role:platform-admin, clusters, create, *, deny
    p, role:platform-admin, clusters, delete, *, deny
```

**Question:** What is the default policy for users who don't have explicit permissions?

---

## Part 4: Creating and Managing Local Users

### Task 4.1: Create Local Users

```bash
# Edit the users ConfigMap
kubectl edit configmap argocd-cm -n argocd
```

Add user accounts to the ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Enable local users
  accounts.alice: apiKey, login
  accounts.bob: apiKey, login
  accounts.charlie: apiKey, login
  accounts.diana: apiKey, login

  # Disable default admin (optional, for security)
  # accounts.admin: ""
```

Save and exit. Then restart Argo CD server:

```bash
# Restart server to pick up changes
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

### Task 4.2: Set User Passwords

```bash
# Login as admin first
argocd login localhost:8080 --username admin --password <your-admin-password> --insecure

# Set password for alice (dev-lead)
argocd account update-password \
  --account alice \
  --new-password 'Alice@Dev2024!'

# Set password for bob (developer)
argocd account update-password \
  --account bob \
  --new-password 'Bob@Dev2024!'

# Set password for charlie (prod-lead)
argocd account update-password \
  --account charlie \
  --new-password 'Charlie@Prod2024!'

# Set password for diana (viewer)
argocd account update-password \
  --account diana \
  --new-password 'Diana@View2024!'

# List all accounts
argocd account list
```

**Expected Output:**

```
NAME     ENABLED  CAPABILITIES
admin    true     login
alice    true     apiKey, login
bob      true     apiKey, login
charlie  true     apiKey, login
diana    true     apiKey, login
```

### Task 4.3: Assign Roles to Users

```bash
# Edit RBAC ConfigMap to assign roles to users
kubectl edit configmap argocd-rbac-cm -n argocd
```

Add role bindings:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # ... (previous policies) ...

    # User role assignments
    g, alice, role:dev-lead
    g, bob, role:readonly
    g, charlie, role:prod-lead
    g, diana, role:readonly

    # Project-specific role assignments
    g, alice, proj:dev-team:developer
    g, bob, proj:dev-team:viewer
    g, charlie, proj:prod-team:prod-admin
```

Restart the server:

```bash
kubectl rollout restart deployment argocd-server -n argocd
```

---

## Part 5: Testing Access Controls

### Task 5.1: Create Test Applications

```bash
# Login as admin
argocd login localhost:8080 --username admin --insecure

# Create a dev application
argocd app create dev-test-app \
  --project dev-team \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev-app1

# Create a prod application
argocd app create prod-test-app \
  --project prod-team \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace prod-app1

# Sync both applications
argocd app sync dev-test-app
argocd app sync prod-test-app
```

### Task 5.2: Test Alice's Access (Dev Lead)

Open a new terminal window:

```bash
# Login as Alice
argocd login localhost:8080 --username alice --password 'Alice@Dev2024!' --insecure

# Alice should be able to view and sync dev apps
argocd app list

# Get dev app details
argocd app get dev-test-app

# Sync dev app
argocd app sync dev-test-app

# Try to access prod app (should fail)
argocd app get prod-test-app
# Expected: permission denied

# Try to create app in prod project (should fail)
argocd app create test-fail \
  --project prod-team \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace prod-app1
# Expected: permission denied
```

**Expected Output:**

```
# For dev-test-app: Success
Name:               dev-test-app
Project:            dev-team
...

# For prod-test-app: Error
FATA[0000] rpc error: code = PermissionDenied desc = permission denied
```

### Task 5.3: Test Bob's Access (Developer/Viewer)

Open another terminal window:

```bash
# Login as Bob
argocd login localhost:8080 --username bob --password 'Bob@Dev2024!' --insecure

# Bob can view dev apps
argocd app list
argocd app get dev-test-app

# Bob cannot sync dev apps (viewer role)
argocd app sync dev-test-app
# Expected: permission denied

# Bob cannot create apps
argocd app create test-bob \
  --project dev-team \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev-app2
# Expected: permission denied
```

### Task 5.4: Test Charlie's Access (Prod Lead)

```bash
# Login as Charlie
argocd login localhost:8080 --username charlie --password 'Charlie@Prod2024!' --insecure

# Charlie can view and sync prod apps
argocd app list
argocd app get prod-test-app
argocd app sync prod-test-app

# Charlie cannot access dev apps
argocd app get dev-test-app
# Expected: permission denied

# Charlie cannot create new apps (only sync existing)
argocd app create test-charlie \
  --project prod-team \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace prod-app1
# Expected: permission denied (no create permission)
```

### Task 5.5: Test Diana's Access (Global Viewer)

```bash
# Login as Diana
argocd login localhost:8080 --username diana --password 'Diana@View2024!' --insecure

# Diana can view all apps (read-only default role)
argocd app list
argocd app get dev-test-app
argocd app get prod-test-app

# Diana cannot sync any apps
argocd app sync dev-test-app
# Expected: permission denied

argocd app sync prod-test-app
# Expected: permission denied
```

---

## Part 6: Advanced RBAC Patterns

### Task 6.1: Namespace-Level Access Control

```bash
# Update dev-team project for namespace-specific access
kubectl edit appproject dev-team -n argocd
```

Modify to restrict to specific namespaces:

```yaml
spec:
  destinations:
  - namespace: dev-app1
    server: https://kubernetes.default.svc
  - namespace: dev-app2
    server: https://kubernetes.default.svc
  # Remove wildcards for tighter control
```

### Task 6.2: Time-Based Access (JWT Token Expiry)

```bash
# Generate a JWT token for alice with expiry
argocd account generate-token --account alice --expires-in 1h

# Save the token
export ALICE_TOKEN="<generated-token>"

# Login using token
argocd login localhost:8080 --auth-token $ALICE_TOKEN --insecure

# Test access
argocd app list

# After 1 hour, the token will expire
```

### Task 6.3: Application-Level Annotations for Access Control

Create an application with access restrictions:

```bash
# Create app with annotation
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: restricted-app
  namespace: argocd
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: dev-team
spec:
  project: dev-team
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: dev-app2
EOF
```

---

## Part 7: Auditing and Monitoring Access

### Task 7.1: View Audit Logs

```bash
# Check Argo CD server logs for access events
kubectl logs -n argocd deployment/argocd-server --tail=50 | grep -i "permission\|login\|auth"

# Check application history for user actions
argocd app history dev-test-app

# View who performed recent syncs
kubectl get events -n argocd --sort-by='.lastTimestamp' | grep Application
```

### Task 7.2: Monitor RBAC Policy Enforcement

```bash
# Test policy validation
argocd account can-i sync applications dev-team/dev-test-app --as alice
argocd account can-i create applications dev-team/* --as bob
argocd account can-i sync applications prod-team/prod-test-app --as alice

# Expected outputs
# Alice can sync dev-team/dev-test-app: yes
# Bob can create applications: no
# Alice can sync prod-team apps: no
```

---

## Challenge Exercise

**Scenario:** Your organization needs a complex RBAC setup for a multi-team environment:

**Teams and Requirements:**

1. **Platform Team:**
   - Full access to all projects
   - Can create/delete projects
   - Can manage clusters
   - Can view all applications

2. **Development Team (3 developers):**
   - Full access to `dev-*` namespaces
   - Can deploy apps from `https://github.com/yourorg/dev-apps.git`
   - Can use: Deployments, Services, ConfigMaps, Secrets, Ingress
   - Cannot use: StatefulSets, PersistentVolumeClaims, RBAC resources

3. **QA Team (2 testers):**
   - Read-only access to `dev-*` and `qa-*` namespaces
   - Can trigger syncs in `qa-*` namespaces
   - Cannot modify application definitions

4. **Production Team (2 ops engineers):**
   - Can sync applications in `prod-*` namespaces
   - Cannot create/modify/delete applications
   - Can view logs and pod details
   - Limited to specific repositories only

5. **Audit/Compliance Team (1 auditor):**
   - Read-only access to ALL resources
   - Can view sync history and events
   - Cannot perform any actions

**Tasks:**

1. Create appropriate projects for each team
2. Define resource whitelists/blacklists
3. Create users for each role
4. Implement RBAC policies
5. Create test applications in each namespace
6. Test each user's permissions thoroughly
7. Document the RBAC model with a diagram
8. Set up audit logging for compliance

**Deliverables:**

- All projects configured with appropriate restrictions
- All users created with correct role assignments
- Test results showing permission boundaries
- RBAC policy documentation
- Audit log examples

---

## Cleanup

```bash
# Login as admin
argocd login localhost:8080 --username admin --insecure

# Delete test applications
argocd app delete dev-test-app --yes
argocd app delete prod-test-app --yes

# Delete projects
argocd proj delete dev-team
argocd proj delete prod-team

# Delete namespaces
kubectl delete namespace dev-app1 dev-app2 prod-app1

# Remove users (edit ConfigMap and remove accounts)
kubectl edit configmap argocd-cm -n argocd
# Remove the accounts.* lines

# Reset RBAC ConfigMap
kubectl delete configmap argocd-rbac-cm -n argocd

# Restart server
kubectl rollout restart deployment argocd-server -n argocd
```

---

## Summary

Excellent work! You've mastered RBAC and multi-tenancy in Argo CD. Here are the key takeaways:

- **Projects:** Isolate teams and environments using AppProjects
- **Resource Control:** Whitelist/blacklist specific Kubernetes resource types
- **RBAC Policies:** Define fine-grained permissions using policy.csv
- **Local Users:** Create users with specific roles and capabilities
- **Project Roles:** Define roles within projects for granular access
- **Testing:** Always test permissions thoroughly before production
- **Audit:** Monitor access logs and user actions for compliance

**Key Concepts:**

1. **AppProject Structure:**

   ```yaml
   spec:
     sourceRepos: [...]        # Allowed Git repositories
     destinations: [...]        # Allowed clusters/namespaces
     clusterResourceWhitelist: [...] # Allowed resource types
     roles: [...]               # Project-specific roles
   ```

2. **RBAC Policy Format:**

   ```
   p, <role>, <resource>, <action>, <object>, allow/deny
   g, <user>, <role>
   ```

3. **Permission Hierarchy:**
   - Admin (full access)
   - Platform Admin (most access, some restrictions)
   - Team Lead (full access to team project)
   - Developer (create/update in team project)
   - Viewer (read-only)

**Security Best Practices:**

1. Use least-privilege principle
2. Create separate projects for different environments
3. Restrict source repositories to known/approved repos
4. Whitelist only necessary Kubernetes resource types
5. Use project roles for team-specific permissions
6. Audit access logs regularly
7. Rotate API keys and passwords
8. Consider SSO integration for production
9. Disable default admin in production (use SSO)
10. Document all RBAC policies

**Key Commands:**

```bash
# Project management
argocd proj create <name>
argocd proj add-source <project> <repo>
argocd proj add-destination <project> <server> <namespace>
argocd proj allow-cluster-resource <project> <group> <kind>

# Role management
argocd proj role create <project> <role>
argocd proj role add-policy <project> <role> --action <action>

# User management
argocd account list
argocd account update-password --account <user>
argocd account can-i <action> <resource> --as <user>
```

---

## Additional Practice

To reinforce your learning, try these additional exercises:

1. **SSO Integration:**
   - Set up OIDC with GitHub or Google
   - Map SSO groups to Argo CD roles
   - Test login via SSO

2. **Advanced RBAC:**
   - Implement deny rules for sensitive operations
   - Create conditional policies based on resource labels
   - Set up separate admin roles for different responsibilities

3. **Multi-Cluster RBAC:**
   - Add multiple Kubernetes clusters
   - Restrict teams to specific clusters
   - Implement cross-cluster project boundaries

4. **Automated User Management:**
   - Script user creation and role assignment
   - Integrate with your organization's identity provider
   - Implement automated user deprovisioning

5. **Compliance and Auditing:**
   - Export audit logs to external system
   - Create reports on user access patterns
   - Set up alerts for policy violations

6. **Emergency Access:**
   - Create break-glass admin accounts
   - Implement approval workflows for sensitive operations
   - Set up escalation procedures

**Helpful Resources:**

- RBAC Documentation: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/
- Projects: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/
- SSO Configuration: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/
- Security Best Practices: https://argo-cd.readthedocs.io/en/stable/operator-manual/security/

---

## Solutions

<details>
<summary>Click to expand Challenge Exercise solutions</summary>

### Solution to Challenge Exercise

This is a comprehensive solution that implements a complete multi-team RBAC structure.

#### Step 1: Create Namespaces

```bash
# Create namespaces for all teams
kubectl create namespace dev-app1
kubectl create namespace dev-app2
kubectl create namespace qa-app1
kubectl create namespace qa-app2
kubectl create namespace prod-app1
kubectl create namespace prod-app2

# Label namespaces
kubectl label namespace dev-app1 team=development environment=dev
kubectl label namespace dev-app2 team=development environment=dev
kubectl label namespace qa-app1 team=qa environment=qa
kubectl label namespace qa-app2 team=qa environment=qa
kubectl label namespace prod-app1 team=production environment=prod
kubectl label namespace prod-app2 team=production environment=prod
```

#### Step 2: Create Projects

```bash
# Platform project (managed by platform team)
argocd proj create platform \
  --description "Platform team - full access" \
  --dest '*,*' \
  --src '*'

# Development project
argocd proj create development \
  --description "Development team project" \
  --dest https://kubernetes.default.svc,dev-* \
  --src 'https://github.com/yourorg/dev-apps.git'

# Add allowed resources for dev
argocd proj allow-cluster-resource development apps Deployment
argocd proj allow-cluster-resource development "" Service
argocd proj allow-cluster-resource development "" ConfigMap
argocd proj allow-cluster-resource development "" Secret
argocd proj allow-cluster-resource development networking.k8s.io Ingress

# Deny dangerous resources
argocd proj deny-cluster-resource development apps StatefulSet
argocd proj deny-cluster-resource development "" PersistentVolumeClaim
argocd proj deny-cluster-resource development "rbac.authorization.k8s.io" "*"

# QA project
argocd proj create qa \
  --description "QA team project" \
  --dest https://kubernetes.default.svc,qa-* \
  --dest https://kubernetes.default.svc,dev-* \
  --src 'https://github.com/yourorg/dev-apps.git' \
  --src 'https://github.com/yourorg/qa-apps.git'

argocd proj allow-cluster-resource qa apps Deployment
argocd proj allow-cluster-resource qa "" Service
argocd proj allow-cluster-resource qa "" ConfigMap

# Production project
argocd proj create production \
  --description "Production team project - restricted" \
  --dest https://kubernetes.default.svc,prod-* \
  --src 'https://github.com/yourorg/prod-apps.git'

argocd proj allow-cluster-resource production apps Deployment
argocd proj allow-cluster-resource production apps StatefulSet
argocd proj allow-cluster-resource production "" Service
argocd proj allow-cluster-resource production "" ConfigMap
argocd proj allow-cluster-resource production "" Secret
argocd proj allow-cluster-resource production "" PersistentVolumeClaim
```

#### Step 3: Create Project Roles

```bash
# Development project roles
argocd proj role create development dev-full \
  --description "Full development access"
argocd proj role add-policy development dev-full -a '*' -p allow -o '*'

argocd proj role create development dev-viewer \
  --description "Development viewer"
argocd proj role add-policy development dev-viewer -a get -p allow -o '*'

# QA project roles
argocd proj role create qa qa-tester \
  --description "QA tester with sync access"
argocd proj role add-policy qa qa-tester -a get -p allow -o '*'
argocd proj role add-policy qa qa-tester -a sync -p allow -o '*/qa-*'

# Production project roles
argocd proj role create production prod-operator \
  --description "Production operator - sync only"
argocd proj role add-policy production prod-operator -a get -p allow -o '*'
argocd proj role add-policy production prod-operator -a sync -p allow -o '*'
argocd proj role add-policy production prod-operator -a override -p allow -o '*'
```

#### Step 4: Create Users

```bash
# Edit ConfigMap to add users
kubectl edit configmap argocd-cm -n argocd
```

Add these accounts:

```yaml
data:
  accounts.platform-admin: apiKey, login
  accounts.dev-alice: apiKey, login
  accounts.dev-bob: apiKey, login
  accounts.dev-carol: apiKey, login
  accounts.qa-david: apiKey, login
  accounts.qa-emma: apiKey, login
  accounts.prod-frank: apiKey, login
  accounts.prod-grace: apiKey, login
  accounts.audit-henry: apiKey, login
```

Restart server and set passwords:

```bash
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd

# Set passwords (as admin)
argocd login localhost:8080 --username admin --insecure

argocd account update-password --account platform-admin --new-password 'Platform@2024!'
argocd account update-password --account dev-alice --new-password 'DevAlice@2024!'
argocd account update-password --account dev-bob --new-password 'DevBob@2024!'
argocd account update-password --account dev-carol --new-password 'DevCarol@2024!'
argocd account update-password --account qa-david --new-password 'QaDavid@2024!'
argocd account update-password --account qa-emma --new-password 'QaEmma@2024!'
argocd account update-password --account prod-frank --new-password 'ProdFrank@2024!'
argocd account update-password --account prod-grace --new-password 'ProdGrace@2024!'
argocd account update-password --account audit-henry --new-password 'AuditHenry@2024!'
```

#### Step 5: Implement RBAC Policies

```bash
kubectl edit configmap argocd-rbac-cm -n argocd
```

Add comprehensive policies:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: ""
  policy.csv: |
    # Platform Team - Full Access
    p, role:platform-admin, *, *, */*, allow
    g, platform-admin, role:platform-admin

    # Development Team - Full access to dev project
    p, role:dev-full, applications, *, development/*, allow
    p, role:dev-full, projects, get, development, allow
    p, role:dev-full, repositories, *, *, allow
    p, role:dev-full, logs, get, development/*, allow
    g, dev-alice, role:dev-full
    g, dev-alice, proj:development:dev-full
    g, dev-bob, role:dev-full
    g, dev-bob, proj:development:dev-full
    g, dev-carol, role:dev-full
    g, dev-carol, proj:development:dev-full

    # QA Team - Read + sync in QA namespaces
    p, role:qa-tester, applications, get, */*, allow
    p, role:qa-tester, applications, sync, qa/*, allow
    p, role:qa-tester, projects, get, *, allow
    p, role:qa-tester, logs, get, */*, allow
    g, qa-david, role:qa-tester
    g, qa-david, proj:qa:qa-tester
    g, qa-emma, role:qa-tester
    g, qa-emma, proj:qa:qa-tester

    # Production Team - Sync only
    p, role:prod-operator, applications, get, production/*, allow
    p, role:prod-operator, applications, sync, production/*, allow
    p, role:prod-operator, applications, override, production/*, allow
    p, role:prod-operator, projects, get, production, allow
    p, role:prod-operator, logs, get, production/*, allow
    g, prod-frank, role:prod-operator
    g, prod-frank, proj:production:prod-operator
    g, prod-grace, role:prod-operator
    g, prod-grace, proj:production:prod-operator

    # Audit/Compliance - Read-only everything
    p, role:auditor, applications, get, */*, allow
    p, role:auditor, projects, get, *, allow
    p, role:auditor, clusters, get, *, allow
    p, role:auditor, repositories, get, *, allow
    p, role:auditor, logs, get, */*, allow
    g, audit-henry, role:auditor
```

Restart server:

```bash
kubectl rollout restart deployment argocd-server -n argocd
```

#### Step 6: Create Test Applications

```bash
# Login as admin
argocd login localhost:8080 --username admin --insecure

# Create dev app
argocd app create dev-guestbook \
  --project development \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev-app1

# Create QA app
argocd app create qa-guestbook \
  --project qa \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace qa-app1

# Create prod app
argocd app create prod-guestbook \
  --project production \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace prod-app1

# Sync all
argocd app sync dev-guestbook
argocd app sync qa-guestbook
argocd app sync prod-guestbook
```

#### Step 7: Test Each User's Permissions

Create a test script:

```bash
#!/bin/bash

# test-rbac.sh
echo "=== Testing RBAC Permissions ==="

# Test Platform Admin
echo -e "\n1. Testing platform-admin (should have full access)..."
argocd login localhost:8080 --username platform-admin --password 'Platform@2024!' --insecure
argocd app list && echo "✓ Can list apps"
argocd proj list && echo "✓ Can list projects"

# Test Dev User
echo -e "\n2. Testing dev-alice (should access dev apps only)..."
argocd login localhost:8080 --username dev-alice --password 'DevAlice@2024!' --insecure
argocd app get dev-guestbook && echo "✓ Can get dev app"
argocd app sync dev-guestbook && echo "✓ Can sync dev app"
argocd app get prod-guestbook 2>&1 | grep -q "PermissionDenied" && echo "✓ Cannot access prod app"

# Test QA User
echo -e "\n3. Testing qa-david (should read all, sync QA only)..."
argocd login localhost:8080 --username qa-david --password 'QaDavid@2024!' --insecure
argocd app get dev-guestbook && echo "✓ Can view dev app"
argocd app get qa-guestbook && echo "✓ Can view QA app"
argocd app sync qa-guestbook && echo "✓ Can sync QA app"
argocd app sync dev-guestbook 2>&1 | grep -q "PermissionDenied" && echo "✓ Cannot sync dev app"

# Test Prod User
echo -e "\n4. Testing prod-frank (should sync prod only, no create)..."
argocd login localhost:8080 --username prod-frank --password 'ProdFrank@2024!' --insecure
argocd app get prod-guestbook && echo "✓ Can view prod app"
argocd app sync prod-guestbook && echo "✓ Can sync prod app"
argocd app create test-fail --project production --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace prod-app2 2>&1 | grep -q "PermissionDenied" && echo "✓ Cannot create app"

# Test Auditor
echo -e "\n5. Testing audit-henry (should read-only everything)..."
argocd login localhost:8080 --username audit-henry --password 'AuditHenry@2024!' --insecure
argocd app list && echo "✓ Can list all apps"
argocd app get dev-guestbook && echo "✓ Can view dev app"
argocd app get prod-guestbook && echo "✓ Can view prod app"
argocd app sync dev-guestbook 2>&1 | grep -q "PermissionDenied" && echo "✓ Cannot sync apps"

echo -e "\n=== RBAC Testing Complete ==="
```

Run the test:

```bash
chmod +x test-rbac.sh
./test-rbac.sh
```

#### Step 8: Create Documentation

Create `RBAC-MODEL.md`:

```markdown
# RBAC Model Documentation

## Team Structure

### 1. Platform Team
- **Members:** platform-admin
- **Permissions:** Full access to all resources
- **Use Cases:** Cluster management, project creation, emergency access

### 2. Development Team
- **Members:** dev-alice, dev-bob, dev-carol
- **Permissions:**
  - Full CRUD on applications in `development` project
  - Access to `dev-*` namespaces only
  - Can use: Deployment, Service, ConfigMap, Secret, Ingress
  - Cannot use: StatefulSet, PVC, RBAC resources
- **Use Cases:** Development and deployment of applications

### 3. QA Team
- **Members:** qa-david, qa-emma
- **Permissions:**
  - Read access to all applications
  - Sync access to `qa-*` namespaces
  - Cannot create/modify/delete applications
- **Use Cases:** Testing, triggering deployments in QA environments

### 4. Production Team
- **Members:** prod-frank, prod-grace
- **Permissions:**
  - View and sync production applications
  - Cannot create/modify/delete applications
  - Limited to approved repositories
- **Use Cases:** Production deployments (from pre-approved configs)

### 5. Audit/Compliance Team
- **Members:** audit-henry
- **Permissions:**
  - Read-only access to everything
  - Can view logs and history
  - Cannot perform any modifications
- **Use Cases:** Compliance audits, security reviews

## Access Matrix

| Role | View Apps | Create Apps | Sync Apps | Delete Apps | View Logs | Manage Projects |
|------|-----------|-------------|-----------|-------------|-----------|-----------------|
| Platform Admin | All | All | All | All | All | Yes |
| Dev Team | Dev | Dev | Dev | Dev | Dev | No |
| QA Team | All | No | QA only | No | All | No |
| Prod Team | Prod | No | Prod | No | Prod | No |
| Auditor | All | No | No | No | All | No |

## Security Controls

1. **Namespace Isolation:** Teams can only deploy to assigned namespaces
2. **Resource Restrictions:** Dev team blocked from StatefulSets, PVCs
3. **Repository Restrictions:** Prod team limited to approved repos
4. **Least Privilege:** Users have minimum necessary permissions
5. **Audit Trail:** All actions logged for compliance

## Escalation Process

For emergency access or exceptions:
1. Contact Platform Team (platform-admin)
2. Document reason for exception
3. Platform admin grants temporary elevated access
4. Revoke access after incident resolution
```

#### Step 9: Audit Logging

```bash
# Create audit log collection script
cat <<'EOF' > collect-audit-logs.sh
#!/bin/bash

echo "=== Argo CD Audit Logs ==="
echo "Collection Time: $(date)"
echo ""

# Get server logs with authentication events
echo "--- Authentication Events ---"
kubectl logs -n argocd deployment/argocd-server --tail=100 | grep -i "login\|auth" | tail -20

# Get application sync events
echo -e "\n--- Recent Sync Events ---"
kubectl get events -n argocd --field-selector involvedObject.kind=Application --sort-by='.lastTimestamp' | tail -20

# Get application history for each app
echo -e "\n--- Application Sync History ---"
for app in dev-guestbook qa-guestbook prod-guestbook; do
  echo "Application: $app"
  argocd app history $app 2>/dev/null || echo "  No access or app not found"
done

echo -e "\n=== End of Audit Report ==="
EOF

chmod +x collect-audit-logs.sh
./collect-audit-logs.sh > audit-report-$(date +%Y%m%d).txt
```

#### Cleanup

```bash
# Delete all test apps
argocd login localhost:8080 --username admin --insecure
argocd app delete dev-guestbook qa-guestbook prod-guestbook --yes

# Delete projects
argocd proj delete development qa production platform

# Delete namespaces
kubectl delete namespace dev-app1 dev-app2 qa-app1 qa-app2 prod-app1 prod-app2

# Reset RBAC
kubectl delete configmap argocd-rbac-cm -n argocd
kubectl edit configmap argocd-cm -n argocd  # Remove all accounts.*

kubectl rollout restart deployment argocd-server -n argocd
```

</details>
