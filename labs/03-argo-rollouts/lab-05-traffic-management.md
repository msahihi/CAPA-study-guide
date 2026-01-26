# Lab 05: Traffic Management with NGINX Ingress

**Duration**: 40 minutes

**Difficulty**: Advanced

## Objectives

By the end of this lab, you will be able to:

- Install and configure NGINX Ingress Controller
- Integrate Argo Rollouts with NGINX for traffic management
- Implement weighted traffic routing for canary deployments
- Configure header-based traffic routing for testing
- Use traffic splitting with multiple services
- Implement advanced traffic management strategies
- Monitor and verify traffic distribution
- Combine traffic management with analysis

## Prerequisites

- Completed [Lab 04: Analysis and Metrics](lab-04-analysis.md)
- Argo Rollouts controller installed and running
- kubectl Argo Rollouts plugin installed
- Access to a Kubernetes cluster
- Understanding of Kubernetes Ingress resources

## Lab Scenario

You are managing a production web application that requires sophisticated traffic routing capabilities. You need to implement canary deployments where actual ingress traffic is split between stable and canary versions based on weights, with the ability to route specific test traffic to the canary version using HTTP headers.

## Step 1: Install NGINX Ingress Controller

### 1.1 Create Ingress Namespace

Create a namespace for NGINX Ingress:

```bash
# Create namespace
kubectl create namespace ingress-nginx

# Verify
kubectl get namespace ingress-nginx
```

### 1.2 Install NGINX Ingress Controller

Install NGINX Ingress using official manifests:

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for deployment to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### 1.3 Verify NGINX Installation

Check the ingress controller is running:

```bash
# Check pods
kubectl get pods -n ingress-nginx

# Check service
kubectl get service -n ingress-nginx ingress-nginx-controller

# Check deployment
kubectl get deployment -n ingress-nginx ingress-nginx-controller

# View controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=20
```

### 1.4 Get Ingress External IP

Get the external IP or LoadBalancer address:

```bash
# Get ingress service details
kubectl get service -n ingress-nginx ingress-nginx-controller

# For cloud providers (AWS, GCP, Azure), wait for EXTERNAL-IP
# For local clusters (minikube, kind), use NodePort or port-forward

# If using minikube
# minikube tunnel

# If using kind or need port-forward
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 &
```

**Note**: Save the EXTERNAL-IP or use `localhost:8080` for port-forward scenarios.

## Step 2: Environment Setup

### 2.1 Create Traffic Management Namespace

Create a namespace for the demo:

```bash
# Create namespace
kubectl create namespace traffic-demo

# Set as default
kubectl config set-context --current --namespace=traffic-demo

# Verify
kubectl config view --minify | grep namespace:
```

### 2.2 Create Stable and Canary Services

Create two services for stable and canary versions:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: traffic-demo-stable
  namespace: traffic-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: traffic-demo
---
apiVersion: v1
kind: Service
metadata:
  name: traffic-demo-canary
  namespace: traffic-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: traffic-demo
EOF
```

### 2.3 Verify Services

Check services are created:

```bash
# List services
kubectl get services -n traffic-demo

# Describe services
kubectl describe service traffic-demo-stable -n traffic-demo
kubectl describe service traffic-demo-canary -n traffic-demo
```

## Step 3: Create Rollout with NGINX Traffic Management

### 3.1 Create Rollout with Traffic Routing

Create a rollout that uses NGINX for traffic management:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: traffic-demo
  namespace: traffic-demo
spec:
  replicas: 5
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: traffic-demo
  template:
    metadata:
      labels:
        app: traffic-demo
    spec:
      containers:
      - name: traffic-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      # Reference to stable service
      stableService: traffic-demo-stable
      # Reference to canary service
      canaryService: traffic-demo-canary
      # Traffic routing configuration
      trafficRouting:
        nginx:
          # Reference to ingress that will be modified
          stableIngress: traffic-demo-ingress
      steps:
      - setWeight: 10
      - pause: {duration: 1m}
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 40
      - pause: {duration: 1m}
      - setWeight: 60
      - pause: {duration: 1m}
      - setWeight: 80
      - pause: {duration: 1m}
EOF
```

### 3.2 Create Ingress Resource

Create an Ingress that will be managed by the rollout:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traffic-demo-ingress
  namespace: traffic-demo
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: traffic-demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: traffic-demo-stable
            port:
              number: 80
EOF
```

### 3.3 Verify Initial Setup

Check the rollout and ingress:

```bash
# Watch rollout until healthy
kubectl argo rollouts get rollout traffic-demo --watch -n traffic-demo
# Press Ctrl+C when healthy

# Check ingress
kubectl get ingress traffic-demo-ingress -n traffic-demo

# Describe ingress
kubectl describe ingress traffic-demo-ingress -n traffic-demo
```

## Step 4: Test Weighted Traffic Routing

### 4.1 Add /etc/hosts Entry

Add entry for local testing (if using localhost):

```bash
# Add to /etc/hosts (Linux/Mac)
echo "127.0.0.1 traffic-demo.local" | sudo tee -a /etc/hosts

# For Windows, edit C:\Windows\System32\drivers\etc\hosts
# Add: 127.0.0.1 traffic-demo.local

# Verify
ping -c 1 traffic-demo.local
```

### 4.2 Test Initial Stable Version

Test the application before rollout:

```bash
# Test stable version (using port-forward if applicable)
curl -H "Host: traffic-demo.local" http://localhost:8080/

# Or if you have external IP
# INGRESS_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# curl -H "Host: traffic-demo.local" http://$INGRESS_IP/

# Test multiple times and check color
for i in {1..10}; do
  curl -s -H "Host: traffic-demo.local" http://localhost:8080/ | grep -o '"color":"[^"]*"'
done
```

**Expected Output:**

```
"color":"blue"
"color":"blue"
"color":"blue"
...all blue
```

### 4.3 Deploy New Version

Update the rollout to trigger canary with traffic splitting:

```bash
# Update to yellow version
kubectl argo rollouts set image traffic-demo \
  traffic-demo=argoproj/rollouts-demo:yellow \
  -n traffic-demo

# Watch rollout progress
kubectl argo rollouts get rollout traffic-demo --watch -n traffic-demo
```

### 4.4 Observe NGINX Canary Annotations

Check the canary ingress created by Argo Rollouts:

```bash
# List all ingresses
kubectl get ingress -n traffic-demo

# Describe canary ingress (created automatically)
kubectl describe ingress traffic-demo-ingress-canary -n traffic-demo

# View canary ingress annotations
kubectl get ingress traffic-demo-ingress-canary -n traffic-demo -o yaml | grep -A 10 annotations
```

**Key Annotations:**

```yaml
annotations:
  nginx.ingress.kubernetes.io/canary: "true"
  nginx.ingress.kubernetes.io/canary-weight: "10"  # Changes based on rollout step
```

### 4.5 Test Traffic Distribution

Test traffic splitting during rollout:

```bash
# Test traffic distribution at 10% canary
for i in {1..50}; do
  curl -s -H "Host: traffic-demo.local" http://localhost:8080/ | grep -o '"color":"[^"]*"'
done | sort | uniq -c

# Expected: ~5 yellow (10%), ~45 blue (90%)
```

**Expected Output:**

```
      5 "color":"yellow"    # ~10% canary
     45 "color":"blue"      # ~90% stable
```

### 4.6 Monitor Traffic Weight Changes

In a separate terminal, watch ingress annotations change:

```bash
# Watch canary ingress annotations
watch -n 2 'kubectl get ingress traffic-demo-ingress-canary -n traffic-demo -o yaml | grep canary-weight'

# Or continuously check traffic distribution
while true; do
  echo "=== Traffic Distribution at $(date +%H:%M:%S) ==="
  for i in {1..20}; do
    curl -s -H "Host: traffic-demo.local" http://localhost:8080/ 2>/dev/null | grep -o '"color":"[^"]*"'
  done | sort | uniq -c
  echo ""
  sleep 30
done
```

## Step 5: Header-Based Routing

### 5.1 Create Rollout with Header-Based Routing

Create a rollout that uses header-based routing:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: traffic-header-demo
  namespace: traffic-demo
spec:
  replicas: 5
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: traffic-header-demo
  template:
    metadata:
      labels:
        app: traffic-header-demo
    spec:
      containers:
      - name: app
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      stableService: traffic-header-stable
      canaryService: traffic-header-canary
      trafficRouting:
        nginx:
          stableIngress: traffic-header-ingress
          # Additional canary ingress for header-based routing
          additionalIngressAnnotations:
            canary-by-header: X-Canary
            canary-by-header-value: always
      steps:
      - setWeight: 20
      - pause: {}  # Manual promotion
      - setWeight: 50
      - pause: {}
      - setWeight: 80
      - pause: {}
EOF
```

### 5.2 Create Services for Header-Based Demo

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: traffic-header-stable
  namespace: traffic-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: traffic-header-demo
---
apiVersion: v1
kind: Service
metadata:
  name: traffic-header-canary
  namespace: traffic-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: traffic-header-demo
EOF
```

### 5.3 Create Ingress for Header-Based Demo

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traffic-header-ingress
  namespace: traffic-demo
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: traffic-header.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: traffic-header-stable
            port:
              number: 80
EOF
```

### 5.4 Add /etc/hosts Entry

```bash
# Add to /etc/hosts
echo "127.0.0.1 traffic-header.local" | sudo tee -a /etc/hosts

# Verify
ping -c 1 traffic-header.local
```

### 5.5 Wait and Deploy New Version

```bash
# Wait for initial deployment
kubectl argo rollouts get rollout traffic-header-demo --watch -n traffic-demo
# Press Ctrl+C when healthy

# Deploy new version
kubectl argo rollouts set image traffic-header-demo \
  app=argoproj/rollouts-demo:green \
  -n traffic-demo

# Wait for rollout to pause
sleep 10
```

### 5.6 Test Header-Based Routing

Test routing with and without header:

```bash
# Request without header (goes to stable based on weight)
for i in {1..10}; do
  curl -s -H "Host: traffic-header.local" http://localhost:8080/ | grep -o '"color":"[^"]*"'
done | sort | uniq -c

# Request with canary header (always goes to canary)
for i in {1..10}; do
  curl -s -H "Host: traffic-header.local" -H "X-Canary: always" http://localhost:8080/ | grep -o '"color":"[^"]*"'
done | sort | uniq -c
```

**Expected Output:**

```
# Without header: ~20% green, ~80% blue
      2 "color":"green"
      8 "color":"blue"

# With header: 100% green
     10 "color":"green"
```

### 5.7 Test with Different Header Values

Test with different header values:

```bash
# X-Canary: always - routes to canary
curl -s -H "Host: traffic-header.local" -H "X-Canary: always" http://localhost:8080/ | grep color

# X-Canary: never - routes to stable
curl -s -H "Host: traffic-header.local" -H "X-Canary: never" http://localhost:8080/ | grep color

# No header - follows weight distribution
curl -s -H "Host: traffic-header.local" http://localhost:8080/ | grep color
```

## Step 6: Advanced Traffic Management

### 6.1 Create Rollout with Managed Routes

Create a rollout with managed routes configuration:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: traffic-managed-routes
  namespace: traffic-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: traffic-managed-routes
  template:
    metadata:
      labels:
        app: traffic-managed-routes
    spec:
      containers:
      - name: app
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      stableService: traffic-managed-stable
      canaryService: traffic-managed-canary
      trafficRouting:
        managedRoutes:
        - name: primary-route
        nginx:
          stableIngress: traffic-managed-ingress
      steps:
      - setWeight: 25
      - pause: {duration: 1m}
      - setCanaryScale:
          weight: 50
      - pause: {duration: 1m}
      - setWeight: 75
      - pause: {duration: 1m}
EOF
```

### 6.2 Create Services and Ingress

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: traffic-managed-stable
  namespace: traffic-demo
spec:
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: traffic-managed-routes
---
apiVersion: v1
kind: Service
metadata:
  name: traffic-managed-canary
  namespace: traffic-demo
spec:
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: traffic-managed-routes
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traffic-managed-ingress
  namespace: traffic-demo
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: traffic-managed.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: traffic-managed-stable
            port:
              number: 80
EOF
```

## Step 7: Combine Traffic Management with Analysis

### 7.1 Create AnalysisTemplate for Traffic Validation

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: nginx-traffic-analysis
  namespace: traffic-demo
spec:
  metrics:
  - name: success-rate
    initialDelay: 30s
    interval: 30s
    successCondition: result >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(rate(nginx_ingress_controller_requests{status=~"2..",exported_namespace="traffic-demo"}[2m]))
          /
          sum(rate(nginx_ingress_controller_requests{exported_namespace="traffic-demo"}[2m]))
EOF
```

### 7.2 Create Rollout with Traffic Management and Analysis

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: traffic-with-analysis
  namespace: traffic-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: traffic-with-analysis
  template:
    metadata:
      labels:
        app: traffic-with-analysis
    spec:
      containers:
      - name: app
        image: argoproj/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      stableService: traffic-analysis-stable
      canaryService: traffic-analysis-canary
      trafficRouting:
        nginx:
          stableIngress: traffic-analysis-ingress
      steps:
      - setWeight: 20
      - pause: {duration: 1m}
      # Analysis after initial traffic shift
      - analysis:
          templates:
          - templateName: nginx-traffic-analysis
      - setWeight: 50
      - pause: {duration: 1m}
      - analysis:
          templates:
          - templateName: nginx-traffic-analysis
      - setWeight: 80
      - pause: {duration: 1m}
EOF
```

### 7.3 Create Services and Ingress for Analysis Demo

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: traffic-analysis-stable
  namespace: traffic-demo
spec:
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: traffic-with-analysis
---
apiVersion: v1
kind: Service
metadata:
  name: traffic-analysis-canary
  namespace: traffic-demo
spec:
  ports:
  - port: 80
    targetPort: http
    name: http
  selector:
    app: traffic-with-analysis
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traffic-analysis-ingress
  namespace: traffic-demo
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: traffic-analysis.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: traffic-analysis-stable
            port:
              number: 80
EOF
```

## Step 8: Monitor Traffic Management

### 8.1 Create Traffic Testing Script

Create a comprehensive testing script:

```bash
cat > /tmp/test-ingress-traffic.sh <<'EOF'
#!/bin/bash

HOST=${1:-traffic-demo.local}
PORT=${2:-8080}
REQUESTS=${3:-100}
HEADER_NAME=${4:-}
HEADER_VALUE=${5:-}

echo "Testing traffic for $HOST"
echo "Sending $REQUESTS requests..."
echo ""

if [ -n "$HEADER_NAME" ] && [ -n "$HEADER_VALUE" ]; then
  echo "Using header: $HEADER_NAME: $HEADER_VALUE"
  for i in $(seq 1 $REQUESTS); do
    curl -s -H "Host: $HOST" -H "$HEADER_NAME: $HEADER_VALUE" http://localhost:$PORT/ 2>/dev/null | grep -o '"color":"[^"]*"'
  done | sort | uniq -c | awk '{
    color=$2
    count=$1
    total='$REQUESTS'
    percentage=(count/total)*100
    printf "%s: %d requests (%.1f%%)\n", color, count, percentage
  }'
else
  for i in $(seq 1 $REQUESTS); do
    curl -s -H "Host: $HOST" http://localhost:$PORT/ 2>/dev/null | grep -o '"color":"[^"]*"'
  done | sort | uniq -c | awk '{
    color=$2
    count=$1
    total='$REQUESTS'
    percentage=(count/total)*100
    printf "%s: %d requests (%.1f%%)\n", color, count, percentage
  }'
fi
EOF

chmod +x /tmp/test-ingress-traffic.sh
```

### 8.2 Use Testing Script

Test with the script:

```bash
# Test normal traffic distribution
/tmp/test-ingress-traffic.sh traffic-demo.local 8080 100

# Test with canary header
/tmp/test-ingress-traffic.sh traffic-header.local 8080 50 X-Canary always

# Test without header
/tmp/test-ingress-traffic.sh traffic-header.local 8080 50
```

### 8.3 Monitor NGINX Ingress Logs

View ingress controller logs:

```bash
# Tail ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50 -f

# Filter for specific host
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=100 | grep traffic-demo.local
```

### 8.4 Check Ingress Status

Monitor ingress resources:

```bash
# List all ingresses in namespace
kubectl get ingress -n traffic-demo

# Watch ingress changes
watch -n 2 'kubectl get ingress -n traffic-demo'

# Get ingress details
kubectl get ingress -n traffic-demo -o yaml

# Check canary weight on canary ingress
kubectl get ingress traffic-demo-ingress-canary -n traffic-demo \
  -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}'
```

## Step 9: Troubleshooting Traffic Management

### 9.1 Verify Service Selectors

Ensure services are selecting correct pods:

```bash
# Check stable service endpoints
kubectl get endpoints traffic-demo-stable -n traffic-demo

# Check canary service endpoints
kubectl get endpoints traffic-demo-canary -n traffic-demo

# Verify pod labels match service selectors
kubectl get pods -n traffic-demo -l app=traffic-demo --show-labels

# Check which pods each service is routing to
kubectl describe service traffic-demo-stable -n traffic-demo
kubectl describe service traffic-demo-canary -n traffic-demo
```

### 9.2 Debug Ingress Issues

Troubleshoot ingress problems:

```bash
# Check ingress class
kubectl get ingressclass

# Verify ingress is using correct class
kubectl get ingress -n traffic-demo -o yaml | grep ingress.class

# Check ingress controller logs for errors
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep ERROR

# Describe ingress for events
kubectl describe ingress traffic-demo-ingress -n traffic-demo
```

### 9.3 Test Direct Service Access

Bypass ingress to test services directly:

```bash
# Port-forward to stable service
kubectl port-forward -n traffic-demo service/traffic-demo-stable 8081:80 &

# Test stable service
curl -s http://localhost:8081/ | grep color

# Port-forward to canary service
kubectl port-forward -n traffic-demo service/traffic-demo-canary 8082:80 &

# Test canary service
curl -s http://localhost:8082/ | grep color

# Clean up port-forwards
pkill -f "kubectl port-forward"
```

## Step 10: Clean Up

### 10.1 Stop Port Forwards

```bash
# Stop all port-forwards
pkill -f "kubectl port-forward"

# Verify
ps aux | grep "kubectl port-forward"
```

### 10.2 Delete Rollouts

```bash
# Delete all rollouts
kubectl delete rollout --all -n traffic-demo

# Verify
kubectl get rollouts -n traffic-demo
```

### 10.3 Delete Services and Ingresses

```bash
# Delete all services
kubectl delete services --all -n traffic-demo

# Delete all ingresses
kubectl delete ingress --all -n traffic-demo

# Verify
kubectl get services,ingress -n traffic-demo
```

### 10.4 Delete AnalysisTemplates

```bash
# Delete analysis templates
kubectl delete analysistemplates --all -n traffic-demo

# Verify
kubectl get analysistemplates -n traffic-demo
```

### 10.5 Delete Namespace

```bash
# Delete namespace
kubectl delete namespace traffic-demo

# Verify
kubectl get namespace traffic-demo
```

### 10.6 Remove /etc/hosts Entries

```bash
# Remove entries from /etc/hosts (Linux/Mac)
sudo sed -i.bak '/traffic-demo.local/d' /etc/hosts
sudo sed -i.bak '/traffic-header.local/d' /etc/hosts
sudo sed -i.bak '/traffic-managed.local/d' /etc/hosts
sudo sed -i.bak '/traffic-analysis.local/d' /etc/hosts

# For Windows, manually edit C:\Windows\System32\drivers\etc\hosts
```

### 10.7 Clean Up Test Script

```bash
# Remove test script
rm /tmp/test-ingress-traffic.sh
```

### 10.8 Uninstall NGINX Ingress (Optional)

```bash
# If you want to remove NGINX Ingress Controller
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Delete namespace
kubectl delete namespace ingress-nginx
```

## Verification

Confirm successful completion:

```bash
# Verify Argo Rollouts is still running
kubectl get deployment argo-rollouts -n argo-rollouts

# Verify traffic-demo namespace is deleted
kubectl get namespace traffic-demo

# Verify NGINX Ingress (if kept)
kubectl get deployment -n ingress-nginx ingress-nginx-controller
```

## Lab Completion Checklist

- [ ] Installed NGINX Ingress Controller
- [ ] Created rollout with NGINX traffic routing
- [ ] Implemented weighted traffic splitting for canary
- [ ] Tested traffic distribution at different weight percentages
- [ ] Configured header-based routing for selective canary access
- [ ] Tested header-based routing with different header values
- [ ] Combined traffic management with analysis
- [ ] Created traffic testing scripts
- [ ] Monitored ingress logs and annotations
- [ ] Successfully cleaned up all resources

## Key Takeaways

1. **NGINX Integration**: Argo Rollouts integrates with NGINX Ingress Controller to manage actual ingress traffic distribution during canary deployments

2. **Weighted Routing**: Traffic weight is controlled through NGINX canary annotations on a dynamically created canary ingress resource

3. **Dual Services**: Requires separate stable and canary services; rollout manages selector updates to route pods to appropriate service

4. **Canary Ingress**: Argo Rollouts automatically creates and manages a canary ingress with `nginx.ingress.kubernetes.io/canary` annotations

5. **Header-Based Routing**: Allows specific traffic (test users, developers) to always hit canary version using HTTP headers like `X-Canary: always`

6. **Progressive Traffic Shift**: As rollout progresses through steps, canary-weight annotation updates automatically, shifting more traffic to canary

7. **Combined with Analysis**: Traffic management can be combined with metric analysis for automated validation and rollback

8. **Real Traffic Testing**: Unlike pod-based traffic splitting, ingress-based routing provides true production traffic distribution

## Troubleshooting

### Traffic Not Splitting

If traffic isn't splitting as expected:

```bash
# Check if canary ingress exists
kubectl get ingress -n traffic-demo | grep canary

# Check canary weight annotation
kubectl get ingress traffic-demo-ingress-canary -n traffic-demo -o yaml | grep canary-weight

# Verify stable and canary services have endpoints
kubectl get endpoints -n traffic-demo

# Check rollout status
kubectl argo rollouts get rollout traffic-demo -n traffic-demo

# Verify NGINX is processing canary annotations
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep canary
```

### Header Routing Not Working

If header-based routing fails:

```bash
# Check canary ingress annotations
kubectl get ingress traffic-demo-ingress-canary -n traffic-demo -o yaml | grep canary-by-header

# Verify header name and value
kubectl describe ingress traffic-demo-ingress-canary -n traffic-demo

# Test with exact header format
curl -v -H "Host: traffic-header.local" -H "X-Canary: always" http://localhost:8080/

# Check NGINX ingress controller version (must support header routing)
kubectl exec -it -n ingress-nginx deployment/ingress-nginx-controller -- nginx-ingress-controller --version
```

### Ingress Not Accessible

If you can't access the ingress:

```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50

# Verify ingress resource exists
kubectl get ingress -n traffic-demo

# Check ingress has correct backend service
kubectl describe ingress traffic-demo-ingress -n traffic-demo

# Ensure port-forward is running (if using local cluster)
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80

# Test without host header
curl -v http://localhost:8080/
```

## Next Steps

Congratulations! You have completed all Argo Rollouts labs. Consider these next steps:

1. **Practice Scenarios**: Combine concepts from all labs to create complex deployment pipelines
2. **Explore Other Ingress Controllers**: Try Istio, Traefik, or AWS ALB for traffic management
3. **Production Readiness**: Implement monitoring, alerting, and SLOs for rollouts
4. **GitOps Integration**: Integrate rollouts with Argo CD for complete GitOps workflows
5. **Advanced Analysis**: Explore more metric providers like Datadog, New Relic, or Wavefront

## Additional Resources

- [Traffic Management Documentation](https://argoproj.github.io/argo-rollouts/features/traffic-management/)
- [NGINX Ingress Integration](https://argoproj.github.io/argo-rollouts/features/traffic-management/nginx/)
- [NGINX Canary Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#canary)
- [Advanced Traffic Management](https://argoproj.github.io/argo-rollouts/features/traffic-management/istio/)
- [Service Mesh Integration](https://argoproj.github.io/argo-rollouts/features/traffic-management/smi/)
- [Best Practices Guide](https://argoproj.github.io/argo-rollouts/best-practices/)
