# On-call and team health

[← Manager](README.md)

On-call is where operations teams burn out. It's also where managers can make the most difference, because most of what makes on-call painful is fixable.

## A sustainable rotation

- **Enough people.** A rotation needs enough engineers that each is on call no more than about one week in four to six, with a secondary. Fewer than that, and on-call becomes a permanent state.
- **Clear handoffs.** A short written handoff at each rotation change: what's ongoing, what's flaky, what changed.
- **Compensate it,** with pay, time off, or both, as your organization allows. Unpaid, unacknowledged on-call is a reliable way to lose good engineers.
- **Time off after a bad night.** Someone paged at 3 a.m. starts late or takes the morning. Make it the default, not something they have to ask for.
- **Follow the sun** when the team spans time zones: hand the pager over at the end of each region's working day, so nobody is routinely woken.
- **Managers on the escalation path,** reachable when the on-call engineer needs a decision, more hands, or someone to talk to customers.

## Alert hygiene

Most on-call pain comes from bad alerts. Review every page in a weekly operational review:

| Question | If no |
|---|---|
| Did it need a human, right then? | Make it a ticket, a dashboard, or delete it |
| Was it about something users would notice? | Alert on the symptom instead ([SLO-based alerting](../devops/observability/README.md#slos-and-alerting)) |
| Did the runbook say what to do? | Write or fix the runbook |
| Did it fire early enough to act? | Tune it, or add a slower burn-rate alert |
| Has it fired repeatedly for the same cause? | Fix the cause, from the "improve" budget ([Planning](03-planning-and-metrics.md)) |

Track **pages per on-call shift** and **pages outside working hours** as team health metrics, and set a target. Google's SRE book recommends at most two incidents per 12-hour shift, since handling one properly (including the follow-up) takes hours ([Being On-Call](https://sre.google/sre-book/being-on-call/)); beyond that, the team is fire-fighting, not engineering.

## Incident reviews

After any significant incident, hold a review and write it up. Make it **blameless**: assume everyone acted reasonably with the information they had, and look for how the system, tools, and process allowed the failure. The question is "how did this make sense at the time?", not "who did this?".

A useful write-up covers:

- **Impact:** who was affected, how, and for how long
- **Timeline:** detection, response, and recovery, with times (UTC)
- **Contributing factors:** technical and organizational, usually several
- **What went well,** which is worth keeping
- **Actions,** each with an owner and a date, tracked to completion like any other work

Share reviews widely. The value is in other teams learning from them, and an organization that reads its incident reviews makes fewer repeats. The [Google SRE book's chapter on postmortem culture](https://sre.google/sre-book/postmortem-culture/) is the standard reference.

## Spotting burnout

Watch for changes, more than levels: someone who was engaged going quiet in meetings, sharp in reviews, or disengaged from work they used to care about; working late constantly; dreading on-call weeks; taking no time off. Ask about it directly and privately in one-on-ones.

What managers can change:

- **Load:** reduce interrupts, fix the noisiest alerts, rebalance on-call
- **Control:** let people choose how they solve problems, and have a say in what the team takes on
- **Recognition:** make invisible work (patching, upgrades, an incident handled well at 3 a.m.) visible and credited
- **Time off:** make sure people take their leave, fully disconnected, and that the rotation covers them

If someone needs more than the team can give, point them to the organization's employee assistance program or health resources, and protect their privacy.

## Measuring team health

Alongside the delivery metrics, track a few health signals over time:

- Pages per shift, and pages outside working hours
- Share of time on "run" work ([Planning](03-planning-and-metrics.md))
- Time to onboard a new engineer to on-call
- Regretted attrition, and why people leave
- A short, anonymous team survey every quarter: workload, clarity, whether people would recommend the team
