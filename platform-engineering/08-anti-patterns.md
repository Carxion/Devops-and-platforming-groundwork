# Anti-patterns

[← Platform engineering](README.md)

The common ways platforms fail, how to recognize each, and how to get out. Most of them come from forgetting one of two things: the platform is a product for its users, and self-service means users don't have to ask.

## Portal first

**Looks like:** the first big project is a developer portal. It launches with a catalog nobody keeps current and templates that lead to the same tickets as before.

**Why it happens:** a portal is visible and demos well; the capabilities behind it are slow, cross-team work.

**Instead:** build the capabilities first (a golden path that works end to end, self-service for the most common requests), and add a portal when finding them is the problem. Keep templates usable without the portal ([Portals](05-developer-portals-and-catalogs.md#portal-and-platform-are-different-things)).

## The golden cage

**Looks like:** everything must go through the platform's path, with no way to step off part of it. Teams whose needs don't fit build workarounds, run shadow infrastructure, or escalate for exceptions.

**Why it happens:** consistency is easier to support, and every exception feels like a risk.

**Instead:** design escape hatches for each part of the path, say plainly what support goes with leaving, and enforce safety through guardrails that apply on and off the path, so leaving costs convenience, never security ([Escape hatches](03-golden-paths.md#escape-hatches-in-practice)). Treat teams leaving the path as feedback.

## Ticket-ops in disguise

**Looks like:** a form, a portal button, or a chatbot in front of a queue that a person works through. Developers still wait days; the platform team still does each request by hand.

**Why it happens:** automating the interface is easier than agreeing to automate the decision behind it.

**Instead:** find what the person checks and turn it into a guardrail, then automate the rest ([Ending ticket-ops](04-self-service-and-abstractions.md#ending-ticket-ops)). Measure time from need to done, not tickets closed.

## The platform as a project

**Looks like:** a program with an end date builds the platform, hands it to an operations team, and disbands. Two years later, it's out of date and nobody can change it.

**Why it happens:** projects are easy to fund; products need a lasting team.

**Instead:** fund a long-lived team with a product owner and a roadmap. Plan for day 2: versioned interfaces, updates that reach existing services, deprecations ([Building and running](06-building-and-running-the-platform.md)).

## Building for yourselves

**Looks like:** the platform reflects the platform team's interests: the newest tools, the most flexible abstractions, a Kubernetes-everything design, while product teams wanted a faster way to get a database.

**Why it happens:** no user research; the team builds what it would want.

**Instead:** interview users, follow their journeys, and prioritize by their pain ([first 90 days](00-first-90-days.md)). Ask "whose cognitive load does this reduce?" of every item ([cognitive load](01-what-platform-engineering-is.md#the-problem-it-solves-cognitive-load)).

## Scaffold and abandon

**Looks like:** templates create services and never touch them again. A year on, there are a hundred versions of the template's past, each with its own outdated pipeline and Dockerfile, and fixing a problem means a hundred merge requests by hand.

**Why it happens:** creation is the satisfying part; updates are tedious.

**Instead:** reference what the platform owns (components, charts) instead of copying it, use a template tool that can update projects, and measure how many services are on current versions ([Day 2](03-golden-paths.md#day-2-keeping-services-on-the-path)).

## Too many paths, none finished

**Looks like:** golden paths for five languages, three deployment targets, and two databases, each partly done, none trusted end to end.

**Why it happens:** every team asks for its stack, and saying yes feels like service.

**Instead:** one path, finished and adopted, then the next by demand. A finished path for most teams beats an unfinished one for everyone.

## The leaky abstraction

**Looks like:** a high-level interface ("just declare a WebService") that works until something breaks, then leaves users unable to see what's wrong. Every failure becomes a ticket to the only people who understand the layer below.

**Why it happens:** abstractions are designed for the happy path.

**Instead:** make every abstraction inspectable (rendered manifests, events, the real resource's status), teach users one level down, and give clear feedback on failures. DORA found clear feedback to be the capability most associated with a good platform experience ([Abstraction](04-self-service-and-abstractions.md#choosing-the-level-of-abstraction)).

## Mandate instead of value

**Looks like:** adoption numbers rise because teams were told to move, while satisfaction falls and teams keep side channels for anything that matters.

**Why it happens:** a mandate shows progress quickly.

**Instead:** use mandates only where the reason isn't the platform's convenience (security, compliance, end of support), and measure satisfaction and delivery alongside adoption ([Adoption](07-adoption-and-measurement.md)). The goal is intrinsic pull.

## Rebranding operations

**Looks like:** the operations team is renamed the platform team, and works the same way: doing things for teams on request.

**Why it happens:** the name changed and the interface didn't.

**Instead:** the difference between operations and a platform is self-service. Pick the most frequent request and make it self-service first; repeat ([What platform engineering is](01-what-platform-engineering-is.md#devops-sre-and-platform-engineering)).

## Next

Back to the [platform engineering guides](README.md), or the [templates](templates/README.md).
