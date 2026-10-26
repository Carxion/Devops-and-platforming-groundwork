# Solution design: <engagement or problem name>

**Author:** <solutions architect> | **Reviewers:** <architect, delivery lead, security> | **Status:** <draft / in review / agreed> | **Version:** <n> | **Date:** <date>

## 1. Summary

Three to five sentences: the problem, the recommended solution, the outcome, and the cost and timeline.

## 2. Business context

- **Problem:** <in the customer's words, with numbers from discovery>
- **Why now:** <the driver and any deadline>
- **Success criteria:**

| Measure | Today | Target | By | How measured |
|---|---|---|---|---|
| <e.g. Time from code complete to production> | <19 days> | <under 1 day> | <date> | <pipeline events> |

## 3. Requirements

### Driving requirements

The three to five requirements and constraints that shape the design most. Every option is tested against these.

1. <e.g. Recover within 1 hour, with no more than 5 minutes of data loss>
2. <e.g. Customer data stays in the EU>
3. <e.g. Live before the seasonal peak on <date>>

### Functional requirements

| ID | Requirement | Priority (must / should / could) | Source |
|---|---|---|---|
| F1 | <requirement> | <must> | <discovery session, date> |

### Quality attributes

| ID | Attribute | Requirement (measurable) | Reason |
|---|---|---|---|
| Q1 | <Availability> | <99.9% per month, measured at the load balancer> | <cost of downtime> |

See the architect's [quality attribute requirements template](../../architect/templates/quality-attribute-requirements.md) for writing these as testable scenarios.

### Constraints

- <e.g. Must run on the customer's approved cloud and landing zone>
- <e.g. Operations team skills: Windows and SQL Server; no Kubernetes experience>

## 4. Current state

<Context diagram of today's systems, with labeled arrows.>

What works, what doesn't, and the main pain points, with evidence.

## 5. Options

### Option A: <name>

- **Summary:** <what it is>
- **Meets the driving requirements:** <yes / partly / no, for each>
- **Build cost and time:** <range>
- **Running cost:** <range per year, main drivers>
- **Strengths:** <…>
- **Weaknesses and risks:** <…>
- **Commits the customer to:** <contracts, skills, hard-to-reverse decisions>

### Option B: <name>

<Same headings.>

### Option C: <name, or "Do the minimum">

<Same headings.>

### Comparison

| Criterion (weight) | Option A | Option B | Option C |
|---|---|---|---|
| <Driving requirement 1 (30%)> | | | |
| <Running cost (20%)> | | | |
| <Time to deliver (20%)> | | | |
| <Operability with current skills (15%)> | | | |
| <Reversibility (15%)> | | | |

Agree the criteria and weights with the customer before scoring. See the [decision matrix template](../../architect/templates/decision-matrix.md).

## 6. Recommendation

The recommended option, and why it's the best fit for this customer's requirements and constraints, in a paragraph.

## 7. Recommended solution

### Context

<Context diagram: the solution as one box, its users, and the systems it connects to.>

### Containers

<Container diagram: the main deployable pieces, data stores, and how they communicate, with labeled arrows.>

### Key design decisions

| Decision | Choice | Alternatives considered | Reason | ADR |
|---|---|---|---|---|
| <e.g. Database> | <managed PostgreSQL> | <self-run on VMs; current SQL Server> | <…> | <link> |

### How it meets the quality attributes

| Attribute | How |
|---|---|
| Availability and recovery | <zones, replicas, backups, failover, tested how> |
| Security | <identity, network boundaries, encryption, logging> |
| Performance and scale | <scaling model, tested limits> |
| Operability | <monitoring, alerting, runbooks, who's on call> |
| Cost | <main cost drivers and how they're controlled> |

### Migration and transition

How to get from the current state to the new one: phases, data migration, coexistence, cutover, and rollback. See the tech lead's [migrations and cutovers guide](../../tech-lead/migrations-and-cutovers.md).

## 8. Cost

| | One-time | Per year |
|---|---|---|
| Build or migration effort | <range> | |
| Cloud consumption | | <range, at expected load> |
| Licenses and support | <…> | <…> |
| People to run it | | <…> |
| Contingency (tied to risks in section 9) | <…> | |
| **Total** | <range> | <range> |

Assumptions behind the cost: <load, growth, rates, discounts>.

## 9. Risks, assumptions, issues, and dependencies

| Type | Description | Owner | Likelihood / impact | Plan |
|---|---|---|---|---|
| Risk | <…> | <…> | <M / H> | <…> |
| Assumption | <…> | <who confirmed it> | | <how and when it's checked> |
| Dependency | <…> | <…> | | <…> |

## 10. Open questions

| Question | Owner | Needed by |
|---|---|---|
| <…> | <…> | <date> |

## 11. Review record

| Reviewer | Role | Date | Outcome |
|---|---|---|---|
| <…> | <architect / delivery lead / security> | <date> | <approved / changes requested> |
