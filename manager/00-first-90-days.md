# Your first 90 days as a manager

[← Manager](README.md)

A checklist for engineering managers taking over a DevOps, platform, or SRE team: what to learn, who to meet, how to understand the team's health and workload, and what to have in place by day 90. It's the manager's counterpart to the [tech lead checklist](../tech-lead/README.md), with the same timing tags:

| Tag | Meaning |
|---|---|
| **W1** | First week. Meeting people and listening. |
| **30** | By day 30. Understand the team, the work, and the expectations. |
| **60** | By day 60. Diagnose what's working and what isn't; agree it with your manager. |
| **90** | By day 90. A plan, and the routines that keep the team running. |

If the team also has a tech lead, divide the work: the tech lead assesses the system ([Assessing an inherited system](../tech-lead/assessing-an-inherited-system.md)); you assess the team, the workload, and the relationships. Compare notes weekly. If you're both, do both, and expect them to take longer.

The same rule applies as for tech leads: **listen first.** A new manager who reorganizes, changes processes, or picks favorites in the first month loses the team's trust before earning it.

---

## Before you start

- [ ] Ask your manager: why is this role open, what's going well, what isn't, and what do they expect from you by day 90?
- [ ] Get the team list, org chart, and any recent context: departures, reorganizations, incidents, survey results.
- [ ] If you were promoted from within the team, plan the change with your manager: how it's announced, and how you'll handle former peers' work and reviews.

## 1. People

### Meet everyone

- [ ] **W1** Hold a first one-on-one with every person on the team. Ask: what do you work on, what's going well, what's frustrating, what should I know, what do you need from me? ([one-on-one template](templates/one-on-one.md))
- [ ] **W1** Tell the team how you work: how to reach you, how you make decisions, and that you'll spend the first weeks listening before changing anything.
- [ ] **30** Set up regular one-on-ones with everyone, and keep them.
- [ ] **30** Learn each person's goals, strengths, and what they want to grow into. Read past reviews and development plans if they exist.
- [ ] **30** Identify any open performance concerns, flight risks, or people under strain. Ask your manager and HR what's already known.

### Understand expectations

- [ ] **30** Find the written expectations for each role (a career ladder or job descriptions). If there aren't any, note it; it's a likely 90-day item ([career ladder template](templates/career-ladder.md)).
- [ ] **30** Learn the review and promotion cycle: when, how, who decides, and anyone currently up for promotion.
- [ ] **60** Check that everyone knows what's expected of them, in their own words. Gaps between your view and theirs are where most performance problems start.

## 2. The work

### What the team owns

- [ ] **30** List what the team owns: services, platforms, pipelines, tools, on-call responsibilities, and recurring obligations (audits, certificate renewals, upgrades). Compare with what other teams *think* it owns.
- [ ] **30** Find out how work arrives: tickets, chat requests, escalations, leadership asks. Who decides priorities today?
- [ ] **30** Measure the split between run work (incidents, requests, patching) and planned work, from tickets and on-call logs, not from impressions ([Planning and metrics](03-planning-and-metrics.md#plan-for-interrupts-not-just-projects)).

### On-call and operations

- [ ] **W1** Find out who's on call this week, how the rotation works, and how you'd be reached in a major incident.
- [ ] **30** Read the last few months of incidents and their reviews. Are review actions completed?
- [ ] **30** Measure on-call load: pages per shift, pages outside working hours, and who carries the most ([On-call and team health](04-on-call-and-team-health.md)).
- [ ] **60** Join an incident (as an observer or the communications lead), and attend the next operational review.

### Delivery

- [ ] **30** Learn the current roadmap and commitments: what's promised, to whom, by when, and how confident the team is.
- [ ] **30** Get a baseline of delivery metrics if any exist (the DORA metrics, or simpler: how long requests take). Don't set targets yet.
- [ ] **60** Identify what's slowing the team down, from the team's own view and from the data.

## 3. Stakeholders

- [ ] **30** Meet the team's main customers (the teams that depend on the platform), and ask what they need, what works, and what frustrates them.
- [ ] **30** Meet the people you depend on: security, finance, partner teams, vendors.
- [ ] **30** Build a [stakeholder map](../tech-lead/templates/stakeholder-map.csv).
- [ ] **30** Agree with your manager how and how often you'll update them ([weekly status template](../tech-lead/templates/weekly-status.md)).
- [ ] **60** Find out how the platform's value is seen by leadership. If it's invisible, that's a priority ([making value visible](05-stakeholders-and-communication.md#make-the-platforms-value-visible)).

## 4. Team health

- [ ] **30** Watch how the team works together: who talks in meetings, who doesn't, how disagreements are handled, how mistakes are treated.
- [ ] **30** Note the rituals that exist and whether they produce decisions or just consume time ([Running the team](01-running-the-team.md#team-rituals)).
- [ ] **60** Look for single points of failure in knowledge and access: one person who knows a system, holds a credential, or is always the one paged.
- [ ] **60** Run a short anonymous team survey or retrospective: workload, clarity, what to keep, what to change.

## 5. Budget and administration

- [ ] **30** Learn the budget you're responsible for: headcount, tools and licenses, cloud spend, training. Who approves what?
- [ ] **30** Find upcoming renewals and contract dates, and any open hiring requisitions.
- [ ] **60** Review who has access to what (tools, production, cloud accounts) and remove access nobody needs. Make sure leavers' access was removed.

---

## 30/60/90-day deliverables

### By day 30

- [ ] A first one-on-one held with everyone, and regular ones running
- [ ] A list of what the team owns, how work arrives, and the measured run/planned split
- [ ] On-call load and incident history understood
- [ ] Stakeholder map, and an agreed update rhythm with your manager
- [ ] A private list of the top people risks (flight risk, burnout, performance), shared only with your manager and HR as appropriate

### By day 60

- [ ] A written assessment, shared with your manager: what's working, the top problems (team, workload, delivery, relationships), and what you propose
- [ ] Two or three small changes the team asked for, done (removing a useless meeting, fixing the noisiest alert, clarifying a process). Small visible wins build trust.
- [ ] Single points of failure identified, with a plan to spread the knowledge

### By day 90

- [ ] A [team charter](templates/team-charter.md): what the team owns and how to work with it, published
- [ ] Priorities for the next quarter agreed with stakeholders, with run work accounted for ([quarterly planning worksheet](templates/quarterly-planning.md))
- [ ] An [on-call policy](templates/on-call-policy.md) written down, if there wasn't one
- [ ] Clear expectations for every role, and a development goal agreed with each person
- [ ] Hiring plan, if the team needs more people, with roles defined ([Hiring and onboarding](02-hiring-and-onboarding.md))
- [ ] Your own 90-day retrospective: ask the team and your manager what you should keep doing and change

---

## Common mistakes for new managers

| Mistake | Instead |
|---|---|
| Changing processes in the first month | Listen first; change what the team asks for, then the rest with evidence |
| Staying on the critical path as an engineer | Do small, non-blocking technical work if you like; never be the bottleneck for a release or the only one who can fix a system |
| Avoiding a hard conversation hoping it resolves itself | Address performance and behavior early, privately, and specifically |
| Treating your former peers differently, better or worse | Be consistent and transparent, and say openly that the relationship has changed |
| Shielding the team from everything | Shield them from noise, but share the context they need to make good decisions |
| Saying yes to every stakeholder request | Make the trade-offs visible and let priorities decide ([Saying no](05-stakeholders-and-communication.md#saying-no-and-escalating)) |
| Measuring individuals by delivery metrics | Use metrics for the team and the system, never as individual scorecards |
