# Your first 90 days on a platform team

[← Platform engineering](README.md)

A checklist for platform engineers and platform leads, whether you're joining an existing platform team or starting one. It uses the same timing tags as the [tech lead checklist](../tech-lead/README.md):

| Tag | Meaning |
|---|---|
| **W1** | First week. Meeting people and listening. |
| **30** | By day 30. Know the users, what exists, and where time goes. |
| **60** | By day 60. One golden path chosen, designed with its users, and being built. |
| **90** | By day 90. That path used by real teams, with measures showing whether it helps. |

As with every role in this repository: **listen first.** The most common way a platform team fails is building what it thinks developers need, well, and finding nobody uses it.

---

## Before you start

- [ ] Ask whoever sponsors the platform: what problem is it meant to solve, how will they judge success in a year, and is using it optional or mandated?
- [ ] Get the list of product teams, the platform's existing components and docs, and any developer survey results.
- [ ] Get access to the repositories, pipelines, clusters, cloud accounts, and the channels where developers ask for help.

## 1. People

- [ ] **W1** Meet everyone on the platform team: what the platform does well, what users complain about, and what they'd stop doing if they could.
- [ ] **W1** Meet the product owner, engineering manager, and architect, if the team has them. Agree who decides what ([working with the other roles](README.md#working-with-the-other-roles)).
- [ ] **30** Interview at least five developers from different product teams, including one team that doesn't use the platform ([user interview guide](../product-owner/templates/user-interview-guide.md)). Ask about their last new service and their last production incident.
- [ ] **30** Meet the people who own what the platform depends on or enforces: security, networking, identity, finance. Find out which of their requirements reach developers today as tickets or reviews.

## 2. What exists

- [ ] **30** Follow a new service from nothing to production as a developer would, using only the docs. Record every wait, ticket, approval, and question you had to ask someone.
- [ ] **30** Map what the platform offers today against the [capability map](templates/capability-map.md): which capabilities are self-service, which need a ticket, and which teams build for themselves.
- [ ] **30** Find out how many ways teams currently do the same thing: pipelines, Dockerfiles, Helm charts or manifests, logging setups. The number is a measure of fragmentation.
- [ ] **30** Read the last few months of requests to the platform team. Group them; the biggest groups are self-service candidates.
- [ ] **60** Get baseline numbers ([Adoption and measurement](07-adoption-and-measurement.md)): time to first production deploy for a new service, the DORA metrics for a few teams, request wait times, and developer satisfaction if there's a survey.

## 3. The first golden path

- [ ] **60** Pick one golden path to build or improve: the most common thing teams do that's slowest or most error-prone today. Usually "a new service, to production."
- [ ] **60** Write its definition with two or three product teams ([golden path definition](templates/golden-path-definition.md)): who it's for, what it gives them, what it decides for them, and how they leave it.
- [ ] **60** Find out which steps on the path need a person today (approvals, tickets, manual setup), and agree with their owners how to make each one automatic or a guardrail.
- [ ] **60** Agree how the path will be supported: who answers questions, how fast, and what happens when it breaks for a team.

## 4. By day 90

- [ ] **90** Have at least two product teams using the golden path for real work, and ask them what got in the way.
- [ ] **90** Compare the measures with the baseline: time to first deploy, tickets for the things the path covers, and what the teams say.
- [ ] **90** Publish what the platform offers, as its users would describe it, and how to get help ([platform service definition](templates/platform-service-definition.md)).
- [ ] **90** Share a summary with your manager and sponsor: what you learned from users, the path you built, what changed, and what's next on the roadmap.
