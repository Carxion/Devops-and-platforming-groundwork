# Preparing a proposal

[← Solutions architect](README.md)

A proposal is a document that lets someone decide. Its job isn't to show how much work went into the design or how much the team knows; it's to give the decision maker what they need to say yes, with the commitments on both sides clear enough that delivery doesn't turn into an argument. This guide covers the structure, the parts that matter most, pricing, formal requests for proposal, and the review before it goes out. The [proposal template](templates/proposal.md) follows the same structure.

## Before you write

Answer these first. If you can't, go back to [discovery](02-discovery-and-requirements.md):

- **Who decides,** and who else will read it? The sponsor reads the first page or two; the technical decision maker reads the design; procurement reads the scope and the price.
- **What decision do you want,** by when?
- **What problem does it solve,** in the sponsor's words?
- **How will success be measured?**
- **What are they comparing it with:** a competitor, an internal team, or doing nothing?

Then write the **one-sentence answer** before anything else: "We recommend replatforming the order system onto managed containers and a managed database, in two phases over 20 weeks, for an estimated build cost of X and a running cost of Y a year, cutting release time from three weeks to a day." If you can't write that sentence, the proposal isn't ready.

## Structure

Lead with the answer, then support it. Barbara Minto's *The Pyramid Principle* describes this order: the conclusion first, then the few arguments that support it, then the evidence for each. It suits readers who are busy and may stop reading at any point.

| Section | Contains | Length |
|---|---|---|
| **Executive summary** | The problem, the recommendation, the outcome, the cost and timeline, and the decision needed | One page |
| **Understanding of the problem** | Business drivers, current state, and success criteria, in the customer's terms | One to two pages |
| **Recommended solution** | What it is, a context diagram, how it meets the driving requirements | Two to four pages |
| **Options considered** | The alternatives, and why the recommendation is better for this customer | One to two pages |
| **Delivery approach** | Phases, milestones, team, how the customer is involved, and how progress is reported | One to two pages |
| **Scope, assumptions, and exclusions** | What's in, what's out, and what you're relying on | As long as it needs |
| **Risks** | The main risks and how they're managed | One page |
| **Cost** | Build and running cost, with what drives them | One to two pages |
| **Why us** (external proposals) | Relevant experience, references, the team | One page |
| **Next steps** | The decision needed, by when, and what happens after | Half a page |
| **Appendices** | Detailed design, requirements traceability, CVs, compliance responses | Whatever's needed |

Keep the main body short, often under 15 pages. Put the detail in appendices for the people who need it.

## The executive summary

Many decision makers read only this, so it has to stand alone. Write it last, after the rest is settled, and rewrite it until it's tight.

```text
Problem         Releases of the order system take three weeks, and one in
                four needs an emergency fix. Two deals were lost on delivery
                speed last quarter.

Recommendation  Replatform the order system onto managed containers and a
                managed database, with an automated deployment pipeline.

Outcome         Releases in under a day, with automated rollback. Change
                fail rate below 10%, from 25% today.

Cost and time   Two phases over 20 weeks. Build cost X; running cost Y a
                year, Z below today's hosting.

Decision        Approval to start phase 1 by <date>, to finish before the
                seasonal peak.
```

The same five parts work for any proposal: **problem, recommendation, outcome, cost and time, decision.** Use the customer's numbers and words. Leave out the technology names unless the reader cares about them.

## Write for the reader

- **Their problem, not your product.** Every section should answer "what does this mean for us?" Cut anything that doesn't.
- **Specific, not generic.** "Proven, scalable, best-in-class" says nothing. "Handles three times your seasonal peak, tested in the POC" says something.
- **Short sentences and plain words.** Define any acronym the sponsor might not know, or leave it out.
- **Show, don't claim.** A number, a diagram, a reference customer, a POC result.
- **Consistent numbers.** If the summary says 20 weeks and the plan says 22, the reader trusts neither.
- **No boilerplate that doesn't fit.** Reused sections are fine, but a paragraph about the wrong industry, or another customer's name left in, can lose the proposal on its own.

## Scope, assumptions, and exclusions

This section protects both sides, and it's the one delivery teams read first. Most disputes during delivery trace back to something this section didn't say.

- **In scope:** the deliverables and activities, specific enough to check. "Migrate the 14 applications listed in Appendix B" rather than "migrate the applications."
- **Out of scope:** what a reasonable reader might assume is included but isn't. "Data cleansing", "changes to the mobile app", "support after go-live beyond 30 days", "licenses for third-party tools."
- **Assumptions:** what you're relying on the customer or others to provide or be true. "The customer provides access to test environments by week 2." "The source database is under 2 TB." "Decisions on design questions within 5 working days." Every assumption from the [RAID log](03-designing-the-solution.md#risks-assumptions-issues-and-dependencies) belongs here.
- **Customer responsibilities:** people, access, decisions, and environments they commit to provide.
- **What happens if an assumption is wrong:** usually a change request, with how it's estimated and agreed.

Write assumptions so they can be checked: "the source database is under 2 TB" can be checked; "the data is in good condition" can't.

## Pricing and cost

How you present cost depends on the setting, but the principles are the same:

- **Show what drives the cost,** not just the total, so the customer can see what changes it.
- **Separate one-time and running costs.** Build or migration cost, then annual running cost: cloud consumption, licenses, support, and staff.
- **State the pricing model** for services work: fixed price (you carry the risk, so it costs more and needs tight scope), time and materials (the customer carries the risk), or a mix, such as fixed price for a well-understood phase and time and materials for discovery.
- **Show contingency explicitly** rather than hiding it in each line. Hidden padding gets negotiated out piece by piece; stated contingency, tied to named risks, is easier to defend.
- **Give options where they help:** a smaller first phase, a cheaper resilience level, a managed service in place of staff.
- **Get commercial sign-off** from whoever owns pricing before it goes out. Don't improvise discounts in a meeting.

For internal proposals, cost is usually "people and cloud spend": the team's time, the run cost, and what it displaces. The manager's guide to [budget, vendors, and contracts](../manager/08-budget-vendors-and-contracts.md) covers the internal side.

## Responding to a request for proposal

A formal request for proposal (RFP) or tender sets the structure and the rules. Within them:

1. **Decide whether to bid.** An RFP written around a competitor's product, with weeks to respond and no access to the customer, is often not worth the effort. Bid where you can win and deliver.
2. **Read the whole thing, twice,** and list every requirement and every instruction: page limits, formats, deadlines, mandatory forms.
3. **Build a compliance matrix:** each requirement, whether you meet it fully, partly, or not, and where in the response it's answered. Evaluators often score against exactly this.
4. **Ask clarifying questions** by the deadline for questions. They're often shared with every bidder, so ask what you need without giving away your approach.
5. **Answer what was asked, in their order and their words.** Evaluators score against a sheet; make every answer easy to find and easy to score.
6. **Be honest about partial fits.** "Partially meets: done with X, with these limitations" scores better than an evasive answer that's found out later, and it doesn't become a contractual problem.
7. **Still lead with the answer.** Even inside a fixed structure, the executive summary and the opening of each section should give the point first.
8. **Plan backward from the deadline,** with time for review and production. Late submissions are usually rejected without being read.

## Review before it goes out

Every proposal gets at least one review by someone who didn't write it:

| Reviewer | Checks |
|---|---|
| A peer solutions architect or architect | The design meets the requirements; the options are real; nothing technical is wrong |
| A delivery lead | The plan, the estimate, and the assumptions; that their team can deliver what's promised |
| Commercial owner | Price, terms, and risk the organization is accepting |
| A reader who knows nothing about it | The executive summary makes sense on its own; the jargon is explained |
| Legal (when terms or liability are involved) | Commitments, warranties, liability |

Then check the details yourself:

- [ ] The executive summary stands alone and states the decision needed.
- [ ] Every number matches everywhere it appears.
- [ ] Every requirement is answered (and, for an RFP, the compliance matrix is complete).
- [ ] Scope, exclusions, and assumptions are specific and checkable.
- [ ] No other customer's name, data, or details anywhere, including in diagrams, file properties, and tracked changes.
- [ ] Diagrams are readable when printed and on a small screen.
- [ ] Names, titles, and the customer's terminology are correct.
- [ ] The file format, length, and naming follow any instructions.

## After it goes out

- **Present it if you can,** rather than only sending it ([Presenting the solution](06-presenting.md)). A proposal that's walked through gets read; one that's emailed often doesn't.
- **Follow up** on the date you agreed.
- **Win or lose, ask why,** and write it down. A short review of every lost proposal (what the customer chose, and the reasons they gave) is the cheapest way to win the next one.

## Next

[Presenting the solution](06-presenting.md).
