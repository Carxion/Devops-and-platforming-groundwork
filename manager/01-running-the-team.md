# Running the team

[← Manager](README.md)

## One-on-ones

A regular, private conversation with each person you manage. It's their meeting, not a status update: status belongs in the team's tools.

- **Weekly or every two weeks, 30 minutes,** and don't cancel it for routine work. Moving it is fine; skipping it repeatedly tells someone they're the first thing to go.
- **They bring the agenda.** Keep a shared document per person with running notes and actions, so nothing is lost between meetings.
- **Ask open questions** when they don't bring topics: What's getting in your way? What would you change about how we work? What are you learning? What do you want to be doing in a year?
- **Write down what you agreed to do, and do it.** Trust is built in the follow-through.

A simple shared agenda:

```text
## 2026-10-13
Their topics:
-
My topics:
-
Actions:
- [ ] (who) what, by when
```

## Expectations

Most performance problems are expectation problems. Write down, for each role:

- **What good looks like** at this level: scope, independence, quality, and how they work with others. Many companies have a career ladder; if yours doesn't, write a one-page version.
- **What the team owns,** and what each person is the go-to for. On platform teams, unclear ownership shows up as duplicated work, dropped alerts, and everyone assuming someone else is handling the vulnerability report.
- **How work happens:** how to pick up tickets, what "done" means (tested, documented, monitored, deployed), when to ask for help, how on-call handoffs work.

## Feedback

- **Give it soon and specifically.** A useful structure is situation, behavior, impact: "In yesterday's incident review (situation), you walked through the timeline without assigning blame (behavior), and two people volunteered mistakes they'd have hidden otherwise (impact)."
- **Praise in public, correct in private,** and make sure praise is as specific as criticism.
- **Ask for it, too:** "What's one thing I could do differently?" Then act on what you hear, visibly.
- **No surprises at review time.** Nothing in a formal review should be news.

## Growth

- Ask each person where they want to go: deeper technical expertise, broader architecture, leading people, or moving toward product or security. Platform work suits all of these.
- Give **stretch assignments** with support: lead an incident review, design a new module, own a migration, run the on-call rotation for a quarter.
- **Rotate the unglamorous work** (dependency updates, upgrades, documentation) so it isn't always the same person, and credit it. On platform teams it's most of the job.
- Track progress against the expectations for the next level, in writing, a couple of times a year.

## Team rituals

Keep meetings few and useful. A typical platform team needs:

| Ritual | Cadence | Purpose |
|---|---|---|
| Stand-up or async check-in | Daily | Blockers and coordination, not status recitation. Ten minutes, or written in chat. |
| Planning | Every 1 to 2 weeks | Choose planned work with interrupts and on-call load accounted for ([Planning](03-planning-and-metrics.md)) |
| Operational review | Weekly | Last week's incidents, pages, alerts, and toil; what to fix ([On-call](04-on-call-and-team-health.md)) |
| Retrospective | Every 2 to 4 weeks | How we work: what to keep, stop, and try. Follow up on last time's actions. |
| Design review | As needed | Significant changes get a short written proposal and review before building ([ADR template](../tech-lead/templates/adr-template.md)) |

Cancel any ritual that has stopped producing decisions or actions.

## Write things down

Distributed and on-call teams depend on written knowledge more than most:

- **Decisions** in architecture decision records, so nobody has to reconstruct why.
- **Runbooks** for every alert ([observability](../devops/observability/README.md#slos-and-alerting)) and every routine operation.
- **Onboarding docs** that a new hire updates as they use them ([Hiring and onboarding](02-hiring-and-onboarding.md)).
- **A team page:** what the team owns, how to request work, how to reach on-call, and the current priorities.

Documentation is a product: it needs an owner, and stale docs are worse than none.

## Psychological safety

People admit mistakes, raise risks, and say "I don't know" only when it's safe to. Google's research on team effectiveness found psychological safety the most important factor in how its teams performed ([re:Work](https://rework.withgoogle.com/en/guides/understanding-team-effectiveness)). In operations work, it's the difference between an engineer reporting "I think I just ran that against production" in thirty seconds or in three hours.

What managers do that builds it: admit their own mistakes first, thank people for raising bad news, run [blameless incident reviews](04-on-call-and-team-health.md#incident-reviews), and never punish someone for an honest error made following the process. The [DORA research](https://dora.dev/) links this kind of culture (in Westrum's terms, "generative") with better software delivery and operational performance.
