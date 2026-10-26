# Concepts and terms

[← Platform engineering](README.md)

Platform engineering has a vocabulary of its own, and several terms are used loosely or interchangeably. This guide defines each one, says where it comes from when there's a clear source, and explains how it relates to the others. The [glossary](../GLOSSARY.md) has one-line versions.

| Group | Terms |
|---|---|
| [The platform](#the-platform) | Platform engineering, internal developer platform (IDP), internal developer portal, platform as a product, thinnest viable platform, platform team, stream-aligned team, X-as-a-Service, cognitive load, developer experience |
| [Paths](#paths) | Golden path, paved road, opinionated defaults, golden cage, escape hatch, off the path, fragmentation, rumour-driven development, tech radar |
| [Control without gatekeeping](#control-without-gatekeeping) | Guardrails, gates, secure by default, policy as code, shift left, shift down, ticket-ops, ClickOps |
| [Building blocks](#building-blocks) | Software template, scaffolding, day 0, day 1, day 2, template drift, software catalog, ownership, scorecard, platform API, abstraction, leaky abstraction, platform orchestrator, composability |
| [Developer workflow](#developer-workflow) | Inner loop, outer loop, time to first deploy, ephemeral environment, self-service, developer journey |
| [People and adoption](#people-and-adoption) | Platform product manager, platform champion, enabling team, inner source, mandate, intrinsic pull |

---

## The platform

### Platform engineering

Building and running an internal platform as a product, so product teams can deliver software through self-service instead of each building and operating their own tooling. The CNCF's [platforms white paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) describes platforms as curating and presenting "foundational capabilities, frameworks and experiences to facilitate and accelerate the work of internal customers." ([What platform engineering is](01-what-platform-engineering-is.md))

### Internal developer platform (IDP)

The platform itself: the integrated set of capabilities, tools, workflows, and interfaces product teams use to build, deploy, and run software. Pipelines, templates, clusters, managed services, identity, observability, and the APIs and automation that tie them together. An IDP doesn't need a portal; many good ones are templates, Git workflows, and documentation.

### Internal developer portal

A user interface *to* the platform: a website where developers find services and their owners, create new ones from templates, read docs, and see status. Backstage is the best-known example. **The portal is not the platform.** A portal in front of ticket-driven processes is a nicer way to wait. The two share the abbreviation "IDP", which causes confusion; say which you mean. ([Developer portals and catalogs](05-developer-portals-and-catalogs.md))

### Platform as a product

Running the platform like a product: users you understand, a product goal and roadmap, outcome measures, documentation, support, and marketing. The opposite of the platform as a project (built once, then maintained) or as a cost center (run as a ticket queue). It's the first attribute in the CNCF white paper's list, and the one the others depend on. ([Product owner guides](../product-owner/01-the-platform-as-a-product.md))

### Thinnest viable platform (TVP)

From Team Topologies: the smallest platform that makes product teams measurably faster. Team Topologies warns that "most internal platforms become bloated monstrosities that slow teams down"; a TVP provides "just enough capability without unnecessary complexity." It can be a wiki page of approved patterns plus some templates. It grows only where users pull it, and it's the same idea DORA calls a **minimum viable platform**: start with the most common workflow.

### Platform team, stream-aligned team

Team Topologies' team types. A **stream-aligned team** delivers a flow of work for part of the business (a product team). A **platform team** provides "a compelling internal product to accelerate delivery" for stream-aligned teams. The platform team's customers are the stream-aligned teams. ([The platform team in Team Topologies](01-what-platform-engineering-is.md#the-platform-team-in-team-topologies))

### X-as-a-Service

Team Topologies' interaction mode where "one team provides and one team consumes something 'as a Service'", with little coordination. The target relationship between a platform and its users: teams consume the platform without meetings, tickets, or the platform team's attention. The other modes, **collaboration** and **facilitation**, are for discovering and adopting, and should be temporary.

### Cognitive load

How much a team has to hold in mind to do its work. Team Topologies' point is that teams "can only handle so much complexity", so a platform's purpose is to take extraneous load (how this cluster does ingress, how to get a certificate) off product teams. ([Cognitive load](01-what-platform-engineering-is.md#the-problem-it-solves-cognitive-load))

### Developer experience (DevEx)

How it feels to do the work: how fast the feedback is, how often you're blocked, how much you have to know. A platform's user experience is developer experience. The [measuring outcomes guide](../product-owner/05-measuring-outcomes.md) covers the SPACE and DevEx frameworks for measuring it.

---

## Paths

### Golden path

The supported, opinionated way to do a common thing, end to end: create a service, add a database, publish an API. Spotify's [description](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem): "the 'opinionated and supported' path to 'build something'." Two parts of that matter:

- **Opinionated:** it makes decisions for you (the language version, the pipeline, the deploy method, the logging format), so you don't have to.
- **Supported:** the platform team keeps it working and helps when it breaks. Leaving it is allowed, but "you will not have the same support."

A golden path is more than a template: it covers the whole journey, includes docs and tutorials, and keeps the services on it current. ([Golden paths](03-golden-paths.md))

### Paved road

Often used as a synonym for golden path, and usually attributed to Netflix. Where a distinction is drawn, a **paved road** emphasizes the infrastructure that makes the path smooth (the road), while a **golden path** emphasizes the journey and its guidance. In practice, pick one term and use it consistently.

### Opinionated defaults

Choices the platform makes so users don't have to, which users can change when they have a reason. Defaults are how a golden path removes decisions without removing freedom. "Secure by default" is the most important case.

### Golden cage

A golden path that can't be left: everything must go through it, and it doesn't fit everyone. It produces workarounds, shadow infrastructure, and resentment. The difference between a golden path and a golden cage is whether there's a way off. ([Anti-patterns](08-anti-patterns.md#the-golden-cage))

### Escape hatch, off the path

A documented way to step off the golden path for part of the stack while keeping the rest: your own Dockerfile but the platform's pipeline, your own chart but the platform's cluster. Going **off the path** means taking on more of the responsibility yourself, with less support, and that trade should be explicit. Good escape hatches are what let a platform be opinionated without being a cage.

### Fragmentation, rumour-driven development

The problem golden paths solve. **Fragmentation** is many teams doing the same thing many different ways: twelve pipeline styles, five logging libraries. Spotify named the way it happens: **rumour-driven development**, where engineers learn how to do things by asking whoever seems to know, which "simply wasn't scalable." Counting the ways teams do one thing is a good first measure of a platform's opportunity.

### Tech radar

A published view of which technologies are recommended, allowed, being trialed, or on the way out, popularized by Thoughtworks. It tells teams what the golden paths are built on, and makes "on the path" and "off the path" visible.

---

## Control without gatekeeping

### Guardrails and gates

A **gate** stops work until someone approves it: a change advisory board, a security review ticket, a firewall request. A **guardrail** keeps work safe automatically and lets it continue: a policy that rejects a public storage bucket, a pipeline step that fails on a critical vulnerability, a namespace that only admits non-root pods. Platforms replace gates with guardrails wherever the rule can be automated, so the safe way is the default and the unsafe way fails fast, without a queue. ([Self-service and abstractions](04-self-service-and-abstractions.md#guardrails-not-gates))

### Secure by default

The platform's defaults are the secure choice: non-root containers, encryption on, least-privilege identities, private networking. A team gets them by doing nothing, and has to opt out deliberately. One of the CNCF white paper's platform attributes.

### Policy as code

Rules written as code, versioned and tested, and enforced automatically: admission policies (Kyverno, OPA Gatekeeper, Pod Security), IaC scanning (checkov), cloud guardrails (AWS SCPs, Azure Policy). The mechanism behind most guardrails. ([Delivery architecture](../architect/05-delivery-architecture.md#policy-as-code))

### Shift left, shift down

**Shift left** moves concerns like testing and security earlier in the development cycle, which in practice often means onto developers. **Shift down** moves them into the platform underneath developers instead. Richard Seroter's [argument for shifting down](https://cloud.google.com/blog/products/application-development/richard-seroter-on-shifting-down-vs-shifting-left) (Google Cloud, 2023) is that asking developers to absorb every concern earlier is "too much"; better to "push more workloads down onto the platforms they're already using." Both have a place: shift left the feedback, shift down the work.

### Ticket-ops

Running a "platform" through requests: file a ticket for a namespace, a database, a DNS record, and wait. It hides queues and handoffs behind a form. The most common thing a platform replaces, and the most common thing a disappointing platform turns into. DORA lists treating the platform as "a reactive ticket system" as a pitfall.

### ClickOps

Making changes by clicking in a cloud console or UI instead of through code. Fast once, impossible to review, repeat, or audit. Platforms replace it with templates and code-defined resources.

---

## Building blocks

### Software template, scaffolding

A **software template** generates a new project with the platform's decisions built in: code layout, pipeline, image build, deploy configuration, catalog entry, docs. **Scaffolding** is running it. Tools include Copier and Cookiecutter (command-line), Backstage's Software Templates (portal), and plain repository templates. The [example in this folder](examples/golden-path-python-service/) is a Copier template.

### Day 0, day 1, day 2

Stages of a service's life. **Day 0** is design and planning; **day 1** is creating and first deploying it; **day 2** is everything after: upgrades, patches, scaling, incidents, migrations, deprecation. Most of a service's life is day 2. A platform that only helps on day 1 (scaffold and walk away) leaves the hardest part to every team.

### Template drift

The gap between a service and the template it came from, as the template improves and the service doesn't. One-shot scaffolding guarantees drift; a year later, a platform has a hundred slightly different copies of its old best practice. Tools that can **update** generated projects (`copier update`), shared components and charts that services *reference* rather than *copy*, and automated update merge requests all close the gap. ([Golden paths](03-golden-paths.md#day-2-keeping-services-on-the-path))

### Software catalog, ownership

A **software catalog** is the inventory of what exists: services, APIs, libraries, resources, and their relationships, each with an **owner**. Backstage's catalog is the common model: entities (Component, API, Resource, System, Domain, Group, User) described in a `catalog-info.yaml` next to the code. Clear ownership is the catalog's most valuable field: during an incident or a vulnerability, "who owns this?" must have an answer. ([Developer portals and catalogs](05-developer-portals-and-catalogs.md))

### Scorecard

A per-service report of how it measures against the platform's standards: has an owner, has runbooks, uses a supported language version, has no critical vulnerabilities, has an SLO. Used to show teams where they stand and to target improvement. Used as a league table to shame teams, it produces gaming.

### Platform API

The contract between the platform and its users, whatever form it takes: a template's questions, a chart's values, a Terraform module's variables, a Kubernetes custom resource, a REST API. Like any API, it needs versioning, documentation, compatibility, and deprecation. ([Building and running the platform](06-building-and-running-the-platform.md#the-platforms-interfaces-are-apis))

### Abstraction, leaky abstraction

An **abstraction** hides detail behind a simpler interface: "a web service with these settings" instead of a Deployment, Service, HPA, PDB, NetworkPolicy, and Ingress. A **leaky abstraction** forces users to understand the hidden detail anyway, usually when something breaks. Good platform abstractions are honest about what they hide, and let users see underneath when they need to (`helm get manifest`, `kubectl describe`). ([Self-service and abstractions](04-self-service-and-abstractions.md#choosing-the-level-of-abstraction))

### Platform orchestrator

A component that takes a developer's high-level request ("this service needs a Postgres database in staging") and turns it into concrete resources per environment, according to platform rules. Examples range from Crossplane compositions and Kubernetes operators to commercial orchestrators. Useful at scale; most platforms start with templates, modules, and charts instead.

### Composability

Platform capabilities that can be used independently and combined: the pipeline without the portal, the database module without the golden path. "Optional and composable" is one of the CNCF white paper's attributes. Composability is what makes escape hatches possible.

---

## Developer workflow

### Inner loop, outer loop

The **inner loop** is a developer's own cycle: write code, run it, test it, repeat, usually on their machine, in seconds. The **outer loop** is everything after a commit: review, CI, build, deploy, verify, in minutes to days. Platforms usually focus on the outer loop; slow inner loops (a service that can't run locally, tests that need a shared environment) cost more developer time than most outer-loop problems.

### Time to first deploy

How long it takes from "we need a new service" to that service running in production, or at least in a real environment. A direct measure of a platform's day-1 experience, and easy to baseline by doing it yourself ([first 90 days](00-first-90-days.md#2-what-exists)). Related: **time to first commit** for a new engineer.

### Ephemeral environment

A short-lived environment created for one purpose, usually one merge request, and destroyed after: a review app. They let changes be tested in isolation without shared, contended staging environments. ([Review apps](../devops/gitlab/07-environments-and-deployments.md#review-apps))

### Self-service

Users doing something themselves, immediately, without asking anyone: through a template, a pull request to a Git repository, a CLI, an API, or a portal. The defining property of a platform. If a capability needs a ticket, it isn't self-service yet, however good the form looks.

### Developer journey

The sequence of steps a developer goes through to achieve something (onboard, create a service, add a dependency, respond to an alert), mapped from their point of view. **Journey mapping** is how platform teams find where time goes; DORA recommends it as part of a product approach.

---

## People and adoption

### Platform product manager

The person accountable for what the platform becomes and why: users, product goal, roadmap, prioritization, and outcomes. In Scrum terms, the product owner. ([Product owner](../product-owner/README.md))

### Platform champion

An engineer in a product team who knows the platform well, gives feedback early, and helps their team adopt it. A lightweight way to scale the platform team's reach; not a substitute for good docs.

### Enabling team

Team Topologies' team type that helps other teams adopt new practices or tools, then steps away. Platform teams often play this role temporarily when launching a golden path or migrating teams onto the platform.

### Inner source

Applying open-source practices inside a company: anyone can read the platform's code and contribute a change by merge request. DORA recommends "extensibility by design" so domain teams can contribute; inner source is how, and it keeps the platform team from being a bottleneck.

### Mandate, intrinsic pull

Two ways to get adoption. A **mandate** requires teams to use the platform; **intrinsic pull** is teams choosing it because it's the easiest way to do their job. The CNCF [maturity model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/) describes adoption maturing from "erratic" through "extrinsic push" to "intrinsic pull" and "participatory." Mandates aren't always wrong (security controls, end of life for old systems), but a platform that only grows by mandate isn't being told whether it's good. ([Adoption and measurement](07-adoption-and-measurement.md))

## Next

[Golden paths](03-golden-paths.md).
