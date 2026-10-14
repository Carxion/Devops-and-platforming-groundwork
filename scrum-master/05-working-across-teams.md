# Working across teams and coaching

[← Scrum master](README.md)

Platform teams sit in the middle of the organization: other teams depend on them, and they depend on security, networking, and vendors. Much of a scrum master's impact comes from outside the team: dependencies, the wider organization, and coaching the people around the team.

## Dependencies

Every dependency between teams is a queue where work waits. Make them visible, then reduce them.

1. **Map them.** For a few sprints, mark every item that waited on another team, and how long. The map usually shows two or three teams account for most of the waiting.
2. **Talk to the other team's scrum master or lead** with the data. Agree how requests flow between you: a shared board, a request form, a service level expectation.
3. **Plan them together.** For larger work, the teams agree the order before either starts, and meet briefly during the sprint (a few people from each, not everyone).
4. **Remove the dependency** where you can. This is the lasting fix: self-service instead of tickets, a team that owns its own pipeline, or a stable interface so changes don't need coordination. [Structuring platform teams](../manager/07-structuring-platform-teams.md) covers Team Topologies' interaction modes, which describe this shift: from collaboration, to the platform consumed as a service.

## Scaling

When several teams work on one product, they need a shared Product Goal and a way to integrate their work. Frameworks for this include Nexus (from Scrum.org), LeSS (Large-Scale Scrum), and SAFe (Scaled Agile Framework). They differ a lot in how much structure they add.

Before adopting one, try the simplest things:

- **One product owner and one Product Backlog** across the teams working on the same product.
- **A short regular sync** of a representative from each team, focused on dependencies and integration problems (often called a scrum of scrums).
- **A joint sprint review** where stakeholders see the integrated result.
- **Shared definitions of done,** so an increment from one team works with another's.

Add a framework when these aren't enough, and adopt it gradually. A scaling framework can't fix teams that don't work well on their own.

## Coaching stances

A scrum master moves between stances depending on what the team needs:

| Stance | When | Looks like |
|---|---|---|
| **Teaching** | The team is new to a practice | Explaining the purpose of an event; showing how WIP limits work |
| **Facilitating** | The team needs help having a productive conversation | Running a retrospective or a planning session so everyone contributes and it reaches a decision |
| **Coaching** | The team (or a person) can find the answer with good questions | "What would make this item small enough to finish this week?" rather than the answer |
| **Mentoring** | Someone wants to learn from your experience | Sharing how you handled a similar situation |
| **Removing impediments** | Something outside the team blocks it | [Escalating with evidence](04-impediments-and-team-health.md#escalating-well) |

New scrum masters often over-teach and under-coach. If you're answering every question, the team is learning to depend on you.

## Working with the other roles

**Product owner.** You help them with the mechanics: a well-ordered, refined backlog, clear Sprint Goals, a sprint review that produces real feedback. They own the decisions about what and why. When the team is overloaded, you bring the data (unplanned work, cycle time); they decide what gives. See the [product owner guides](../product-owner/README.md).

**Engineering manager.** The manager owns hiring, growth, and performance; you own the process. Share observations about the team's working patterns, not about individuals' performance. If you see a performance or wellbeing problem, raise it with the person first and the manager second. Agree with the manager that they won't use the team's flow metrics to evaluate people.

**Tech lead.** The tech lead owns technical direction. Help them get technical work (debt, upgrades, reliability) into the backlog with a clear reason the product owner can weigh, and help them make technical decisions visible to the team ([design reviews and RFCs](../tech-lead/design-reviews-and-rfcs.md)).

**Leadership.** Leaders often want a status number. Offer outcomes instead: what shipped and what it changed, forecasts with probabilities ([forecasting](03-flow-and-metrics.md#forecasting-without-estimates)), and the impediments only they can remove. A scrum master who only protects the team from leadership becomes a bottleneck; one who translates both ways makes both sides better informed.

## Measuring yourself

You're doing well when the team runs its own events, raises and removes most impediments itself, meets most Sprint Goals despite interrupts, and improves something real every few sprints. Ask the team in your own retrospective: what should I do more of, less of, and stop?

## Next

Back to the [scrum master overview](README.md), or to the [product owner guides](../product-owner/README.md).
