# Assessing an inherited system

[← Tech lead checklist](README.md)

The [checklist](README.md) says *what* to find out in your first 60 days; this guide is *how*. It turns sections [2](README.md#2-evaluating-the-programs-problems) (evaluating problems) and [9](README.md#9-306090-day-deliverables) (30/60/90 deliverables) into a working method: map the system, trace a change and an incident through it, read its history, talk to the people, score the risks, and present what you found.

The output is the set of [templates](templates/) the checklist asks for by day 30 and day 60: a system inventory, a metrics baseline, a risk register, a findings register, and a findings report.

| Step | Produces | Checklist |
|---|---|---|
| [1. Map the system](#1-map-the-system) | [System inventory](templates/system-inventory.csv), a context diagram | 9, by day 30 |
| [2. Follow a change to production](#2-follow-a-change-to-production) | Pipeline map with timings; baseline metrics | 2.2, 5, 6 |
| [3. Follow an incident](#3-follow-an-incident) | How detection and response really work | 8 |
| [4. Read the history](#4-read-the-history) | Evidence from incidents, tickets, commits, and costs | 2.1 |
| [5. Talk to people](#5-talk-to-people) | Pain inventory | 1.3, 2.3 |
| [6. Inspect the code and configuration](#6-inspect-the-code-and-configuration) | Observations about build, tests, IaC, and security | 4, 7 |
| [7. Score the risks](#7-score-the-risks) | [Risk register](templates/risk-register.csv) | 9, by day 30 |
| [8. Synthesize and present](#8-synthesize-and-present) | [Findings register](templates/findings-register.csv) and [findings report](templates/findings-report.md) | 2.4 to 2.6 |

Do steps 1 to 6 in parallel over the first four weeks, rather than one after another: interviews tell you where to look in the history, and the history tells you what to ask in interviews.

**Ground rule:** observe before you judge. Everything in an inherited system was someone's reasonable decision under constraints you can't see yet. Write observations ("deploys need three manual approvals"), not verdicts ("the release process is broken"). Verdicts come at step 8, with evidence.

---

## 1. Map the system

Build the [system inventory](templates/system-inventory.csv): every service, data store, pipeline, environment, account or subscription, and external dependency, with an owner for each. Don't trust a single source; reconcile several:

| Source | What it tells you | How |
|---|---|---|
| The cloud's own resource lists | What actually exists, including what nobody mentioned | AWS: [resource inventory](../devops/aws/README.md) and the tagging API; Azure: [Resource Graph](../devops/azure/README.md#make-output-usable) |
| Infrastructure as code and its state | What's managed, and therefore what isn't | `terraform state list` in each stack ([Terraform operations](../devops/terraform/OPERATIONS.md)); compare with the cloud's list to find unmanaged resources |
| Pipeline definitions | How things get built and where they're deployed | The CI system's configuration files in each repository |
| DNS zones and load balancers | What's exposed, and to whom | Every public name is an entry point; each needs an owner |
| Cost reports by service and tag | What's big, what's growing, what's untagged | The [AWS](../devops/aws/guides/cost.md) and [Azure](../devops/azure/guides/cost.md) cost guides |
| Monitoring and alert configuration | What someone cared enough to watch | Alert rules and dashboards; what's missing is a finding |
| Identity: roles, groups, service principals | Who and what can change things | The [AWS](../devops/aws/guides/identity-and-access.md) and [Azure](../devops/azure/guides/identity-and-access.md) identity guides |
| People | Everything the tools don't show | Ask each team: "What would break if this disappeared tomorrow?" |

Then draw a **context diagram**: the system as one box, its users, and every external system it talks to, with arrows for data flows. Next, a **container diagram**: the services, data stores, and queues inside. (These are the first two levels of the [C4 model](https://c4model.com/).) Have the team correct it; their corrections are themselves findings about shared understanding.

Signals to note as you go: resources with no owner, no tags, or no IaC; environments that differ from each other in ways nobody can explain; anything only one person understands.

## 2. Follow a change to production

Pick a real, recent, ordinary change, such as a small bug fix, and trace it from the first commit to running in production. Ask the engineer who made it to walk you through. Record each stage and how long it took:

| Stage | Questions |
|---|---|
| Ticket to first commit | How is work assigned? How long did it wait? |
| Commit to pull request merged | How long did review take? How many reviewers? What checks ran? |
| Merge to artifact built | How long did CI take? Did it fail and get retried? Is the artifact built once and promoted, or rebuilt per environment? |
| Artifact to test environments | Automatic or manual? Who triggers it? |
| Approvals | Who approved, through what system, and how long did the change wait for them? |
| Deploy to production | Automated or a person following steps? How is success verified? How would it roll back? |
| After deploy | Who would know if it broke, and how? |

This one walk-through gives you a first estimate of change lead time, shows where work waits, and reveals manual steps no document mentions. Do it for two or three changes from different teams before generalizing. Then measure properly across many changes for the [metrics baseline](templates/metrics-baseline.csv), recording the method beside each number so you can repeat it at day 90.

## 3. Follow an incident

Take a recent incident and walk it end to end, with the people who handled it:

- **Detection:** did monitoring catch it, or a user? How long between the start of impact and the first alert?
- **Response:** who was paged, was there a runbook, did it help, who had the access needed?
- **Recovery:** what fixed it, how long did it take, and was the fix a rollback, a config change, or code?
- **Follow-up:** was there a review, what actions came out of it, and were they done?

Then read the last 6 to 12 months of incident reports and look for patterns: repeat causes, services that appear again and again, actions that were never completed. A pattern of unfinished review actions is a stronger finding than any single incident. The [observability](../devops/observability/README.md) and [on-call](../manager/04-on-call-and-team-health.md) guides describe what good looks like.

## 4. Read the history

Systems and teams leave evidence. Collect it before forming opinions:

- **Incident reports and postmortems** (step 3)
- **Audit findings, open remediation plans, and accepted risks**: what's known and agreed to be wrong
- **Vulnerability scans:** count and *age* of open findings by severity; anything in the known-exploited catalog is urgent
- **Tickets:** the oldest open ones, what gets reopened, what's always deprioritized
- **Cost trend** over several months, by service
- **Pipeline data:** build durations, failure rates, retries

### What the commit history shows

Version control is the most honest record of how a system really changes. Run these in each important repository (they work on any Git repository):

```sh
# Who has committed in the last year, and how much: a first look at the bus factor
git shortlog -sn --no-merges --since="1 year ago" HEAD

# The 15 files changed most often in the last year: where the change and the bugs concentrate
git log --since="1 year ago" --format= --name-only --no-merges | grep -v '^$' | sort | uniq -c | sort -rn | head -15

# For one directory: how many distinct people changed it in the last year (1 means one person holds that knowledge)
git log --since="1 year ago" --format='%aN' --no-merges -- path/to/component | sort -u | wc -l

# How often commits mention fixes, month by month: a rough signal of churn and quality
git log --since="1 year ago" --no-merges --format='%ad %s' --date=format:%Y-%m | grep -iE ' (fix|hotfix|revert)' | cut -d' ' -f1 | uniq -c
```

The second command, broken down (see [complex commands](../devops/bash/07-complex-commands.md) for more):

| Part | Does |
|---|---|
| `git log --since="1 year ago" --no-merges` | Every non-merge commit in the last year |
| `--format= --name-only` | Print no commit details, just the names of the files each commit changed |
| `grep -v '^$'` | Drop the blank lines between commits |
| `sort \| uniq -c \| sort -rn \| head -15` | Count how many commits touched each file, most-changed first |

Files that change often and that only one person touches are the system's highest-risk knowledge. Treat these numbers as prompts for conversations, never as measures of individual people.

## 5. Talk to people

Ask engineers, operators, application teams, security, and the people who use the system the same three questions:

1. **What slows you down?**
2. **What scares you?** (The answer is often the best risk signal you'll get.)
3. **What do you work around?**

And, for longer conversations, the [first-conversation questions](templates/first-conversation-questions.md).

- **Sample widely,** not just the loudest or most senior voices. New hires notice friction that veterans have stopped seeing. Operators and on-call engineers know where the system really breaks.
- **Ask about specifics:** "Tell me about the last time a deploy went wrong" gets a better answer than "How are deploys?"
- **Listen without fixing.** If you propose a solution in the first conversation, people tell you less in the second.
- **Write observations, not solutions,** with the source: "Three of five engineers named the shared staging environment as the main blocker."
- **Confirm before reporting.** A claim from one interview is a lead; corroborate it with data or a second source.

## 6. Inspect the code and configuration

You don't need to read everything. Check the things that predict trouble:

| Check | How | Why it matters |
|---|---|---|
| Can someone new build and run it from the README? | Try it yourself, timing how long it takes | If you can't, neither can the next new hire or the person on call at 3 a.m. |
| Are there tests, and do they run in CI? | Look at the pipeline and coverage reports | Untested code changes slowly and breaks often |
| Secrets in the repository or its history? | A secret scanner such as gitleaks over the full history | Leaked credentials must be rotated, not just deleted |
| How old are the dependencies and base images? | Dependency manifests, `FROM` lines, scanner output | Old dependencies are both vulnerabilities and upgrade debt |
| Is infrastructure in code, and does the code match reality? | `terraform plan` against each environment: unexpected changes mean drift | Drift means the code can't be trusted to rebuild anything |
| Do environments match? | Compare IaC variables and configuration across dev, test, and prod | Differences explain "works in staging" failures |
| Are runbooks current? | Pick three alerts and follow their runbooks | Stale runbooks fail exactly when needed |
| How are images and artifacts built? | Dockerfiles, build scripts ([Docker security](../devops/docker/06-security.md)) | Root containers, unpinned bases, and secrets in layers are common |

The [devops](../devops/README.md) folder has reference implementations to compare against: what a hardened [Kubernetes workload](../devops/kubernetes/README.md), a secured [Terraform stack](../devops/terraform/README.md), or a [Dockerfile](../devops/docker/02-dockerfiles.md) looks like.

## 7. Score the risks

Findings describe what's true now. **Risks** describe what could happen: "If the one engineer who knows the billing pipeline leaves, then month-end billing can't be fixed when it fails." Keep them in the [risk register](templates/risk-register.csv), written as "if..., then...", and score each on two 1 to 5 scales:

| Score | Likelihood (in the next 12 months) | Impact |
|---|---|---|
| 1 | Rare: hard to imagine | Negligible: internal inconvenience |
| 2 | Unlikely: could happen, hasn't | Minor: a short outage of a non-critical service, small cost |
| 3 | Possible: has happened elsewhere, or once here | Moderate: noticeable customer impact, hours of outage, a reportable compliance gap |
| 4 | Likely: has happened here, or the conditions are present | Major: extended outage of a critical service, data loss with recovery, a failed audit |
| 5 | Almost certain: expected without action | Severe: data breach, unrecoverable data loss, regulatory action, extended outage of the core business |

**Score = likelihood × impact.** As a default:

| Score | Treat as | Action |
|---|---|---|
| 15 to 25 | High | Raise with your manager now; don't wait for the readout |
| 8 to 12 | Medium | Plan a response in the roadmap |
| 1 to 6 | Low | Record; accept or revisit later |

Use your organization's own risk scale instead if it has one; consistency with how leadership already reads risk matters more than the exact numbers.

**Red flags to escalate immediately,** whatever their score:

- Shared or unrotated administrator or root credentials, or long-lived keys in code or CI
- Backups that have never been restored, or no backups of a critical data store
- Internet-exposed vulnerabilities in the known-exploited catalog
- Storage or databases open to the internet
- Production knowledge, access, or recovery depending on one person
- Audit logging turned off, or logs nobody can access

Share the **top five risks privately with your manager by day 30** (checklist section 9), before any group sees them.

## 8. Synthesize and present

1. **Write each finding up** in the [findings register](templates/findings-register.csv) as an observation with evidence, then classify it ([2.4](README.md#24-classify-each-problem)): symptom or cause, constraint type, owner, impact, effort.
2. **Group symptoms under causes.** Ten findings often come down to two or three causes. "Slow pipelines", "flaky tests", and "engineers skip CI" may all be one under-resourced build system.
3. **Prioritize** ([2.5](README.md#25-prioritize)): active security and availability exposure first, then two or three quick wins to build trust, then impact relative to effort. State what you're deliberately not fixing.
4. **Draft the [findings report](templates/findings-report.md):** a summary someone can stop after, what's working, the top five to seven findings with evidence, proposed priorities, and what you need from each stakeholder.
5. **Pre-brief individually** ([2.6](README.md#26-present-findings)): your manager first, then each owner of an area a finding touches. Nobody should hear about a problem in their area for the first time in a group meeting. Pre-briefs also catch your mistakes before they're public.
6. **Present,** then turn agreed findings into the [roadmap](templates/roadmap.md) by day 90.

## Traps

| Trap | Instead |
|---|---|
| Proposing solutions in week one | Collect observations for at least the first month |
| Recommending the tools you used at your last job | Describe the problem first; let the solution follow from the constraints here |
| Treating one bad incident as a trend | Look for patterns across months of evidence |
| Talking only to leadership, or only to engineers | Sample every role, including users and on-call |
| Assuming every oddity is a mistake | Ask why it's that way; many are answers to constraints you haven't met yet |
| Findings that read as blame | Describe systems and conditions, credit what works, and never name individuals in findings |
| Trying to assess everything | Go deep on the critical paths (deploys, incidents, the data that matters) and note the rest as "not assessed" |
