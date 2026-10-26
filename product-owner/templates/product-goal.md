# Product goal: <platform or product name>

**Owner:** <product owner> | **Agreed:** <date> | **Review by:** <date, a few months out>

## Users

Who uses the product, and what are they trying to do? Name groups specific enough to design for.

| User group | What they're trying to do | How many |
|---|---|---|
| <e.g. Product engineers shipping new services> | <e.g. Get a new service to production quickly and safely> | <e.g. 40 teams> |

## Problems

What gets in their way today? Evidence from interviews, data, and support requests.

- <e.g. A new service takes 9 days to reach production, mostly waiting on tickets for a pipeline, DNS, and a database> (<evidence: interviews with 6 teams; request data>)
- <problem> (<evidence>)

## The product goal

One sentence: the outcome for users that the backlog serves for the next few months.

> <e.g. Any team can take a new service to production in under a day, without filing a ticket.>

## How we'll know

| Measure | Baseline | Target | Source |
|---|---|---|---|
| <e.g. Median time from new repository to first production deploy> | <9 days> | <1 day> | <pipeline events> |
| <e.g. New services started from the template> | <35%> | <80%> | <repository data> |
| <a guardrail, e.g. Change fail rate for those services> | <8%> | <stays under 10%> | <deployment data> |

## Out of scope (for this goal)

- <e.g. Migrating existing services to the template>
- <e.g. Windows workloads>

## Risks and assumptions

- <e.g. Assumes security approves pre-approved network patterns; check by <date>>

## Not this goal

Requests that don't serve the goal go to the backlog with this reason, and wait until the goal is met or abandoned.
