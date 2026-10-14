# Worked example: the first 90 days on a fictional program

[← Tech lead checklist](README.md)

The [checklist](README.md) and the [assessment method](assessing-an-inherited-system.md) are abstract by design. This page shows what they produce, by following a tech lead through 90 days on an invented program. Every name, number, and finding here is **fictional**: the point is the shape of each deliverable, so you can see what "done" looks like before you start your own.

## The setup

**Example Freight** (a placeholder company) runs an order and shipment-tracking platform for its customers. The platform team of six engineers maintains:

- About 30 services on a Kubernetes cluster in one AWS account, plus a second, older account with three EC2-based services nobody has touched in two years
- A PostgreSQL database (managed), a message queue, and object storage for shipping documents
- CI in a hosted CI service; deploys to production by a script an engineer runs from their laptop after a change-approval meeting on Thursdays
- Terraform for the newer account, partially; the older account was built by hand

**Alex**, the new tech lead, joins after the previous lead moved to another team. Alex's manager, **Sam**, says the priorities are "fewer outages, and product teams keep complaining that releases are slow."

---

## Week 1: access and first conversations

Following [section 0](README.md#0-access-and-logistics) and [section 1](README.md#1-stakeholders-and-management), Alex gets read-only access to both cloud accounts, the repositories, CI, and the paging tool, and books first conversations with 14 people across the platform team, two product teams, security, support, and finance.

Part of Alex's [stakeholder map](templates/stakeholder-map.csv) after week one:

| Name / role | Organization | What they need from us | What we need from them | Influence | Preferred channel | Last contact |
|---|---|---|---|---|---|---|
| Sam, engineering manager | Platform | Fewer outages, faster releases, a plan by day 90 | Air cover for priorities; budget decisions | H | Weekly one-on-one | Day 2 |
| Priya, product lead | Orders product | Releases more often than weekly | Agreement on what "release" means for them | H | Chat, then meeting | Day 4 |
| Jordan, security lead | Security | Evidence that vulnerabilities get fixed in time | Their scan data and risk-acceptance records | M | Email | Day 5 |
| Casey, support lead | Customer support | Warning before releases; fewer "tracking is down" tickets | Their ticket data by category | M | Chat | Day 5 |

## Day 30: inventory, baseline, and risks

### System inventory (excerpt)

From the [system inventory](templates/system-inventory.csv), reconciled from the AWS resource lists, Terraform state, CI configuration, DNS, and conversations:

| ID | Type | Name | Environment | Owner team | Deploys via | Support status | Notes |
|---|---|---|---|---|---|---|---|
| S-01 | Service | order-api | prod, staging | Platform | Laptop script | Supported | Highest-traffic service |
| S-07 | Service | label-printer | prod | **Unknown** | Manual on EC2 | OS end of life | In the old account; not in Terraform |
| S-12 | Data store | orders-db | prod | Platform | Terraform | Supported | Backups on; **restore never tested** |
| S-19 | Pipeline | release.sh | n/a | Platform (one engineer) | Run by hand | n/a | Only one person has run it this year |

Three findings emerged just from building the inventory: a production service with no owner, an unsupported operating system, and a deploy path that depends on one person.

### Baseline metrics (excerpt)

From the [metrics baseline](templates/metrics-baseline.csv), each with its method:

| Metric | Baseline | Method | Can the team move it? |
|---|---|---|---|
| Change lead time (median) | 9 days | Commit time to production deploy time, last 90 days of release notes and CI data | Partly: the weekly approval meeting sets a floor of up to 7 days |
| Deployment frequency | 1 per week | Release log | Partly: same gate |
| Change fail rate | 22% (11 of 50) | Releases followed by a rollback or hotfix within 48 hours, from release notes and incidents | Yes |
| Failed deployment recovery time (median) | 3.5 hours | Incident start to resolution, for release-caused incidents | Yes |
| CI duration (median / p95) | 24 / 41 minutes | CI system's API, last 30 days | Yes |
| Open critical vulnerabilities | 7, oldest 140 days | Security's scanner export | Yes |

### Top risks (shared privately with Sam on day 28)

From the [risk register](templates/risk-register.csv), scored on the [5 × 5 scale](assessing-an-inherited-system.md#7-score-the-risks):

| ID | Risk | L | I | Score |
|---|---|---|---|---|
| R-01 | If orders-db fails or is corrupted, then we may not be able to restore it, because a restore has never been tested | 2 | 5 | 10 |
| R-02 | If the engineer who runs release.sh is unavailable, then we can't release, including emergency fixes | 4 | 4 | 16 |
| R-03 | If one of the 7 critical vulnerabilities is exploited (two are in the known-exploited catalog), then customer data could be exposed | 3 | 5 | 15 |
| R-04 | If label-printer's unsupported OS is compromised, then an attacker has a foothold in a production account, with no owner to notice | 3 | 4 | 12 |
| R-05 | If change failure stays at 22%, then outages continue at about one a fortnight, eroding customer trust | 4 | 3 | 12 |

R-02 and R-03 scored **High** (15 or more), so Alex raised them with Sam in week four instead of waiting for the readout, as the scoring guidance says. Sam agreed to an immediate fix for R-03's two known-exploited vulnerabilities.

## Day 60: findings

### Pain inventory, condensed

Alex asked everyone the [three questions](assessing-an-inherited-system.md#5-talk-to-people): what slows you down, what scares you, what do you work around? Recurring answers:

- "Releases are a whole Thursday. If something breaks, it's Friday too." (four engineers)
- "Only one of us really knows release.sh." (three engineers, including that one)
- "Staging doesn't match production, so we test in production by accident." (two engineers, one product lead)
- "We find out tracking is down from customers." (support)

### Findings register (excerpt)

| ID | Observation | Symptom / cause | Constraint type | Owner | Impact | Effort | Priority |
|---|---|---|---|---|---|---|---|
| F-01 | Production deploys run from one engineer's laptop by a manual script | Cause | Removable | Platform | Delivery speed, availability | M | P1 |
| F-02 | Releases wait up to 7 days for a weekly approval meeting; 48 of the last 50 were approved without changes | Cause | Relocatable | Change board chair | Delivery speed | S (conversation) | P2 |
| F-03 | Staging differs from production in database version and three feature flags | Cause | Removable | Platform | Availability | M | P2 |
| F-04 | 7 critical vulnerabilities, oldest 140 days; two in the known-exploited catalog | Symptom (no patching cadence) | Removable | Platform with Security | Security | S to M | P1 |
| F-05 | Alerts are on CPU and memory; none on order errors or tracking freshness | Cause | Removable | Platform | Availability | S | P2 |
| F-06 | label-printer runs an unsupported OS in an account with no owner | Symptom | Removable | Unknown | Security | M | P2 |
| F-07 | Database restore never tested | Cause | Removable | Platform | Availability | S | P1 |

Note the move from symptoms to causes: "releases are slow" (the complaint) breaks down into F-01, F-02, and F-03. And F-02 is **Relocatable**, not Removable: the approval is a real control, but the review could move into the pipeline as an automated standard change for low-risk releases, which needs the change board chair's agreement, not the team's.

### Findings report (summary section)

From the [findings report](templates/findings-report.md):

> **Summary.** The platform is fundamentally sound: the newer account is mostly in Terraform, the cluster is well configured, and the team handles incidents calmly. Three problems drive most of the outages and slow releases: deploys depend on one person and a laptop script (F-01), the weekly approval gate adds up to seven days to every change (F-02), and staging doesn't match production (F-03). Two security items need action now: critical vulnerabilities in the known-exploited catalog (F-04), and a never-tested database restore (F-07). I'm asking for agreement on these priorities, the change board's help to make routine releases a pre-approved standard change, and a decision on who owns label-printer.

Before presenting, Alex pre-briefed Sam, then the change board chair (because F-02 was about their process) and the engineer who runs release.sh (so they heard "this depends too much on one person" as a risk to them, not a criticism). The chair suggested the standard-change route themselves.

### Quick wins (shipped by day 60)

| Win | Effort | Result against baseline |
|---|---|---|
| Patched the two known-exploited vulnerabilities | 2 days | Critical count 7 → 5; known-exploited 2 → 0 |
| Tested a database restore in a scratch environment | 1 day | Restore works; took 47 minutes. Documented as a runbook. R-01 likelihood lowered |
| Added alerts on order error rate and tracking freshness | 3 days | Caught a tracking outage in week 8 before support did |

## Day 90: roadmap

From the [roadmap](templates/roadmap.md):

| Goal | Measure | Baseline | Target | By | From findings |
|---|---|---|---|---|---|
| Anyone on the team can release safely, any day | Engineers who've released in the quarter | 1 | 6 | Q2 | F-01 |
| Routine changes ship within a day | Change lead time (median) | 9 days | 1 day | Q3 | F-01, F-02, F-03 |
| Fewer release-caused incidents | Change fail rate | 22% | Under 10% | Q3 | F-01, F-03 |
| No critical vulnerability older than 30 days | Oldest open critical | 140 days | 30 days | Q2 | F-04 |

| Quarter | Item | Owner |
|---|---|---|
| Q2 | Move production deploys into CI with the same steps as release.sh, then retire the script ([migration guide](migrations-and-cutovers.md)) | Platform |
| Q2 | Monthly patching cadence; vulnerability age on the team dashboard | Platform with Security |
| Q2 | Standard-change process for low-risk releases, agreed with the change board | Alex with the change board chair |
| Q3 | Rebuild staging from the same Terraform as production | Platform |
| Q3 | Migrate label-printer into the main account and Terraform, or retire it (owner decision first) | Owner TBD by Sam |

**Non-goals for the next two quarters:** replacing the CI system (it isn't the bottleneck), moving to a service mesh (no problem it would solve yet), and multi-region (cost not justified by current availability needs). Writing these down stopped three recurring debates.

**Capacity:** measured run work was 45% of the team's time. The plan protects 20% for improvement and puts roadmap items in the remaining 35%, which is why the list is short.

## What Alex got wrong (the 90-day retrospective)

The checklist's last day-90 item is your own retrospective. Alex's:

- **Assumed the approval meeting was the main delay,** from the complaints, before measuring. The data showed staging mismatches caused as many delays (failed releases rescheduled to the next week). The baseline corrected it before the readout.
- **Waited too long to talk to support.** Their ticket data was the best evidence of customer impact, and arrived in week five instead of week one.
- **Underestimated the run work.** The first draft roadmap assumed 70% capacity for projects. Measuring on-call and requests gave 35%.
- **What worked:** pre-briefing the change board chair turned the likeliest opponent of F-02 into its sponsor.

## Using this example

- Your numbers, findings, and priorities will differ; the *structure* is what carries over: evidence behind every finding, symptoms traced to causes, constraint types that tell you who can change what, risks scored and escalated early, quick wins measured against the baseline, and a roadmap with non-goals and a real capacity number.
- Keep your real versions in your organization's systems, not in a public repository.
