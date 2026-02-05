# Event Bus

## Overview

The Event Bus is a critical component in Argo Events that connects EventSources to Sensors. It acts as a message broker that receives events from event sources and delivers them to sensors. Argo Events uses NATS (with JetStream) as the underlying messaging system to provide reliable, scalable event delivery. The Event Bus ensures loose coupling between event producers (EventSources) and event consumers (Sensors), enabling flexible and scalable event-driven architectures.

## Key Topics

### Event Bus Architecture

The Event Bus provides the messaging backbone for Argo Events.

**Architecture Components:**

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│             │         │             │         │             │
│ EventSource │──Pub──▶ │  Event Bus  │──Sub──▶ │   Sensor    │
│             │         │   (NATS)    │         │             │
└─────────────┘         └─────────────┘         └─────────────┘
      │                       │                       │
      │                       │                       │
   External              Event Storage            Triggers
   Systems               & Routing                 Actions
```

**Key Characteristics:**

- **Publish-Subscribe Pattern**: EventSources publish events; Sensors subscribe to events
- **Decoupling**: EventSources and Sensors don't need to know about each other
- **Buffering**: Events are buffered in the event bus for reliability
- **Multi-Tenancy**: Separate event buses can be created per namespace
- **Scalability**: NATS provides high-throughput, low-latency messaging
- **Persistence**: JetStream provides message persistence and replay capabilities

### EventBus CRD

The EventBus is a Kubernetes custom resource that defines the event bus configuration for a namespace.

**EventBus Structure:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  # NATS streaming configuration
  nats:
    # Native NATS with JetStream
    native:
      # Replication factor for high availability
      replicas: 3
      # Authentication
      auth: token
      # Persistence configuration
      persistence:
        storageClassName: standard
        accessMode: ReadWriteOnce
        volumeSize: 10Gi
```

**Key Components:**

- **metadata**: Standard Kubernetes metadata (typically named "default")
- **spec.nats**: NATS configuration for the event bus
- **native**: Use NATS deployed within Kubernetes (recommended)
- **exotic**: Use external NATS cluster (advanced use case)

### NATS Configuration

Argo Events uses NATS with JetStream for reliable message delivery.

**Native NATS Deployment:**

The native option deploys NATS within the Kubernetes cluster.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    native:
      # Number of NATS replicas for HA
      replicas: 3
      # Authentication method
      auth: token
      # Container image settings
      containerTemplate:
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
      # Metrics exporter settings
      metricsContainerTemplate:
        resources:
          requests:
            cpu: "10m"
            memory: "16Mi"
      # Persistence for message storage
      persistence:
        storageClassName: gp2
        accessMode: ReadWriteOnce
        volumeSize: 20Gi
```

**Authentication Options:**

- **none**: No authentication (development only)
- **token**: Token-based authentication (recommended)
- **tls**: TLS certificate-based authentication (most secure)

**Example with TLS:**

```yaml
spec:
  nats:
    native:
      replicas: 3
      auth: tls
      tlsConfig:
        caCertSecret:
          name: nats-ca
          key: ca.crt
        serverCertSecret:
          name: nats-server-cert
          key: tls.crt
        serverKeySecret:
          name: nats-server-cert
          key: tls.key
```

### External NATS (Exotic)

For advanced use cases, you can connect to an external NATS cluster.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    exotic:
      # External NATS connection URL
      url: nats://my-nats-cluster.example.com:4222
      # Cluster ID for NATS Streaming
      clusterID: my-cluster
      # Authentication
      auth: token
      accessSecret:
        name: nats-access
        key: token
```

### Event Bus Setup

Setting up the Event Bus is required before creating EventSources and Sensors.

**Installation Steps:**

1. **Install Argo Events** (if not already installed):

   ```bash
   kubectl create namespace argo-events
   kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
   ```

2. **Create EventBus**:

   ```bash
   kubectl apply -n argo-events -f - <<EOF
   apiVersion: argoproj.io/v1alpha1
   kind: EventBus
   metadata:
     name: default
   spec:
     nats:
       native:
         replicas: 3
         auth: token
   EOF
   ```

3. **Verify EventBus Status**:

   ```bash
   kubectl get eventbus -n argo-events
   kubectl describe eventbus default -n argo-events
   ```

**EventBus Status Phases:**

- **Pending**: EventBus is being created
- **Running**: EventBus is operational
- **Error**: EventBus encountered an error

### Event Routing

The Event Bus routes events from EventSources to Sensors based on event names.

**Event Naming Convention:**

Events are identified by:

- **EventSource Name**: The name of the EventSource resource
- **Event Name**: The specific event name within the EventSource

```yaml
# EventSource defines events
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook-source
spec:
  webhook:
    example-event:  # This is the event name
      port: "12000"
      endpoint: /example
```

```yaml
# Sensor subscribes to events by name
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-sensor
spec:
  dependencies:
    - name: webhook-dep
      eventSourceName: webhook-source  # EventSource name
      eventName: example-event         # Event name
```

**Event Subjects:**

Internally, events are published to NATS subjects with the format:

```
<namespace>.<eventSourceName>.<eventName>
```

For example:

- Namespace: `argo-events`
- EventSource: `webhook-source`
- Event: `example-event`
- Subject: `argo-events.webhook-source.example-event`

### Persistence and Reliability

JetStream provides persistence and delivery guarantees.

**Storage Configuration:**

```yaml
spec:
  nats:
    native:
      replicas: 3
      persistence:
        # Storage class for persistent volumes
        storageClassName: fast-ssd
        # Access mode
        accessMode: ReadWriteOnce
        # Volume size per replica
        volumeSize: 50Gi
      # JetStream settings
      jetstream:
        # Enable JetStream (default: true)
        enabled: true
        # Max memory for JetStream
        memorySize: 1Gi
        # Max file storage
        fileSize: 10Gi
```

**Delivery Guarantees:**

- **At-least-once**: Default delivery mode; messages may be delivered multiple times
- **Exactly-once**: Can be achieved with proper sensor idempotency design
- **Message Ordering**: Preserved within a single subject

### Multi-Namespace Event Buses

Each namespace can have its own EventBus for isolation.

**Namespace Isolation:**

```bash
# Create EventBus in namespace "team-a"
kubectl create namespace team-a
kubectl apply -n team-a -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
spec:
  nats:
    native:
      replicas: 3
EOF
```

```bash
# Create EventBus in namespace "team-b"
kubectl create namespace team-b
kubectl apply -n team-b -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
spec:
  nats:
    native:
      replicas: 3
EOF
```

EventSources and Sensors in each namespace use their own EventBus, providing complete isolation.

### Scaling and High Availability

**Replica Configuration:**

For high availability, run multiple NATS replicas:

```yaml
spec:
  nats:
    native:
      # 3 replicas for HA (recommended for production)
      replicas: 3
      # Anti-affinity to spread across nodes
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  controller: eventbus-controller
                  eventbus-name: default
              topologyKey: kubernetes.io/hostname
```

**Resource Management:**

```yaml
spec:
  nats:
    native:
      replicas: 3
      containerTemplate:
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
      persistence:
        volumeSize: 100Gi
```

### Monitoring Event Bus

**Health Checks:**

```bash
# Check EventBus status
kubectl get eventbus -n argo-events

# Describe EventBus for detailed status
kubectl describe eventbus default -n argo-events

# Check NATS pods
kubectl get pods -n argo-events -l controller=eventbus-controller

# View NATS logs
kubectl logs -n argo-events -l controller=eventbus-controller
```

**Metrics:**

NATS exposes Prometheus metrics for monitoring:

```yaml
spec:
  nats:
    native:
      replicas: 3
      # Enable metrics exporter
      metricsContainerTemplate:
        resources:
          requests:
            cpu: "10m"
            memory: "16Mi"
```

**Key Metrics:**

- Message publish rate
- Message delivery rate
- Queue depth
- Connection count
- Subscription count

## Practice Examples

### Example 1: Basic EventBus

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    native:
      replicas: 1
      auth: none
```

### Example 2: Production EventBus

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    native:
      replicas: 3
      auth: token
      persistence:
        storageClassName: fast-ssd
        accessMode: ReadWriteOnce
        volumeSize: 50Gi
      containerTemplate:
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
      metricsContainerTemplate:
        resources:
          requests:
            cpu: "10m"
            memory: "16Mi"
          limits:
            cpu: "50m"
            memory: "64Mi"
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  controller: eventbus-controller
              topologyKey: kubernetes.io/hostname
```

### Example 3: EventBus with TLS

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    native:
      replicas: 3
      auth: tls
      tlsConfig:
        caCertSecret:
          name: nats-ca-cert
          key: ca.crt
        serverCertSecret:
          name: nats-server-cert
          key: tls.crt
        serverKeySecret:
          name: nats-server-cert
          key: tls.key
      persistence:
        storageClassName: standard
        volumeSize: 20Gi
```

### Example 4: External NATS Connection

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    exotic:
      url: nats://external-nats.example.com:4222
      clusterID: production-cluster
      auth: token
      accessSecret:
        name: nats-access-token
        key: token
```

## Study Resources

- [EventBus Specification](https://argoproj.github.io/argo-events/concepts/eventbus/) - Complete EventBus reference
- [NATS Documentation](https://docs.nats.io/) - NATS messaging system
- [JetStream Guide](https://docs.nats.io/nats-concepts/jetstream) - NATS JetStream persistence
- [EventBus Examples](https://github.com/argoproj/argo-events/tree/master/examples/eventbus) - Official examples

## Key Points to Remember

- EventBus is required for Argo Events to function; it connects EventSources to Sensors
- NATS with JetStream is the default and recommended implementation
- Each namespace typically has its own EventBus named "default"
- Native NATS deployment is recommended for most use cases
- Production EventBuses should use 3 replicas for high availability
- Persistence ensures events are not lost during pod restarts
- Token or TLS authentication should be used in production (not "none")
- Events are routed by namespace, EventSource name, and event name
- NATS subjects follow the pattern: `<namespace>.<eventSourceName>.<eventName>`
- JetStream provides at-least-once delivery guarantees
- Multiple EventBuses can be created for namespace isolation
- EventBus status should be "Running" before creating EventSources and Sensors
- Metrics can be exported for monitoring EventBus health and performance
- Storage size should be planned based on event volume and retention requirements

## Hands-On Practice

- [Lab 01: Installation and Basics](../../labs/04-argo-events/lab-01-installation-basics.md) - Install Argo Events and create an EventBus, verify the installation
- [Lab 02: Event Sources](../../labs/04-argo-events/lab-02-event-sources.md) - Work with EventBus to connect EventSources and Sensors
