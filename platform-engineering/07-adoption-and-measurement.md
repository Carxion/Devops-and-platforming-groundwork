# Adoption and measurement

[← Platform engineering](README.md)

A platform succeeds when teams use it and it makes them faster and safer. This guide covers earning adoption, what to measure, and assessing the platform's maturity. The product owner's [measuring outcomes guide](../product-owner/05-measuring-outcomes.md) covers the measurement frameworks (SPACE, DevEx, DORA, surveys) in more depth; this one focuses on what's specific to platforms.

## Earn adoption

The CNCF [maturity model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/) describes how adoption matures:

| Level | Adoption is | Means |
|---|---|---|
| Provisional | Erratic | Some teams use parts, by word of mouth |
| Operational | Extrinsic push | Teams use it because they're told to |
| Scalable | Intrinsic pull | Teams choose it, because it's the easiest way to do their work |
| Optimizing | Participatory | Teams contribute to it |

Mandates have their place (a security control, the end of an old system), but a platform that grows only by mandate never learns whether it's good. Ways to earn pull:

- **Make the golden path the fastest way.** If a team can go from nothing to production faster on the path than off it, most will take it.
- **Remove a pain teams already feel,** not one the platform team thinks they should feel: the ticket they wait on, the pipeline they maintain, the audit they dread.
- **Start with willing teams,** and make them visibly successful. A team that tells others "we shipped in a day" does more than any announcement.
- **Migrate teams for them** where you can: open the merge request that moves a service onto the path.
- **Show up:** office hours, onboarding sessions, pairing on first use, a channel that answers.
- **Listen to who isn't using it,** and why. Their reasons are the backlog.

## What to measure

Measure outcomes for users, not output from the platform team. A balanced set, from DORA's [platform engineering guidance](https://dora.dev/capabilities/platform-engineering/) and the measures this repository uses elsewhere:

| Area | Measure | Why |
|---|---|---|
| **Speed of the path** | Time to first deploy for a new service | The golden path's headline number; baseline it by doing it yourself |
| **Delivery** | Change lead time, deployment frequency, change fail rate, failed deployment recovery time ([DORA](../manager/03-planning-and-metrics.md#measuring-delivery-the-dora-metrics)) | DORA found platforms can lower throughput and stability if not managed carefully; watch both |
| **Independence** | Tickets to the platform team per week, by kind; share of tasks done without help | DORA associates developer independence with higher productivity |
| **Adoption** | Share of services on the golden path; share on the latest template, component, and chart versions | Reach, and day-2 health |
| **Experience** | Developer satisfaction with the platform (survey), and the top complaints | What numbers miss ([survey template](templates/developer-experience-survey.md)) |
| **Reliability** | The platform's own SLOs: pipeline success excluding user errors, provisioning time, cluster availability | The platform is production for everyone |
| **Fragmentation** | How many ways teams do one thing (pipelines, Dockerfiles, deploy methods) | Falling numbers mean the paths are working |

Read them together. Adoption up and satisfaction down is a mandate working, not a platform; satisfaction up and delivery metrics down needs investigating; tickets down and time to first deploy flat may mean the tickets moved somewhere else.

## Measure the journey, not just the steps

The most useful measure is often the simplest: **do the journey yourself, every quarter,** with only the docs, and time it. Create a service, add a database, deploy, roll back, find the logs. Each wait, error, and question is a finding. It's the platform team's equivalent of using your own product, and it catches regressions no dashboard shows.

## Assess maturity, aspect by aspect

The CNCF maturity model rates five aspects, each independently, at four levels:

| Aspect | Provisional | Operational | Scalable | Optimizing |
|---|---|---|---|---|
| **Investment** | Voluntary or temporary | Dedicated team | As product | Enabled ecosystem |
| **Adoption** | Erratic | Extrinsic push | Intrinsic pull | Participatory |
| **Interfaces** | Custom processes | Standard tooling | Self-service solutions | Integrated services |
| **Operations** | By request | Centrally tracked | Centrally enabled | Managed services |
| **Measurement** | Ad hoc | Consistent collection | Insights | Quantitative and qualitative |

Use it to find the aspect holding the platform back, not as a score to raise. The model itself says each aspect "should be considered independently" and that "reaching the highest level should not be a goal in itself": higher levels cost more funding and people's time. The [self-assessment template](templates/platform-maturity-assessment.md) turns it into questions with evidence.

## Report it

Monthly is usually enough: the outcome measures and their trend, what shipped, what's next and why, and the top user complaints with what you're doing about them. Report bad news early. Tie it to the [product goal](../product-owner/templates/product-goal.md), so stakeholders see one direction, not a list of features.

## Next

[Anti-patterns](08-anti-patterns.md).
