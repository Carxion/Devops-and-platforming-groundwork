# Discovery guide: <engagement or problem name>

**Solutions architect:** <name> | **Note taker:** <name> | **Session:** <business / technical / users / security> | **Attendees:** <roles> | **Date:** <date>

45 to 60 minutes per session. Ask about real, recent events and ask for numbers. Don't present solutions; say you'll come back with options. Pick the sections that fit the session; few sessions need all of them.

## Before

- [ ] Read what's public about the customer, and what your organization already knows (earlier engagements, support history, account notes)
- [ ] Write down what you think the problem is, and the three things you most need to learn
- [ ] Agree who takes notes, and ask permission to take them
- [ ] Prepare a rough current-state diagram from what you know, to correct in the session

## Opening (5 minutes)

- "We have <time>. I'd like to understand the problem and what success looks like, so I can come back with options. I won't be presenting anything today."
- What prompted this, and why now?

## Business drivers and success (business session)

- What problem are you trying to solve? What happens if nothing changes?
- What does it cost today, in time, money, risk, or customers? Can you give a recent example?
- Who's asking for this, and what are they measured on?
- How will you know it worked? What number moves, by how much, by when?
- Is there a budget, roughly? How is it approved?
- Is there a date that matters (a contract end, a regulatory deadline, a seasonal peak)? What happens if it's missed?
- Have you tried to solve this before? What happened?

## Decision process (business session)

- Who makes the final decision? Who else has to agree?
- What's the approval path, and how long does it usually take?
- Who else are you talking to about this, inside or outside the organization?
- What would make you choose not to go ahead?

## Current state (technical session)

- Walk me through how <a release / an order / a request> works today, end to end.
- What systems are involved? Which are you happy with, and which not?
- What does it integrate with? How (APIs, files, shared databases, messaging)?
- How much data, and how fast is it growing? Where does it live?
- How many users, from where, and when is the peak?
- What breaks most often? When was the last serious incident, and what happened?
- What's documented, and how current is it?

## Quality attributes (technical session)

For each, ask for a number and the reason behind it:

| Attribute | Question | Answer | Reason |
|---|---|---|---|
| Availability | How much downtime is acceptable, and when? | | |
| Recovery | How quickly must it recover, and how much data can be lost? | | |
| Performance | How fast must it respond, at what load? | | |
| Scale | What's the expected growth, and the peak? | | |
| Security | What data is sensitive? What controls are required? | | |
| Compliance | Which regulations, standards, or audits apply? | | |
| Data residency | Where must data be stored and processed? | | |
| Cost | Is there a ceiling on running cost? | | |

## Constraints

- Which clouds, vendors, and tools are approved, or ruled out?
- Existing contracts or licenses that must be used or that end soon?
- Standards the solution must meet (architecture, security, network)? Who owns them?
- Skills the team has, and doesn't have?

## Operating model (operations session)

- Who will run this after it's delivered? What skills and hours do they have?
- How is it monitored today? Who's on call?
- How do changes reach production today? Who approves them?
- What support do you need from us after go-live, and for how long?

## Users (users session)

- Tell me about the last time you <did the task>. Where did you wait, or get stuck?
- What do you work around today?
- If you could change one thing, what would it be?

## Closing (5 minutes)

- Play back a two-minute summary of what you heard. "Have I got that right?"
- Is there anything I should have asked and didn't?
- Who else should I talk to?
- Next step, and when.

## After: the written follow-up

Send within one or two working days, and ask the customer to correct it.

```text
Subject: Summary of our discussion on <topic>, <date>

Thank you for your time. Here's what we heard; please correct anything we've got wrong.

The problem:          <one or two sentences, in their words>
Why now:              <the driver and any deadline>
Success looks like:   <the measures and targets>
Key requirements:     <the three to five that will drive the design>
Constraints:          <budget, dates, approved technology, regulations>
Assumptions we're making: <what we're treating as true; please confirm>
Open questions:       <question, who we think can answer it>
Next steps:           <action, owner, date>
```
