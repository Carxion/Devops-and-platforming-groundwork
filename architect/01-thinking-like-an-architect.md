# Thinking like an architect

[← Architect](README.md)

Architecture is the set of decisions that are expensive to change later. An architect's job is less about drawing diagrams than about making those decisions well: understanding what the system must achieve, finding the options, making the trade-offs explicit, and deciding at the right time with the right people.

## The role

A DevOps or platform architect typically:

- Sets the **technical direction** for the platform: foundations, standards, and the paved paths teams use
- **Owns the hard-to-reverse decisions:** cloud structure, network topology, identity model, data stores, deployment model
- **Reviews designs** across teams for consistency, risk, and fit ([design reviews](../tech-lead/design-reviews-and-rfcs.md))
- **Balances the whole** against each part: a choice that's best for one team can be worst for the platform
- **Writes things down,** so decisions outlive the people who made them

Good architects stay close to the implementation: reading code, reviewing pull requests, and joining incident reviews. Architecture disconnected from how systems actually run produces designs that look right and fail in operation.

## Start from quality attributes

Functional requirements say what a system does; **quality attributes** (non-functional requirements) say how well, and they drive most architectural decisions. The ISO/IEC 25010 product quality model is a common reference list. For platforms, the ones that matter most:

| Attribute | Ask | Example requirement |
|---|---|---|
| Availability | How much downtime is acceptable, and when? | 99.9% of requests succeed, measured monthly |
| Latency and performance | How fast, at what percentile, under what load? | p95 under 300 ms at 500 requests per second |
| Scalability | What grows, how fast, and to what ceiling? | Handles three times today's peak without redesign |
| Recoverability | How much data loss and downtime after a disaster? | RPO 5 minutes, RTO 1 hour |
| Security | What must be protected, from whom? | Customer data encrypted, accessible only to the order service's identity |
| Operability | Can the people running it understand and fix it? | Every alert has a runbook; a new engineer can deploy in their first week |
| Deployability | How often, how safely can it change? | Any team deploys independently, daily, with automated rollback |
| Cost | What's the budget, and how does cost scale? | Under a set amount per thousand orders |
| Compliance | Which obligations apply? | Data stays in one region; audit logs kept for a set period |

**Make them measurable.** "Highly available" can't be designed for or tested; "99.9% of requests succeed over 30 days" can. The [quality-attribute requirements template](templates/quality-attribute-requirements.md) writes them as testable scenarios. Get them agreed with the people who own the business outcome, because they set the cost: each additional nine of availability, or minute off the recovery time, costs more.

## Every decision is a trade-off

There are no best practices without context, only trade-offs. Common ones in platform work:

| More of | Usually costs |
|---|---|
| Availability (more zones, regions, redundancy) | Money, complexity, consistency |
| Consistency (strong, synchronous) | Latency and availability during partitions |
| Security controls | Developer friction, speed, cost |
| Flexibility (generic, configurable) | Simplicity, and the cost of configuring it |
| Standardization | Teams' freedom to choose what fits them |
| Portability (avoiding provider-specific services) | Features, speed, and often cost ([Portability](08-portability-and-multi-cloud.md)) |
| Speed of delivery now | Maintainability later |

State the trade-off explicitly in every significant decision: what you're optimizing for, what you're giving up, and why that's right here. A [decision matrix](templates/decision-matrix.md) helps when there are several options and criteria.

## Reversible and irreversible decisions

Not every decision deserves the same care. Sort them:

| | Reversible (two-way door) | Hard to reverse (one-way door) |
|---|---|---|
| Examples | A library, a CI job's structure, an alert threshold, an instance size | Cloud provider, account structure, network address ranges, identity provider, primary data store, public APIs |
| Approach | Decide quickly, at the lowest level that can, and adjust | Slow down: RFC, review, prototypes, and an explicit decision by the right people |
| Documentation | A pull request description | An [ADR](../tech-lead/templates/adr-template.md), with alternatives and consequences |

Two things make an architect valuable here: noticing when a decision that looks small is actually hard to reverse (an IP address plan, a naming convention baked into hundreds of resources), and **making decisions more reversible** where possible: interfaces between components, feature flags, expand-and-contract migrations, and keeping options open until the information arrives.

**Decide at the last responsible moment:** late enough to have the information, early enough that not deciding doesn't make the decision for you.

## Constraints are inputs

Every real system has constraints that aren't negotiable by the architect: budget, existing contracts, regulations, the skills of the team, the organization's chosen cloud, an approval process. Write them down at the start of a design, and classify them as the [tech lead checklist](../tech-lead/README.md#24-classify-each-problem) does: removable, relocatable, evidence-automatable, or fixed. Designs that ignore a fixed constraint fail at review or in production; designs that treat a removable constraint as fixed miss better options.

**Team skills are a constraint too.** The best design the team can't operate is worse than a simpler one it can.

## Fitness functions: keep the architecture true

An architecture decision is only real if the system keeps conforming to it. **Fitness functions** (from *Building Evolutionary Architectures* by Ford, Parsons, and Kua) are automated checks that a system still has the properties the architecture requires, run continuously, usually in CI:

| Property | Fitness function | In this repository |
|---|---|---|
| No public storage, encryption everywhere | IaC scanning on every pull request | checkov on [Terraform](../devops/terraform/README.md), [CloudFormation and Bicep](../devops/aws/cloudformation/README.md) |
| Containers run non-root, read-only | Policy checks on manifests and images | kubeconform and checkov on [Kubernetes](../devops/kubernetes/README.md); the [Docker audit](../software/containers/docker/scripts/docker-audit.sh) |
| API contract stays compatible | Contract tests against the spec | [Schemathesis and Spectral](../software/api-testing/README.md) |
| SLOs are met | Burn-rate alerts | [SLO rules](../devops/observability/prometheus/rules/web-app-slo.yaml) |
| No known critical vulnerabilities ship | Image scanning gate | Trivy on every image build ([Docker security](../software/containers/docker/08-hardening.md)) |
| Latency budget holds under load | Load test thresholds | [k6 thresholds](../software/api-testing/k6/load.js) |

If a rule matters, automate its check. A standard that relies on reviewers remembering it erodes within months.

## Use the Well-Architected frameworks

Both major clouds publish a framework for reviewing workloads against the same broad pillars: operational excellence, security, reliability, performance efficiency, cost optimization, and sustainability (AWS adds sustainability as a sixth pillar; Azure covers it in its own guidance).

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)

Use them as checklists for reviews and as shared vocabulary with cloud provider teams; both providers offer review tools that walk through the questions. They're broad, not prescriptive: they tell you what to consider, and your quality attributes tell you how much of each you need.

## Communicate the architecture

- **Diagrams at the right level:** a context view for everyone, container views for engineers, and detail only where needed. The [C4 model](https://c4model.com/) is a simple, widely used approach.
- **Decision records** for every significant choice, kept with the code.
- **Principles,** a short list (five to ten) that teams can apply without asking: "managed services before self-run", "every resource in code", "identities over secrets".
- **Reference implementations** that show the principles working, like the stacks in [devops/](../devops/README.md). Teams copy working examples far more readily than they follow documents.
