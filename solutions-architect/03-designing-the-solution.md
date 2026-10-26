# Designing the solution

[← Solutions architect](README.md)

With the problem, requirements, and constraints agreed, the design work is to find the options, choose between them honestly, prove what's uncertain, and estimate what it will take. The [architect](../architect/README.md) guides cover what makes a design technically sound; this guide covers how a solutions architect gets from requirements to a recommendation the customer can act on. The [solution design template](templates/solution-design.md) follows the same order.

## Start from the requirements, not the technology

Before drawing anything, write down the three to five requirements that will drive the design: usually the hardest quality attributes and constraints. "Recovery within 1 hour in another region", "data stays in the EU", "the operations team knows Windows, not Linux", "live in 4 months." These are the tests every option has to pass, and they explain the design to anyone who reads it later.

Then check them against the ten questions in the [architect README](../architect/README.md#the-ten-questions-to-ask-of-any-platform-design). Any question you can't answer is a gap in discovery, not something to guess.

## Generate real options

Show at least two options, and usually three. One option isn't a choice, it's a request for approval, and it invites the question "what else did you consider?" Make the options genuinely different, not one good option and two straw men.

Common axes that produce real options:

| Axis | For example |
|---|---|
| **Build, buy, or use managed** | Self-run Kubernetes, a managed Kubernetes service, or a managed container platform |
| **How much change** | Rehost as is, replatform onto managed services, or refactor for the cloud |
| **Scope and phasing** | Everything at once, or the riskiest or most valuable part first |
| **Cost against resilience** | Single region with backups, or a warm standby in a second region |
| **Who operates it** | The customer's team, a managed service provider, or your team |

For migrations, both major clouds publish the same family of strategies: retire, retain, rehost, relocate, repurchase or replace, replatform, and refactor or rearchitect. See the AWS [migration strategies](https://docs.aws.amazon.com/prescriptive-guidance/latest/large-migration-guide/migration-strategies.html) and the Azure Cloud Adoption Framework's [migration strategy guide](https://learn.microsoft.com/azure/cloud-adoption-framework/plan/select-cloud-migration-strategy). Deciding per application, not for the whole estate, usually produces a cheaper and safer plan: retire what nobody uses, rehost what's stable, and spend modernization effort where it pays back.

Include **"do nothing"** or **"do the minimum"** as a baseline when it helps the sponsor see the cost of not acting.

## Choose between options

Compare options against the driving requirements, not a generic feature list. The architect's [decision matrix](../architect/templates/decision-matrix.md) makes the weights explicit; agree the weights with the customer *before* scoring, or the scoring looks rigged.

For each option, be able to say in a sentence or two:

- **What it costs:** to build, and to run each year, with the main drivers.
- **How long it takes,** and what has to happen first.
- **What it's good at and bad at,** against the driving requirements.
- **The main risks,** and what would reduce them.
- **What it commits the customer to:** contracts, skills, lock-in, decisions that are hard to reverse ([reversible and irreversible decisions](../architect/01-thinking-like-an-architect.md#reversible-and-irreversible-decisions)).

Then **recommend one,** and say why. The customer is paying for your judgment; a neutral table with no recommendation leaves them to do your job. Keep the alternatives visible so they can see you considered them.

## Use reference architectures, then adapt them

Start from something proven: your organization's reference architectures, the cloud providers' published ones, or the tested [reference stacks](../devops/terraform/README.md) in this repository. They save time and carry lessons already learned.

Then adapt them to this customer's requirements and say where you did. Copying a reference architecture unchanged, without checking it against the requirements, is how a customer ends up paying for multi-region resilience they didn't need, or missing a control their regulator requires.

Check the design against a Well-Architected framework ([AWS](https://aws.amazon.com/architecture/well-architected/), [Azure](https://learn.microsoft.com/azure/well-architected/)) and the [architecture review checklist](../architect/templates/architecture-review-checklist.md) before it goes to the customer. Both catch the gaps that are embarrassing to have pointed out in the meeting.

## Draw it at the right level

Use diagrams that answer the audience's question, and no more:

| Audience | Diagram | Shows |
|---|---|---|
| Sponsor and business | Context | The solution as one box, its users, and the systems it connects to |
| Architects and engineering leads | Containers | The main deployable pieces, data stores, and how they communicate |
| Delivery team | Components and deployment | What runs where, networks, identities, and environments |

The [C4 model](https://c4model.com/) is a simple, widely used way to keep these levels separate. Whatever notation you use, give every diagram a title, a legend, and labeled arrows ("sends orders, HTTPS"). An unlabeled box-and-line diagram means something different to everyone who reads it.

Draw the **current state** too, at the same level. The difference between the two diagrams *is* the project, and it's where the migration effort and risk live.

## Prove what's risky: proofs of concept

A proof of concept (POC) answers a specific question that can't be answered on paper: "Can the legacy system's data be replicated with under 5 minutes' lag?", "Does the product's single sign-on work with their identity provider?" It's not a pilot, and it's not a free first phase.

Run one when a wrong assumption would sink the solution and testing it is cheap compared with being wrong. Then:

1. **Write down the question,** and why it matters to the decision.
2. **Agree the success criteria with the customer before starting,** in numbers: "replication lag under 5 minutes at the nightly peak volume." Criteria agreed afterward always move.
3. **Time-box it,** usually days to a few weeks, and agree what happens at the end: proceed, change the design, or stop.
4. **Build the minimum** that answers the question. A POC that grows into a production system carries POC shortcuts into production.
5. **Report the result honestly,** including a failure. A POC that shows an option won't work has done its job.

The [proof-of-concept plan template](templates/proof-of-concept-plan.md) has the structure.

## Estimating effort and cost

Your estimate becomes someone's budget and someone else's deadline. Make it honest, show how you got it, and give a range.

**Effort.** Break the work into pieces small enough to estimate, ideally with the people who'll do the work or with data from similar past engagements. Estimate each piece as a range, not a single number. Add the work people forget: environments, CI/CD, security reviews, testing, data migration, cutover, documentation, training, handover, and project management.

**Uncertainty shrinks as the work is understood.** Steve McConnell's *Software Estimation: Demystifying the Black Art* describes the "cone of uncertainty": estimates made at the very start of a project can be off by a factor of several in either direction, narrowing as requirements and design firm up. In practice:

| Stage | Give |
|---|---|
| First conversation | An order of magnitude, clearly labeled as such: "this is a few months of work, not a few weeks or a few years" |
| After discovery | A range with its assumptions: "14 to 20 weeks, assuming the two integrations use their documented APIs" |
| After design and any POC | A range narrow enough to commit to, with contingency stated separately |

Don't let an early number become the commitment. If someone asks for a figure before discovery, give the order of magnitude and say what you'd need to narrow it.

**Running cost.** Estimate the cost to run the solution each year, not just to build it, using the providers' pricing calculators and the real expected usage. Show the main cost drivers (compute, storage, data transfer, licenses, support, and the people to run it) and how cost changes with load. The [cost architecture guide](../architect/07-cost-architecture.md) covers the levers. Customers who are surprised by the first cloud bill stop trusting the rest of the proposal.

**Total cost of ownership (TCO).** When comparing with the current state or with alternatives, compare over the same period (often three to five years), including migration, licenses, staff time, and the cost of running both during the transition. Be explicit about what's in and out; TCO comparisons are easy to skew.

## Risks, assumptions, issues, and dependencies

Keep a running list from the first discovery session (often called a RAID log):

| Type | Is | Example |
|---|---|---|
| **Risk** | Something that might happen and would hurt | The vendor API's rate limits may be too low for the nightly sync |
| **Assumption** | Something you're treating as true without proof | The customer's team will provide test data by week 2 |
| **Issue** | Something already going wrong | The security review board doesn't meet until next month |
| **Dependency** | Something the work needs from someone else | Network connectivity to the data center, owned by the customer's network team |

Every item needs an owner. Risks need a likelihood, an impact, and a plan; the tech lead's [risk register](../tech-lead/templates/risk-register.csv) works for this. Assumptions go into the proposal ([Preparing a proposal](05-preparing-a-proposal.md#scope-assumptions-and-exclusions)), because each one is a promise the customer is making to you.

## Get it reviewed before the customer sees it

Before a design goes out:

- **A peer architect** reviews it against the requirements and the review checklist.
- **A delivery lead** reviews the estimate and the plan: could their team build this, in this time, for this cost?
- **Security** reviews anything touching identity, data, or networks, especially if it breaks a standard.
- **Whoever owns pricing and terms** reviews anything commercial.

The [design review guide](../tech-lead/design-reviews-and-rfcs.md#running-the-review) describes how to run a useful review. An internal review that finds a problem is cheap; a customer who finds it is not.

## Next

[Working with stakeholders](04-working-with-stakeholders.md).
