# Structuring platform teams

[← Manager](README.md)

How teams are drawn shapes what gets built: who owns what, how work flows between teams, and how much each team has to keep in its head. This guide covers sizing and ownership, treating the platform as a product, and the team types and interaction modes from Team Topologies, the most widely used model for this.

## Size and ownership

- **Small teams:** roughly five to nine people. Smaller, and on-call and absences overwhelm the team; larger, and communication overhead grows until the team splits informally anyway.
- **Clear ownership of each thing:** every service, pipeline, cluster, and account has exactly one owning team. Shared ownership usually means nobody owns it ([system inventory](../tech-lead/templates/system-inventory.csv)).
- **Ownership includes operating it:** the team that builds a platform component is on call for it. Separate "build" and "run" teams tend to produce systems that are hard to run.
- **Manage cognitive load:** a team can only understand and safely change so many systems. If a team owns more than it can learn, it will either move slowly or make mistakes. When that happens, reduce what it owns, simplify it, or split the team.

## The platform as a product

A platform team's customers are other engineering teams. Treating the platform as a product, with users, a roadmap, and measures of whether it helps, is the difference between a platform teams choose and one they route around. The [CNCF platforms white paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) describes this model in detail.

| Product habit | On a platform team |
|---|---|
| Know your users | Regular conversations with application teams: what slows them down, what they work around |
| Solve their problems, not yours | Prioritize what saves application teams the most time or risk, not what's most interesting to build |
| Make the right way the easy way | Golden paths: templates, defaults, and self-service that are faster than doing it alone, with security and observability built in |
| Document it | Getting-started guides, reference docs, and examples, maintained like code |
| Measure adoption and satisfaction | Which teams use what, how long onboarding takes, a short survey each quarter |
| Have a roadmap and say no | A public plan, with the reasons for what's not on it |

A platform that's mandatory but worse than the alternatives creates resentment and shadow infrastructure. A platform that's genuinely easier gets adopted without mandates.

## Team types and interactions

[Team Topologies](https://teamtopologies.com/) (Skelton and Pais) describes four team types, each with a different purpose:

| Type | Purpose | Example in this repository's world |
|---|---|---|
| **Stream-aligned** | Delivers a product or service end to end for customers; most teams should be this type | The orders product team |
| **Platform** | Provides internal services that reduce the load on stream-aligned teams | The team that runs Kubernetes, CI/CD templates, and the observability stack |
| **Enabling** | Helps other teams learn a capability, then moves on | A small SRE or DevSecOps group that coaches teams on SLOs or supply-chain security |
| **Complicated subsystem** | Owns a part that needs deep specialist knowledge | A team owning a search engine or a pricing engine |

And three ways teams interact:

| Mode | Means | Use when |
|---|---|---|
| **Collaboration** | Working closely together for a period | Discovering something new together, such as designing a new platform capability with its first users. Expensive; keep it time-boxed. |
| **X-as-a-service** | One team consumes another's service through a clear interface, with little coordination | The normal mode between a platform and its users, once a capability is stable |
| **Facilitating** | One team helps another learn | An enabling team coaching a stream-aligned team |

Most friction between platform and application teams comes from an unclear or mismatched interaction mode: a platform team that expects to be consumed as a service while its users need collaboration, or the reverse. Name the mode for each relationship, and change it on purpose as a capability matures.

## Signs the structure needs to change

| Symptom | Possible cause | Response |
|---|---|---|
| Every change needs several teams to coordinate | Boundaries don't match how work flows | Redraw ownership around the flow of change |
| The platform team is a ticket queue that never empties | Platform consumed through tickets, not self-service | Invest in self-service; measure requests that could be automated |
| Application teams build their own infrastructure around the platform | The platform is harder to use than the alternative | Talk to them; fix the golden path |
| One team owns far more than it can understand | Cognitive load too high | Reduce scope, simplify, or split |
| On-call is unbearable for one team | Too much owned, too few people, or noisy systems | See [On-call and team health](04-on-call-and-team-health.md) |
| Specialists (security, SRE) are a bottleneck for every team | Specialists doing work for teams instead of enabling them | Shift to an enabling model: coach, provide tooling and guardrails |

## Changing team structure

Reorganizations are disruptive, so change structure deliberately and not often:

- **Start from the problem** (the symptoms above), not from an org chart you prefer.
- **Talk to the people affected** before deciding, and explain the reasons when announcing.
- **Move ownership explicitly:** every system, on-call rotation, budget line, and stakeholder relationship goes somewhere, written down. Things dropped in a reorganization surface later as incidents.
- **Expect a dip** in delivery while new teams form, and plan for it.
- **Review after a quarter:** did the symptoms improve?
