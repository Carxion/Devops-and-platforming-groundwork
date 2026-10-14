# Architect

[← DevOps and Platforming Groundwork](../README.md)

For DevOps, platform, and cloud architects: the people who design the foundations that every team builds on, and who own the decisions that are expensive to reverse. The [tech lead](../tech-lead/README.md) runs a program and the [manager](../manager/README.md) runs a team; the architect shapes the structure both of them work within, across teams and over years.

These guides are organized as **considerations**: what to think about, the questions that expose weak designs, the trade-offs, and sensible defaults. Each links to tested implementations in [devops/](../devops/README.md), so a principle here can be compared with working code there.

| Guide | Covers |
|---|---|
| [Thinking like an architect](01-thinking-like-an-architect.md) | The role, quality attributes, trade-offs, reversible and irreversible decisions, constraints, fitness functions, and the Well-Architected frameworks |
| [Cloud foundations and landing zones](02-cloud-foundations.md) | Account and subscription structure, identity, network topology, guardrails, environments, and shared services |
| [Reliability and disaster recovery](03-reliability-and-disaster-recovery.md) | Availability targets, failure domains, redundancy, recovery objectives, disaster recovery strategies, and limiting blast radius |
| [Security architecture](04-security-architecture.md) | Zero trust, identity as the perimeter, segmentation, secrets and encryption, supply chain, audit, and threat modeling |
| [Delivery and infrastructure-as-code architecture](05-delivery-architecture.md) | Pipeline design, environment promotion, GitOps, IaC structure and state boundaries, policy as code, and golden paths |
| [Observability and operations architecture](06-observability-and-operations.md) | Telemetry pipelines, signal ownership, SLO design, incident tooling, and operability as a design requirement |
| [Cost architecture](07-cost-architecture.md) | Designing for cost: unit economics, scaling models, data transfer, commitments, and cost visibility |
| [Portability, hybrid, and multi-cloud](08-portability-and-multi-cloud.md) | When multi-cloud is worth it, levels of portability, lock-in as a trade-off, hybrid connectivity, and exit plans |

## Templates

| Template | Use |
|---|---|
| [architecture-review-checklist.md](templates/architecture-review-checklist.md) | A consideration-by-consideration checklist for reviewing a design before it's built |
| [decision-matrix.md](templates/decision-matrix.md) | A weighted comparison of options against agreed criteria, to make trade-offs explicit |
| [quality-attribute-requirements.md](templates/quality-attribute-requirements.md) | Measurable non-functional requirements (availability, latency, recovery, security, cost) as testable scenarios |

Architects also use the tech lead's [RFC](../tech-lead/templates/rfc-design-doc.md) and [ADR](../tech-lead/templates/adr-template.md) templates, and the [design review guide](../tech-lead/design-reviews-and-rfcs.md) describes how to run reviews.

## The ten questions to ask of any platform design

A short version of the whole folder, for when there's no time for the rest:

1. **What are the quality attributes,** in numbers? Availability, latency, recovery time and data loss, throughput, cost ceiling. ([Thinking like an architect](01-thinking-like-an-architect.md))
2. **What fails, and what happens then?** Each dependency, zone, and region. ([Reliability](03-reliability-and-disaster-recovery.md))
3. **What can each identity do,** and is that the least it needs? ([Security](04-security-architecture.md))
4. **Where are the trust and network boundaries,** and what crosses them? ([Security](04-security-architecture.md))
5. **How does a change reach production,** and how does it roll back? ([Delivery](05-delivery-architecture.md))
6. **How will we know it's healthy,** from the user's point of view? ([Observability](06-observability-and-operations.md))
7. **What does it cost now, and at ten times the load?** ([Cost](07-cost-architecture.md))
8. **Which decisions are hard to reverse,** and are they getting the most scrutiny? ([Thinking like an architect](01-thinking-like-an-architect.md))
9. **Who owns it, operates it, and pays for it,** in two years? ([Cloud foundations](02-cloud-foundations.md))
10. **What's the simplest design that meets the requirements?** Every component added is one more to secure, run, upgrade, and pay for.
