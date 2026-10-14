# Prioritization

[← Product owner](README.md)

Ordering the backlog is the product owner's most consequential decision, and the most contested. A visible method doesn't make the decisions for you, but it makes them explainable: stakeholders can disagree with the inputs instead of suspecting the outcome.

Pick one method, use it consistently, and show the scores. The method matters less than using one.

## Cost of delay and WSJF

**Cost of delay** asks what it costs to do something later instead of now. It's often the most useful question for platform work, where much of the value is in avoiding a loss: a support deadline, a security exposure, teams waiting.

**WSJF** (weighted shortest job first), from the Scaled Agile Framework, ranks items by cost of delay divided by size, so small, urgent, valuable items go first:

```text
WSJF = cost of delay / job size

cost of delay = user or business value + time criticality + risk reduction or opportunity enablement
```

Score each part relatively, comparing items against each other (often with a Fibonacci-like scale: 1, 2, 3, 5, 8, 13, 20), not in absolute units.

| Item | Value | Time criticality | Risk reduction | Cost of delay | Size | WSJF |
|---|---|---|---|---|---|---|
| Upgrade Kubernetes before end of support | 3 | 13 | 13 | 29 | 8 | 3.6 |
| Self-service preview environments | 13 | 3 | 2 | 18 | 13 | 1.4 |
| Fix the slow build cache | 8 | 2 | 1 | 11 | 3 | 3.7 |

The fix to the build cache ranks first despite less value: it's small. Without the division by size, big features tend to win every time.

## RICE

**RICE**, published by Intercom, scores reach, impact, confidence, and effort:

```text
RICE = (reach × impact × confidence) / effort
```

| Factor | Means | Scale (Intercom's) |
|---|---|---|
| **Reach** | How many users (or teams) it affects in a period | A count, e.g. 30 teams per quarter |
| **Impact** | How much it helps each one | 3 massive, 2 high, 1 medium, 0.5 low, 0.25 minimal |
| **Confidence** | How sure you are of the estimates | 100% high, 80% medium, 50% low |
| **Effort** | Work required | Person-months (or person-weeks) |

RICE suits feature work where reach varies a lot. It handles deadlines poorly (a support end date has low reach and huge urgency), so platform teams often use WSJF or cost of delay for those. The [prioritization worksheet](templates/prioritization.md) has both.

## MoSCoW

**MoSCoW**, from the DSDM method, sorts items for a fixed scope or release:

- **Must have:** the release fails without it.
- **Should have:** important, but there's a workaround.
- **Could have:** nice if there's time.
- **Won't have (this time):** explicitly out, for now.

It's quick, and good for agreeing a release's scope with stakeholders. It doesn't order items within a category, and everything tends to drift into "must."

## Kano

The **Kano model** classifies features by how users react:

- **Basic (must-be):** expected; their absence causes anger, their presence goes unnoticed. For a platform: it's up, it's secure, the docs are correct.
- **Performance:** more is better, roughly in proportion: faster builds, shorter wait for environments.
- **Delighters (attractive):** unexpected, and pleasing when present: a preview environment on every pull request.

It's a reminder that delighters don't make up for broken basics. A platform with flaky deploys gains nothing from a new dashboard.

## Balancing run, improve, and build

Scoring every item against every other one rarely works for a platform team, because some work has to happen regardless. Most teams set the split first, then prioritize within each part:

| Part | What | Typical share (adjust to your data) |
|---|---|---|
| **Run** | Incidents, on-call, requests, upgrades that can't wait | Whatever it really takes, measured |
| **Improve** | Debt, reliability, toil reduction, automation of frequent requests | A fixed share, e.g. 20% |
| **Build** | New capabilities toward the product goal | The rest |

If "run" grows every quarter, the most valuable "improve" work is whatever shrinks it. The manager's [planning guide](../manager/03-planning-and-metrics.md) covers this split from the capacity side.

## Saying no

Most requests can't be done now, and some shouldn't be done at all. Saying no well keeps trust:

- **Say no to the timing, not the person:** "Not this quarter, because the self-service database goal comes first. Here's where it sits."
- **Show the trade-off:** "We can do this next sprint if we push the Kubernetes upgrade; that risks running unsupported. Which matters more to you?" Often the requester chooses to wait.
- **Offer what's possible now:** a workaround, documentation, or the self-service option.
- **Close what you won't do,** with the reason, rather than leaving it to rot in the backlog.
- **Escalate real conflicts** between stakeholders to whoever sets the organization's priorities, with the options laid out, instead of deciding by who asked last.

## Next

[Roadmaps and stakeholders](04-roadmaps-and-stakeholders.md).
