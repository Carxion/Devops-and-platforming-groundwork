# Hiring and onboarding

[← Manager](README.md)

## Define the role before you interview

Write down what the person will actually do in their first year, then the skills that needs. For platform and DevOps roles, be specific: "operate and evolve our EKS clusters and Terraform modules, share on-call for the platform" says far more than "DevOps engineer, 5+ years of Kubernetes".

Separate:

- **Must have on day one,** which you'll test for: for example, debugging a Linux system, reading and writing infrastructure code, reasoning about failure.
- **Can learn on the job,** which you won't filter on: your specific cloud, your CI system, your observability stack. Teaching a strong engineer a tool takes weeks; the reverse takes years.

## Structured interviews

Every candidate for the same role gets the same questions, scored against the same written criteria, by interviewers who each cover a different area. That's both fairer and more predictive than unstructured conversations, where interviewers mostly measure how much the candidate resembles them.

| Stage | Assesses | Example |
|---|---|---|
| Screen (30 min) | Basic fit, motivation, logistics | Their most interesting recent problem, and why they want this role |
| Technical deep dive (60 min) | Depth in their own experience | Walk through a system they ran: how it failed, how they knew, what they changed |
| Practical exercise (60 to 90 min) | Doing the work | Troubleshoot a broken service in a sandbox, or review a Terraform or Kubernetes change for problems |
| Collaboration (45 min) | How they work with others | An incident or disagreement: what happened, what they did, what they'd do differently |

**Work samples beat puzzles.** For operations roles, the best exercise is close to the job: a container that won't start, a pipeline that fails, a pull request with a security flaw. The [Docker troubleshooting](../devops/docker/08-troubleshooting.md) and [Kubernetes operations](../devops/kubernetes/OPERATIONS.md) guides are a good source of realistic, broken-on-purpose scenarios. Keep take-home work short (two hours at most) and say so.

Score each area separately on a written scale (for example 1 to 4, with what each score means) before the debrief, so the first opinion voiced doesn't anchor everyone else's.

## Onboarding new engineers

A new engineer's first weeks shape how they work for years. Plan them, the same way the [tech lead checklist](../tech-lead/README.md) plans a tech lead's first 90 days.

### Before day one

- Accounts, laptop, and access requested (cloud accounts, repositories, CI, chat, paging tool), so day one isn't spent waiting.
- A **buddy** named: a peer, not the manager, for the hundred small questions.
- The onboarding doc reviewed and current.

### First week

- Meet the team, the manager, and the main stakeholders.
- Get the development environment working, and **ship a small change to production** (a documentation fix, a small config change) through the normal pipeline. It proves the access and teaches the path.
- Read the team page, the architecture overview, and the runbooks for the most common alerts.

### First 30 days

- Pair on real work, then take tickets alone.
- Shadow on-call for a rotation: watch, ask, don't carry the pager yet.
- **Fix the onboarding docs** wherever they were wrong or missing. New people see the gaps that everyone else has stopped noticing.

### By 60 to 90 days

- Join the on-call rotation, with a secondary or the buddy as backup the first time.
- Own a small project end to end.
- A conversation about how it's going, in both directions: what's working, and what onboarding should change for the next person.

### Access, done safely

Grant access by role through groups, not one person at a time, and with the least privilege the work needs ([identity and access](../devops/aws/guides/identity-and-access.md)). Production write access and on-call come after the person has seen how things work, not on day one. Have the same process for **offboarding**: removing access on the last day is as important as granting it on the first.
