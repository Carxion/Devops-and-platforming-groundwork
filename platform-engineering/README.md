# Platform engineering

[← DevOps and Platforming Groundwork](../README.md)

For platform engineers and the people who lead platform teams: building an **internal developer platform** that product teams choose to use because it makes their work faster and safer. New to a platform team? Start with [your first 90 days](00-first-90-days.md). Looking for a term? [Concepts and terms](02-concepts-and-terms.md) defines the vocabulary: golden paths, paved roads, guardrails, the thinnest viable platform, cognitive load, and the rest.

The CNCF's [platforms white paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) defines a platform as "an integrated collection of capabilities defined and presented according to the needs of the platform's users." The important words are *integrated* and *the needs of the platform's users*: a pile of tools isn't a platform, and neither is infrastructure designed around what the platform team finds interesting.

| Guide | Covers |
|---|---|
| [Your first 90 days](00-first-90-days.md) | A W1/30/60/90 checklist for joining or starting a platform team: users, what exists, the first golden path, and measures |
| [What platform engineering is](01-what-platform-engineering-is.md) | Why platforms exist (cognitive load), how they relate to DevOps and SRE, Team Topologies' platform team, the platform as a product, and when you don't need one |
| [Concepts and terms](02-concepts-and-terms.md) | The vocabulary, explained and related: golden path, paved road, guardrails and gates, golden cage, escape hatch, TVP, IDP and portal, X-as-a-Service, shift down, day 0/1/2, and more |
| [Golden paths](03-golden-paths.md) | What makes one, designing and building one, templates that keep improving after day one, and the tested example in this folder |
| [Self-service and abstractions](04-self-service-and-abstractions.md) | Interfaces (templates, Git, CLIs, APIs, portals), choosing the level of abstraction, guardrails instead of gates, and ending ticket-ops |
| [Developer portals and catalogs](05-developer-portals-and-catalogs.md) | Software catalogs and ownership, Backstage's model, scaffolder templates, TechDocs, scorecards, and when a portal is worth it |
| [Building and running the platform](06-building-and-running-the-platform.md) | Capabilities, starting thin, build or buy, platform APIs and contracts, versioning and deprecation, the platform's own reliability and support |
| [Adoption and measurement](07-adoption-and-measurement.md) | Earning adoption instead of mandating it, developer experience, what to measure (DORA, time to first deploy, satisfaction), and the maturity model |
| [Anti-patterns](08-anti-patterns.md) | Portal first, the golden cage, ticket-ops in disguise, the platform as a project, abstraction leaks, and how to get out of each |

## Templates and examples

| Path | What it is |
|---|---|
| [templates/](templates/README.md) | Golden path definition, capability map, platform service definition, maturity self-assessment, developer experience survey |
| [examples/golden-path-python-service](examples/golden-path-python-service/) | A real golden path: one `copier copy` gives a team a Python service with tests, a hardened image, a GitLab pipeline that builds, scans, and deploys, values for the platform's shared Helm chart, a catalog entry, and docs. [check.sh](examples/check.sh) generates a service, runs its checks, updates it to a newer template, builds it, and deploys it to a hardened cluster |

The golden path is built from the rest of the repository: the [GitLab CI/CD component](../devops/gitlab/examples/components/README.md), the [Helm web-app chart](../devops/helm/examples/charts/web-app/), the [Python boilerplate](../software/python/README.md)'s image pattern, and the [namespace baseline](../devops/kubernetes/README.md) it deploys into. That's the point of a platform: the pieces already exist; the platform makes them one coherent, supported path.

## The short version

1. **Start from the users' pain, not the tools.** Interview product teams and follow a new service from idea to production; the waits and tickets you find are the backlog. ([Building](06-building-and-running-the-platform.md))
2. **Build the thinnest viable platform,** and grow it only where users pull. A wiki page, three templates, and well-documented cloud services can be a platform.
3. **Pave one golden path end to end** before adding a second: one kind of service from repository to production, fully supported. ([Golden paths](03-golden-paths.md))
4. **Self-service, not tickets.** If using the platform means filing a request and waiting, it's an operations queue with a new name. ([Self-service](04-self-service-and-abstractions.md))
5. **Guardrails, not gates.** Make the safe way the default and the unsafe way hard, automatically, instead of reviewing every change by hand.
6. **Earn adoption.** The platform should be the easiest way, so teams choose it. Mandating it hides whether it's any good. ([Adoption](07-adoption-and-measurement.md))
7. **Treat it as a product,** with users, a roadmap, and outcome measures, run by a team that talks to its users every week ([product owner guides](../product-owner/README.md)).
8. **Keep day 2 in mind.** A template that scaffolds a service and then abandons it creates drift; a golden path keeps improving the services already on it.

## Working with the other roles

A platform team is usually a [manager](../manager/README.md)'s team, with a [product owner](../product-owner/README.md) deciding what the platform becomes and an [architect](../architect/README.md) owning the foundations it builds on. [Structuring platform teams](../manager/07-structuring-platform-teams.md) covers team design, and [The platform as a product](../product-owner/01-the-platform-as-a-product.md) covers discovery and the product goal. This folder is about what the platform *is* and how to build it well.

> **Status.** Starter content, with named sources: the CNCF [platforms white paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) and [platform engineering maturity model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/), [Team Topologies](https://teamtopologies.com/key-concepts) (Skelton and Pais), DORA's [platform engineering capability](https://dora.dev/capabilities/platform-engineering/), Spotify's [golden paths](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem) article, and the [Backstage](https://backstage.io/docs/overview/what-is-backstage) documentation. The golden path example is tested with Copier 9.19, Helm 4.3, and Kubernetes 1.34.
