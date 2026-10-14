# Design reviews and RFCs

[← Tech lead checklist](README.md)

Most expensive mistakes in platform work are made before any code is written: the wrong boundary between services, a data store that can't scale the way it needs to, a security model that can't pass review, a migration with no way back. A short written design, reviewed by the right people, catches them while they're cheap to fix. This guide covers when to write one, how to write it, and how to run a review that improves the design instead of just approving it.

## Which document, when

| Document | Use for | Size | Template |
|---|---|---|---|
| **None** (just a pull request) | Changes inside one team's area that are easy to reverse | n/a | |
| **ADR** (architecture decision record) | Recording a decision and why: chosen, with alternatives and consequences | Half a page | [adr-template.md](templates/adr-template.md) |
| **RFC or design doc** | Proposing a significant change *before* building it, to get review and agreement | 2 to 6 pages | [rfc-design-doc.md](templates/rfc-design-doc.md) |
| **Cutover runbook** | Executing a risky change step by step | As long as the steps | [cutover-runbook.md](templates/cutover-runbook.md) |

Write an RFC when a change is any of:

- **Hard to reverse:** a data model, a public API, a choice of database or cloud service, a network design
- **Crossing team boundaries:** other teams must change, adopt, or depend on it
- **Expensive:** more than a few engineer-weeks, or a new recurring cost
- **Security- or compliance-relevant:** new data flows, new external access, new identities with broad permissions
- **Contested:** people already disagree about the approach

Skip it for anything a pull request review covers well. A design-review process that demands documents for small changes teaches people to avoid it, or to write documents nobody reads.

## Writing a good RFC

The [template](templates/rfc-design-doc.md) has the sections; these are the habits that make one useful:

- **Lead with the problem, with evidence.** A reviewer who doesn't agree there's a problem won't engage with the solution. Link the findings or incidents behind it.
- **State non-goals.** They stop the review from expanding into everything adjacent.
- **Show the alternatives honestly,** including "do nothing", with real pros. A design that presents only straw-man alternatives reads as a decision already made, and reviewers stop trying.
- **Cover operations, security, and cost,** not just the happy-path architecture. These are where platform designs usually fail review, or worse, pass it and fail in production.
- **Make the migration part of the design.** How existing systems and users move over, in what stages, and how each stage rolls back ([Migrations and cutovers](migrations-and-cutovers.md)).
- **Say what you don't know.** Open questions invite help; hidden ones surface in production.
- **Keep it short.** If it's longer than six pages, it's probably two designs, or it's carrying an appendix that should be linked instead.
- **Use diagrams** for structure and data flow: a context diagram and a container diagram (the [C4 model](https://c4model.com/)) cover most needs.

## Running the review

### Before

1. **Choose reviewers deliberately:** someone from each team affected, someone from security if data or access changes, someone who will operate it, and one person outside the immediate area for a fresh view. Three to six people.
2. **Share it with time to read:** at least three working days before any meeting, with a date the comment period closes.
3. **Review asynchronously first.** Comments in the document let everyone think before reacting, and give quieter reviewers an equal voice.

### The meeting (if one is needed)

Hold one only for what written comments couldn't settle. Thirty to sixty minutes:

- **Don't present the document.** Everyone read it. Start with the open questions and unresolved comments.
- **Separate understanding from disagreement:** "What would have to be true for this to fail?" is more productive than "I don't like this."
- **The author owns the design;** reviewers advise. The decider (named in advance) decides.
- **End with a decision or a specific next step:** accepted, accepted with changes, needs another round on a named question, or rejected.

### Questions that find problems

| Area | Ask |
|---|---|
| Failure | What happens when each dependency is slow or down? What's the blast radius of a bad deploy? |
| Scale | What grows with users, data, or teams, and where does it break first? |
| Security | What identity does each component use, with what permissions? What data crosses which boundary? What's exposed to the internet? |
| Operations | How do we know it's healthy? What does on-call do at 3 a.m. when it isn't? How is it upgraded? |
| Data | How is it backed up, restored, migrated, and deleted? Who owns it? |
| Cost | What does it cost per month at today's load, and at ten times? Who pays? |
| Reversibility | If this turns out wrong in six months, what does it take to undo? |
| People | Who will build it, run it, and maintain it in two years? Does the team have the skills? |

### After

- Record the decision as an [ADR](templates/adr-template.md), linking the RFC, so the reasoning survives after the document goes stale.
- Update the RFC's status (accepted, rejected, superseded). An index of RFCs with their status is the team's design history.
- If the design changes significantly during building, update it or write a short follow-up. A design doc that no longer matches the system misleads the next reader.

## Making it a team habit

- **Model it yourself:** the tech lead's own proposals go through the same review.
- **Keep the bar proportional,** so the process stays lighter than the work it protects.
- **Reward good reviews,** not just good designs. A review comment that prevents an outage is invisible unless someone says so.
- **Review decisions later:** a quarterly look at the ADRs from six months ago (which held up, which didn't, and why) improves the next round of designs more than any template.
