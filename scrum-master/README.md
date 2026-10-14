# Scrum master

[← DevOps and Platforming Groundwork](../README.md)

For scrum masters, agile coaches, and delivery leads working with DevOps, platform, and SRE teams. New to the team? Start with [your first 90 days](00-first-90-days.md), the scrum master's counterpart to the [tech lead checklist](../tech-lead/README.md).

Scrum was designed for teams building a product in planned increments. Platform and operations teams also carry interrupts, on-call, incidents, and toil, and their customers are other engineers. Applied by the book, Scrum fights that reality: sprints get blown up by incidents, and velocity becomes a number to defend. These guides keep what Scrum is for (a goal, a rhythm, transparency, and inspecting and adapting) and adapt the rest to how operations work arrives.

| Guide | Covers |
|---|---|
| [Your first 90 days as a scrum master](00-first-90-days.md) | A W1/30/60/90 checklist: meet the team, observe the events, map how work really arrives, find the impediments, and agree what to change |
| [Scrum for platform teams](01-scrum-for-platform-teams.md) | The Scrum framework in brief, where it fits and fails for operations work, handling interrupts, and when Kanban or a hybrid is better |
| [Running the events](02-running-the-events.md) | Sprint planning, the daily scrum, refinement, the sprint review, and the retrospective: purpose, facilitation, and what goes wrong |
| [Flow and metrics](03-flow-and-metrics.md) | Throughput, cycle time, work item age, and WIP; why velocity misleads; forecasting without estimates; tracking unplanned work |
| [Impediments and team health](04-impediments-and-team-health.md) | Finding and removing impediments, escalating, working agreements, psychological safety, and conflict |
| [Working across teams and coaching](05-working-across-teams.md) | Dependencies between teams, scaling, and the coaching stances, plus how the scrum master works with the product owner, manager, and tech lead |

## Templates

[templates/](templates/README.md): sprint planning, retrospective formats, a working agreement, a definition of done for infrastructure and platform work, an impediment log, and a team health check.

## Who does what

The roles around a team overlap. A useful split, to agree locally:

| Role | Owns | Folder |
|---|---|---|
| Product owner | What the team works on and why: the product goal and the order of the backlog | [product-owner/](../product-owner/README.md) |
| Scrum master | How the team works: the process, its effectiveness, and removing what's in its way | Here |
| Engineering manager | The people: hiring, growth, performance, and staffing | [manager/](../manager/README.md) |
| Tech lead | The technical direction: architecture, quality, and technical risk | [tech-lead/](../tech-lead/README.md) |

On small teams one person often holds two of these. The combination to avoid is scrum master and manager: people stop raising problems in retrospectives with the person who writes their review.

> **Status.** Starter content: practitioner defaults, with the [Scrum Guide](https://scrumguides.org/scrum-guide.html) (November 2020) and the [Kanban Guide](https://kanbanguides.org/english/) (May 2025) as the primary sources for the frameworks.
