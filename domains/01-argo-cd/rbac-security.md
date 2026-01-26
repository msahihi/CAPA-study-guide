# RBAC and Security

## Overview

Security is a critical aspect of Argo CD deployment and operations. This section covers Role-Based Access Control (RBAC) policies, Single Sign-On (SSO) configuration, various authentication methods, secrets management, and webhook security. Understanding these concepts ensures secure multi-tenant Argo CD deployments and proper access control for the CAPA exam.

Proper RBAC configuration allows organizations to grant granular permissions to users and teams while maintaining security boundaries. Integration with enterprise authentication systems through SSO provides centralized identity management.

## Key Topics

### RBAC Policies

Argo CD implements two layers of RBAC:

1. **Argo CD RBAC**: Controls access to Argo CD resources (applications, projects, repositories, clusters)
2. **Kubernetes RBAC**: Controls Argo CD's permissions in target clusters

#### RBAC Configuration Structure

RBAC policies are configured in the `argocd-rbac-cm` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default role for authenticated users
  policy.default: role:readonly

  # Policy definitions in CSV format
  policy.csv: |
    # Format: p, subject, resource, action, object, effect
    # subject: user or role
    # resource: applications, clusters, repositories, projects, accounts, etc.
    # action: get, create, update, delete, sync, override, action/*
    # object: <project>/<application> or */* for all
    # effect: allow or deny

  # OIDC group mapping
  scopes: '[groups, email]'
```

#### RBAC Policy Format

**Policy Statement Structure**:

```
p, <subject>, <resource>, <action>, <object>, <effect>
```

**Components**:

- **subject**: User email, group, or role
- **resource**: applications, clusters, repositories, projects, accounts, certificates, gpgkeys
- **action**: get, create, update, delete, sync, override, action/*
- **object**: Target resource (e.g., `default/myapp`, `*/*,`<project>/<app>`)
- **effect**: allow or deny

#### Role Definitions

**Built-in Roles**:

```yaml
data:
  policy.csv: |
    # Admin role - full access
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, certificates, *, *, allow
    p, role:admin, gpgkeys, *, *, allow

    # Readonly role - read-only access
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, clusters, get, *, allow
    p, role:readonly, repositories, get, *, allow
    p, role:readonly, projects, get, *, allow
    p, role:readonly, accounts, get, *, allow
    p, role:readonly, certificates, get, *, allow
    p, role:readonly, gpgkeys, get, *, allow
```

#### Custom Role Examples

**Developer Role** (can create and sync apps):

```yaml
data:
  policy.csv: |
    # Developer role definition
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, create, */*, allow
    p, role:developer, applications, update, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, delete, */*, allow
    p, role:developer, repositories, get, *, allow
    p, role:developer, clusters, get, *, allow
    p, role:developer, projects, get, *, allow

    # Assign role to users
    g, developer@example.com, role:developer
    g, dev-team@example.com, role:developer
```

**Operator Role** (can sync and override):

```yaml
data:
  policy.csv: |
    # Operator role definition
    p, role:operator, applications, get, */*, allow
    p, role:operator, applications, sync, */*, allow
    p, role:operator, applications, override, */*, allow
    p, role:operator, applications, action/*, */*, allow
    p, role:operator, repositories, get, *, allow
    p, role:operator, clusters, get, *, allow

    # Assign role to users
    g, ops-team@example.com, role:operator
```

**Project-Specific Role** (restricted to specific project):

```yaml
data:
  policy.csv: |
    # Team A can only access their project
    p, role:team-a, applications, *, team-a/*, allow
    p, role:team-a, repositories, get, *, allow
    p, role:team-a, clusters, get, *, allow
    p, role:team-a, projects, get, team-a, allow

    # Assign users to team-a role
    g, user1@example.com, role:team-a
    g, user2@example.com, role:team-a
```

#### Group Bindings

Map users or groups to roles:

```yaml
data:
  policy.csv: |
    # Define roles (policies above)
    p, role:admin, applications, *, */*, allow

    # Bind users to roles
    g, admin@example.com, role:admin
    g, jane.doe@example.com, role:admin

    # Bind groups to roles (from SSO/OIDC)
    g, administrators, role:admin
    g, devops-team, role:developer
    g, engineering, role:readonly
```

#### Resource-Specific Permissions

**Applications**:

```yaml
data:
  policy.csv: |
    # Get/view applications
    p, role:viewer, applications, get, */*, allow

    # Create applications
    p, role:creator, applications, create, */*, allow

    # Update application spec
    p, role:editor, applications, update, */*, allow

    # Delete applications
    p, role:manager, applications, delete, */*, allow

    # Sync applications
    p, role:deployer, applications, sync, */*, allow

    # Override sync (ignore sync policies)
    p, role:overrider, applications, override, */*, allow

    # Execute actions (restart, rotate secrets)
    p, role:operator, applications, action/*, */*, allow
```

**Clusters**:

```yaml
data:
  policy.csv: |
    # View clusters
    p, role:cluster-viewer, clusters, get, *, allow

    # Manage clusters
    p, role:cluster-admin, clusters, create, *, allow
    p, role:cluster-admin, clusters, update, *, allow
    p, role:cluster-admin, clusters, delete, *, allow
```

**Repositories**:

```yaml
data:
  policy.csv: |
    # View repositories
    p, role:repo-viewer, repositories, get, *, allow

    # Manage repositories
    p, role:repo-admin, repositories, create, *, allow
    p, role:repo-admin, repositories, update, *, allow
    p, role:repo-admin, repositories, delete, *, allow
```

**Projects**:

```yaml
data:
  policy.csv: |
    # View projects
    p, role:project-viewer, projects, get, *, allow

    # Manage projects
    p, role:project-admin, projects, create, *, allow
    p, role:project-admin, projects, update, *, allow
    p, role:project-admin, projects, delete, *, allow
```

#### Complete RBAC Example

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default policy for authenticated users
  policy.default: role:readonly

  # RBAC policies
  policy.csv: |
    # Admin role - full access
    p, role:admin, *, *, *, allow

    # Developer role - manage applications in their project
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, create, */*, allow
    p, role:developer, applications, update, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, delete, */*, allow
    p, role:developer, repositories, get, *, allow
    p, role:developer, clusters, get, *, allow
    p, role:developer, projects, get, *, allow

    # SRE role - sync and manage all applications
    p, role:sre, applications, *, */*, allow
    p, role:sre, clusters, get, *, allow
    p, role:sre, repositories, get, *, allow
    p, role:sre, projects, get, *, allow

    # Readonly role - view only
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, clusters, get, *, allow
    p, role:readonly, repositories, get, *, allow
    p, role:readonly, projects, get, *, allow

    # Team-specific roles
    p, role:team-frontend, applications, *, frontend-*/*, allow
    p, role:team-backend, applications, *, backend-*/*, allow

    # Bind users to roles
    g, admin@example.com, role:admin
    g, sre@example.com, role:sre
    g, dev@example.com, role:developer

    # Bind groups to roles (from SSO)
    g, administrators, role:admin
    g, sre-team, role:sre
    g, developers, role:developer
    g, frontend-team, role:team-frontend
    g, backend-team, role:team-backend

  # OIDC scopes for group mapping
  scopes: '[groups, email, profile]'
```

### SSO Configuration

Argo CD supports SSO integration via Dex or direct OIDC.

#### Dex Configuration

Dex is an identity provider that supports multiple authentication backends.

**Enable Dex**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
      # GitHub
      - type: github
        id: github
        name: GitHub
        config:
          clientID: $dex.github.clientID
          clientSecret: $dex.github.clientSecret
          orgs:
            - name: example-org
              teams:
                - developers
                - sre

      # GitLab
      - type: gitlab
        id: gitlab
        name: GitLab
        config:
          baseURL: https://gitlab.example.com
          clientID: $dex.gitlab.clientID
          clientSecret: $dex.gitlab.clientSecret
          groups:
            - developers
            - operations

      # LDAP
      - type: ldap
        id: ldap
        name: LDAP
        config:
          host: ldap.example.com:636
          insecureNoSSL: false
          insecureSkipVerify: false
          bindDN: cn=admin,dc=example,dc=com
          bindPW: $dex.ldap.bindPW
          usernamePrompt: Email Address
          userSearch:
            baseDN: ou=users,dc=example,dc=com
            filter: "(objectClass=person)"
            username: mail
            idAttr: DN
            emailAttr: mail
            nameAttr: cn
          groupSearch:
            baseDN: ou=groups,dc=example,dc=com
            filter: "(objectClass=groupOfNames)"
            userAttr: DN
            groupAttr: member
            nameAttr: cn

      # SAML
      - type: saml
        id: saml
        name: Okta
        config:
          ssoURL: https://example.okta.com/app/example/exk/sso/saml
          caData: |
            LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
          redirectURI: https://argocd.example.com/api/dex/callback
          usernameAttr: email
          emailAttr: email
          groupsAttr: group

      # OIDC (Generic)
      - type: oidc
        id: google
        name: Google
        config:
          issuer: https://accounts.google.com
          clientID: $dex.google.clientID
          clientSecret: $dex.google.clientSecret
          hostedDomains:
            - example.com
```

**Dex Secrets**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
stringData:
  dex.github.clientID: "github-client-id"
  dex.github.clientSecret: "github-client-secret"
  dex.gitlab.clientID: "gitlab-client-id"
  dex.gitlab.clientSecret: "gitlab-client-secret"
  dex.ldap.bindPW: "ldap-bind-password"
  dex.google.clientID: "google-client-id"
  dex.google.clientSecret: "google-client-secret"
```

#### Direct OIDC Configuration

Configure Argo CD to use OIDC directly without Dex:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Okta
    issuer: https://example.okta.com
    clientID: argo-cd-client-id
    clientSecret: $oidc.okta.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims:
      groups:
        essential: true
```

**OIDC Secret**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
stringData:
  oidc.okta.clientSecret: "okta-client-secret"
```

### Authentication Methods

#### Local Users

Create local users in Argo CD:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Disable admin user (optional)
  admin.enabled: "true"

  # Define accounts
  accounts.developer: apiKey, login
  accounts.ci-pipeline: apiKey
  accounts.readonly-user: login
```

**Set User Passwords**:

```bash
# Set password for user
argocd account update-password --account developer --new-password <password>

# Generate API token for user
argocd account generate-token --account ci-pipeline

# List accounts
argocd account list

# Get account details
argocd account get --account developer
```

**Assign Permissions to Local Users**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    # Developer account permissions
    p, developer, applications, *, */*, allow
    p, developer, repositories, get, *, allow

    # CI pipeline account permissions
    p, ci-pipeline, applications, sync, */*, allow
    p, ci-pipeline, applications, get, */*, allow

    # Readonly account permissions
    p, readonly-user, applications, get, */*, allow
```

#### Service Accounts

Use Kubernetes Service Accounts for automation:

```yaml
# Create ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-automation
  namespace: argocd

---
# Create Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argocd-automation
  namespace: argocd
rules:
- apiGroups:
  - argoproj.io
  resources:
  - applications
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete

---
# Create RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-automation
  namespace: argocd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argocd-automation
subjects:
- kind: ServiceAccount
  name: argocd-automation
  namespace: argocd
```

**Get ServiceAccount Token**:

```bash
# Create token secret
kubectl create token argocd-automation -n argocd

# Use token for authentication
argocd login argocd.example.com --auth-token <token>
```

#### API Tokens

Generate API tokens for programmatic access:

```bash
# Generate token for account
argocd account generate-token --account ci-pipeline

# Generate token with expiration
argocd account generate-token --account ci-pipeline --expires-in 24h

# List tokens
argocd account list

# Delete token
argocd account delete-token --account ci-pipeline <token-id>
```

**Use API Token**:

```bash
# Login with token
argocd login argocd.example.com --auth-token <token>

# Use in scripts
export ARGOCD_AUTH_TOKEN='<token>'
argocd app list

# Use with curl
curl -H "Authorization: Bearer <token>" \
  https://argocd.example.com/api/v1/applications
```

### Secrets Management

#### Git Repository Credentials

**Username/Password**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/example/repo.git
  username: myuser
  password: mypassword
```

**SSH Key**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-repo-ssh
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@github.com:example/repo.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
    -----END OPENSSH PRIVATE KEY-----
```

**GitHub Token**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-token
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/example/repo.git
  username: not-used
  password: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### Helm Repository Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: helm-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: helm
  url: https://charts.example.com
  username: myuser
  password: mypassword
```

#### Cluster Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cluster-credentials
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
stringData:
  name: production-cluster
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

#### External Secrets Integration

Use External Secrets Operator for secret management:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-repo-creds
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: git-repo-creds
    template:
      metadata:
        labels:
          argocd.argoproj.io/secret-type: repository
      type: Opaque
      data:
        type: git
        url: https://github.com/example/repo.git
        username: "{{ .username }}"
        password: "{{ .password }}"
  data:
    - secretKey: username
      remoteRef:
        key: github/credentials
        property: username
    - secretKey: password
      remoteRef:
        key: github/credentials
        property: password
```

### Webhook Security

#### GitHub Webhook

Configure webhook secret for GitHub:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
stringData:
  webhook.github.secret: "my-webhook-secret"
```

**Configure in argocd-cm**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  webhook.github.secret: webhook.github.secret
```

**GitHub Webhook URL**:

```
https://argocd.example.com/api/webhook
```

#### GitLab Webhook

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
stringData:
  webhook.gitlab.secret: "my-gitlab-webhook-secret"
```

**GitLab Webhook URL**:

```
https://argocd.example.com/api/webhook
```

#### Bitbucket Webhook

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
stringData:
  webhook.bitbucket.uuid: "my-bitbucket-uuid"
```

**Bitbucket Webhook URL**:

```
https://argocd.example.com/api/webhook
```

#### Webhook Ingress Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-webhook
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.example.com
    http:
      paths:
      - path: /api/webhook
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              name: https
```

## Practice Examples

### Example 1: Multi-Team RBAC Setup

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly

  policy.csv: |
    # Platform admins - full access
    p, role:platform-admin, *, *, *, allow
    g, platform-admins, role:platform-admin

    # Team A - frontend applications
    p, role:team-a, applications, *, team-a/*, allow
    p, role:team-a, projects, get, team-a, allow
    p, role:team-a, repositories, get, *, allow
    p, role:team-a, clusters, get, *, allow
    g, team-a-developers, role:team-a

    # Team B - backend applications
    p, role:team-b, applications, *, team-b/*, allow
    p, role:team-b, projects, get, team-b, allow
    p, role:team-b, repositories, get, *, allow
    p, role:team-b, clusters, get, *, allow
    g, team-b-developers, role:team-b

    # SRE team - can sync all applications
    p, role:sre, applications, get, */*, allow
    p, role:sre, applications, sync, */*, allow
    p, role:sre, applications, action/*, */*, allow
    p, role:sre, clusters, get, *, allow
    g, sre-team, role:sre

    # Auditors - read-only access
    p, role:auditor, applications, get, */*, allow
    p, role:auditor, projects, get, *, allow
    p, role:auditor, clusters, get, *, allow
    p, role:auditor, repositories, get, *, allow
    g, auditors, role:auditor
```

### Example 2: SSO with GitHub

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
    - type: github
      id: github
      name: GitHub
      config:
        clientID: $dex.github.clientID
        clientSecret: $dex.github.clientSecret
        orgs:
          - name: my-org
            teams:
              - platform-admins
              - sre-team
              - developers
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
stringData:
  dex.github.clientID: "your-github-client-id"
  dex.github.clientSecret: "your-github-client-secret"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    g, my-org:platform-admins, role:admin
    g, my-org:sre-team, role:sre
    g, my-org:developers, role:developer
  scopes: '[groups, email]'
```

### Example 3: CI/CD Integration with API Token

```bash
#!/bin/bash
# CI/CD script for syncing applications

# Set Argo CD details
ARGOCD_SERVER="argocd.example.com"
ARGOCD_TOKEN="${ARGOCD_AUTH_TOKEN}"
APP_NAME="myapp"

# Login with token
argocd login "$ARGOCD_SERVER" \
  --auth-token "$ARGOCD_TOKEN" \
  --grpc-web

# Update application image
argocd app set "$APP_NAME" \
  --kustomize-image "myapp=myapp:${CI_COMMIT_SHA}"

# Sync application
argocd app sync "$APP_NAME" --prune

# Wait for sync to complete
argocd app wait "$APP_NAME" --sync --health --timeout 300

# Get application status
argocd app get "$APP_NAME"
```

## Study Resources

- [RBAC Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- [SSO Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)
- [Dex Connectors](https://dexidp.io/docs/connectors/)
- [Security Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/security/)
- [Webhook Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/webhook/)

## Key Points to Remember

- RBAC policies configured in `argocd-rbac-cm` ConfigMap
- Policy format: `p, subject, resource, action, object, effect`
- Resources: applications, clusters, repositories, projects, accounts
- Actions: get, create, update, delete, sync, override, action/*
- Group bindings map users/groups to roles using `g, user/group, role`
- Default policy applies to all authenticated users
- Dex enables SSO with multiple identity providers
- Direct OIDC integration available without Dex
- Local users defined in `argocd-cm` with `accounts.<name>` fields
- API tokens generated per account with optional expiration
- Repository credentials stored as Secrets with label `argocd.argoproj.io/secret-type: repository`
- Cluster credentials stored as Secrets with label `argocd.argoproj.io/secret-type: cluster`
- Webhook secrets configured for GitHub, GitLab, and Bitbucket
- External Secrets Operator can manage Argo CD secrets
- RBAC scopes control which claims are used for group mapping

## Hands-On Practice

For practical exercises and labs on RBAC and security, see:

- [Lab 04: Implementing RBAC](../../labs/01-argo-cd/lab-04-rbac.md)
