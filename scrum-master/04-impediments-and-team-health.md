# Impediments and team health

[← Scrum master](README.md)

An impediment is anything that slows the team down that the team can't easily remove itself. Removing them is the most visible value a scrum master adds, and the team's health decides whether people raise them at all.

## Finding impediments

People rarely announce impediments; they work around them. Look for:

- **Waiting.** Items that sit in a column for days (high [work item age](03-flow-and-metrics.md#the-four-flow-measures)). Ask what they're waiting for: a review, an approval, another team, an environment.
- **Repeated complaints** in daily scrums and retrospectives.
- **Workarounds.** Scripts nobody owns, manual steps "just for now," shared credentials.
- **Interrupts from the same source,** sprint after sprint ([tracking unplanned work](03-flow-and-metrics.md#tracking-unplanned-work)).
- **Questions in one to ones:** "What's the most annoying part of your week?"

Common impediments on platform teams: slow or manual approvals for production changes, dependencies on a central network or security team, flaky pipelines and tests, missing environments, unclear priorities from too many stakeholders, and too much on-call load.

## Removing them

Log every impediment ([template](templates/impediment-log.md)) with who raised it, its impact, its owner, and its status. Then sort by who can act:

| Who can fix it | What the scrum master does |
|---|---|
| The team | Make it visible and help the team plan it, often as a backlog item |
| The scrum master | Do it: arrange access, set up a meeting, chase a decision |
| Someone outside the team | Escalate with evidence, then follow up until it's resolved or explicitly declined |

### Escalating well

- **Bring evidence, not frustration:** "Production changes wait a median of 3 days for CAB approval; 40 changes last quarter; here's the cycle time data." Numbers move managers.
- **Propose a fix,** or at least an experiment: "Pre-approve standard changes that pass the pipeline's checks."
- **Name an owner and a date** for the decision.
- **Report back to the team,** even when the answer is no. An impediment that disappears into a manager's inbox teaches the team not to raise the next one.

## Working agreements

A working agreement is the team's own short list of how it works together: core hours, how to ask for review, how fast to respond in chat, what happens when someone's blocked, meeting norms, and how on-call handoffs work. Write it with the team, keep it to one page, and revisit it in a retrospective every few months. The [working agreement template](templates/working-agreement.md) has prompts.

It's the team's agreement, not the scrum master's rules. The scrum master's role is to help the team notice when it isn't following its own agreement, and to ask whether the agreement needs to change.

## Psychological safety

Psychological safety is a shared belief that the team is safe for interpersonal risk-taking: admitting a mistake, asking a question, disagreeing (Amy Edmondson's definition). Google's Project Aristotle research found it the most important of the team dynamics it studied for team effectiveness. Without it, retrospectives are polite, incidents are hidden, and impediments go unreported.

What the scrum master can do:

- **Model it:** admit your own mistakes and uncertainty first.
- **Respond well to bad news.** Thank people for raising problems, especially incidents and missed goals.
- **Make blameless reviews the norm** ([incident review template](../manager/templates/incident-review.md)).
- **Watch who speaks.** Use rounds, written input first, and smaller groups, so quieter people are heard.
- **Raise concerns about leadership behavior** privately with the manager, when that's the cause.

## Team health checks

A health check is a short, regular self-assessment by the team: each person rates areas such as clarity of goals, pace, quality, support, learning, and fun, then the team discusses the results. The [team health check template](templates/team-health-check.md) is one version, adapted from the format Spotify published.

- Run it every two or three months, and compare trends.
- Discuss it in a retrospective; let the team pick one area to improve.
- Keep the results within the team. Reported upward, scores improve and honesty disappears.

## Conflict

Disagreement about ideas is healthy; conflict between people that stops work isn't. When it's about the work (how to design something, what to prioritize), help the people involved make their reasoning visible and agree how to decide: a spike, an experiment, the tech lead's call, or the product owner's. When it's personal, talk to each person privately first, and involve the manager if it continues or affects performance. The scrum master facilitates; the manager handles performance and people issues.

## Next

[Working across teams and coaching](05-working-across-teams.md).
