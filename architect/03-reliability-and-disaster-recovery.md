# Reliability and disaster recovery

[← Architect](README.md)

Everything fails eventually: instances, zones, regions, dependencies, deployments, and people. Reliability architecture decides which failures the system survives automatically, which it recovers from with effort, and which it accepts, at a cost the business has agreed to.

## Start with the targets

Before designing redundancy, agree the numbers, per service, with the people who own the outcome:

| Target | Means | Example |
|---|---|---|
| **Availability (SLO)** | Share of requests or time the service works, over a window | 99.9% over 30 days (about 43 minutes of budget) |
| **RTO** (recovery time objective) | How long recovery from a disaster may take | 1 hour |
| **RPO** (recovery point objective) | How much data, measured in time, may be lost | 5 minutes |

**Tier services** rather than giving everything the highest target: a small number of critical services (orders, payments, authentication) justify expensive resilience; internal tools usually don't. Each tier gets a target and a matching standard design. Write targets as [quality attributes](templates/quality-attribute-requirements.md).

**Composite availability:** a service that depends on others in series can't be more available than their product. Three dependencies at 99.9% each give at most about 99.7%. Either the dependencies must be more available than the service, or the service must degrade gracefully without them.

## Failure domains

Design for each level of failure explicitly:

| Failure | Typical design response |
|---|---|
| Instance or container | Several instances behind a load balancer; health checks; automatic replacement (auto scaling, Kubernetes) |
| Availability zone | Spread across at least two zones (three where quorum matters); zone-redundant managed services ([the Terraform stacks](../devops/terraform/README.md) do this) |
| Region | A disaster recovery strategy (below), chosen by RTO and RPO |
| Dependency (database, third-party API) | Timeouts, retries with backoff, circuit breakers, caches, graceful degradation |
| Bad deployment | Progressive delivery (canary, blue-green), automated rollback on SLO burn ([Delivery](05-delivery-architecture.md)) |
| Bad configuration or human error | Changes through code and review, guardrails, staged rollouts of configuration as well as code |
| Account or credential compromise | Separate accounts, immutable backups in another account, break-glass access |

Most outages come from changes (deployments and configuration), not hardware. Safe change mechanisms often buy more availability than extra redundancy.

## Disaster recovery strategies

The standard strategies, from cheapest and slowest to most expensive and fastest (as described in the [AWS disaster recovery whitepaper](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html); the same patterns apply on Azure):

| Strategy | In the recovery region | Typical RTO / RPO | Cost |
|---|---|---|---|
| **Backup and restore** | Backups only; rebuild everything from code after a disaster | Hours to a day / hours | Lowest |
| **Pilot light** | Data replicated; core infrastructure defined but mostly off | Tens of minutes to hours / minutes | Low |
| **Warm standby** | A scaled-down, running copy of the full system | Minutes / seconds to minutes | Medium |
| **Active-active (multi-site)** | Full capacity serving traffic in several regions | Near zero / near zero | Highest, plus the hardest data consistency problems |

Choose by the agreed RTO and RPO, per tier. Whatever the strategy:

- **Infrastructure as code** is a precondition: you can't rebuild quickly what was built by hand.
- **Backups are immutable and in another account** (and often another region), so a compromised or deleted account doesn't take the backups with it.
- **Restores are tested,** on a schedule, with timings recorded. An untested backup is a hope, not a plan. (The [worked example](../tech-lead/worked-example.md) finds exactly this.)
- **Failover is rehearsed,** including failing back. Game days that fail over a real service in a planned window are the only way to know the RTO is real.
- **Dependencies are included:** DNS, identity, secrets, CI/CD, and third-party services the recovery itself needs.

## Limiting blast radius

Even with redundancy, design so that any single failure affects as little as possible:

- **Cells or shards:** split users or tenants across independent copies of the stack, so a failure (or a bad deploy) hits one cell, not everyone.
- **Bulkheads:** separate resource pools per dependency or customer class, so one overloaded part can't starve the rest.
- **Rate limits and load shedding:** reject excess load cleanly at the edge rather than collapsing under it.
- **Progressive rollout by cell or region:** deploy to a small cell first, then the rest.
- **Static stability:** systems that keep working, in a degraded but safe mode, when their control plane or a dependency is unavailable (for example, keeping the last known configuration rather than failing closed).

## Data

- **Choose replication by RPO:** synchronous replication (no data loss, added latency, usually within a region) or asynchronous (some data loss, cross-region).
- **Consistency trade-offs:** multi-region writes require either conflict handling or a single write region. Most systems should keep one write region and fail over, rather than attempt active-active writes.
- **Point-in-time recovery** for databases, to recover from corruption and mistakes, not just outages ([storage and data guides](../devops/aws/guides/storage-and-data.md)).
- **Logical backups** (exports) in addition to snapshots, for recovering individual records and moving between versions.

## Review questions

- What are the SLO, RTO, and RPO, and who agreed them?
- What happens if each dependency is slow? Down? Returning errors?
- Which components are in only one zone? Only one region?
- When was a restore last tested, and how long did it take?
- Could a compromised production account delete the backups?
- What's the blast radius of a bad deployment, and of a bad configuration change?
- How does the system behave at twice its peak load? Where does it break first?
