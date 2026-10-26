# Flow and metrics

[← Scrum master](README.md)

Metrics help a team see how work flows and whether changes help. They hurt when they become targets or a way to compare teams. This guide covers the measures that work for platform teams, the one that usually doesn't, and how to forecast without estimating everything.

## The four flow measures

The [Kanban Guide](https://kanbanguides.org/english/) (May 2025) defines four measures. They need only the date each item started and finished, which any board tool records.

| Measure | Definition (Kanban Guide) | What it tells you |
|---|---|---|
| **WIP** (work in progress) | "The number of work items started but not finished" | How much the team is juggling. High WIP means long waits and context switching |
| **Throughput** | "The number of work items finished per unit of time" | How much the team finishes; the basis for forecasting |
| **Work item age** | "The elapsed time between when a work item started and the current date" | Which items in progress are stuck *now*, before they become late |
| **Cycle time** | "The elapsed time between when a work item started and when a work item finished" | How long work takes once started; what a requester waits after you begin |

Little's Law ties them together: for a reasonably stable process, average cycle time equals average WIP divided by average throughput. To finish things sooner, the most reliable lever is **less work in progress**, not working harder.

Look at cycle time as a distribution, not an average: "85% of items finish within 6 days" is more useful (and more honest) than "average 4.2 days." A scatter plot of cycle times by finish date shows both the typical range and the outliers worth discussing.

## WIP limits

Set a limit on how many items can be in each column (or in progress overall), and don't start new work while at the limit: help finish something instead. Start with roughly the number of people on the team, then lower it until it's slightly uncomfortable. When an item is blocked, the limit makes the block visible and urgent instead of letting people quietly start something else.

## Why velocity misleads

Velocity (story points completed per sprint) is useful only to the team that produced it, and only for rough planning. It goes wrong when:

- **It becomes a target.** Points inflate, and velocity goes up with no change in what's delivered. ("When a measure becomes a target, it ceases to be a good measure": Goodhart's law.)
- **It's compared across teams.** Points aren't a unit; each team calibrates differently.
- **It ignores unplanned work.** A platform team that spent half the sprint on incidents shows "low velocity" for doing its job.

If the team uses points, keep velocity inside the team. Report throughput, cycle time, and outcomes outward.

## Tracking unplanned work

For a platform team, the most useful single number is often **the share of work that was unplanned**. Track it per sprint (or per week) by type:

| Type | Example | Usually fixed by |
|---|---|---|
| Incidents | Pages, outages | Reliability work: alerts, capacity, removing failure modes |
| Requests | Access, environments, quota increases | Self-service and automation |
| Questions | "How do I deploy to staging?" | Documentation, templates, office hours |
| Toil | Manual certificate renewals, cleanup | Automation, as planned backlog items |

Bring the breakdown to the retrospective and to the product owner. The aim is a declining share over time, and fixing the biggest source is usually the highest-value item on the backlog. The [manager's planning guide](../manager/03-planning-and-metrics.md) covers balancing run, improve, and build work.

## Forecasting without estimates

Instead of estimating every item, forecast from what the team has actually finished. A **Monte Carlo simulation** does this:

1. Take the team's daily (or weekly) throughput for the last 8 to 12 weeks.
2. Simulate the future many times (thousands): for each simulated day, pick a random past day's throughput.
3. Count, in each simulation, how many days it takes to finish the remaining items (or how many items finish by a date).
4. Read off the percentiles: "85% of simulations finished the 40 remaining items within 31 working days."

It answers "when will it be done?" and "how much by this date?" with a probability, using data the board already has. It works best when items are roughly similar in size; the team's refinement rule ("nothing bigger than three days") helps. Spreadsheet templates and most Kanban tools can run it.

Remember that forecasts assume the future looks like the recent past. A new on-call load, a reorganization, or a holiday period changes that; refresh the forecast as data changes.

## Delivery outcomes

Flow measures show how work moves through the team. The [DORA metrics](../manager/03-planning-and-metrics.md) show how software moves to production: deployment frequency, lead time for changes, change fail rate, failed deployment recovery time, and rework rate. A platform team often owns the pipelines that determine them for everyone else, which makes them outcome measures for the platform's product owner too ([measuring outcomes](../product-owner/05-measuring-outcomes.md)).

## Using metrics well

- **The team owns its metrics.** Review them in retrospectives to find improvements, not in status meetings to judge.
- **Pair every speed measure with a quality one.** Faster cycle time with more incidents isn't an improvement.
- **Look at trends,** not single sprints.
- **Never use them to rank individuals.** It destroys collaboration and the data both.

## Next

[Impediments and team health](04-impediments-and-team-health.md).
