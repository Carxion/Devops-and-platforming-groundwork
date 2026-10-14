# Architecture review: <design or system name>

**Design doc:** <link to RFC> · **Reviewer:** <name> · **Date:** YYYY-MM-DD · **Outcome:** Approved / Approved with changes / Needs another review / Not approved

Work through the sections that apply; mark the rest "n/a" with a reason. For each "no" or "unclear", record a finding below. Each section links to the guide that explains it.

## Requirements and trade-offs ([guide](../01-thinking-like-an-architect.md))

- [ ] Quality attributes are stated as measurable targets: availability, latency, RTO, RPO, cost ([template](quality-attribute-requirements.md))
- [ ] The targets are agreed with whoever owns the business outcome
- [ ] Constraints are listed and classified (removable, relocatable, evidence-automatable, fixed)
- [ ] Alternatives, including "do nothing", were considered and the trade-offs stated ([decision matrix](decision-matrix.md))
- [ ] Hard-to-reverse decisions are identified and recorded as ADRs
- [ ] It's the simplest design that meets the requirements

## Foundations ([guide](../02-cloud-foundations.md))

- [ ] It runs in accounts or subscriptions appropriate to its environment and sensitivity
- [ ] IP ranges are allocated from the estate's plan, with no overlaps
- [ ] It fits the existing guardrails, or requested exceptions are documented and approved
- [ ] Required tags and naming conventions are applied

## Reliability ([guide](../03-reliability-and-disaster-recovery.md))

- [ ] Every component survives the loss of one zone, or the exception is accepted for its tier
- [ ] The disaster recovery strategy matches the RTO and RPO
- [ ] Each dependency's failure has a defined behavior: timeout, retry, fallback, or degraded mode
- [ ] Backups are immutable, stored in another account, and restores are tested on a schedule
- [ ] The blast radius of a bad deployment or configuration change is limited
- [ ] Capacity at twice peak load has been considered

## Security ([guide](../04-security-architecture.md))

- [ ] No long-lived credentials: workload identities, OIDC for CI/CD, single sign-on for people
- [ ] Each identity has least privilege, scoped to specific resources
- [ ] Trust boundaries are drawn, and a threat model (STRIDE or similar) was done
- [ ] Nothing is internet-facing except through defined ingress; data services use private access
- [ ] Data is classified; encryption at rest and in transit is in place; secrets are in a secrets manager
- [ ] Artifacts are built in CI, scanned, and (where required) signed and verified at deployment
- [ ] Audit logging and threat detection cover the new components
- [ ] Compliance obligations are identified, and the evidence is produced automatically where possible

## Delivery ([guide](../05-delivery-architecture.md))

- [ ] Everything is defined in code and deployed only through the pipeline
- [ ] The same artifact is promoted through environments
- [ ] Deployments are progressive, with automated rollback
- [ ] Infrastructure state boundaries limit blast radius; state is remote, locked, and encrypted
- [ ] Relevant policies are enforced as code in CI or at admission

## Observability and operations ([guide](../06-observability-and-operations.md))

- [ ] SLOs are defined from the user's perspective, with burn-rate alerts
- [ ] Every alert has a runbook
- [ ] Telemetry uses OpenTelemetry (or the agreed standard), with trace IDs linking signals
- [ ] Sensitive data is kept out of logs and traces
- [ ] The owning team and on-call rotation are named, and they've reviewed the design

## Cost ([guide](../07-cost-architecture.md))

- [ ] Monthly cost is estimated at current and ten-times load, with the unit cost
- [ ] Data transfer between zones, regions, and the internet is estimated
- [ ] Redundancy matches the service's tier
- [ ] Budgets and cost alerts are set up for the new resources

## Portability ([guide](../08-portability-and-multi-cloud.md))

- [ ] Use of provider-specific services is a deliberate choice, with the switching cost understood
- [ ] Data can be exported in a documented format, and the export has been tested
- [ ] Critical vendor dependencies have an exit plan

## Findings

| # | Area | Finding | Severity (blocker / should fix / consider) | Owner | Resolution |
|---|---|---|---|---|---|
| 1 | | | | | |

## Decision

<Approved, approved with the changes above, or not approved, with reasons. Link the ADRs created.>
