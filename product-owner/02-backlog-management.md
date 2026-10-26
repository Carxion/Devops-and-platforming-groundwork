# Backlog management

[← Product owner](README.md)

The Product Backlog is the single, ordered list of everything the team might do to improve the product. Kept well, it shows anyone what's coming and why. Kept badly, it's a graveyard of hundreds of old requests nobody will do, and nobody can find what matters.

## A healthy backlog

The DEEP criteria (from Roman Pichler and Mike Cohn) describe a backlog that works:

| Property | Means |
|---|---|
| **Detailed appropriately** | Items near the top are small and clear; items further down can be rough ideas |
| **Estimated** (or at least sized) | The team has a sense of how big the top items are, enough to plan and forecast |
| **Emergent** | It changes as the team learns; reordering and rewriting items is normal |
| **Prioritized** (ordered) | Every item has a place relative to the others; the top is what's next |

Habits that keep it that way:

- **Keep the top two sprints' worth refined**, and leave the rest rough.
- **Prune regularly.** If an item has sat untouched for six months, close it. If it matters, it'll come back with fresh context.
- **One backlog per product,** including technical and operations work, so trade-offs are made in one place.
- **Say where requests go.** Users should know how to ask, and hear back quickly whether and when.

## User stories

A user story describes a need from the user's point of view, so the team understands who it's for and why. The common format, from Connextra:

```text
As a <type of user>,
I want <something>,
so that <the outcome or reason>.
```

```text
As a product engineer creating a new service,
I want a repository template that already deploys to staging,
so that I can show a working service on day one without filing tickets.
```

A story isn't a specification. It's a reminder of a conversation; the details come from talking to the team and to users. Bill Wake's INVEST checklist describes a good one: independent, negotiable, valuable, estimable, small, and testable.

Not every item needs the format. "Upgrade the cluster to Kubernetes 1.34 before 1.32 leaves support" is clear as written; forcing it into "as a platform team I want" adds nothing. Use whatever makes the who and why clear. The [user story template](templates/user-story.md) has the full structure.

## Acceptance criteria

Acceptance criteria say what must be true for an item to be accepted. Write them before the work starts, with the team. Given/When/Then makes them precise and testable:

```text
Given a new repository created from the service template,
When the first pull request is merged,
Then the service is deployed to staging within 15 minutes,
  And its health check, logs, and metrics are visible in the standard dashboard,
  And no ticket or manual step was needed.
```

Acceptance criteria are specific to an item; the team's [definition of done](../scrum-master/templates/definition-of-done.md) applies to every item. Don't repeat the definition of done in each story.

## Splitting work

Items at the top should be small enough to finish in a few days. Split **vertically**: each piece delivers something a user can use, end to end, even if it's narrow. Splitting by technical layer ("the Terraform module," then "the pipeline," then "the docs") gives pieces nobody can use until the last one is done.

Patterns that work for platform features:

| Split by | Example |
|---|---|
| **Environment** | Self-service databases in dev first, then staging, then production |
| **User group** | Works for the two teams who asked first, then generalize |
| **Happy path first** | Create a database; resizing, backups, and deletion follow as separate items |
| **Manual behind the scenes** | The user gets self-service; for now, a script the team runs fulfills it, until usage proves it's worth automating |
| **Options** | One database engine first; others later if there's demand |
| **Interface** | A command-line tool first; a web interface later |
| **Spike first** | When the team doesn't know how, a time-boxed investigation that ends with an answer and the real items |

## Technical work, debt, and operations work

These belong in the same backlog as features, because they compete for the same capacity. Make each one weighable:

| Kind | Write it as | Example |
|---|---|---|
| **Technical debt** | The cost of not fixing it, in terms users or the business feel | "Deploys take 25 minutes because of the old build cache; fixing it saves every team about 20 minutes per deploy" |
| **Reliability** | The risk, and the error budget it affects | "The single NAT gateway is a single point of failure for all private services; it failed twice last year" |
| **Upgrades and end-of-life** | The deadline and what happens after it | "Kubernetes 1.32 leaves support in two months; after that, no security patches" |
| **Toil reduction** | Hours per week saved, and the requests it removes | "Manual certificate renewals take 3 hours a month and caused one outage" |
| **Operations requests** | Usually not backlog items: handled through the team's request process | Access requests, quota increases (unless the fix is making them self-service) |

The tech lead brings technical items with reasons; the product owner orders them against everything else. If technical work never wins, agree a fixed share of capacity for it ([balancing run, improve, and build](03-prioritization.md#balancing-run-improve-and-build)).

## Next

[Prioritization](03-prioritization.md).
