# Working with stakeholders

[← Solutions architect](README.md)

A solution is agreed by people, not by diagrams. Most solutions that stall do so because someone important wasn't consulted, didn't trust the people proposing it, or found out about a problem late. This guide covers who the stakeholders usually are, how to build trust with them, how to manage scope and expectations, and how to hand the solution over cleanly.

## Who's in the room

Every engagement has people in these roles, though one person may hold several and the titles vary:

| Role | Usually | Cares about | What they need from you |
|---|---|---|---|
| **Sponsor or economic buyer** | A director, VP, or executive with the budget | The business outcome, cost, risk, and their own credibility | A short, clear case: problem, outcome, cost, risk, and the decision you need |
| **Technical decision maker** | An architect, head of engineering, or CTO | Fit with their standards and strategy, whether it'll work, what it commits them to | Depth, honest trade-offs, the alternatives you considered |
| **Users** | Engineers, operators, analysts | Whether it makes their work easier or harder | To be asked, and to see their input in the design |
| **Operators** | Operations, SRE, support | Whether they can run it, at 3 a.m., with the skills they have | The operating model, runbooks, monitoring, training |
| **Security, risk, and compliance** | CISO's team, data protection, audit | Controls, evidence, regulatory exposure | Early involvement, controls mapped to their requirements |
| **Procurement and legal** | Purchasing, contracts | Terms, pricing, vendor risk | Clear scope, assumptions, and pricing that match the contract |
| **Your own side** | Account manager, delivery lead, product team | Winning, delivering profitably, a happy customer | No surprises: early warning of scope, risk, and price changes |

Watch for the **blocker**: someone without formal authority who can still stop or slow the decision, such as a security lead who wasn't consulted, an architect whose standard you're breaking, or a team whose work the solution replaces. Find them early, and meet them before the decision meeting, not in it.

Map them as you go. The tech lead's [stakeholder map](../tech-lead/templates/stakeholder-map.csv) works: what each person needs from you, what you need from them, their influence, and when you last spoke.

## Building trust

The customer's technical people judge you within the first few meetings, mostly on whether you're straight with them.

- **Say "I don't know, I'll find out,"** and then find out, in writing, by when you said. Guessing confidently and being wrong costs more than any single answer is worth.
- **Say what your solution doesn't do well.** Every option has weaknesses; naming them first makes the rest of what you say believable.
- **Do your homework.** Read what they sent before the meeting. Don't ask questions their own documents answer.
- **Follow up on everything you said you'd do.** Small promises kept are what make the big one believable.
- **Respect their existing work.** The current system was built by people in the room, under constraints you don't know. "Here's what's changed since this was built" lands better than "this is wrong."
- **Represent them inside your own organization.** When the customer needs something your side resists, argue for it. They'll notice.

## Managing scope and expectations

Scope grows unless someone manages it. Each small addition seems reasonable; together they break the estimate.

- **Write scope down early and keep it current.** The discovery summary, then the design, then the proposal ([scope, assumptions, and exclusions](05-preparing-a-proposal.md#scope-assumptions-and-exclusions)).
- **When asked for more, make the trade-off visible:** "We can add that. It's about three more weeks; we can extend the date, drop the reporting module, or do it as a second phase. Which do you prefer?" The decision is theirs; the consequences should be clear.
- **Don't agree to things in the hallway.** "Let me check that with the delivery team and confirm in writing" is a professional answer, not a delay.
- **Say early when something's at risk,** with options. Bad news is a planning conversation weeks before a decision and a crisis the day before.
- **Never commit delivery to something delivery hasn't seen.** If you need an answer quickly, call the delivery lead before you answer the customer.

The tech lead's guide to [negotiating scope and timelines](../tech-lead/working-with-product-and-leadership.md#negotiating-scope-and-timelines) and the manager's guide to [saying no and escalating](../manager/05-stakeholders-and-communication.md#saying-no-and-escalating) go further.

## Keeping everyone aligned

- **One written source of truth** for decisions, open questions, and the RAID log, shared with the customer. Decisions made in meetings and not written down get remade.
- **Short, regular updates** to the sponsor: what's been decided, what's open, what you need from them, and by when. Weekly is usually enough during an active engagement; the tech lead's [weekly status](../tech-lead/templates/weekly-status.md) is a good shape.
- **Pre-brief before big meetings.** Walk the key people through the recommendation one to one first, so the meeting confirms a decision instead of debating it ([Presenting](06-presenting.md#before-the-meeting)).
- **Close every meeting with actions,** owners, and dates, and send them the same day.

## Disagreement

You'll disagree with customers, and with your own side.

- **Agree on the facts first:** the requirements, the risks, the costs. Most disagreements are about priorities, which are the customer's to set once the facts are agreed.
- **Disagree in private before in public,** with your reasoning and evidence.
- **Ask what would change their mind,** and whether you can get that evidence: a POC, a reference customer, a cost model.
- **Record significant decisions you disagreed with:** what was chosen, by whom, with what known risks ([ADR template](../tech-lead/templates/adr-template.md)). Not to assign blame, but so delivery understands why.
- **Walk away from what you can't support.** If a customer insists on something unsafe, illegal, or undeliverable, say so plainly and escalate inside your organization. A lost engagement costs less than a failed one.

When the disagreement is with your own side, usually over price, scope, or a promise sales made, raise it before the proposal goes out, not after. The delivery team and the customer both pay for promises that can't be kept.

## Handing over to delivery

The handover is where knowledge is lost. Everything the solutions architect learned in discovery and design has to reach the delivery team, or they'll rediscover it the expensive way.

- **Involve delivery before the handover:** in estimating, in reviewing the design, ideally in a late discovery session. A delivery lead who's seen the work before it's sold is far more likely to deliver it.
- **Hand over in a working session, not just a document.** Walk through the problem, the drivers, the design and why, what was promised, and what worries you.
- **Hand over the promises explicitly:** scope, assumptions, exclusions, dates, and anything said to the customer that isn't in the contract but they'll expect.
- **Introduce the people.** The delivery lead should meet the customer's key stakeholders with you, so the relationship transfers.
- **Stay reachable.** Agree how long you'll be on call for questions, and check in after a few weeks to see what you got wrong. It's the fastest feedback on your own work.

The [delivery handover template](templates/delivery-handover.md) has the checklist.

## Next

[Preparing a proposal](05-preparing-a-proposal.md).
