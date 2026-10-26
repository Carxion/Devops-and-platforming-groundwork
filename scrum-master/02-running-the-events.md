# Running the events

[← Scrum master](README.md)

Each Scrum event exists for one purpose. When an event stops serving it, people stop seeing the point, and the event becomes a meeting to sit through. For each event: what it's for, how to run it, and what goes wrong.

The scrum master doesn't have to run every event. The goal is a team that runs them well on its own; facilitate at first, then hand facilitation to team members.

## Sprint planning

**Purpose:** agree why this sprint is valuable (the Sprint Goal), what can be done toward it, and how.

1. **Start with the goal, not the list.** The product owner proposes the objective that would make this sprint valuable: "Teams can create their own preview environments," not "Do tickets 412, 415, and 420." The team shapes it into the Sprint Goal.
2. **Check capacity honestly.** Who's away, who's on call or handling interrupts, and how much unplanned work arrived in recent sprints ([handling interrupts](01-scrum-for-platform-teams.md#handling-interrupts)).
3. **Pull items toward the goal,** from the top of a refined backlog, until the team is confident about the goal. Not to fill every hour: leave slack.
4. **Plan the first days in detail,** the rest roughly. The plan will change; the goal shouldn't.

The [sprint planning template](templates/sprint-planning.md) covers these steps.

| Goes wrong | Try |
|---|---|
| No Sprint Goal, or "finish these tickets" | Ask the product owner: if only one thing gets done this sprint, what should it be? Build the goal from that |
| Planning takes hours because items aren't understood | Refine before planning: items at the top of the backlog should already be small and clear |
| Every sprint is overcommitted | Plan from what the team actually finished in recent sprints, minus reserved capacity |
| The plan is set by one person | The Developers decide how much they can do. The product owner decides the order, not the amount |

## Daily scrum

**Purpose:** 15 minutes for the Developers to inspect progress toward the Sprint Goal and adapt the plan for the next day.

The Scrum Guide doesn't require the three questions ("yesterday, today, blockers"), and they tend to turn the event into individual status reports. Instead, **walk the board from right to left**: start with the items closest to done, and ask what it would take to finish them. Then look at anything blocked or ageing. That keeps attention on finishing work and on the goal, not on looking busy.

| Goes wrong | Try |
|---|---|
| A status report to the scrum master or manager | Stand back; let the Developers talk to each other. Managers can attend but shouldn't run it |
| Runs long with problem-solving | Note the topic, finish the daily scrum, and let the people involved stay afterwards |
| Nobody mentions the Sprint Goal | Put the goal at the top of the board, and ask "are we still on track for it?" at the end |
| On-call engineer reports on incidents for ten minutes | A one-line summary; details go in the incident channel or review |

## Refinement

**Purpose:** get items ready before they're needed: understood, small enough to finish in a few days, and with acceptance criteria. The Scrum Guide treats it as ongoing work, not an event; many teams hold one or two short sessions a sprint anyway.

- Refine about one to two sprints ahead. Further out, detail goes stale.
- Bring the people who'll do the work, and someone who understands the users.
- Split large items by user-visible slices, not by technical layer: "Teams can create a database in dev" before "Teams can create a database in prod," not "Terraform module" then "pipeline" then "docs." The [product owner's backlog guide](../product-owner/02-backlog-management.md#splitting-work) has patterns.
- Estimate only if estimates help the team decide something. Many teams do better with a simple rule ("nothing bigger than three days") and [throughput forecasting](03-flow-and-metrics.md#forecasting-without-estimates).

## Sprint review

**Purpose:** inspect the outcome of the sprint with stakeholders, and decide together what to do next. It's a working session, not a presentation.

- **Show working changes to the people who use them.** For a platform team, that's other engineers: demo the new pipeline template on a real service, and let them try it.
- **Ask for feedback and use it.** What would make this useful to you? What should we do next? The product owner adjusts the backlog from what they hear.
- **Be honest about what didn't get done** and why, including the interrupt load.
- **Share the numbers that matter to stakeholders:** adoption, how long requests wait, incidents, not velocity.

| Goes wrong | Try |
|---|---|
| Slides and status updates | Ban slides for a sprint. Show the real thing, in the real tool |
| No stakeholders come | Invite the specific people affected by this sprint's work, and keep it short |
| Platform work is invisible ("we upgraded things") | Show the effect: deploy time before and after, a request that used to take a ticket and now takes a command |

## Retrospective

**Purpose:** inspect how the team worked (people, process, tools, the definition of done) and choose improvements to make.

A reliable structure is the five stages from Esther Derby and Diana Larsen's *Agile Retrospectives*:

1. **Set the stage:** a quick check-in, and a reminder of the last retrospective's actions. Were they done? Did they help?
2. **Gather data:** what happened this sprint. Use facts too: the share of unplanned work, cycle time, incidents.
3. **Generate insights:** why did it happen? Look for causes in systems and process, not people.
4. **Decide what to do:** one to three actions, each with an owner and a date. Put them in the next sprint's backlog so they're planned work, not good intentions.
5. **Close:** a quick check of how the retrospective itself went.

Vary the format to keep it fresh; the [retrospective formats](templates/retrospective-formats.md) template has several.

| Goes wrong | Try |
|---|---|
| The same complaints every sprint, nothing changes | Fewer actions, each owned and planned in the backlog. Start the next retrospective by reviewing them |
| People don't speak up | Anonymous input first (sticky notes, a form), smaller groups, and keep the manager out if that's the reason |
| Problems outside the team's control dominate | Escalate them as impediments ([Impediments](04-impediments-and-team-health.md)), report back, and focus the retrospective on what the team can change |
| Blame | Follow the [blameless incident review](../manager/templates/incident-review.md) approach: what about the system made this likely? |

## Next

[Flow and metrics](03-flow-and-metrics.md).
