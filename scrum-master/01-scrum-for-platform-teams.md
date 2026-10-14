# Scrum for platform teams

[← Scrum master](README.md)

Scrum is a lightweight framework for teams solving complex problems in short cycles: set a goal, build toward it, inspect the result, adapt. This guide covers the framework in brief, then how to apply it to teams whose work is part planned and part interrupt-driven.

## The framework in brief

The [Scrum Guide](https://scrumguides.org/scrum-guide.html) (November 2020) is short and is the definition. In summary:

| Element | What it is |
|---|---|
| **Scrum Team** | One team, typically 10 or fewer people, with three accountabilities: the **Developers** (everyone doing the work), one **Product Owner**, and one **Scrum Master** |
| **Sprint** | A fixed-length cycle of one month or less, in which the team turns ideas into a usable increment. A new sprint starts as soon as the last ends |
| **Sprint Planning** | Decide why this sprint is valuable (the Sprint Goal), what can be done, and how. At most 8 hours for a one-month sprint, less for shorter sprints |
| **Daily Scrum** | 15 minutes for the Developers to inspect progress toward the Sprint Goal and adapt the plan for the next day |
| **Sprint Review** | Inspect the outcome with stakeholders and decide what to do next. At most 4 hours for a one-month sprint |
| **Sprint Retrospective** | Inspect how the team worked, and plan improvements. At most 3 hours for a one-month sprint |
| **Product Backlog**, committed to a **Product Goal** | The ordered list of what's needed to improve the product, toward one longer-term objective |
| **Sprint Backlog**, committed to a **Sprint Goal** | The Sprint Goal, the items chosen for it, and the plan to deliver them |
| **Increment**, committed to the **Definition of Done** | Each usable step toward the Product Goal; work is only part of an increment when it meets the Definition of Done |

Refinement (breaking backlog items down and adding detail) is an ongoing activity, not a formal event. The Scrum Master is accountable for the team's effectiveness; the guide calls them "true leaders who serve the Scrum Team and the larger organization."

What the framework is *for* matters more than its parts: **transparency** (everyone can see the work and its state), **inspection** (look at results often), and **adaptation** (change course when they're off). An adaptation that keeps those three is in the spirit of Scrum; a ritual that hides reality isn't, however faithfully it follows the guide.

## Where Scrum fits a platform team, and where it doesn't

| Work | Fits Scrum? | Why |
|---|---|---|
| Building platform capabilities: a new deployment pipeline, a self-service database, a Kubernetes upgrade program | Well | Planned, valuable in increments, benefits from a goal and stakeholder feedback |
| Migrations and modernization | Well | Long efforts that need visible progress and regular course correction |
| Incidents and on-call | No | Can't wait for planning; must be handled immediately |
| Requests from other teams (access, environments, config changes) | Partly | Small and frequent; some are urgent, many can wait a few days |
| Toil (repetitive manual operations) | Partly | Should shrink over time, which is itself planned work |

Most platform teams have all of these. The question isn't whether to "do Scrum," but how to give the planned work a goal and a rhythm without pretending the unplanned work doesn't exist.

## Handling interrupts

Pick one approach, make it explicit, and measure it:

- **Reserve capacity.** Plan the sprint to, say, 60 to 70% of the team's capacity, and leave the rest for interrupts. Set the reserve from data (how much unplanned work arrived in recent sprints), not hope. If the reserve isn't used, pull in more planned work.
- **Rotate an interrupt handler.** One person per sprint or week (often the on-call engineer) takes all incoming requests and incidents, shielding the rest of the team. They aren't counted toward planned work. Rotate it so nobody becomes the permanent help desk.
- **Separate the flows.** Track interrupt work on the same board, in its own lane, so it's visible and measurable. Hidden work can't be reduced.

And in every case:

- **Count it.** Track how much unplanned work arrived each sprint and what kind. Bring the numbers to the retrospective and the product owner. The biggest sources are usually fixable: missing self-service, flaky systems, unclear documentation. Fixing them is product backlog work.
- **Protect the Sprint Goal, not the plan.** The Sprint Goal is the commitment; the items are a forecast. When an incident takes two days, the team adjusts the plan (with the product owner) to still meet the goal if it can, and says early if it can't.
- **Cancel only when the goal is obsolete.** The Scrum Guide lets the product owner cancel a sprint if its goal becomes obsolete. A major incident rarely makes the goal obsolete; it makes it late.

## Scrum, Kanban, or both

| | Scrum | Kanban |
|---|---|---|
| Cadence | Fixed sprints with planning, review, and retrospective | Continuous flow; cadences for replenishment and review are chosen by the team |
| Commitment | A Sprint Goal per sprint | Limits on work in progress, and service level expectations ("85% of requests done within 5 days") |
| Change mid-cycle | Possible, but the plan was made for the sprint | Normal: new work enters when capacity frees up |
| Core measures | Whatever helps (the guide doesn't prescribe metrics) | WIP, throughput, work item age, cycle time ([Kanban Guide](https://kanbanguides.org/english/)) |
| Best for | Planned product work with stakeholder feedback | Request and operations work that arrives continuously |

Many platform teams do well with **both**: Scrum's goal, review, and retrospective for the planned work, and Kanban's WIP limits and flow measures for everything. The Scrum Guide doesn't forbid any of Kanban's practices, and the Kanban Guide is written to be used alongside other frameworks.

Consider pure Kanban when most work is requests and operations, when sprint goals are routinely missed because of interrupts despite reserving capacity, or when the team is a service team (an SRE team serving many product teams, a help desk for the platform).

## Sprint length

Two weeks is a common choice. Shorter sprints give faster feedback and smaller plans to blow up; longer sprints suit work that needs longer to show a usable result. For platform teams with heavy interrupts, one week is often better than two: less to replan when an incident hits, and a goal that's still relevant at the end. Change the length rarely, and only after discussing it in a retrospective.

## Next

[Running the events](02-running-the-events.md).
