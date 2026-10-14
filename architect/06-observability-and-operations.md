# Observability and operations architecture

[← Architect](README.md)

A system nobody can see into can't be operated, however well it's designed. Operability belongs in the architecture from the start: how telemetry is produced and collected, who owns which signals, how service levels are defined, and what on-call needs to respond. The [observability folder](../devops/observability/README.md) covers the practice and the tools; this guide covers the decisions.

## Operability as a requirement

Add these to every design's [quality attributes](templates/quality-attribute-requirements.md), as testable statements:

- Every service has SLOs for availability and latency, with burn-rate alerts
- Every alert links to a runbook
- A deployment can be correlated with changes in metrics (deploy markers or annotations)
- Logs, metrics, and traces for a request can be linked by a trace ID
- The service exposes health endpoints that distinguish "running" from "ready to serve"
- A new on-call engineer can diagnose the top three failure modes from the dashboards

## The telemetry pipeline

| Decision | Considerations | Default |
|---|---|---|
| **Instrumentation standard** | Vendor SDKs tie you to a backend; OpenTelemetry doesn't | OpenTelemetry for traces, metrics, and logs, with semantic conventions for attribute names |
| **Collection** | Apps sending directly to a backend versus through collectors | Collectors (an agent per node or a gateway tier) that batch, redact, sample, and route, so backends can change without touching apps ([lab collector](../devops/observability/local-stack/otel-collector.yaml)) |
| **Backends** | Cloud-native (CloudWatch, Azure Monitor), open source (Prometheus, Loki, Tempo), managed open source, or commercial | Choose by scale, skills, and cost; many estates combine cloud-native for managed services with Prometheus for Kubernetes ([choosing a stack](../devops/observability/README.md#choosing-a-stack)) |
| **Multi-account and multi-region** | Where telemetry is aggregated, and who can see it | A central observability account or workspace, with per-team access; data residency respected |
| **Retention** | Cost against investigation and compliance needs | Defined per signal type: short for high-volume debug data, longer for metrics and audit logs |
| **Sampling** | Full traces are expensive at scale | Keep all errors and slow requests, sample the rest (tail sampling in the collector) |
| **Sensitive data** | Telemetry leaks secrets and personal data easily | Redact at the source and in the collector; never log tokens or personal data |

## Signal ownership

- **Platform signals** (cluster health, node capacity, shared services) belong to the platform team.
- **Service signals** (requests, errors, latency, business events) belong to the team that owns the service, built on platform-provided instrumentation.
- **Shared dashboards and alert rules live in code** ([dashboards as code](../devops/observability/grafana/README.md#dashboards-as-code), [rules with tests](../devops/observability/prometheus/README.md#test-rules-like-code)), versioned and reviewed like everything else.

## SLO design

- **Measure from the user's side:** at the load balancer or API gateway, not CPU on a host.
- **Few SLOs per service,** typically availability and latency, on the paths users care about.
- **Alert on burn rate,** not raw thresholds, so pages mean the budget is genuinely at risk ([SLO alerting](../devops/observability/prometheus/README.md#alert-on-slos-not-on-every-metric)).
- **Dependencies' SLOs constrain yours:** a service can't promise more than its critical dependencies deliver ([composite availability](03-reliability-and-disaster-recovery.md#start-with-the-targets)).
- **Error budgets drive decisions:** when a service has spent its budget, reliability work takes priority over features.

## Incident tooling

Design the response path, not just the detection:

- **Paging:** alerts routed by service ownership and severity to the right rotation
- **Incident coordination:** a standard way to declare an incident, a channel or bridge, roles (commander, communications), and a status page for customers
- **Access during incidents:** on-call engineers can get the access they need quickly, through a pre-approved, audited path (just-in-time elevation, break-glass)
- **Runbooks next to the alerts,** and automation for common remediations where safe
- **Reviews and follow-through:** a blameless review process and a way to track actions to completion ([incident review template](../manager/templates/incident-review.md))

## Review questions

- How would on-call know this service is unhealthy before a customer does?
- Can a single user's request be followed across every service it touches?
- What does the telemetry cost per month, and what drives it?
- Could sensitive data end up in logs or traces? What stops it?
- Where are the dashboards and alert rules defined, and who reviews changes to them?
- If the observability backend itself is down, how would we know, and what still works?
