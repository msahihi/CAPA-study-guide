# Analysis and Metrics

## Overview

Argo Rollouts provides sophisticated analysis capabilities to validate deployments using metrics from various providers. AnalysisTemplates define queries against metric systems, success/failure criteria, and validation logic. This enables automated, metrics-driven progressive delivery where deployments proceed or rollback based on real application performance data.

## Key Topics

### AnalysisTemplate Structure

AnalysisTemplates are Kubernetes custom resources that define how to query metrics and determine success or failure.

**Basic AnalysisTemplate:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 1m
    successCondition: result >= 0.95
    failureCondition: result < 0.90
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          sum(rate(http_requests_total{status=~"2.*"}[5m])) /
          sum(rate(http_requests_total[5m]))
```

**AnalysisTemplate Fields:**

- `metrics`: List of metrics to collect and analyze
- `args`: Parameters that can be passed when referencing the template
- `dryRun`: List of metrics for dry-run mode (won't fail rollout)
- `measurementRetention`: Number of measurements to keep

**Metric Configuration:**

- `name`: Unique name for the metric
- `interval`: How often to run the query (e.g., 1m, 30s)
- `initialDelay`: Delay before first measurement
- `count`: Number of measurements to perform (default: unlimited)
- `successCondition`: Expression that must be true for success
- `failureCondition`: Expression that causes immediate failure
- `failureLimit`: Number of failures before marking analysis as failed
- `inconclusiveLimit`: Number of inconclusive measurements allowed
- `consecutiveErrorLimit`: Consecutive errors before failure
- `provider`: Metric provider configuration

### Metric Providers

Argo Rollouts supports multiple metric providers for gathering analysis data.

#### Prometheus

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: prometheus-metrics
spec:
  args:
  - name: service-name
  metrics:
  - name: error-rate
    interval: 30s
    successCondition: result < 0.05
    failureCondition: result >= 0.10
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          sum(rate(http_requests_total{
            service="{{args.service-name}}",
            status=~"5.."
          }[2m])) /
          sum(rate(http_requests_total{
            service="{{args.service-name}}"
          }[2m]))

  - name: latency-p95
    interval: 30s
    successCondition: result < 500
    failureCondition: result >= 1000
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{
              service="{{args.service-name}}"
            }[2m])) by (le)
          ) * 1000
```

#### Datadog

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: datadog-metrics
spec:
  args:
  - name: service-name
  metrics:
  - name: error-rate
    interval: 1m
    successCondition: result < 5
    provider:
      datadog:
        apiVersion: v1
        interval: 5m
        query: |
          avg:trace.http.request.errors{service:{{args.service-name}}}.as_count()
```

**Datadog Configuration:**

Requires API and Application keys as secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: datadog-api-key
type: Opaque
stringData:
  api-key: <datadog-api-key>
  app-key: <datadog-app-key>
```

#### CloudWatch

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: cloudwatch-metrics
spec:
  metrics:
  - name: target-response-time
    interval: 1m
    successCondition: result < 500
    provider:
      cloudWatch:
        interval: 300
        metricDataQueries:
        - id: rate
          expression: m1 / 60
        - id: m1
          metricStat:
            metric:
              namespace: AWS/ApplicationELB
              name: TargetResponseTime
              dimensions:
              - name: LoadBalancer
                value: app/my-alb/1234567890
            period: 300
            stat: Average
            unit: Seconds
          returnData: false
```

#### New Relic

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: newrelic-metrics
spec:
  metrics:
  - name: error-percentage
    interval: 1m
    successCondition: result < 5
    failureCondition: result >= 10
    provider:
      newRelic:
        profile: prod
        query: |
          FROM Transaction
          SELECT percentage(count(*), WHERE error IS true)
          WHERE appName = 'my-app'
```

**New Relic Configuration:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: newrelic
type: Opaque
stringData:
  personal-api-key: <api-key>
  account-id: "<account-id>"
```

#### Wavefront

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: wavefront-metrics
spec:
  metrics:
  - name: error-rate
    interval: 1m
    successCondition: result < 0.05
    provider:
      wavefront:
        address: https://example.wavefront.com
        query: |
          sum(rate(5m, ts("http.requests.errors", app="my-app"))) /
          sum(rate(5m, ts("http.requests.total", app="my-app")))
```

#### Web/HTTP Provider

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: http-benchmark
spec:
  metrics:
  - name: webmetric
    successCondition: result == true
    provider:
      web:
        url: "http://my-server/api/v1/measurement?service={{args.service-name}}"
        timeoutSeconds: 20
        headers:
        - key: Authorization
          value: "Bearer {{ secret.token }}"
        jsonPath: "{$.success}"
```

#### Kubernetes Job Provider

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: job-based-test
spec:
  metrics:
  - name: test-job
    provider:
      job:
        spec:
          template:
            spec:
              containers:
              - name: test
                image: curlimages/curl:latest
                command: ["/bin/sh", "-c"]
                args:
                - |
                  curl -f http://my-app/health || exit 1
              restartPolicy: Never
          backoffLimit: 1
```

### Success and Failure Conditions

Conditions use expression language to evaluate metric results.

**Condition Syntax:**

```yaml
successCondition: result >= 0.95
failureCondition: result < 0.90

# Between two values
successCondition: result >= 0.90 && result <= 1.00

# Multiple conditions with logical operators
successCondition: result.ok == true && result.latency < 500

# Check for existence
successCondition: result != nil

# Array operations
successCondition: len(result) > 0

# Complex expressions
successCondition: result.errorRate < 0.05 && result.requestCount > 100
```

**Numeric Comparisons:**

```yaml
metrics:
- name: error-rate
  successCondition: result < 0.05      # Less than 5%
  failureCondition: result >= 0.10     # 10% or higher fails
  inconclusiveCondition: result >= 0.05 && result < 0.10  # Between: inconclusive
```

**Boolean Results:**

```yaml
metrics:
- name: health-check
  successCondition: result == true
  failureCondition: result == false
```

**String Matching:**

```yaml
metrics:
- name: status-check
  successCondition: result == "healthy"
  failureCondition: result == "unhealthy"
```

**Failure and Inconclusive Limits:**

```yaml
metrics:
- name: intermittent-check
  successCondition: result == true
  failureLimit: 3              # Fail after 3 failures
  inconclusiveLimit: 5         # Fail after 5 inconclusive
  consecutiveErrorLimit: 2     # Fail after 2 consecutive errors
  interval: 30s
  count: 10                    # Run 10 times total
```

**Initial Delay:**

```yaml
metrics:
- name: warm-up-check
  initialDelay: 2m    # Wait 2 minutes before first check
  interval: 30s
  successCondition: result >= 0.95
```

### AnalysisRun Lifecycle

AnalysisRun is a Kubernetes resource that represents an instantiation of an AnalysisTemplate.

**Creating AnalysisRun:**

AnalysisRuns are typically created automatically by Rollouts, but can be created manually:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisRun
metadata:
  name: manual-analysis
spec:
  metrics:
  - name: success-rate
    interval: 1m
    successCondition: result >= 0.95
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          sum(rate(http_requests_total{status=~"2.*"}[5m])) /
          sum(rate(http_requests_total[5m]))
```

**AnalysisRun Status:**

```yaml
status:
  phase: Running  # Pending, Running, Successful, Failed, Error, Inconclusive
  metricResults:
  - name: success-rate
    phase: Running
    successful: 5
    failed: 0
    inconclusive: 0
    measurements:
    - phase: Successful
      value: "0.98"
      startedAt: "2024-01-20T10:00:00Z"
      finishedAt: "2024-01-20T10:00:05Z"
    - phase: Successful
      value: "0.97"
      startedAt: "2024-01-20T10:01:00Z"
      finishedAt: "2024-01-20T10:01:05Z"
```

**Viewing AnalysisRun Status:**

```bash
# List all analysis runs
kubectl get analysisrun

# Get details of specific run
kubectl describe analysisrun my-analysis-run

# Watch analysis run progress
kubectl get analysisrun my-analysis-run -w

# Get analysis run with kubectl-argo-rollouts plugin
kubectl argo rollouts get analysisrun my-analysis-run
```

**AnalysisRun Phases:**

- **Pending**: Waiting to start
- **Running**: Currently executing measurements
- **Successful**: All metrics passed success conditions
- **Failed**: One or more metrics failed
- **Error**: Error occurred during analysis
- **Inconclusive**: Results were inconclusive

**Terminating AnalysisRun:**

```bash
# Terminate running analysis
kubectl argo rollouts terminate analysisrun my-analysis-run
```

### Integrating Analysis with Rollouts

**Background Analysis:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 5
  strategy:
    canary:
      analysis:
        templates:
        - templateName: success-rate
        - templateName: latency-check
        startingStep: 1    # Start at step 1
        args:
        - name: service-name
          value: my-app-canary
      steps:
      - setWeight: 20
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 5m}
```

**Step-Level Analysis:**

```yaml
strategy:
  canary:
    steps:
    - setWeight: 20
    - pause: {duration: 2m}
    - analysis:
        templates:
        - templateName: smoke-tests
        args:
        - name: service-name
          value: my-app-canary
    - setWeight: 50
    - pause: {duration: 5m}
```

**Pre/Post-Promotion Analysis (Blue-Green):**

```yaml
strategy:
  blueGreen:
    activeService: my-app-active
    previewService: my-app-preview
    prePromotionAnalysis:
      templates:
      - templateName: smoke-tests
      args:
      - name: service-name
        value: my-app-preview
    postPromotionAnalysis:
      templates:
      - templateName: production-checks
      args:
      - name: service-name
        value: my-app-active
```

## Practice Examples

### Example 1: Comprehensive AnalysisTemplate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: comprehensive-analysis
spec:
  args:
  - name: service-name
  - name: namespace
    value: default
  metrics:
  - name: success-rate
    interval: 1m
    count: 5
    successCondition: result >= 0.95
    failureCondition: result < 0.90
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          sum(rate(http_requests_total{
            service="{{args.service-name}}",
            namespace="{{args.namespace}}",
            status=~"2.."
          }[2m])) /
          sum(rate(http_requests_total{
            service="{{args.service-name}}",
            namespace="{{args.namespace}}"
          }[2m]))

  - name: latency-p95
    interval: 1m
    count: 5
    initialDelay: 30s
    successCondition: result < 500
    failureCondition: result >= 1000
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{
              service="{{args.service-name}}"
            }[2m])) by (le)
          ) * 1000

  - name: cpu-usage
    interval: 30s
    successCondition: result < 80
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          avg(rate(container_cpu_usage_seconds_total{
            pod=~"{{args.service-name}}.*",
            namespace="{{args.namespace}}"
          }[1m])) * 100
```

### Example 2: Multi-Provider Analysis

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: multi-provider
spec:
  args:
  - name: service-name
  metrics:
  # Prometheus for technical metrics
  - name: error-rate
    interval: 1m
    successCondition: result < 0.05
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          rate(http_errors_total{service="{{args.service-name}}"}[2m])

  # HTTP endpoint for business metrics
  - name: conversion-rate
    interval: 2m
    successCondition: result >= 0.03
    provider:
      web:
        url: "https://analytics.example.com/api/conversion?service={{args.service-name}}"
        headers:
        - key: Authorization
          value: "Bearer {{ secret.analytics-token }}"
        jsonPath: "{$.conversionRate}"

  # Job for integration tests
  - name: integration-test
    count: 1
    successCondition: result == "passed"
    provider:
      job:
        spec:
          template:
            spec:
              containers:
              - name: test-runner
                image: test-suite:latest
                env:
                - name: SERVICE_URL
                  value: "http://{{args.service-name}}"
              restartPolicy: Never
```

## Study Resources

- [Analysis Overview](https://argoproj.github.io/argo-rollouts/features/analysis/) - Official documentation
- [AnalysisTemplate Specification](https://argoproj.github.io/argo-rollouts/features/analysis/#analysistemplate) - Complete spec reference
- [Metric Providers](https://argoproj.github.io/argo-rollouts/analysis/providers/) - All supported providers
- [Expression Syntax](https://github.com/antonmedv/expr/blob/master/docs/Language-Definition.md) - Condition expression language

## Key Points to Remember

- AnalysisTemplates define reusable metric queries and validation logic
- Multiple metric providers supported: Prometheus, Datadog, CloudWatch, New Relic, etc.
- Success/failure conditions use expression language for flexibility
- AnalysisRuns are instances created from templates during rollouts
- Background analysis runs throughout canary deployment
- Step-level analysis acts as validation gates
- Failure limits and inconclusive limits prevent flaky metric failures
- Initial delay allows time for metrics to stabilize
- Count parameter limits number of measurements
- Analysis failures trigger automatic rollback
- Templates can accept arguments for reusability
- Multiple metrics in single template for comprehensive validation
- Web provider enables custom metric sources via HTTP

## Hands-On Practice

- [Lab 04: Analysis and Metrics](../../labs/03-argo-rollouts/lab-04-analysis.md) - Implement automated metrics-based validation with Prometheus and AnalysisTemplates
