# Presenting the solution

[← Solutions architect](README.md)

A presentation is a meeting with a purpose: usually a decision, sometimes agreement on a direction or the next step. The slides support the conversation; they aren't the point. This guide covers preparing, structuring the story, diagrams and demos, whiteboarding, handling questions and objections, and presenting remotely. The [presentation plan template](templates/presentation-plan.md) is a one-page way to prepare.

## Start from the outcome

Before opening a slide tool, write down:

1. **What you want to happen by the end of the meeting:** "approval to start phase 1", "agreement to run a POC", "the security lead's support for the network design." If the honest answer is "nothing in particular," it may not need to be a meeting.
2. **Who will be there,** and what each of them cares about ([Working with stakeholders](04-working-with-stakeholders.md#whos-in-the-room)).
3. **What each person needs to hear** to support that outcome, and what objection each is most likely to raise.
4. **How much time you really have.** Plan to use half to two-thirds of it for content and leave the rest for discussion; meetings start late and questions take longer than expected.

## Before the meeting

- **Pre-brief the key people one to one:** the sponsor, the technical decision maker, and anyone who might object. Walk them through the recommendation, listen to their concerns, and adjust. The meeting should confirm a decision, not be the first time anyone hears it. Nobody likes being surprised in front of their colleagues.
- **Know the room's politics.** Whose project is this replacing? Who argued for a different option? Address their concerns respectfully, and don't make anyone look foolish in front of their boss.
- **Rehearse out loud,** at least once, ideally with a colleague playing a skeptical customer. Time it. Most first rehearsals run long.
- **Prepare for the likely questions.** Write down the ten hardest, with short answers and where the detail lives (a backup slide, an appendix).
- **Check the logistics:** who's presenting which part, the screen-sharing setup, the demo environment, a backup if the network fails, and the materials to send afterward.

## Structure the story

Lead with the answer, as in the [proposal](05-preparing-a-proposal.md#structure). A structure that works for most solution presentations:

| Part | Time (of a 30-minute slot) | Content |
|---|---|---|
| **The ask** | 1 minute | Why we're here and the decision we're asking for |
| **The problem** | 3 minutes | Their problem, in their words and numbers, from discovery. Check it: "Is this still right?" |
| **The recommendation** | 5 minutes | What it is, at the context level, and how it meets the success criteria |
| **Why this option** | 3 minutes | The alternatives considered, and the trade-offs, briefly |
| **What it takes** | 3 minutes | Timeline, cost, team, what's needed from them, and the main risks |
| **The decision and next steps** | 2 minutes | The ask again, specifically, with the date |
| **Discussion** | 13 minutes | Questions, objections, and agreement on actions |

Two things make the biggest difference:

- **Say the recommendation in the first two minutes.** If the sponsor gets called away after five minutes, they should leave knowing what you recommend and why.
- **Check the problem with them before solving it.** If something has changed since discovery, you want to know before you spend twenty minutes on a solution to last month's problem.

## Slides

- **One message per slide,** written as the slide title in a full sentence: "Managed containers cut release time from three weeks to a day," not "Architecture overview." Reading only the titles should tell the whole story.
- **Few words on the slide.** If you're going to say it, the slide doesn't need it in full; if they're going to read it, you should stop talking. Put the detail in the proposal or backup slides.
- **Their numbers and their words.** "Your release takes 19 days" lands harder than "releases are slow."
- **Readable from the back of the room** and on a laptop screen in a video call: large text, high contrast, no dense tables on main slides. Check contrast against the WCAG guidelines ([quick reference](https://www.w3.org/WAI/WCAG22/quickref/)) if you're unsure, and don't use color alone to carry meaning.
- **Backup slides** for the detail the technical audience may ask for: the container diagram, the cost breakdown, the security controls, the migration plan. Showing them on request answers the question and shows you'd thought about it.

## Diagrams

Diagrams are often what people remember. Use the level that fits the audience ([Designing the solution](03-designing-the-solution.md#draw-it-at-the-right-level)):

- **Context diagrams for business audiences:** the solution as one box, its users, and the systems it connects to. Leave out the cloud service icons; they mean nothing to most sponsors.
- **Container diagrams for technical audiences,** with labeled arrows.
- **Before and after,** side by side, to show what changes.
- **Build complex diagrams up in steps** rather than showing everything at once, so the audience follows one idea at a time.
- **Point at what you're talking about,** on screen or with a cursor. "As you can see here" only works if they can see where "here" is.

## Live demos

A good demo is the most convincing thing you can show; a failed one can sink the meeting. Treat it like a production change:

- **Demo their use case,** not every feature. Show the three minutes that solve the problem they told you about.
- **Script it** and rehearse it end to end, in the same environment you'll present from.
- **Have a fallback:** a recording or screenshots of the same steps, ready to switch to without fuss.
- **Reset the environment beforehand,** with clean data that looks realistic but contains nothing real, and none from another customer.
- **Hide everything else:** notifications, unrelated browser tabs, bookmarks, other customers' names in a dropdown, credentials on screen.
- **Narrate the why, not the clicks:** "Now the developer merges, and with no ticket the change is in production in six minutes," not "I click here, then here."
- **If it breaks, say so calmly,** switch to the fallback, and move on. Debugging live in front of a customer helps nobody.

## Whiteboarding

Drawing together, on a whiteboard or a shared online canvas, is often more persuasive than slides, because the audience helps build the picture and so owns it.

- **Start with what they know:** draw their current state first, and ask them to correct it.
- **Draw in layers:** users and outcomes first, then the main pieces, then detail only where asked.
- **Write labels, not just boxes,** and keep a legend if you use shapes or colors to mean something.
- **Hand them the marker.** Ask "what's missing?" and let them draw it.
- **Practice your standard drawings** (the reference architecture, the delivery pipeline, the network) until you can draw them cleanly while talking.
- **Photograph or export the result** and send it with the meeting notes.

## Questions and objections

Questions mean people are engaged. Handle them well and they help your case.

- **Listen to the whole question,** then pause. Restate it if it's complex ("so the concern is the cost after year one?") to be sure you're answering the right one.
- **Answer briefly,** then check: "Does that answer it?" Long answers lose everyone else in the room.
- **Say "I don't know" when you don't,** and commit to when you'll come back with the answer. Then do.
- **Take deep detail offline** if it's only relevant to one person: "Good question, and it's a detailed one. Can we cover it after, so we keep time for the decision?" Then follow up.
- **Treat objections as information.** An objection usually points at a real concern: cost, risk, effort, or someone's standing. Find the concern behind it ("What would you need to see to be comfortable with that?") and address that.
- **Don't argue to win.** If someone disagrees strongly, acknowledge the point, agree on the facts, and offer to resolve it with evidence: a POC, a reference, a cost model. Winning an argument in the meeting can lose the decision afterward.

Common objections, and where the answer usually lies:

| Objection | Usually means | Answer with |
|---|---|---|
| "It's too expensive." | The value isn't clear, or the budget doesn't fit | The cost of the problem and the outcome; a smaller first phase |
| "It's too risky." | Something unproven, or a bad past experience | The POC, references, the phased plan, the rollback |
| "We could build it ourselves." | Pride in the team, or real capability | Respect it; compare total effort, time, and running cost honestly. Sometimes they're right |
| "Now isn't the right time." | Competing priorities, or no urgency | The cost of waiting, from discovery; a smaller step now |
| "What about lock-in?" | Fear of a hard-to-reverse commitment | What's portable and what isn't, and the exit plan ([portability](../architect/08-portability-and-multi-cloud.md)) |

## Presenting remotely

- **Camera on, and look at the camera** when making key points, not at the slides.
- **Shorter is better.** Attention drops faster on calls; aim for less content and more interaction.
- **Ask questions by name** to keep people involved: "Priya, does this match how your team deploys today?" (with a name from the meeting, not a guess).
- **Watch the chat,** or ask a colleague to, and answer questions from it.
- **Share only the window you need,** not the whole screen, to avoid exposing email, chat, or other customers' material.
- **Send the slides afterward,** not before, unless asked: a deck read in advance without the conversation is easy to misread.

## After the meeting

- **Send a summary the same day:** decisions made, actions with owners and dates, and the answers you promised.
- **Follow up on every open question** by the date you gave.
- **Ask a colleague for feedback** on how it went: what landed, what didn't, which questions caught you out. Add the hard questions to next time's preparation.

## Next

Back to the [solutions architect guides](README.md), or the [templates](templates/README.md).
