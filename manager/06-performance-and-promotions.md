# Performance and promotions

[← Manager](README.md)

Performance management is mostly done in ordinary weeks: clear expectations, regular feedback, and support, so that formal reviews confirm what everyone already knows. This guide covers goals, reviews, handling underperformance fairly, and building a promotion case. Your organization's HR policies and employment law come first; involve HR early in anything formal.

## Goals

- **Two to four goals per person per review period,** mixing delivery ("migrate the remaining services to the new pipeline"), operational ("lead two incident reviews"), and growth ("present a design at the architecture review").
- **Outcomes over activity:** "deploys for the payments team need no manual steps" rather than "work on the pipeline."
- **Tied to the expectations for their level** ([career ladder](templates/career-ladder.md)), so progress toward promotion is visible.
- **Revisited quarterly in one-on-ones.** Plans change; goals that no longer make sense should change with them, in writing.

On platform teams, make sure goals recognize run work: someone who carried a heavy on-call quarter and kept the platform stable did valuable work even if their project slipped.

## Reviews

A review should contain no surprises. If something in it is news to the person, the feedback came too late.

**Gather evidence through the whole period,** not the last two weeks: notes from one-on-ones, the work itself (designs, pull requests, incident reviews), and input from peers and stakeholders who worked with them.

**Write it against the expectations, with examples:**

- What they achieved, with the impact (on the team, the platform, customers)
- How they did it: collaboration, quality, operational habits
- Where they grew, and where they should focus next
- Specific examples for every claim: "led the Kubernetes upgrade across 30 services with no customer impact" rather than "strong technical skills"

**Watch for bias** in your own reviews:

| Bias | Check |
|---|---|
| Recency | Did you weigh the whole period, or just the last month? |
| Visibility | Does quiet, reliable work (patching, documentation, on-call) count as much as visible projects? |
| Similarity | Are you rating people who work like you more highly? |
| Halo and horns | Is one strong or weak area coloring everything else? |
| Inconsistent language | Would you use the same words for the same behavior from anyone on the team? |

Calibrating with peer managers (comparing ratings and evidence across teams) catches many of these.

**Deliver it in conversation,** before or with the written version, leaving time for their questions and their view. End with agreed goals for the next period.

## When someone is struggling

Most underperformance has a cause other than ability or effort: unclear expectations, the wrong role, too much load, missing skills, or something in their life outside work. Find out which before deciding what to do.

1. **Talk early and privately,** about specific, observed behavior and its impact: "The last three changes you deployed needed rollbacks, and two caused customer-facing errors."
2. **Ask before concluding:** "What's getting in the way?" The answer might be a process problem, a skills gap, or something personal.
3. **Agree on what good looks like,** specifically, and what support you'll give: pairing, training, a change in workload, clearer requirements.
4. **Follow up regularly** and write down what you discussed and agreed, each time.
5. **Recognize improvement** as clearly as you named the problem.

If things don't improve after a fair period with real support, the next step is usually a formal improvement plan, which has HR and legal implications. **Involve HR before you start one,** follow your organization's process, and make the plan genuinely achievable. A plan designed to fail is unfair to the person and corrosive to the trust of everyone who watches it.

Never handle these conversations in public or in group channels, and never through the team's tools (dashboards ranking individuals by commits or tickets, for instance).

## Promotions

### Before the case

- **Talk about growth constantly,** not just at promotion time. Everyone on the team should know where they stand against the next level, and what's missing.
- **Create the opportunities:** the next level usually requires larger scope (leading a project, designing a system, mentoring). Make sure the work exists and goes to people ready to grow into it, not always to the same person.
- **Promote for sustained behavior at the next level,** not potential alone and not reward for tenure.

### Building the case

A promotion case argues that someone is *already* working at the next level, with evidence:

- **The expectations for the target level,** from the career ladder
- **Examples against each dimension,** across several months: what they did, the scope, and the impact
- **Input from others:** peers, other teams, stakeholders who saw the work
- **How they've grown** since the last level
- **Any gaps,** stated honestly, with why they don't block the promotion

Operational work is often undersold in promotion cases. Make it concrete: "led the response to four severity-1 incidents and the reviews that followed; the actions eliminated the leading cause of pages" is as strong as any feature.

### When it doesn't happen

Tell them yourself, promptly, with the specific gaps and a plan to close them. Agree what evidence would make the case next time, and check progress in one-on-ones.

## Recognition

Reviews and promotions are infrequent; recognition should be constant:

- **Specific and timely:** what they did and why it mattered, soon after it happened
- **Public when appropriate** (team channels, stakeholder updates), private when the person prefers
- **For the invisible work too:** the upgrade nobody noticed because nothing broke, the alert cleanup, the runbook that saved an hour at 3 a.m.
