# Incident review: <short title>

**Incident ID:** <id> · **Severity:** <1 to 4> · **Date of incident:** YYYY-MM-DD · **Review held:** YYYY-MM-DD · **Author:** <name> · **Status:** Draft / Reviewed / Actions complete

This review is **blameless**: it assumes everyone acted reasonably with the information they had, and asks how the system, tools, and process allowed the failure. It names roles, not individuals. See [incident reviews](../04-on-call-and-team-health.md#incident-reviews).

## Summary

<Three to five sentences: what happened, the impact, the cause, and the most important action.>

## Impact

- **Who was affected:** <customers, internal teams, which services>
- **How:** <errors, slowness, unavailable, data affected>
- **Duration:** <start of impact> to <end of impact> UTC (<total>)
- **Detected by:** <alert / customer report / engineer noticed>, <N> minutes after impact began
- **Measurable effect:** <failed requests, error budget consumed, orders lost, support tickets>

## Timeline

All times UTC.

| Time | Event |
|---|---|
| HH:MM | <change, trigger, or first sign> |
| HH:MM | <alert fired / report received> |
| HH:MM | <acknowledged; first actions> |
| HH:MM | <key decisions and what informed them> |
| HH:MM | <mitigated> |
| HH:MM | <resolved> |

## Contributing factors

Usually several, technical and organizational. Ask "how did this make sense at the time?" rather than "who did this?".

-
-

## What went well

-

## Where we got lucky

<Things that limited the damage but that we can't count on next time.>

## Actions

Each with an owner and a date, tracked to completion like any other work. Prefer actions that remove a class of problem over ones that only fix this instance.

| Action | Type (prevent / detect / mitigate / process) | Owner | Due | Ticket | Done |
|---|---|---|---|---|---|
| | | | | | [ ] |

## Supporting material

<Links: dashboards, logs, the change that triggered it, chat channel, related incidents.>
