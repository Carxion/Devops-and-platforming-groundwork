# Working with product and leadership

[← Tech lead checklist](README.md)

A tech lead's technical findings only change anything once the people who set priorities and budgets agree with them. Product managers, engineering managers, and senior leaders are deciding between many good uses of the same people and money; your job is to make the technical side of those decisions clear, honest, and comparable. This guide covers translating technical work into business terms, negotiating scope, presenting a roadmap, and handling disagreement.

## Understand what they're measured on

Before proposing anything, learn what the people you need agreement from are accountable for:

| Role | Usually measured on | What they need from you |
|---|---|---|
| Product manager | Customer outcomes, feature delivery, adoption, revenue | Honest estimates, early warning of risk, options when something won't fit |
| Engineering manager | Delivery, team health, retention, budget | A realistic plan, risks to the team, technical context for staffing decisions |
| Director or VP | Portfolio of outcomes, budget, organizational risk | Short summaries, clear asks, the cost of not acting |
| Security and compliance leads | Risk posture, audit results | Evidence, timelines, and early involvement |
| Finance | Spend against budget, forecasts | Cost estimates, trends, and the reasons for changes |

Ask them directly in your first conversations ([section 1.3](README.md#13-run-first-conversations)): "What does a good quarter look like for you?" Then frame your proposals around their answers.

## Translate technical work into business terms

Leaders don't need to understand the technology to make good decisions about it. They need the consequences:

| Instead of | Say |
|---|---|
| "We need to refactor the deployment pipeline." | "Releases take nine days from code complete to customers. Two of those changes would cut it to one day, so features you've already paid for reach customers a week sooner." |
| "We have a lot of technical debt in the order service." | "Changes to ordering take three times longer than elsewhere and cause most of our incidents. Fixing the two worst parts would cost six engineer-weeks and roughly halve both." |
| "The database is on an old version." | "Our database version loses vendor security fixes in March. After that, a published vulnerability could expose customer data with no fix available. Upgrading takes three weeks; it needs to start by January." |
| "We should adopt Kubernetes." | (Don't lead with the tool. Lead with the problem it solves, and only if that problem is real here.) |

The pattern: **the problem, its cost in terms they care about (time, money, risk, customers), what fixing it costs, and what changes afterward.** Use numbers from your [baseline](templates/metrics-baseline.csv) wherever possible; "about nine days, measured from the last 50 releases" persuades in a way that "slow" doesn't.

### Expressing risk

Risks are easiest to decide on when stated the same way every time: **likelihood, impact, and the cost to reduce it**, ideally from your [risk register](templates/risk-register.csv). "If the one person who runs releases is out, we can't ship an emergency fix. Likely within a year; impact is an extended outage. Fixing it takes about four weeks."

Then let the accountable person decide, and record the decision. Accepting a risk is a legitimate business choice; your job is to make sure it's made knowingly, by the right person, not by default.

## Negotiating scope and timelines

When asked "can we have X by date Y?":

- **Don't answer on the spot** for anything substantial. "Let me look at it with the team and come back tomorrow" is a professional answer.
- **Offer options, not just yes or no:** the full scope later, a smaller version by the date, or the date with something else dropped. Make the trade-off theirs to choose.
- **Give ranges with their assumptions:** "four to six weeks, assuming the vendor API works as documented; we'll know in the first week."
- **Make run work visible.** Leaders often plan as if the whole team works on projects. Show the measured share of on-call, incidents, and requests ([capacity in the roadmap](templates/roadmap.md)).
- **Escalate early when a commitment is at risk,** with options. Bad news three weeks before a deadline is a planning conversation; the day before, it's a crisis.

### Getting technical work onto the roadmap

Reliability, security, and technical-debt work competes with features. Approaches that work:

- **Tie it to outcomes they already want:** faster delivery, fewer incidents, passing an audit.
- **Show the trend:** "incidents per month have doubled since last year" moves priorities more than a single bad week.
- **Agree a standing budget** for improvement work (for example 20% of capacity) instead of arguing for each item.
- **Bundle it with feature work** that touches the same area: improving a component while you're already changing it is cheaper than a separate project.
- **Deliver what you promised.** Each technical improvement that lands on time and shows a measurable result makes the next one easier to fund.

## Presenting a roadmap

For the day-90 roadmap ([section 9](README.md#9-306090-day-deliverables)) or any quarterly plan:

1. **Pre-brief individually** the people whose plans it affects most, especially anyone whose request it defers.
2. **Open with the goals and the evidence,** not the list of projects: what will be measurably better, and why these goals.
3. **Show the capacity:** how much of the team's time is available for the roadmap after run work, and therefore why the list is the length it is.
4. **Show the non-goals** explicitly. Leaders often agree more readily to a plan that says clearly what it won't do.
5. **Name the decisions you need** from the audience, and the date you need them by.
6. **Say how progress will be reported:** which metrics, how often, and where.

## Disagreement

You'll sometimes disagree with a product or leadership decision.

- **Disagree in private first,** with your reasoning and evidence, before any group setting.
- **Separate facts from judgment.** Agree on the facts (the risk, the cost, the timeline) even if you disagree about the choice. Then the decision is about priorities, which is theirs to make.
- **Ask what would change their mind,** and whether you can get that evidence.
- **Once decided, commit,** and make the decision succeed. If it was the wrong call, the results will show it, and you'll have the credibility to revisit it.
- **Write down significant disagreements** with technical risk (an ADR or a note on the risk register): what was decided, by whom, with what known risks. Not to assign blame later, but so the next person understands why.
- **Escalate only for real harm:** safety, security, legal, or ethical concerns justify going above someone's head. Ordinary priority disagreements don't.

## Keeping them informed

- **A regular written update** ([weekly status](templates/weekly-status.md)) with the same structure every time: what changed, risks, decisions needed, and the handful of metrics that matter.
- **No surprises.** Leaders should hear about significant risks and incidents from you, before they hear from anyone else.
- **Report outcomes, not activity:** "lead time is down from nine days to three" rather than "we migrated the pipeline."
- **Credit the team** specifically and publicly. It builds the team's reputation, and their trust in you.
