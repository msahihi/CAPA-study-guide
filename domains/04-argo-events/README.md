# Argo Events - Event-Based Automation (12%)

Argo Events is an event-driven workflow automation framework for Kubernetes. It enables you to trigger Argo Workflows, Kubernetes resources, and other actions in response to events from various sources like webhooks, calendars, message queues, and Kubernetes resources. Argo Events follows a declarative approach to define event sources, event bus, sensors, and triggers for building reactive, event-driven systems.

## Topics

### [Event Sources and Sensors](event-sources-sensors.md)

Understanding the EventSource CRD for capturing events from various sources (webhook, calendar, resource, message queues), the Sensor CRD for defining event dependencies and triggers, event bus architecture using NATS/JetStream, and how the event bus connects sources to sensors.

### [Triggers and Actions](triggers-actions.md)

Exploring different trigger types supported by sensors, creating trigger templates for various actions, defining trigger conditions and filters, implementing common integration patterns (CI/CD automation, webhook processing, resource watching, scheduled operations), and triggering Argo Workflows or Kubernetes resources.

## Related Labs

Practice these hands-on labs to reinforce your understanding:

- [Lab 01: Installation and Basics](../../labs/04-argo-events/lab-01-installation-basics.md) - 20 minutes
- [Lab 02: Event Sources](../../labs/04-argo-events/lab-02-event-sources.md) - 35 minutes
- [Lab 03: Sensors](../../labs/04-argo-events/lab-02-event-sources.md) - 40 minutes
- [Lab 04: Integrations](../../labs/04-argo-events/lab-02-event-sources.md) - 45 minutes

## Study Resources

- [Argo Events Official Documentation](https://argoproj.github.io/argo-events/) - Complete reference guide
- [Argo Events Getting Started](https://argoproj.github.io/argo-events/quick_start/) - Quick start guide
- [Event Source Types](https://argoproj.github.io/argo-events/concepts/event_source/) - All supported event sources
- [Sensor Examples](https://github.com/argoproj/argo-events/tree/master/examples/sensors) - Official sensor examples
- [Argo Events Documentation](https://argoproj.github.io/argo-events/) - Production deployment guidance

## Key Exam Topics

Focus on these critical areas for the exam:

- EventSource CRD structure and configuration
- Different event source types (webhook, calendar, resource, etc.)
- Sensor CRD and event dependencies
- Event bus architecture and NATS configuration
- Trigger templates and trigger conditions
- Trigger actions (Argo Workflows, K8s resources, HTTP)
- Event filtering and event payload extraction
- Integration with Argo Workflows
- Webhook automation patterns
- Calendar-based scheduling vs CronWorkflow
- Resource watching and state-based triggers
- Event bus scaling and reliability
