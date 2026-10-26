# Roadmaps and stakeholders

[← Product owner](README.md)

A roadmap tells users and stakeholders where the platform is going and why, so they can plan around it. It's a communication tool, not a delivery contract. This guide covers a roadmap format that stays honest, how to frame it in outcomes, and how to work with the people who care about it.

## Now, next, later

A **now/next/later** roadmap (a format popularized by Janna Bastow of ProdPad) replaces dates with horizons:

| Horizon | Contains | Certainty |
|---|---|---|
| **Now** | What the team is working on this sprint or month | High: committed, and well understood |
| **Next** | What comes after, in the next one to three months | Medium: likely, still being shaped |
| **Later** | Problems worth solving after that | Low: direction, not commitment |

It works for platform teams because it's honest about uncertainty: interrupts, incidents, and discovery change plans, and a date-based roadmap with quarters of features turns into a list of missed promises. The [roadmap template](templates/roadmap.md) has the layout.

Where a real date exists (an end-of-support deadline, a compliance date, a data center exit), show it as a constraint on the item, not as a delivery date for everything.

## Outcomes, not outputs

Write roadmap items as the problem solved or the outcome for users, not the feature:

| Output (avoid) | Outcome (prefer) |
|---|---|
| Build a service catalog | Any engineer can find who owns a service and how to reach them in under a minute |
| Migrate to the new CI system | Pipelines run in under 10 minutes, and teams stop maintaining their own runners |
| Add database self-service | Teams get a production database the same day, without a ticket |

An outcome leaves room for the team to find the best solution, and tells stakeholders what they'll actually get. It also makes the measures obvious ([Measuring outcomes](05-measuring-outcomes.md)).

## OKRs

Many organizations set **objectives and key results**: a qualitative objective, with two to five measurable key results that show it's met.

```text
Objective: Make it fast and safe for any team to ship a new service.

Key results:
- Median time from new repository to first production deploy falls from 9 days to 1.
- 80% of new services this quarter use the service template (from 35%).
- Change fail rate for services on the platform stays under 10%.
```

Key results are outcomes, not tasks ("launch the template" is a task). Tie the product goal, the roadmap's "now" and "next," and the OKRs together, so the team sees one direction, not three documents.

## Working with stakeholders

Map who cares about the platform, how much influence they have, and what they need. The [stakeholder map template](../tech-lead/templates/stakeholder-map.csv) in the tech lead folder works for this.

| Stakeholder | Usually wants | Give them |
|---|---|---|
| Engineering leadership | Faster delivery, fewer incidents, predictable cost | Outcomes and trends; the trade-offs that need their decision |
| User team leads | Their requests done; no surprise breaking changes | The roadmap, early notice of changes, a channel that answers |
| Security and compliance | Controls that hold everywhere | Built-in controls in the golden path; evidence on request |
| Finance | Cost visibility and control | Cost per team or service; the effect of platform changes on spend |
| The team itself | A clear goal and time to do things properly | The why behind priorities; protection from the loudest requester |

Habits that help:

- **Review the roadmap with users in sprint reviews,** not only with leadership.
- **Publish it where users can find it,** and update it when it changes, saying why.
- **Report outcomes regularly** (monthly is often enough), including bad news early.
- **Hold a regular open session** (office hours, a quarterly user forum) where users can raise problems directly.

## Deprecations and migrations

Platforms accumulate old ways of doing things: an old CI system, a deprecated module version, a legacy cluster. Retiring them is product work and needs the same care as launching something:

1. **Make the new way clearly better** before asking anyone to move. Teams move to what helps them; they resist migrations that only help the platform team.
2. **Announce early, with a date and a reason:** what's going, what replaces it, when, and why.
3. **Make migrating easy:** a guide, tooling that does most of the work, and help for teams with unusual cases.
4. **Track who's left,** and talk to each remaining team directly.
5. **Stop new use first** (no new services on the old way), then migrate existing use, then switch off.
6. **Switch off on the date.** Extensions for one team turn into extensions for all; agree any exception explicitly, with its own date.

The tech lead's [migrations and cutovers guide](../tech-lead/migrations-and-cutovers.md) covers the technical side.

## Next

[Measuring outcomes](05-measuring-outcomes.md).
