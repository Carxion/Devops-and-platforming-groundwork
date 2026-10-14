# Cost architecture

[← Architect](README.md)

In the cloud, architecture decisions are spending decisions: the choice of compute model, data store, region layout, and replication strategy sets most of the bill before anyone tunes anything. Cost is a quality attribute like latency or availability, with a target, and it's cheapest to get right in the design.

For running costs day to day (tagging, budgets, cleanup), see the manager's [budget guide](../manager/08-budget-vendors-and-contracts.md#cloud-cost) and the [AWS](../devops/aws/guides/cost.md) and [Azure](../devops/azure/guides/cost.md) cost guides.

## Design for unit cost

Total spend grows with the business; what matters is **unit cost**, the cost per unit of value: per customer, per order, per thousand requests, per tenant. Define the unit for each major workload, design to a target for it, and track it over time.

- **Rising total, flat or falling unit cost:** healthy growth.
- **Rising unit cost:** waste, a design that doesn't scale economically, or a pricing change. Investigate.

Unit cost also makes trade-offs concrete: "multi-region active-active would roughly double cost per order, to buy an RTO improvement from one hour to near zero. Is that worth it for this tier?"

## The big levers

| Decision | Cost considerations |
|---|---|
| **Compute model** | Always-on VMs or nodes suit steady load; containers on shared clusters raise utilization; serverless suits spiky or low traffic but can cost more at sustained high volume. Model costs at today's and projected load before choosing. |
| **Instance and processor type** | ARM-based instances (AWS Graviton, Azure Cobalt and Ampere) often cost less for the same work; newer generations usually give more per unit cost |
| **Managed versus self-run** | Managed services cost more per unit of resource but less in people's time; include engineering time in the comparison |
| **Data transfer** | Often the most surprising line: traffic between zones and regions, out to the internet, and through NAT gateways is charged. Keep chatty services in one zone where resilience allows, use private endpoints, and cache at the edge. |
| **Storage** | Choose tiers by access pattern, with lifecycle rules to move or delete old data; retention set by requirement, not by default |
| **Redundancy** | Each extra zone, region, and replica multiplies cost. Match it to the agreed tier ([Reliability](03-reliability-and-disaster-recovery.md)), not to "maximum" |
| **Observability** | Log and metric volume, cardinality, and retention can rival compute costs ([observability cost](../devops/observability/README.md#cost-and-cardinality)) |
| **Environments** | Non-production running 24/7 at production size is a common waste; scale down, schedule off-hours shutdown, or use ephemeral environments |
| **Licensing** | Bring-your-own-license options, per-core licensing on large instances, and commercial tools priced per host or per GB |

## Commitments

Savings plans, reservations, and committed-use discounts lower the price of steady usage substantially, in exchange for a one- or three-year commitment.

- **Commit only after removing waste,** or you lock in paying for it.
- **Commit to the stable baseline,** and leave the variable part on demand or spot.
- **Prefer flexible commitments** (compute savings plans over specific instance reservations) when the architecture may change.
- **Coordinate with finance,** since commitments are financial decisions with accounting implications.

## Spot and preemptible capacity

Spare capacity at large discounts, reclaimable at short notice. Suitable for interruptible work: batch jobs, CI runners, stateless workers, and Kubernetes node pools for fault-tolerant workloads. Design for interruption (checkpointing, graceful shutdown, mixed capacity pools) before relying on it.

## Make cost visible in the architecture

- **Tagging and account structure** that attribute every cost to an owner and workload ([Cloud foundations](02-cloud-foundations.md#tagging-and-naming))
- **Cost estimates in design reviews:** the [RFC template](../tech-lead/templates/rfc-design-doc.md) has a cost section; require it for significant designs, at current and ten-times load
- **Budgets and anomaly alerts** per account or workload ([budget templates](../devops/aws/cloudformation/cost/budget.yaml))
- **Cost in the pipeline:** tools that estimate the cost change of an infrastructure pull request make cost visible at the moment it's decided

## Sustainability

Cloud carbon footprint follows resource use, so most cost efficiency is also carbon efficiency: higher utilization, right-sizing, efficient instance types, less data stored and moved. Region choice matters too, since grids differ in carbon intensity. Both providers publish emissions data for their customers and include sustainability in their Well-Architected guidance ([Thinking like an architect](01-thinking-like-an-architect.md#use-the-well-architected-frameworks)).

## Review questions

- What does this cost per month at today's load, and at ten times? What's the unit cost?
- What's the most expensive component, and is it the one that delivers the most value?
- How much data crosses zones, regions, or the internet, and at what price?
- What runs 24/7 that doesn't need to?
- How will we know if costs start rising faster than usage?
- Is the redundancy matched to the service's tier, or to "as much as possible"?
