# Migrations and cutovers

[← Tech lead checklist](README.md)

Much of a platform tech lead's roadmap turns out to be migrations: to a new CI system, a new cluster or Kubernetes version, infrastructure as code, a managed database, another region, or another cloud. Building the new thing is often the easier half; moving every service, team, and byte of data onto it, without an outage, is the rest. This guide covers planning a migration, the patterns that make it safe, and running the cutover itself.

## Plan the migration

### Start from the inventory

You can't migrate what you haven't found. From the [system inventory](templates/system-inventory.csv), list everything in scope, with:

- **Owner** and who must agree to its move
- **Dependencies,** in both directions: what it calls, and what calls it (including the hard-coded addresses and firewall rules nobody remembers)
- **Data:** size, how fast it changes, and how much downtime or data loss is acceptable (its RPO and RTO)
- **Risk:** how critical it is, and how well it's understood

### Order the work

- **Start with something real but forgiving:** a low-risk service with an engaged owner. The first move teaches you what the plan missed.
- **Do the hardest one second or third,** not last, while the team still has energy and time to adjust the approach.
- **Group by dependency:** services that share a database usually move together.
- **Leave the long tail visible:** the last 10% of a migration (the odd services, the unowned ones) often takes as long as the first 90%. Track it explicitly, or the old platform never gets switched off.

### Write it down

Significant migrations get an [RFC](templates/rfc-design-doc.md) ([Design reviews and RFCs](design-reviews-and-rfcs.md)) covering the approach, stages, rollback at each stage, and how you'll know it worked. Each risky step gets a [cutover runbook](templates/cutover-runbook.md).

## Patterns that make migrations safe

| Pattern | How it works | Use for |
|---|---|---|
| **Strangler fig** | Route traffic for one piece of functionality at a time to the new system, until the old one has nothing left ([Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html)) | Replacing a large application or platform gradually |
| **Expand and contract** (parallel change) | Add the new form alongside the old, migrate users to it, then remove the old ([Fowler](https://martinfowler.com/bliki/ParallelChange.html)) | Database schema changes, API changes, configuration formats |
| **Parallel run** | Run old and new side by side on the same input, compare outputs, and switch only when they match | Pipelines, calculations, anything where correctness is hard to test |
| **Dark launch / shadow traffic** | Send a copy of real traffic to the new system without using its responses | Performance and capacity testing with real load |
| **Canary migration** | Move a small share of traffic or users first, watch, then increase ([CI/CD glossary](../GLOSSARY.md#continuous-integration-and-delivery)) | Services behind a load balancer or DNS |
| **Blue-green** | Stand up the full new environment, switch everything at once, keep the old one ready to switch back | When gradual movement isn't possible, but a fast rollback is |
| **Big bang** | Everything moves at once, with downtime | Only when nothing else is feasible; needs rehearsal and a tested rollback |

Prefer the patterns near the top: they turn one large, risky event into many small, reversible ones.

### Data is the hard part

Stateless services can move back and forth easily. Data can't, once both systems are taking writes. Decide early:

- **How the data moves:** a snapshot and restore (simple, needs downtime), replication from old to new (little downtime, more setup), or dual writes (complex; avoid unless necessary)
- **The point of no return:** the moment the new system accepts writes the old one doesn't have. Before it, rollback is easy. After it, rollback means moving data *back*. Mark it in every plan.
- **How you'll verify:** row counts, checksums, and sample comparisons between old and new, before switching

## Before the cutover

The [cutover runbook template](templates/cutover-runbook.md) lists these; the ones most often skipped are:

- **A full rehearsal, including the rollback,** in an environment as close to production as you have. Time every step. The rollback is the part people skip rehearsing, and the part that's needed when things are already going wrong.
- **Lowering DNS TTLs** at least one old TTL before the window, so a DNS switch (and a switch back) takes effect quickly.
- **A tested restore** of the data you're moving.
- **Access checked for everyone executing,** by actually logging in, not assuming.
- **Go/no-go criteria written in advance,** so the decision to proceed isn't made under pressure in the moment.

## During the cutover

- **One person leads** and makes the go/no-go, point-of-no-return, and rollback calls. Everyone else executes and verifies.
- **Follow the runbook.** If reality differs from it, stop and decide deliberately; improvising under time pressure is how cutovers turn into incidents.
- **Verify each step independently:** the person who ran a step isn't the one who confirms it worked.
- **Record actual times** against the rehearsal; large differences are early warnings.
- **Roll back on the criteria you wrote,** not on hope. A rollback is a successful use of the plan, not a failure.
- **Communicate at start, at milestones, and at the end,** to the channels in the runbook.

## After the cutover

- **Watch closely** for the first day, and for a full business cycle (a week, a month-end) for anything periodic.
- **Keep the old system read-only** for a set period, so you can compare or recover, then **switch it off on a date.** Old platforms left running "just in case" keep costing money and security attention for years.
- **Hold a short review** whether it went well or not: timings versus rehearsal, what the plan missed, and what the next move should do differently.
- **Update the inventory, diagrams, runbooks, and monitoring.** A migration isn't done until the documentation describes the new world.

## Migrations as a program

When a migration spans many teams (every service onto a new platform, say):

- **Make the new path better, not just mandatory.** Teams move faster to a platform that saves them work. Provide templates, documentation, and help, and remove the old platform's pain from the new one.
- **Do the first few moves with each team,** then provide self-service tooling for the rest.
- **Publish progress:** services migrated, remaining, and blocked, with owners. Visible progress keeps priority.
- **Set the end date early** and agree it with leadership, so the last stragglers have a reason to move.
- **Fund the long tail:** budget time for the unowned and unusual services, or they'll keep the old platform alive.

The [worked example](worked-example.md) includes a small migration: moving production deploys from a laptop script into CI, then retiring the script.
