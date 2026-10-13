# Stakeholders and communication

[← Manager](README.md)

A platform team's stakeholders are mostly other engineering teams, plus security, finance, and leadership. They judge the team on what they can see: how fast requests get done, how often the platform breaks, and whether they hear about problems from the team or discover them themselves.

## Know who they are

Map them once and keep it current: who depends on the platform, who funds it, who can block it, and what each needs from you. The [stakeholder map template](../tech-lead/templates/stakeholder-map.csv) and [section 1 of the tech lead checklist](../tech-lead/README.md#1-stakeholders-and-management) cover this in detail.

## Status updates

A short written update, on a fixed day, does more than any meeting:

- **Lead with what changed** and what needs attention: decisions needed, risks, slips. Readers stop at the first paragraph.
- **The same format every time,** so readers know where to look. The [weekly status template](../tech-lead/templates/weekly-status.md) is a starting point.
- **Bad news early.** A risk reported three weeks before a deadline is a planning conversation; reported the day before, it's a crisis and a trust problem.
- **Short.** If it takes more than two minutes to read, cut it.

## Decisions

- **Write proposals down** before big decisions, with the options considered and why one was chosen. An [ADR](../tech-lead/templates/adr-template.md) works for technical decisions; a one-page memo for the rest.
- **Name the decider.** Many stalled decisions are stalled because nobody knows who decides. A RACI chart (see the [glossary](../GLOSSARY.md#delivery-teams-and-governance)) makes it explicit.
- **Disagree, then commit:** argue fully before the decision, then support it fully after.

## Saying no, and escalating

A platform team gets more requests than it can do. Make the trade-offs visible rather than quietly overcommitting:

- "We can do this, and it means X moves to next quarter. Which do you prefer?"
- Publish how to request work, how requests are prioritized, and what's in the queue.
- **Escalate early and factually** when something needs a decision above you: the situation, the options, their costs, and your recommendation. Escalating is part of the job, not a failure.

## Make the platform's value visible

Platform and operations work is invisible when it goes well. Make the results visible, in the stakeholders' terms:

| Instead of | Say |
|---|---|
| "We upgraded the clusters" | "Every service is on a supported Kubernetes version; nobody needs to schedule their own upgrade this year" |
| "We built a new pipeline template" | "New services go from repository to production in a day instead of two weeks" |
| "We tuned alerting" | "Pages dropped from 40 a week to 6, and none of last month's incidents were found by customers first" |
| "We patched a CVE" | "We fixed a critical vulnerability across 300 services within 48 hours of disclosure" |

The [DORA metrics and SLOs](03-planning-and-metrics.md#measuring-delivery-the-dora-metrics), cost trends, and incident counts give the numbers. Report them regularly, not only when asking for something.

## Managing up

- Know what your manager is measured on, and how your team's work helps.
- Bring problems with options and a recommendation, not just the problem.
- Ask how they prefer to be updated, and how often, and stick to it.
- Make sure they hear about significant risks and incidents from you, first.
