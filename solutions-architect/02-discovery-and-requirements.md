# Discovery and requirements

[← Solutions architect](README.md)

Discovery is where the solution is won or lost. Most failed solutions solved the problem as it was first described, not the problem the customer actually had. This guide covers what to find out, how to run the sessions, and how to turn what you hear into requirements someone can design and test against. The [discovery guide template](templates/discovery-guide.md) has the questions in a form you can take into a meeting.

## Problem before solution

Customers often arrive with a solution already in mind: "we need Kubernetes," "we want to move to Azure," "we need a new CI system." Treat that as a hypothesis, not a requirement. Ask what it's for, then ask again:

```text
"We need to move to Kubernetes."
  → Why?                 "Our deployments are slow and break a lot."
  → What does that cost? "A release takes three weeks, and one in four needs a hotfix."
  → Why does it matter?  "Our main competitor ships weekly. We lost two deals on features last quarter."
```

The real problem is release speed and reliability, tied to lost revenue. Kubernetes might help. So might a deployment pipeline, smaller releases, or automated testing, any of which could be faster and cheaper. You can still recommend Kubernetes, but now you can explain why in terms the sponsor cares about, and you'll know how to measure whether it worked.

Don't argue with the original request in the first meeting. Learn the problem, then show how your recommendation solves it, even when it's different from what they asked for.

## What to find out

| Area | Questions | Why it matters |
|---|---|---|
| **Business drivers** | Why now? What happens if nothing changes? Who's asking for this, and what are they measured on? | The drivers decide which trade-offs are acceptable, and give the proposal its opening |
| **Success criteria** | How will you know this worked? What number moves, by how much, by when? | Without these, you can't choose between options or prove the result |
| **Current state** | What exists today: systems, data, integrations, teams, contracts, and how well they work? | Every solution starts from somewhere; migrations and integrations are where estimates go wrong |
| **Users and consumers** | Who uses it, how many, from where, doing what? | Sizing, latency, access, and support needs |
| **Functional requirements** | What must the solution do? | Scope |
| **Quality attributes** | Availability, latency, recovery time and data loss, scale, security, compliance, operability, cost ceiling | These drive the architecture more than the features do ([Thinking like an architect](../architect/01-thinking-like-an-architect.md#start-from-quality-attributes)) |
| **Constraints** | Budget, deadlines, approved clouds and vendors, regulations, data residency, existing contracts, team skills | Constraints eliminate options early, which saves design time |
| **Decision process** | Who decides, who influences, who can block? What's the approval path and timeline? Who else are they talking to? | A proposal to the wrong person, at the wrong time, isn't read ([Working with stakeholders](04-working-with-stakeholders.md)) |
| **Operating model** | Who will run it after delivery? What skills do they have? What support hours? | A solution the customer can't run fails after handover |

Ask about money directly and early: "Is there a budget for this, roughly?" A design that costs ten times the budget wastes everyone's time, and most people answer honestly if asked plainly.

## Running discovery sessions

**Prepare.** Read what's public about the customer and what your organization already knows: earlier engagements, support history, the account manager's notes. Write down what you think the problem is, and what you most need to learn. Don't spend the customer's time on questions their website answers.

**Pick the right people.** One session rarely covers it. Typically:

| Session | With | Focus |
|---|---|---|
| Business | The sponsor and business owners | Drivers, success criteria, budget, timeline, decision process |
| Technical | Architects, engineering leads, operations | Current state, integrations, quality attributes, constraints |
| Users | People who'll use or run it | How work happens today, pain points, what they'd change |
| Security and compliance | Security, risk, data protection | Controls, regulations, approval process |

**Run it as a conversation, not an interview.**

- **Open with purpose and time:** "We have an hour. I want to understand the problem and what success looks like, so I can come back with options. I won't present anything today."
- **Ask open questions** ("Walk me through how a release happens today") before closed ones ("Do you use feature flags?").
- **Ask for examples and numbers.** "Deployments are slow" becomes "the last five took 12 to 19 days." Specifics turn opinions into requirements.
- **Ask what they've tried,** and why it didn't work. It saves you proposing it again, and shows what the organization resists.
- **Listen more than you talk.** If you're talking more than a third of the time, you're presenting, not discovering.
- **Bring a second person** to take notes, so you can listen and follow up.
- **Draw while you listen.** A rough current-state diagram, checked with them as you go ("so this calls that, nightly?"), catches misunderstandings in the room.
- **Close by playing it back:** a two-minute summary of what you heard, and the next step.

**Follow up in writing within a day or two:** what you heard, the requirements and constraints as you understood them, open questions, and next steps. Ask them to correct it. A written summary the customer has agreed to is the foundation of the proposal, and the first thing to check when someone later says "that's not what we asked for."

## Turning notes into requirements

Raw notes aren't requirements. Each requirement should be specific, testable, and traceable to a reason:

| Weak | Strong |
|---|---|
| "Must be highly available" | "Customer-facing checkout available 99.9% per month, measured at the load balancer. Driver: each hour of outage costs roughly the revenue of an average day's sales." |
| "Must be secure" | "Customer personal data encrypted at rest and in transit, with access logged and kept 1 year. Driver: the data protection policy and regional regulation." |
| "Must be fast" | "Search returns in under 500 ms at the 95th percentile at 200 requests per second." |
| "Must scale" | "Handles three times today's peak (the seasonal sale) without manual changes." |

The architect's [quality attribute requirements template](../architect/templates/quality-attribute-requirements.md) writes these as testable scenarios.

Then sort them:

- **Must, should, could.** Push back on a list where everything is a must; ask "if we had to launch without this, could we?"
- **Requirement or assumption?** "Traffic will grow 20% a year" is an assumption. Write it down as one, with who confirmed it, because the design depends on it.
- **Conflicts.** "Lowest possible cost" and "99.99% availability across regions" pull in opposite directions. Surface the conflict and let the sponsor choose, rather than choosing silently.

## Traps

| Trap | What happens | Instead |
|---|---|---|
| **Solutioning in discovery** | You pitch before you understand; the customer stops telling you things | Hold the design until the follow-up. Say "I have ideas; let me check them against what you've told me first" |
| **Only talking to the technical team** | A design the engineers love that the sponsor won't fund | Meet the sponsor; get the business drivers in their words |
| **Only talking to the sponsor** | A design that ignores how things really work | Meet the people who'll build, use, and run it |
| **Taking the first answer** | "Downtime is fine on weekends" turns out to mean one weekend a quarter, with notice | Ask for the example, the number, and who'd object |
| **Not asking what they've tried** | You propose the thing that failed last year | Ask early, and ask why it failed |
| **Skipping the operating model** | Delivered, then abandoned, because nobody could run it | Ask who runs it, with what skills and hours |
| **Missing non-functional requirements** | The happy path works; it falls over at peak, or fails audit | Walk through the quality attributes explicitly |
| **No written summary** | Everyone remembers the meeting differently | Send one, and get it corrected |

## Next

[Designing the solution](03-designing-the-solution.md).
