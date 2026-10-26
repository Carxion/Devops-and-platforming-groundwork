# Measuring outcomes

[← Product owner](README.md)

A platform team can be very busy and still not help anyone. Outcome measures show whether the platform makes its users faster, safer, or happier, and they're what the product owner reports instead of a list of shipped features.

Choose two to four measures tied to the product goal, take a baseline before changing anything, and review them regularly with the team.

## Adoption and usage

The simplest test of a platform's value: do teams choose to use it?

| Measure | Tells you |
|---|---|
| Share of services (or teams) using each capability | Whether it's adopted; low use of an important capability is a problem to investigate |
| New services that start on the golden path | Whether the default is the platform, or teams route around it |
| Abandoned attempts (started and not finished) | Where users give up |
| Requests and questions per team | What still needs a human; a falling number is usually good |

Adoption is meaningful when teams have a real choice. If the platform is mandatory, measure satisfaction and speed instead, because use is forced.

## Developer experience

Developer experience is how it feels to build and ship on the platform. Two research-based frameworks help choose what to measure:

- **SPACE** (Forsgren, Storey, Maddila, Zimmermann, Houck, and Butler, *ACM Queue*, 2021) names five dimensions, which spell its name: satisfaction and well-being, performance, activity, communication and collaboration, and efficiency and flow. Its main advice: measure across several dimensions, never productivity from a single number such as commits or lines of code.
- **DevEx** (Noda, Storey, Forsgren, and Greiler, *ACM Queue*, 2023) focuses on three: **feedback loops** (how fast developers learn the result of their work: builds, tests, reviews, deploys), **cognitive load** (how much they have to know and keep in mind), and **flow state** (how often they can work without interruption).

Platform measures that map onto these:

| Measure | How to get it |
|---|---|
| Time from new repository to first production deploy | Pipeline and deployment events |
| Build and pipeline duration (median and slow end) | CI data |
| Time waiting for an environment, access, or approval | Request timestamps |
| Onboarding time: days to a new hire's first merged change | Version control history |
| Satisfaction with the platform, and its parts | A regular survey (below) |

## The DORA metrics

The [DORA metrics](../manager/03-planning-and-metrics.md#measuring-delivery-the-dora-metrics) measure software delivery performance: deployment frequency, lead time for changes, change fail rate, failed deployment recovery time, and rework rate. A platform team usually owns the pipelines and environments that shape them for every other team, which makes them platform outcomes too.

Report them for the services on the platform, as trends. Comparing teams by them turns them into targets; use them to find where the platform could help most.

## Surveys

Ask users directly, regularly (every quarter or half year), with the same questions each time so you see trends:

- How satisfied are you with each capability (deployments, logs, databases)? (1 to 5 each)
- How easy is it to deploy a change, find logs, or get a database? (1 to 5 each)
- What's the biggest thing slowing you down?
- What should the platform team do next?

Keep it short (under five minutes), share the results with users, and say what you'll do about them. A survey nobody hears back from gets fewer answers next time. Pair the scores with interviews: the numbers show where; conversations show why.

## SLOs as product quality

For users, reliability is the most basic feature (a [Kano](03-prioritization.md#kano) basic). Set service level objectives for the platform's own services, from the users' point of view: the deployment pipeline succeeds for valid changes, the API responds, logs arrive within a minute. The [observability guides](../devops/observability/README.md) cover SLOs and error budgets.

The error budget is a product tool: while it's healthy, the team ships features; when it's spent, reliability work moves to the top of the backlog. Agree that rule with the team and stakeholders in advance, so it isn't argued during an incident.

## Running experiments

When you're not sure a change will help, test it small before building it fully:

1. **State the hypothesis:** "If we add a service template, teams will reach their first deploy in under a day."
2. **Choose the measure and the baseline** before starting.
3. **Try the smallest version** with a few willing teams: a template in a repository, before building a portal.
4. **Compare, then decide:** keep and grow it, change it, or stop.

Most ideas improve when users touch them early; some turn out not to be needed at all, which is the cheapest thing to learn.

## Reporting

A monthly outcome report can fit on one page:

- **The product goal** and progress toward it
- **Two to four outcome measures,** with trends
- **What shipped,** described as what users can now do
- **What's next,** from the roadmap
- **Risks and decisions needed** from stakeholders

## Next

Back to the [product owner overview](README.md), or to the [scrum master guides](../scrum-master/README.md).
