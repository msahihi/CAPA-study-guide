# Lab 04: Analysis and Metrics

**Duration**: 45 minutes

**Difficulty**: Advanced

## Objectives

By the end of this lab, you will be able to:

- Install and configure Prometheus for metrics collection
- Create AnalysisTemplate resources for metric validation
- Integrate analysis with canary rollouts
- Configure success and failure thresholds for metrics
- Implement automated rollout validation based on metrics
- Handle analysis failures and automatic rollbacks
- Use background analysis and inline analysis
- Create AnalysisRun resources manually

## Prerequisites

- Completed [Lab 03: Canary Deployments](lab-03-canary.md)
- Argo Rollouts controller installed and running
- kubectl Argo Rollouts plugin installed
- Access to a Kubernetes cluster with sufficient resources
- Basic understanding of Prometheus and metrics

## Lab Scenario

You are deploying updates to a critical production application. To ensure quality and reliability, you need automated validation of new versions based on key performance indicators (KPIs) such as error rates, response times, and resource usage. Analysis templates enable automated promotion or rollback based on real metrics from Prometheus.

## Step 1: Install Prometheus

### 1.1 Create Monitoring Namespace

Create a namespace for Prometheus:

```bash
# Create namespace
kubectl create namespace monitoring

# Verify
kubectl get namespace monitoring
```

### 1.2 Deploy Prometheus

Deploy a basic Prometheus instance:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: \$1:\$2
        target_label: __address__
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--web.enable-lifecycle'
        ports:
        - containerPort: 9090
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
        resources:
          requests:
            memory: 256Mi
            cpu: 100m
          limits:
            memory: 512Mi
            cpu: 500m
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: ClusterIP
  ports:
  - port: 9090
    targetPort: 9090
    protocol: TCP
    name: http
  selector:
    app: prometheus
EOF
```

### 1.3 Verify Prometheus Installation

Check Prometheus is running:

```bash
# Check deployment
kubectl get deployment prometheus -n monitoring

# Check pod
kubectl get pods -n monitoring -l app=prometheus

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s

# Check service
kubectl get service prometheus -n monitoring
```

### 1.4 Access Prometheus UI

Port-forward to access Prometheus:

```bash
# Port-forward (run in background or separate terminal)
kubectl port-forward -n monitoring service/prometheus 9090:9090 &

# Wait a moment for port-forward to establish
sleep 3

# Test access (if curl is available)
curl -s http://localhost:9090/-/healthy

# Open in browser: http://localhost:9090
# Or continue with command line tools
```

## Step 2: Deploy Application with Metrics

### 2.1 Create Analysis Namespace

Create a namespace for the demo:

```bash
# Create namespace
kubectl create namespace analysis-demo

# Set as default
kubectl config set-context --current --namespace=analysis-demo
```

### 2.2 Deploy Demo Application with Metrics

Deploy an application that exposes Prometheus metrics:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: analysis-demo
  namespace: analysis-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: analysis-demo
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: analysis-demo
  namespace: analysis-demo
spec:
  replicas: 5
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: analysis-demo
  template:
    metadata:
      labels:
        app: analysis-demo
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: analysis-demo
        image: msahihi/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
        env:
        - name: VERSION
          value: "blue"
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 30s}
      - setWeight: 40
      - pause: {duration: 30s}
      - setWeight: 60
      - pause: {duration: 30s}
      - setWeight: 80
      - pause: {duration: 30s}
EOF
```

### 2.3 Verify Application Deployment

Wait for application to be ready:

```bash
# Watch rollout
kubectl argo rollouts get rollout analysis-demo --watch -n analysis-demo
# Press Ctrl+C when healthy

# Verify pods are running
kubectl get pods -n analysis-demo -l app=analysis-demo

# Test application endpoint
kubectl run test-pod --image=curlimages/curl:latest -n analysis-demo --rm -it -- \
  curl -s http://analysis-demo
```

## Step 3: Create AnalysisTemplate

### 3.1 Create Basic AnalysisTemplate

Create a template that checks for HTTP errors:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: analysis-demo
spec:
  metrics:
  - name: success-rate
    initialDelay: 30s      # Wait 30s before starting analysis
    interval: 30s          # Run query every 30s
    successCondition: result >= 0.95  # 95% success rate required
    failureLimit: 3        # Fail after 3 consecutive failures
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(
            rate(
              http_requests_total{
                status=~"2..",
                namespace="analysis-demo",
                rollouts_pod_template_hash="{{ .rollouts_pod_template_hash }}"
              }[2m]
            )
          )
          /
          sum(
            rate(
              http_requests_total{
                namespace="analysis-demo",
                rollouts_pod_template_hash="{{ .rollouts_pod_template_hash }}"
              }[2m]
            )
          )
EOF
```

### 3.2 Create Response Time AnalysisTemplate

Create a template for response time validation:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: response-time
  namespace: analysis-demo
spec:
  metrics:
  - name: p95-response-time
    initialDelay: 30s
    interval: 30s
    successCondition: result <= 1000  # P95 should be under 1000ms
    failureLimit: 3
    count: 5                # Run 5 times total
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          histogram_quantile(
            0.95,
            sum(
              rate(
                http_request_duration_seconds_bucket{
                  namespace="analysis-demo",
                  rollouts_pod_template_hash="{{ .rollouts_pod_template_hash }}"
                }[2m]
              )
            ) by (le)
          ) * 1000
EOF
```

### 3.3 Create CPU Usage AnalysisTemplate

Create a template for CPU monitoring:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: cpu-usage
  namespace: analysis-demo
spec:
  metrics:
  - name: cpu-usage
    initialDelay: 30s
    interval: 20s
    successCondition: result <= 0.8  # CPU should be below 80%
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(
            rate(
              container_cpu_usage_seconds_total{
                namespace="analysis-demo",
                pod=~"analysis-demo.*"
              }[2m]
            )
          ) by (pod)
EOF
```

### 3.4 Verify AnalysisTemplates

List created templates:

```bash
# List analysis templates
kubectl get analysistemplates -n analysis-demo

# Describe templates
kubectl describe analysistemplate success-rate -n analysis-demo
kubectl describe analysistemplate response-time -n analysis-demo
kubectl describe analysistemplate cpu-usage -n analysis-demo

# View template YAML
kubectl get analysistemplate success-rate -n analysis-demo -o yaml
```

## Step 4: Integrate Analysis with Rollout

### 4.1 Create Rollout with Background Analysis

Create a rollout that runs continuous background analysis:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollout-with-analysis
  namespace: analysis-demo
spec:
  replicas: 5
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: rollout-with-analysis
  template:
    metadata:
      labels:
        app: rollout-with-analysis
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: msahihi/rollouts-demo:blue
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
      steps:
      - setWeight: 20
      - pause: {duration: 2m}
      - setWeight: 40
      - pause: {duration: 2m}
      - setWeight: 60
      - pause: {duration: 2m}
      - setWeight: 80
      - pause: {duration: 2m}
      # Background analysis runs throughout entire rollout
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: rollouts_pod_template_hash
          valueFrom:
            podTemplateHashValue: Latest
EOF
```

### 4.2 Create Service for Rollout

Create a service:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: rollout-with-analysis
  namespace: analysis-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: rollout-with-analysis
EOF
```

### 4.3 Verify Rollout Creation

Wait for initial deployment:

```bash
# Watch rollout
kubectl argo rollouts get rollout rollout-with-analysis --watch -n analysis-demo
# Press Ctrl+C when healthy

# Check rollout status
kubectl argo rollouts get rollout rollout-with-analysis -n analysis-demo
```

## Step 5: Test Analysis During Rollout

### 5.1 Create Load Generator

Create a pod to generate traffic:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: load-generator
  namespace: analysis-demo
spec:
  containers:
  - name: load
    image: busybox:latest
    command:
    - /bin/sh
    - -c
    - |
      while true; do
        wget -q -O- http://rollout-with-analysis
        sleep 0.1
      done
EOF
```

### 5.2 Deploy New Version with Analysis

Update the rollout to trigger analysis:

```bash
# Update to yellow version
kubectl argo rollouts set image rollout-with-analysis \
  app=msahihi/rollouts-demo:yellow \
  -n analysis-demo

# Watch rollout with analysis
kubectl argo rollouts get rollout rollout-with-analysis --watch -n analysis-demo
```

**Observe:**

- Rollout progresses through canary steps
- AnalysisRun is created automatically
- Analysis runs in background throughout rollout
- Rollout continues if analysis succeeds

### 5.3 Monitor AnalysisRun

Check the analysis run status:

```bash
# List analysis runs
kubectl get analysisruns -n analysis-demo

# Get latest analysis run name
ANALYSIS_RUN=$(kubectl get analysisruns -n analysis-demo \
  --sort-by=.metadata.creationTimestamp -o name | tail -1)

# Watch analysis run
kubectl argo rollouts get analysisrun ${ANALYSIS_RUN#*/} -n analysis-demo --watch

# Get detailed status
kubectl describe analysisrun ${ANALYSIS_RUN#*/} -n analysis-demo
```

**Expected Output:**

```
Name:            rollout-with-analysis-abc123-1
Namespace:       analysis-demo
Status:          ✔ Successful
Strategy:        Canary
Started:         2024-01-15 10:30:00 +0000 UTC
Finished:        2024-01-15 10:35:00 +0000 UTC

Metrics:
  ✔ success-rate
    Successful:  5
    Failed:      0
    Inconclusive: 0
    Measurement Details:
    - 2024-01-15 10:30:30: 0.98 (✔)
    - 2024-01-15 10:31:00: 0.97 (✔)
    - 2024-01-15 10:31:30: 0.99 (✔)
    - 2024-01-15 10:32:00: 0.96 (✔)
    - 2024-01-15 10:32:30: 0.98 (✔)
```

### 5.4 View Analysis Metrics

Get metric measurements:

```bash
# Get analysis run in JSON
kubectl get analysisrun ${ANALYSIS_RUN#*/} -n analysis-demo -o json | jq .status

# Get specific metric measurements
kubectl get analysisrun ${ANALYSIS_RUN#*/} -n analysis-demo -o json | \
  jq '.status.metricResults[] | {name: .name, phase: .phase, measurements: .measurements}'
```

## Step 6: Inline Analysis

### 6.1 Create Rollout with Inline Analysis

Create a rollout with analysis at specific steps:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollout-inline-analysis
  namespace: analysis-demo
spec:
  replicas: 5
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: rollout-inline-analysis
  template:
    metadata:
      labels:
        app: rollout-inline-analysis
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: msahihi/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 1m}
      # Inline analysis after 20% step
      - analysis:
          templates:
          - templateName: success-rate
          args:
          - name: rollouts_pod_template_hash
            valueFrom:
              podTemplateHashValue: Latest
      - setWeight: 50
      - pause: {duration: 1m}
      # Inline analysis after 50% step
      - analysis:
          templates:
          - templateName: success-rate
          - templateName: cpu-usage
      - setWeight: 80
      - pause: {duration: 1m}
EOF
```

Create service:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: rollout-inline-analysis
  namespace: analysis-demo
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: rollout-inline-analysis
EOF
```

### 6.2 Deploy with Inline Analysis

Wait for initial deployment and then update:

```bash
# Wait for initial deployment
kubectl argo rollouts get rollout rollout-inline-analysis --watch -n analysis-demo
# Press Ctrl+C when healthy

# Update image
kubectl argo rollouts set image rollout-inline-analysis \
  app=msahihi/rollouts-demo:yellow \
  -n analysis-demo

# Watch rollout - it will pause at each analysis step
kubectl argo rollouts get rollout rollout-inline-analysis --watch -n analysis-demo
```

**Observe:**

- Rollout pauses after 20% to run analysis
- If analysis succeeds, proceeds to 50%
- Pauses again after 50% to run analysis
- Multiple templates can run at same step

### 6.3 Monitor Inline Analysis

```bash
# List all analysis runs
kubectl get analysisruns -n analysis-demo -l rollout=rollout-inline-analysis

# Watch the latest
LATEST_RUN=$(kubectl get analysisruns -n analysis-demo \
  -l rollout=rollout-inline-analysis \
  --sort-by=.metadata.creationTimestamp -o name | tail -1)

kubectl argo rollouts get analysisrun ${LATEST_RUN#*/} -n analysis-demo --watch
```

## Step 7: Simulate Analysis Failure

### 7.1 Create Failing AnalysisTemplate

Create a template that will always fail:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: always-fail
  namespace: analysis-demo
spec:
  metrics:
  - name: always-fail
    initialDelay: 10s
    interval: 10s
    failureLimit: 1
    successCondition: result > 1.0  # Impossible condition
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: "scalar(0.5)"  # Always returns 0.5
EOF
```

### 7.2 Create Rollout with Failing Analysis

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollout-fail-analysis
  namespace: analysis-demo
spec:
  replicas: 5
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: rollout-fail-analysis
  template:
    metadata:
      labels:
        app: rollout-fail-analysis
    spec:
      containers:
      - name: app
        image: msahihi/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 30s}
      - analysis:
          templates:
          - templateName: always-fail
      - setWeight: 50
      - pause: {duration: 30s}
EOF
```

### 7.3 Trigger Failing Rollout

Deploy and observe automatic rollback:

```bash
# Wait for initial deployment
kubectl argo rollouts get rollout rollout-fail-analysis --watch -n analysis-demo
# Press Ctrl+C when healthy

# Update image to trigger rollout
kubectl argo rollouts set image rollout-fail-analysis \
  app=msahihi/rollouts-demo:red \
  -n analysis-demo

# Watch rollout - it will fail and rollback automatically
kubectl argo rollouts get rollout rollout-fail-analysis --watch -n analysis-demo
```

**Observe:**

- Rollout reaches 20% weight
- Analysis runs and fails
- Rollout automatically aborts
- Traffic returns to stable version
- Status shows "Degraded"

### 7.4 Verify Automatic Rollback

```bash
# Check rollout status
kubectl argo rollouts get rollout rollout-fail-analysis -n analysis-demo

# Check analysis run
FAILED_RUN=$(kubectl get analysisruns -n analysis-demo \
  -l rollout=rollout-fail-analysis \
  --sort-by=.metadata.creationTimestamp -o name | tail -1)

kubectl describe analysisrun ${FAILED_RUN#*/} -n analysis-demo

# Verify stable version is active
kubectl get pods -n analysis-demo -l app=rollout-fail-analysis
```

## Step 8: Web Metrics Provider

### 8.1 Create Web-based AnalysisTemplate

Create a template that uses a web endpoint instead of Prometheus:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: web-metric
  namespace: analysis-demo
spec:
  metrics:
  - name: webmetric
    initialDelay: 5s
    interval: 10s
    successCondition: "result == true"
    failureLimit: 3
    count: 3
    provider:
      web:
        url: "http://rollout-with-analysis/health"
        jsonPath: "{$.healthy}"
EOF
```

### 8.2 Create Rollout with Web Analysis

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollout-web-analysis
  namespace: analysis-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rollout-web-analysis
  template:
    metadata:
      labels:
        app: rollout-web-analysis
    spec:
      containers:
      - name: app
        image: msahihi/rollouts-demo:blue
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            memory: 32Mi
            cpu: 5m
  strategy:
    canary:
      steps:
      - setWeight: 33
      - pause: {duration: 30s}
      - analysis:
          templates:
          - templateName: web-metric
      - setWeight: 67
      - pause: {duration: 30s}
EOF
```

## Step 9: Manual AnalysisRun

### 9.1 Create Manual AnalysisRun

Create an AnalysisRun manually for testing:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisRun
metadata:
  name: manual-analysis-run
  namespace: analysis-demo
spec:
  metrics:
  - name: manual-test
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: "up{job='kubernetes-pods'}"
    initialDelay: 5s
    interval: 10s
    successCondition: result >= 0
    count: 3
EOF
```

### 9.2 Monitor Manual AnalysisRun

Watch the manual analysis:

```bash
# Watch analysis run
kubectl argo rollouts get analysisrun manual-analysis-run -n analysis-demo --watch

# Get status
kubectl get analysisrun manual-analysis-run -n analysis-demo

# Describe
kubectl describe analysisrun manual-analysis-run -n analysis-demo
```

## Step 10: Advanced Analysis Configuration

### 10.1 Create Template with Multiple Metrics

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: multi-metric-analysis
  namespace: analysis-demo
spec:
  metrics:
  - name: error-rate
    initialDelay: 30s
    interval: 30s
    successCondition: result < 0.05
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(rate(http_requests_total{status=~"5..",namespace="analysis-demo"}[2m]))
          /
          sum(rate(http_requests_total{namespace="analysis-demo"}[2m]))

  - name: request-rate
    initialDelay: 30s
    interval: 30s
    successCondition: result > 10
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(rate(http_requests_total{namespace="analysis-demo"}[2m]))

  - name: memory-usage
    initialDelay: 30s
    interval: 30s
    successCondition: result < 104857600  # 100MB in bytes
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(container_memory_usage_bytes{namespace="analysis-demo",pod=~"rollout-with-analysis.*"})
EOF
```

### 10.2 Use Template with Arguments

Create a reusable template with arguments:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: parameterized-analysis
  namespace: analysis-demo
spec:
  args:
  - name: service-name
  - name: error-threshold
    value: "0.05"
  metrics:
  - name: error-rate
    initialDelay: 30s
    interval: 30s
    successCondition: result < {{args.error-threshold}}
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(rate(http_requests_total{status=~"5..",service="{{args.service-name}}"}[2m]))
          /
          sum(rate(http_requests_total{service="{{args.service-name}}"}[2m]))
EOF
```

Use with rollout:

```bash
# In a rollout spec, you would use it like this:
# analysis:
#   templates:
#   - templateName: parameterized-analysis
#   args:
#   - name: service-name
#     value: my-service
#   - name: error-threshold
#     value: "0.03"
```

## Step 11: Monitoring and Debugging

### 11.1 View All AnalysisRuns

```bash
# List all analysis runs
kubectl get analysisruns -n analysis-demo

# List with status
kubectl get analysisruns -n analysis-demo -o wide

# List successful runs
kubectl get analysisruns -n analysis-demo --field-selector status.phase=Successful

# List failed runs
kubectl get analysisruns -n analysis-demo --field-selector status.phase=Failed
```

### 11.2 Debug Failed Analysis

```bash
# Get failed analysis runs
FAILED_RUNS=$(kubectl get analysisruns -n analysis-demo \
  --field-selector status.phase=Failed -o name)

# Examine each failed run
for run in $FAILED_RUNS; do
  echo "=== ${run} ==="
  kubectl describe ${run} -n analysis-demo
  echo ""
done

# Get metric results
kubectl get analysisrun ${FAILED_RUNS[0]#*/} -n analysis-demo -o json | \
  jq '.status.metricResults'
```

### 11.3 View Analysis Events

```bash
# Get events for analysis runs
kubectl get events -n analysis-demo \
  --field-selector involvedObject.kind=AnalysisRun \
  --sort-by='.lastTimestamp'
```

## Step 12: Clean Up

### 12.1 Stop Load Generator

```bash
# Delete load generator
kubectl delete pod load-generator -n analysis-demo
```

### 12.2 Delete Rollouts

```bash
# Delete all rollouts
kubectl delete rollout --all -n analysis-demo

# Verify
kubectl get rollouts -n analysis-demo
```

### 12.3 Delete AnalysisTemplates and Runs

```bash
# Delete analysis templates
kubectl delete analysistemplates --all -n analysis-demo

# Delete analysis runs
kubectl delete analysisruns --all -n analysis-demo

# Verify
kubectl get analysistemplates,analysisruns -n analysis-demo
```

### 12.4 Delete Services

```bash
# Delete all services
kubectl delete services --all -n analysis-demo

# Verify
kubectl get services -n analysis-demo
```

### 12.5 Delete Namespace

```bash
# Delete namespace
kubectl delete namespace analysis-demo

# Verify
kubectl get namespace analysis-demo
```

### 12.6 Clean Up Prometheus (Optional)

```bash
# If you want to remove Prometheus
kubectl delete deployment prometheus -n monitoring
kubectl delete service prometheus -n monitoring
kubectl delete configmap prometheus-config -n monitoring

# Delete monitoring namespace
kubectl delete namespace monitoring

# Stop port-forward if running
pkill -f "kubectl port-forward.*prometheus"
```

## Verification

Confirm successful completion:

```bash
# Verify Argo Rollouts is still running
kubectl get deployment argo-rollouts -n argo-rollouts

# Verify namespaces are deleted
kubectl get namespace analysis-demo
kubectl get namespace monitoring
```

## Lab Completion Checklist

- [ ] Installed Prometheus for metrics collection
- [ ] Created AnalysisTemplate resources with Prometheus queries
- [ ] Integrated background analysis with canary rollout
- [ ] Implemented inline analysis at specific rollout steps
- [ ] Configured success and failure thresholds
- [ ] Tested automated rollback on analysis failure
- [ ] Created manual AnalysisRun for testing
- [ ] Used web-based metric provider
- [ ] Created parameterized analysis templates
- [ ] Successfully cleaned up all resources

## Key Takeaways

1. **AnalysisTemplate**: Defines reusable metric queries and validation rules that can be referenced by multiple rollouts

2. **Background Analysis**: Runs continuously throughout the entire rollout, providing ongoing validation of the canary version

3. **Inline Analysis**: Runs at specific steps in the rollout, acting as quality gates before proceeding to the next step

4. **Automated Rollback**: When analysis fails (exceeds failureLimit), the rollout automatically aborts and reverts to stable version

5. **Metric Providers**: Support multiple providers (Prometheus, Datadog, CloudWatch, Web) for flexible metric collection

6. **Success/Failure Conditions**: Define thresholds using expressions (e.g., `result >= 0.95`) to determine analysis outcome

7. **AnalysisRun**: Actual execution instance of an AnalysisTemplate, created automatically by rollouts or manually for testing

8. **Count and Interval**: Control how many times and how often metric queries run during analysis

## Troubleshooting

### Prometheus Not Scraping Metrics

If Prometheus isn't collecting metrics:

```bash
# Check Prometheus pod logs
kubectl logs -n monitoring deployment/prometheus

# Verify pod annotations
kubectl get pods -n analysis-demo -o yaml | grep -A 3 "prometheus.io"

# Check Prometheus targets
kubectl port-forward -n monitoring service/prometheus 9090:9090
# Visit http://localhost:9090/targets in browser

# Verify service discovery
kubectl get pods -n monitoring -o yaml | grep -A 10 kubernetes_sd_configs
```

### Analysis Always Failing

If analysis runs always fail:

```bash
# Check AnalysisRun details
kubectl describe analysisrun <run-name> -n analysis-demo

# Check metric measurements
kubectl get analysisrun <run-name> -n analysis-demo -o json | \
  jq '.status.metricResults[].measurements'

# Test Prometheus query directly
kubectl port-forward -n monitoring service/prometheus 9090:9090
# Use Prometheus UI to test query

# Check Prometheus connectivity from analysis controller
kubectl exec -it -n argo-rollouts deployment/argo-rollouts -- \
  wget -O- http://prometheus.monitoring.svc.cluster.local:9090/-/healthy
```

### AnalysisRun Not Created

If AnalysisRun isn't being created:

```bash
# Check rollout events
kubectl describe rollout <rollout-name> -n analysis-demo

# Check AnalysisTemplate exists
kubectl get analysistemplate -n analysis-demo

# Verify template name in rollout spec
kubectl get rollout <rollout-name> -n analysis-demo -o yaml | grep -A 5 analysis

# Check controller logs
kubectl logs -n argo-rollouts deployment/argo-rollouts | grep -i analysis
```

## Next Steps

Continue to the next lab:

- [Lab 05: Traffic Management](lab-05-traffic-management.md) - Integrate NGINX ingress for advanced traffic routing

## Additional Resources

- [Analysis Documentation](https://argoproj.github.io/argo-rollouts/features/analysis/)
- [AnalysisTemplate Specification](https://argoproj.github.io/argo-rollouts/features/analysis/#analysistemplate)
- [Metric Providers](https://argoproj.github.io/argo-rollouts/analysis/prometheus/)
- [Background Analysis](https://argoproj.github.io/argo-rollouts/features/analysis/#background-analysis)
- [Analysis Arguments](https://argoproj.github.io/argo-rollouts/features/analysis/#analysis-template-arguments)
