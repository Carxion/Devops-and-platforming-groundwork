# Planning and metrics

[← Manager](README.md)

## Plan for interrupts, not just projects

Platform and operations teams are interrupt-driven: incidents, requests from product teams, security patches, expiring certificates. Plans that assume the whole team works on roadmap projects fail every time, and the team looks unreliable when it's actually overloaded.

Make the split explicit, and measure it:

| Bucket | Examples | Typical share |
|---|---|---|
| **Run** (keeping things going) | On-call, incidents, requests, patching, upgrades | Measure it: often 30 to 50% on teams that haven't automated much |
| **Improve** (reducing future run work) | Automation, alert cleanup, technical debt, reliability fixes | At least 20%, protected |
| **Build** (new capability) | New platform features, migrations, projects for other teams | Whatever's left |

Google's SRE practice caps operational toil at 50% of an engineer's time, because past that, the team can no longer reduce it ([Site Reliability Engineering, "Eliminating Toil"](https://sre.google/sre-book/eliminating-toil/)). If "run" keeps growing, the answer is more "improve", not more people doing the same toil.

A simple way to make interrupts visible: put a rotating **interrupt handler** (often the on-call engineer) on all incoming requests and small issues for the week, so everyone else can focus.

## Roadmaps

- **Outcomes, not just outputs.** "Deployments take under 15 minutes and need no manual steps" is a goal; "migrate to Argo CD" is one way to get there.
- **A quarter in detail, the next two roughly,** and revisit monthly. Further ahead, write themes.
- **Show what's not on it,** and why. Saying no clearly is part of the plan.
- **Include the run work** and its expected size, so nobody's surprised when a big upgrade takes a sprint.
- Agree it with stakeholders ([Stakeholders](05-stakeholders-and-communication.md)) and publish it where they can see it.

## Technical debt

Every system accumulates it. Manage it like any other work:

- **Keep a register** with the cost of each item in terms stakeholders understand: hours of toil a month, incident risk, how much slower a kind of change is. The [findings register](../tech-lead/templates/findings-register.csv) works for this.
- **Pay down continuously** from the "improve" budget, rather than waiting for a rewrite that never gets approved.
- **Prioritize by cost and risk,** not by how annoying it is: an end-of-life Kubernetes version or an unsupported OS goes ahead of an awkward script.
- **Stop adding more:** reviews and [definitions of done](../GLOSSARY.md#delivery-teams-and-governance) catch new debt cheaper than paying it back later.

## Measuring delivery: the DORA metrics

The [DORA research program](https://dora.dev/guides/dora-metrics/) has studied software delivery for over a decade. Its metrics measure the delivery system, in two groups:

| Group | Metric | Definition (DORA's) |
|---|---|---|
| Throughput | **Change lead time** | Time for a change to go from committed to version control to deployed in production |
| Throughput | **Deployment frequency** | Number of deployments over a period, or the time between them |
| Throughput | **Failed deployment recovery time** | Time to recover from a deployment that fails and needs immediate intervention |
| Instability | **Change fail rate** | Share of deployments that need immediate intervention (a rollback or hotfix) |
| Instability | **Deployment rework rate** | Share of deployments that are unplanned, made because of an incident in production |

DORA's finding is that throughput and stability go together: the teams that deploy most often also fail least and recover fastest, because small, frequent changes are easier to test, review, and roll back.

How to use them well:

- **Measure teams and systems, never individuals.** Metrics tied to people's performance get gamed, and stop measuring anything.
- **Look at trends, not single numbers,** and compare a team to its own past, not to other teams with different systems.
- **Use them to find constraints.** Long lead time? Look at review waits, slow pipelines, and manual approvals. High change fail rate? Look at test coverage and deployment strategy. They point to where to look, not to the answer.
- **Get the data from the systems,** not from surveys where possible: deployment events from CI/CD, incidents from the incident tool. The [observability stack](../devops/observability/README.md) can chart them.

Pair them with **reliability** (are SLOs met? see [observability](../devops/observability/README.md#slos-and-alerting)) and **team health** ([On-call and team health](04-on-call-and-team-health.md)): fast delivery that burns out the on-call rotation isn't success.

## Estimates

- Estimate in ranges, and say what the range depends on: "two to four weeks, depending on whether the old cluster's add-ons work on the new version."
- Break large work into pieces small enough to finish in a few days; most estimation error lives in the parts nobody broke down.
- Track how estimates compared with reality, as a team, without blame, to calibrate.
- For platform work, include the migration: building the new thing is often half the work, and moving every team onto it is the other half.
