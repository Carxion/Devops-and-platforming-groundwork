# The role

[← Solutions architect](README.md)

A solutions architect designs a solution to a specific business problem, makes the case for it, and stays accountable for its shape until it's agreed and handed to the people who build it. The job is half technical and half communication, and failing at either half fails the engagement.

## What a solutions architect owns

| Owns | Means |
|---|---|
| **Understanding the problem** | Running discovery, so the solution addresses the business problem and not just the request ([Discovery](02-discovery-and-requirements.md)) |
| **The solution's shape** | The options, the recommendation, the main components and how they connect, and the trade-offs made ([Designing the solution](03-designing-the-solution.md)) |
| **Feasibility** | Confidence that it can be built, run, and paid for: proven where it's risky, estimated where it isn't |
| **The case for it** | A proposal and presentation that let the decision makers decide ([Proposal](05-preparing-a-proposal.md), [Presenting](06-presenting.md)) |
| **Technical trust** | Being the person the customer believes on technical questions, which means saying "no" and "I don't know" when they're true |
| **A clean handover** | Delivery inherits the solution, its assumptions, and its promises, with nothing left in the architect's head ([Working with stakeholders](04-working-with-stakeholders.md#handing-over-to-delivery)) |

What it usually doesn't own: the commercial terms (an account or engagement manager), the delivery plan and day-to-day technical decisions once building starts (the [tech lead](../tech-lead/README.md)), and the organization-wide standards the solution has to meet (the [architect](../architect/README.md) or an enterprise architecture function).

## How it differs from other architect roles

Titles vary between organizations; the work is a better guide than the title.

| Role | Scope | Time horizon | Typical output |
|---|---|---|---|
| **Enterprise architect** | The whole organization's systems and technology strategy | Years | Target state, standards, technology portfolio |
| **Platform or cloud architect** ([architect/](../architect/README.md)) | The shared foundations: landing zones, networks, identity, delivery | Years | Foundations, guardrails, reference implementations |
| **Solutions architect** | One business problem, across whatever systems it touches | Weeks to months | Options, a recommended design, a proposal |
| **Technical or software architect** | One system's internal design | The life of the system | Component design, interfaces, technical decisions |

A solutions architect works *within* the enterprise and platform architects' standards, and *ahead of* the technical architect and tech lead. When a solution needs to break a standard, the solutions architect raises it with whoever owns the standard; they don't quietly design around it.

## The settings

The same skills apply in different settings, with different pressures:

| Setting | The customer | The pressure to watch |
|---|---|---|
| **Vendor (pre-sales)** | An external buyer evaluating your product | Designing around the product rather than the problem. If your product doesn't fit, saying so builds more trust than a stretched design |
| **Consultancy or systems integrator** | A client paying for a project | Winning on a low estimate that delivery can't meet. Your estimate becomes someone else's deadline |
| **Internal platform or IT team** | Other teams in your own company | Being treated as a gatekeeper. Internal customers can route around you, so the design has to be easier than the alternative |

## Where it fits in an engagement

Most engagements, internal or external, follow the same arc. The solutions architect is most active in the middle:

```text
 Qualify  →  Discover  →  Design  →  Propose  →  Decide  →  Hand over  →  Deliver
 is this      what's the    options,    written      the         to the        (delivery
 worth it?    problem?      a POC if    case, price  customer's  delivery      team, with
                            risky       or effort    decision    team          the SA on call)
```

- **Qualify.** Before investing weeks, check that the problem is real, someone has the budget and authority to act on it, and it's something you can solve. A quick "no" saves both sides time.
- **Discover.** Learn the business drivers, current state, requirements, and constraints ([Discovery](02-discovery-and-requirements.md)).
- **Design.** Shape options, choose one, prove what's risky, estimate ([Designing the solution](03-designing-the-solution.md)).
- **Propose and decide.** Write it up and present it so the decision makers can decide ([Proposal](05-preparing-a-proposal.md), [Presenting](06-presenting.md)).
- **Hand over.** Give delivery everything they need, then stay reachable ([handover](04-working-with-stakeholders.md#handing-over-to-delivery)).

The stages overlap and loop. A proof of concept can send you back to discovery; a pricing review can send you back to design. That's normal; the failure is skipping a stage, usually discovery.

## What good looks like

- **Customers describe the solution in their own words,** as a solution to their problem, not as your product or your diagram.
- **Delivery teams trust the proposals.** They rarely find assumptions that weren't written down, and estimates hold within the stated range.
- **Losses are learned from.** A lost proposal gets a short review: what the customer chose instead, and why.
- **Designs get reused.** A solution built once becomes a reference architecture, a discovery question, or a demo for the next engagement.
- **The architect says no** to work that isn't a fit, and to promises that can't be kept, early and plainly.

## Skills to build

| Skill | How to build it |
|---|---|
| Technical breadth across cloud, delivery, security, data, and operations | The [architect](../architect/README.md) guides; deploying the [reference stacks](../devops/terraform/README.md) yourself |
| Depth in at least one area, so you can answer the second and third question | Hands-on work in it: build, break, and fix it |
| Discovery and questioning | Shadowing experienced architects; the [discovery guide](templates/discovery-guide.md) |
| Clear writing | Writing proposals and having them edited hard; reading your own after delivery to see what was misunderstood |
| Presenting and whiteboarding | Practice with feedback, recorded if possible ([Presenting](06-presenting.md)) |
| Commercial awareness: how the customer's business makes money and spends it | Asking about it in discovery; reading their public reports where they exist |

## Next

[Discovery and requirements](02-discovery-and-requirements.md).
