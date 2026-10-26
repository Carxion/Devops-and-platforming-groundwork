# Solutions architect

[← DevOps and Platforming Groundwork](../README.md)

For solutions architects working on cloud, DevOps, and platform engagements: the people who turn a business problem into a solution someone will fund, and who stay accountable until it's delivered. The role looks the same whether you work for a vendor, a consultancy, a systems integrator, or an internal platform team that "sells" to the rest of the company. New to the role? Start with [your first 90 days](00-first-90-days.md).

The [architect](../architect/README.md) guides cover *what makes a design good*: quality attributes, reliability, security, cost. These guides cover the rest of the job: finding out what problem actually needs solving, shaping a solution the stakeholders will agree to, writing it up as a proposal, and presenting it so the right people decide. A technically excellent design that nobody funds, or that solves the wrong problem, is a failure of the solutions architect, not the audience.

| Guide | Covers |
|---|---|
| [Your first 90 days as a solutions architect](00-first-90-days.md) | A W1/30/60/90 checklist: learn the offering and the customers, shadow engagements, then run discovery, a design, and a proposal yourself |
| [The role](01-the-role.md) | What a solutions architect owns, how the role differs from enterprise, platform, and technical architects, and where it fits in an engagement from first call to handover |
| [Discovery and requirements](02-discovery-and-requirements.md) | Running discovery: business drivers, current state, requirements, constraints, and success criteria; good questions and the traps |
| [Designing the solution](03-designing-the-solution.md) | From requirements to options, choosing between them, reference architectures, proofs of concept, estimating effort and cost, and risks |
| [Working with stakeholders](04-working-with-stakeholders.md) | Who's in the room and what each wants, building trust, managing scope and expectations, disagreement, and handing over to delivery |
| [Preparing a proposal](05-preparing-a-proposal.md) | The structure of a proposal that gets approved, the executive summary, scope and assumptions, pricing, responding to an RFP, and reviewing before it goes out |
| [Presenting the solution](06-presenting.md) | Knowing the audience, structuring the story, diagrams, live demos, whiteboarding, handling questions and objections, and presenting remotely |

## Templates

[templates/](templates/README.md): discovery guide, solution design document, proof-of-concept plan, proposal, presentation plan, and delivery handover.

## The short version

When there's no time for the rest of the folder, these eight habits cover most of it:

1. **Find the business problem before the technical one.** "Move to Kubernetes" is a solution. "Releases take three weeks and the competitor ships daily" is a problem. ([Discovery](02-discovery-and-requirements.md))
2. **Agree how success will be measured** before designing anything, in numbers the sponsor cares about.
3. **Show options, not one answer,** with the trade-offs in plain terms, and recommend one. ([Designing the solution](03-designing-the-solution.md))
4. **Write the assumptions and exclusions down.** Most failed engagements fail on something nobody wrote down. ([Preparing a proposal](05-preparing-a-proposal.md))
5. **Know who decides,** who influences, and who can block, and meet each of them before the big meeting. ([Working with stakeholders](04-working-with-stakeholders.md))
6. **Lead with the answer.** The first two minutes of a presentation or the first page of a proposal should be enough to decide on. ([Presenting](06-presenting.md))
7. **Prove the riskiest assumption cheaply,** with a time-boxed proof of concept and success criteria agreed in advance.
8. **Never sell what can't be delivered.** The delivery team inherits every promise you make; involve them before you make it.

## Working with the other roles

The solutions architect owns the solution's shape and the case for it, up to the point it's agreed and handed to the people who build it. The [architect](../architect/README.md) sets the standards and foundations that solutions have to fit; the [tech lead](../tech-lead/README.md) owns technical direction once delivery starts; the [product owner](../product-owner/README.md) owns what an internal platform builds and why; the [manager](../manager/README.md) owns the people. On a small engagement one person may hold several of these roles. Say which hat you're wearing when it matters.

> **Status.** Starter content: practitioner defaults, with named sources for the frameworks they draw on: the [C4 model](https://c4model.com/), the AWS and Azure [Well-Architected](https://aws.amazon.com/architecture/well-architected/) and Cloud Adoption Frameworks, and Barbara Minto's pyramid principle.
