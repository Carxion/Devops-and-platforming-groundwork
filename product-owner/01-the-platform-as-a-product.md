# The platform as a product

[← Product owner](README.md)

A platform is a product whose users are engineers. This guide covers what the product owner is accountable for, who the users are, how to learn what they need, and how to set a goal the backlog can serve. The organizational side (team types, and why a platform should be run as a product) is in the manager's [Structuring platform teams](../manager/07-structuring-platform-teams.md#the-platform-as-a-product).

## The accountabilities

The [Scrum Guide](https://scrumguides.org/scrum-guide.html) makes the Product Owner accountable for maximizing the value of the product, and for effective Product Backlog management, which includes:

- developing and explicitly communicating the Product Goal,
- creating and clearly communicating Product Backlog items,
- ordering Product Backlog items, and
- ensuring the Product Backlog is transparent, visible, and understood.

The product owner can delegate the work (the team often writes items), but stays accountable. And they're **one person, not a committee**: when five stakeholders each set priorities, nobody does.

What the role isn't: a project manager tracking dates, a proxy who passes requests from stakeholders to the team, or the team's manager. The Developers decide how much they can do in a sprint and how to do it.

## Who the users are

A platform usually has several groups of users with different needs. Name them, because "developers" is too broad to design for:

| User | Typical needs | Example measure |
|---|---|---|
| Product engineers shipping services | Get from idea to production fast; not think about infrastructure | Time from new repository to first production deploy |
| Teams operating services | See what's happening, get paged for the right things, fix quickly | Time to find the cause of an incident |
| Data and ML engineers | Compute, storage, and pipelines with the right access | Time to get a working environment |
| Security and compliance | Controls that hold everywhere without chasing teams | Share of services meeting the baseline |
| Finance and leadership | Predictable cost, visible value | Cost per service or per team; adoption |
| New hires | Get productive without a guide sitting next to them | Days to first merged change |

Users also differ in how much control they want: some want a paved road that handles everything, others want building blocks they assemble. The usual answer is a golden path that covers most cases, with escape hatches for the rest, and a clear view of what the platform supports in each.

## Discovery: learning what users need

Requests tell you what users think the solution is. Discovery finds the problem behind them.

- **Interview users** regularly, a few a month, not only when planning. Ask about their recent work, not hypotheticals: "Tell me about the last time you created a new service," rather than "Would you use a service template?" The [user interview guide](templates/user-interview-guide.md) has questions.
- **Watch them work.** Sit with an engineer setting up a new service. The steps they skip, the docs they don't find, and the colleague they message instead are the findings.
- **Read the support channel.** The questions asked most often are the biggest usability gaps.
- **Look at the data:** which capabilities are used, which are abandoned halfway, and where requests wait.
- **Talk to the teams that don't use the platform.** Their reasons (missing features, distrust, a past outage) are often the most important input.

Write down what you learn where the team can see it. Shared understanding of users is what lets the team make good small decisions without asking you.

## The product goal

The Scrum Guide's Product Goal is the long-term objective for the team, which the Product Backlog serves. One goal at a time; the team fulfills (or abandons) it before taking on the next.

A good product goal for a platform:

- **Describes an outcome for users,** not a list of features: "Any team can take a new service to production in under a day, without a ticket," not "Build service templates, a deployment pipeline, and a database module."
- **Is measurable,** so you know when it's met.
- **Fits a horizon of months,** not weeks or years.
- **Helps say no:** if a request doesn't serve the goal, it can wait.

The [product goal canvas](templates/product-goal.md) walks through users, problems, the goal, measures, and what's out of scope.

## Start with the thinnest viable platform

Team Topologies (Skelton and Pais) describes the **thinnest viable platform**: the smallest set of capabilities that makes product teams faster. Sometimes it's a wiki page of approved patterns, a set of templates, and a few well-documented cloud services, not a large custom system.

Grow it only when users need more, and prefer:

- **Buying or using managed services** over building, for anything that isn't specific to your organization.
- **Self-service over tickets:** every request that needs a human is a queue.
- **Documentation and templates** as product features, not afterthoughts.
- **Fewer, well-supported capabilities** over many half-finished ones.

A platform that tries to do everything ends up maintaining everything, with nothing left to improve the parts users depend on.

## Next

[Backlog management](02-backlog-management.md).
