# Your first 90 days as a scrum master

[← Scrum master](README.md)

A checklist for scrum masters joining a DevOps, platform, or SRE team: what to observe, who to meet, how to see the way work really flows, and what to have agreed by day 90. It uses the same timing tags as the [tech lead checklist](../tech-lead/README.md):

| Tag | Meaning |
|---|---|
| **W1** | First week. Meeting people and watching. |
| **30** | By day 30. Understand the team, how work arrives, and how the events run. |
| **60** | By day 60. Know the main impediments and agree the first changes with the team. |
| **90** | By day 90. A few changes running, measured, and owned by the team. |

The rule is the same as for every role in this repository: **observe first.** A new scrum master who changes the board, the sprint length, and the retrospective format in the first month teaches the team that process is something done to them.

---

## Before you start

- [ ] Ask whoever hired you: why this role, why now, what's going well, what isn't, and what they expect by day 90?
- [ ] Find out who the product owner, manager, and tech lead are, and whether any of them currently does the scrum master's work.
- [ ] Get access to the backlog tool, the team's chat channels, the on-call schedule, and the incident history.

## 1. People

- [ ] **W1** Meet everyone on the team one to one. Ask: what's working, what's frustrating, what slows you down, and what do you want from a scrum master (some teams have had a bad one)?
- [ ] **W1** Meet the product owner. Agree how you'll work together, and ask how they decide what comes next.
- [ ] **W1** Meet the engineering manager and the tech lead. Agree the split of responsibilities ([who does what](README.md#who-does-what)).
- [ ] **30** Meet the team's main customers and stakeholders: the teams that depend on the platform, and whoever sends the most requests. Ask what it's like to work with the team.
- [ ] **30** Find out how the team feels about Scrum itself. Teams that experienced it as overhead need it to earn its place again.

## 2. How work arrives

- [ ] **30** Map every way work reaches the team: the backlog, tickets, chat messages, incidents, on-call pages, requests in meetings, and the manager's direct asks.
- [ ] **30** For two sprints, track how much work was planned and how much arrived during the sprint. Unplanned work is usually a bigger share than the team believes until it's counted.
- [ ] **30** Find out how interrupts are handled today: a rotation, whoever's free, or everyone at once.
- [ ] **30** Check the board matches reality: is everything the team works on visible on it, including operations work?
- [ ] **60** Measure throughput, cycle time, and work item age from the board's history ([Flow and metrics](03-flow-and-metrics.md)). Note the oldest items in progress.

## 3. The events

- [ ] **W1** Attend every event as an observer: planning, the daily scrum, refinement, the review, and the retrospective.
- [ ] **30** For each event, note whether it achieves its purpose ([Running the events](02-running-the-events.md)), how long it takes, and who talks.
- [ ] **30** Check whether sprints have goals, and whether anyone can say what this sprint's goal is.
- [ ] **30** Read the last few retrospectives' actions. Were they done? Teams stop believing in retrospectives when nothing changes.
- [ ] **30** Find out whether the team has a definition of done, and whether it covers operational readiness (monitoring, runbooks, rollback). See the [template](templates/definition-of-done.md).
- [ ] **60** Check whether the sprint review shows working changes to real users, or a status report to managers.

## 4. Impediments

- [ ] **30** Start an impediment log ([template](templates/impediment-log.md)) with everything you've heard. Note which the team can fix and which need someone outside it.
- [ ] **60** Find the impediments that cost the most time: waiting on another team, approvals, environments, flaky pipelines, unclear priorities.
- [ ] **60** Check how the team handles dependencies on other teams, and how long work waits on them.
- [ ] **60** Run a team health check ([template](templates/team-health-check.md)) and compare the results with what you've observed.

## 5. Agree the first changes

- [ ] **60** Share what you've observed with the team in a retrospective, as observations rather than verdicts. Let the team choose what to change first.
- [ ] **60** Agree a working agreement with the team if it doesn't have one ([template](templates/working-agreement.md)).
- [ ] **60** Agree with the product owner how unplanned work is handled and made visible ([Scrum for platform teams](01-scrum-for-platform-teams.md#handling-interrupts)).
- [ ] **90** Have two or three changes running, each with a way to tell whether it helped (for example, cycle time, the share of unplanned work, or how often the sprint goal is met).
- [ ] **90** Hand facilitation of at least one event to a team member. The goal is a team that doesn't need you in every meeting.

## 6. By day 90

- [ ] **90** Share a short summary with the team, the product owner, and the manager: what you found, what changed, what it did, and what's next.
- [ ] **90** Have the top impediments outside the team's control escalated, each with an owner.
- [ ] **90** Agree with the team which metrics you'll keep watching, and review them in retrospectives rather than reporting them upward.
