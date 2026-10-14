# Budget, vendors, and contracts

[← Manager](README.md)

Platform teams often own a large share of an organization's technology spend: cloud infrastructure, tool licenses, support contracts, and sometimes contractors. Managing it well is part of the job, and doing it visibly builds credibility with leadership. This guide covers cloud cost ownership, choosing and managing vendors, and working with contractors. Your organization's finance, procurement, legal, and security processes take precedence; involve them early.

## Know your budget

- [ ] What you're responsible for: headcount, cloud spend, tools and licenses, support contracts, training, contractors
- [ ] Who approves spend at each level, and the purchasing process and lead times
- [ ] The budget cycle: when next year's budget is set, and when you need to have asked
- [ ] Every contract's renewal date, notice period, and auto-renewal terms. Missing a notice period can lock in another year of a tool you meant to drop.

Keep these in one place, with an owner and a review date for each line.

## Cloud cost

Cloud bills grow by default: new resources are easy to create and easy to forget. The practice of managing them, shared between engineering and finance, is called **FinOps** ([FinOps Foundation](https://www.finops.org/framework/)).

**Make cost visible and owned:**

- **Tag everything** with an owner, environment, and cost center, enforced by policy ([AWS](../devops/aws/guides/cost.md) and [Azure](../devops/azure/guides/cost.md) cost guides show how to find untagged spend).
- **Show each team its own costs** monthly (showback), even if you don't charge them back. Teams that see their spend reduce it.
- **Set budgets and alerts** per account or subscription ([AWS budget template](../devops/aws/cloudformation/cost/budget.yaml), [Azure budget template](../devops/azure/bicep/governance/budget.bicep)).
- **Track unit cost** (cost per customer, per order, per thousand requests) alongside the total. A rising bill with a falling unit cost is growth; a rising unit cost is waste or a design problem.

**Common savings,** roughly in order of effort:

| Saving | Typical approach |
|---|---|
| Idle and orphaned resources | Unattached disks, old snapshots, unused IP addresses, forgotten test environments: find them monthly and delete with an owner's approval |
| Non-production schedules | Stop dev and test environments outside working hours |
| Right-sizing | Match instance and database sizes to measured use |
| Storage lifecycle | Move old data to cheaper tiers; delete what retention policy no longer requires |
| Logging and monitoring volume | Often a surprise line item: drop noisy logs, set retention ([observability cost](../devops/observability/README.md#cost-and-cardinality)) |
| Commitment discounts | Savings plans or reservations for steady, predictable usage, once the waste is gone |
| Architecture | Serverless or containers for spiky workloads, ARM-based instances, fewer data transfers across zones and regions |

Report savings in your stakeholder updates. Cost reduction is one of the most visible ways a platform team demonstrates value ([Stakeholders](05-stakeholders-and-communication.md#make-the-platforms-value-visible)).

## Choosing tools and vendors

**Before buying, write down the problem** and how you'll know the tool solved it. Many tool purchases solve problems the team could have solved with what it already has, or don't solve the real problem at all.

**Build, buy, or use open source:**

| Option | Strengths | Costs people forget |
|---|---|---|
| Build | Exactly what you need | Maintaining it forever, and the knowledge leaving with its author |
| Buy (commercial) | Support, features, someone else maintains it | Licenses that grow with usage, lock-in, procurement time, vendor risk |
| Open source, self-run | No license fee, transparency, community | Running, upgrading, securing, and supporting it yourself |
| Open source, managed | Open standards without the operations | Usage-based pricing, provider's feature limits |

**Evaluate with a short, structured process:**

1. **Requirements,** must-have and nice-to-have, agreed with the people who'll use it.
2. **A shortlist** of two or three options, including the "use what we have" option.
3. **A time-boxed trial** with real use cases and real users, not just a demo.
4. **The questions demos skip:**
   - Security: how it authenticates (single sign-on?), what data it stores and where, its security certifications, its vulnerability history
   - Operations: how it fails, how it's upgraded, what support response times are in the contract
   - Exit: how you get your data out, and what leaving would cost
   - Cost: pricing at today's scale and at three times, and what triggers price increases
   - Vendor health: how long they've existed, how many customers, what happens if they're acquired
5. **A written recommendation** ([RFC](../tech-lead/templates/rfc-design-doc.md) or ADR), so the next person knows why.

Bring in security and procurement before the trial, not after the decision: their review can take weeks, and can rule a tool out.

## Managing vendors

- **One owner per vendor relationship,** with the contract, renewal date, contacts, and support process recorded.
- **Review each vendor yearly:** are we using it, is it worth the cost, is there a better option, are there unresolved issues?
- **Know how to escalate:** support case severities, account managers, and what the contract promises.
- **Watch usage-based pricing:** set alerts on usage, not just on the invoice, to catch surprises early.

## Contractors and consultants

Contractors can add capacity or expertise quickly; managed badly, they leave behind systems nobody understands.

- **Scope by outcomes,** with clear deliverables and acceptance criteria, not just hours.
- **Pair contractors with employees** on everything they build, so the knowledge stays.
- **Same standards as the team:** code review, documentation, security practices, the same pipelines.
- **Least-privilege, time-limited access,** through your identity provider, removed on the last day ([access done safely](02-hiring-and-onboarding.md#access-done-safely)).
- **A handover before they leave:** documentation, runbooks, and a walkthrough with the team that will own the work.
- Respect the contractual and employment boundaries your organization defines; treating contractors exactly like employees can create legal problems. Ask HR or procurement where the lines are.
