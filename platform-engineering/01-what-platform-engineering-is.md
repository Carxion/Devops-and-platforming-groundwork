# What platform engineering is

[← Platform engineering](README.md)

Platform engineering is building and running an **internal platform as a product**: a coherent set of self-service capabilities (create a service, get a database, deploy, observe, manage secrets) that product teams use to ship software without each team becoming expert in everything underneath. This guide covers why it exists, how it relates to DevOps and SRE, where the platform team sits, and when you don't need one.

## The problem it solves: cognitive load

DevOps asked product teams to own their software end to end: build it, ship it, run it. That was right, and it brought a problem with it. To ship one service, a team now needs to know containers, a CI system, Kubernetes, Helm or Kustomize, a cloud's identity model, networking, secrets management, observability, policy, and cost. Each is a specialty. A team spending its attention on all of them has less for the product.

Team Topologies (Matthew Skelton and Manuel Pais) frames this as **cognitive load**: teams "can only handle so much complexity." Drawing on cognitive load theory, it's useful to separate three kinds:

| Kind | Is | A platform should |
|---|---|---|
| **Intrinsic** | The complexity of the problem itself: the business domain, the service's own logic | Leave it with the team. It's their job |
| **Extraneous** | Complexity that comes from the environment: how to get a certificate, which pipeline syntax, how this cluster does ingress | Remove as much as possible |
| **Germane** | The learning that makes the team better at its domain | Make room for it |

A platform's job is to take on extraneous load, so product teams can spend theirs on intrinsic and germane work. That's the test for anything the platform builds: whose cognitive load does it reduce, and by how much?

The CNCF's [platforms white paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) gives the same reasons in operational terms: reduce cognitive load on product teams, improve reliability and resilience, accelerate development through reuse, reduce security and compliance risk, and use cloud services cost-effectively.

## DevOps, SRE, and platform engineering

| | Is | Relationship |
|---|---|---|
| **DevOps** | A culture and set of practices: the people who build software also ship and run it, with automation and shared responsibility | Platform engineering is one way to make DevOps work at scale, without every team rebuilding the same infrastructure |
| **SRE** | Reliability engineering: SLOs, error budgets, incident response, and engineering away toil | Platforms build reliability in (probes, rollbacks, SLO tooling), and the platform itself needs SRE practices |
| **Platform engineering** | Building the internal product that provides shared capabilities as self-service | The platform is how DevOps and SRE practices reach every team by default |

A platform team isn't an operations team with a new name. The difference is the interface: an operations team does things *for* product teams when asked; a platform team builds things product teams do *themselves*.

## The platform team in Team Topologies

[Team Topologies](https://teamtopologies.com/key-concepts) names four team types and three ways they interact:

| Team type | Does |
|---|---|
| **Stream-aligned** | Delivers a flow of work for a part of the business: the product teams, and the platform's customers |
| **Platform** | Provides "a compelling internal product to accelerate delivery" for stream-aligned teams |
| **Enabling** | Helps other teams adopt new practices or tools, then steps away |
| **Complicated subsystem** | Owns a part that needs deep specialist knowledge |

| Interaction mode | Means | Platform example |
|---|---|---|
| **X-as-a-Service** | One team provides, another consumes, with little coordination | Teams use the golden path without talking to the platform team: the goal state |
| **Collaboration** | Two teams work closely, for a limited time, to discover something | The platform team pairs with a product team to design a new golden path |
| **Facilitation** | One team helps and mentors another | An enabling engineer helps a team migrate onto the platform |

The default between platform and product teams should be **X-as-a-Service**. Collaboration is for discovery, and it should end: a platform that needs to collaborate with every team to be used isn't self-service yet. [Structuring platform teams](../manager/07-structuring-platform-teams.md) covers team design in more depth.

## The platform as a product

The CNCF white paper lists the attributes of a good platform: **platform as a product, user experience, documentation and onboarding, self-service, reduced cognitive load, optional and composable, and secure by default.** The first is the one the others depend on: a platform is a product whose customers are other engineers, who usually have alternatives (building their own, or going straight to the cloud). It needs:

- **Users it understands,** from interviews and observation, not assumptions.
- **A product goal** and a roadmap, so it isn't run as a queue of requests.
- **Outcome measures:** time to first deploy, adoption, satisfaction, delivery performance.
- **Marketing and support:** docs, onboarding, a place to ask, and announcements of changes.

The [product owner guides](../product-owner/README.md) cover how: users and discovery, the product goal, backlog, prioritization, roadmaps, and measuring outcomes.

## What a platform contains

The white paper's capabilities, roughly what a mature platform offers:

| Group | Capabilities |
|---|---|
| **Interfaces** | Web portals; APIs for provisioning; golden path templates and documentation |
| **Build and delivery** | Automation for building and testing; automation for delivering and verifying services; development environments |
| **Runtime and resources** | Infrastructure services; data services; messaging and event services |
| **Cross-cutting** | Application observability; identity and secret services; security services; artifact storage |

Nobody builds all of that first, and most of it should be existing products (a cloud's managed database, a CI system, an observability stack) integrated and presented coherently, not built from scratch. [Building and running the platform](06-building-and-running-the-platform.md) covers where to start.

## When you don't need a platform team

A platform team costs several engineers. It pays back when many teams repeat the same work. Signs you're not there yet:

- **A few teams,** who can agree conventions in a conversation. Shared templates and a wiki page may be the whole platform for now.
- **One kind of workload,** already well served by a managed service (a PaaS, a serverless platform) that is in effect someone else's platform.
- **No time to talk to users.** A platform team that can't do discovery will build the wrong thing; better to start with an enabling engineer who works inside product teams and finds the repeated pain.

The **thinnest viable platform** (Team Topologies' term) is the answer to "how much platform?": the smallest set of capabilities that makes teams measurably faster, grown only as users pull. [Concepts and terms](02-concepts-and-terms.md#thinnest-viable-platform-tvp) has more.

## What the research says

DORA's research on [platform engineering](https://dora.dev/capabilities/platform-engineering/) is the most useful public evidence:

- Using an internal developer platform improves individual productivity, team performance, and organizational performance. It can also lower change stability and throughput if it isn't managed carefully, so measure delivery performance alongside productivity ([DORA 2024 report](https://dora.dev/research/2024/dora-report/)).
- Developer **independence**, doing tasks without depending on an enabling team, was associated with a 5% productivity improvement at both team and individual levels.
- The platform capability most associated with a good user experience is **clear feedback on task outcomes**: when something fails, developers can see what and why.
- Expect a dip before the gains: introducing a platform adds complexity before it removes it.
- The recommended practices are product-centric: user research, a minimum viable platform built around the most common workflow, extensibility so other teams can contribute, and avoiding rigid one-size-fits-all mandates.

## Next

[Concepts and terms](02-concepts-and-terms.md).
