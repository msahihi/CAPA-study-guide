# Argo Events - Event-Based Automation (15%)

Argo Events is an event-driven workflow automation framework for Kubernetes. It enables you to trigger Argo Workflows, Kubernetes resources, and other actions in response to events from various sources like webhooks, calendars, message queues, and Kubernetes resources. Argo Events follows a declarative approach to define event sources, event bus, sensors, and triggers for building reactive, event-driven systems.

## Topics

### [Event Sources and Sensors](event-sources-sensors.md)

Understanding the EventSource CRD for capturing events from various sources (webhook, calendar, resource, message queues), the Sensor CRD for defining event dependencies and triggers, different event source types, and how sensors process events.

### [Event Bus](event-bus.md)

Learning the event bus architecture that connects event sources to sensors, configuring NATS/JetStream as the event bus implementation, setting up event bus for different namespaces, and understanding event routing and delivery guarantees.

### [Triggers and Actions](triggers-actions.md)

Exploring different trigger types supported by sensors, creating trigger templates for various actions, defining trigger conditions and filters, and implementing actions like triggering Argo Workflows, creating Kubernetes resources, and making HTTP requests.

### [Integration Patterns](integration-patterns.md)

Implementing common integration patterns including CI/CD automation, webhook-based automation for GitHub/GitLab events, resource watching for Kubernetes object changes, calendar-based scheduled triggers, and integration with external systems and message queues.

## Related Labs

Practice these hands-on labs to reinforce your understanding:

- [Lab 01: Installation and Basics](../../labs/04-argo-events/lab-01-installation-basics.md) - 20 minutes
- [Lab 02: Event Sources](../../labs/04-argo-events/lab-02-event-sources.md) - 35 minutes
- [Lab 03: Triggers](../../labs/04-argo-events/lab-03-triggers.md) - 40 minutes
- [Lab 04: Integration with Argo Workflows](../../labs/04-argo-events/lab-04-integration.md) - 45 minutes

## Study Resources

- [Argo Events Official Documentation](https://argoproj.github.io/argo-events/) - Complete reference guide
- [Argo Events Getting Started](https://argoproj.github.io/argo-events/quick_start/) - Quick start guide
- [Event Source Types](https://argoproj.github.io/argo-events/eventsources/setup/) - All supported event sources
- [Sensor Examples](https://github.com/argoproj/argo-events/tree/master/examples/sensors) - Official sensor examples
- [Argo Events Best Practices](https://argoproj.github.io/argo-events/best-practices/) - Production deployment guidance

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
