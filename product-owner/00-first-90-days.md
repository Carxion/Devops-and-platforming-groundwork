# Your first 90 days as a product owner

[← Product owner](README.md)

A checklist for product owners and product managers joining a platform, DevOps, or SRE team: who the users are, what they need, what the platform does today, and what to have in place by day 90. It uses the same timing tags as the [tech lead checklist](../tech-lead/README.md):

| Tag | Meaning |
|---|---|
| **W1** | First week. Meeting people and listening. |
| **30** | By day 30. Know the users, the platform, and the backlog. |
| **60** | By day 60. A product goal and a way of prioritizing, agreed with the team and stakeholders. |
| **90** | By day 90. A roadmap, outcome measures, and a backlog that reflects both. |

As with every role in this repository: **listen first.** A new product owner who reorders the whole backlog in week two, before talking to users, loses the team's trust and usually reorders it again later.

---

## Before you start

- [ ] Ask whoever hired you: why this role, why now, what does success look like in a year, and what decisions are yours to make?
- [ ] Get the team list, the platform's main components, and any existing roadmap, strategy, or survey results.
- [ ] Get access to the backlog tool, the request channels, and the platform's usage data and dashboards.

## 1. People

- [ ] **W1** Meet the team one to one: what does the platform do well, what do users complain about, and what would they build next?
- [ ] **W1** Meet the scrum master, engineering manager, and tech lead. Agree who decides what ([working with the other roles](README.md#working-with-the-other-roles)).
- [ ] **30** Interview at least five users from different teams: product engineers, SREs, data engineers, whoever uses the platform ([user interview guide](templates/user-interview-guide.md)). Include a team that *doesn't* use it.
- [ ] **30** Meet the stakeholders: engineering leadership, security, finance, and the leaders of the biggest user teams. Ask what they need from the platform and what worries them.

## 2. The platform today

- [ ] **30** Write down what the platform offers today, as its users would describe it: "deploy a service," "get a database," "see my logs," not component names.
- [ ] **30** Find out how much each capability is used, and by whom. Low use of something important is a finding.
- [ ] **30** Follow a new service from nothing to production, as a user would, with the docs only. Note every wait, ticket, and confusing step.
- [ ] **30** Find out how users ask for help today, and what they ask most often. The [scrum master's unplanned-work tracking](../scrum-master/03-flow-and-metrics.md#tracking-unplanned-work) and the request channels have this.
- [ ] **60** Get the baseline numbers you'll measure against ([Measuring outcomes](05-measuring-outcomes.md)): adoption, time to first deploy, DORA metrics, request wait times, and any satisfaction survey.

## 3. The backlog

- [ ] **30** Read the whole backlog. Note how much is old, how much has no clear user or reason, and how much is requests versus planned work.
- [ ] **30** Find out how items get in and how order is decided today: by you, by whoever asks loudest, or by nobody.
- [ ] **60** Clean it up with the team: close what's obsolete, merge duplicates, and make sure the top of the backlog is refined ([Backlog management](02-backlog-management.md)).
- [ ] **60** Check that technical debt, reliability, and toil reduction are in the backlog alongside features, with reasons you can weigh.

## 4. Goal and prioritization

- [ ] **60** Draft a product goal from what you've heard ([product goal canvas](templates/product-goal.md)), and test it with the team, users, and stakeholders.
- [ ] **60** Agree a prioritization method with the team and stakeholders, and use it visibly ([Prioritization](03-prioritization.md)). Choose one; consistency matters more than the method.
- [ ] **60** Agree with the team how much capacity goes to run, improve, and build work, and review it each quarter.
- [ ] **60** Agree how requests from other teams are handled: what's self-service, what goes in the backlog, and how quickly users hear back.

## 5. By day 90

- [ ] **90** Publish a now/next/later roadmap tied to the product goal ([template](templates/roadmap.md)), and walk the main user teams through it.
- [ ] **90** Agree two to four outcome measures with the team and leadership, and report them regularly.
- [ ] **90** Run sprint reviews that real users attend and give feedback in.
- [ ] **90** Share a summary with the team and your manager: what you learned from users, the goal, the roadmap, and what you'll measure.
