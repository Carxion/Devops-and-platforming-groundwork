# Building and running the platform

[← Platform engineering](README.md)

This guide covers deciding what to build, starting thin, building or buying, treating the platform's interfaces as APIs, changing and retiring them, and running the platform as a production service in its own right.

## Map the capabilities

List what product teams need to get software to production and keep it there, and how each is provided today. The [capability map template](templates/capability-map.md) uses the CNCF white paper's capabilities as rows:

| Capability | Today | Self-service? | Golden path covers it? |
|---|---|---|---|
| Source and review | GitLab | Yes | Yes |
| Build and test automation | Each team's own pipeline | Partly | Component |
| Delivery and verification | Manual helm commands | No | Pipeline deploy jobs |
| Runtime | Shared EKS clusters | Namespace by ticket | No |
| Data services | Managed Postgres by ticket | No | No |
| Observability | Logs yes, metrics by request | Partly | Partly |
| Identity and secrets | Long-lived keys in CI variables | No | No |
| Security services | Scans in some pipelines | Partly | Image scan |
| Artifact storage | Container registry | Yes | Yes |

The gaps and the "by ticket" entries, weighted by how often teams need them, are the platform's backlog.

## Start thin, grow by pull

The [thinnest viable platform](02-concepts-and-terms.md#thinnest-viable-platform-tvp) is the smallest set that makes teams measurably faster. A sensible first version:

1. **Documentation of the way things are done here,** with working examples: one pipeline, one Dockerfile pattern, one deploy method.
2. **One golden path** end to end, built from those ([Golden paths](03-golden-paths.md)).
3. **Self-service for the most-requested ticket** ([Ending ticket-ops](04-self-service-and-abstractions.md#ending-ticket-ops)).
4. **Guardrails** for the controls that are reviewed by hand today.

Then grow where users pull: the next path, the next capability, the next ticket type. A capability nobody asked for is a support burden with no users.

## Build, buy, or integrate

Most of a platform should be existing products, integrated well. The platform team's unique work is the integration, the defaults, and the experience.

| Choose | When | Examples |
|---|---|---|
| **Use a managed service** | It does the job and the team would only operate it | Managed Kubernetes, managed databases, the cloud's secrets manager, a hosted CI system |
| **Adopt open source** | No managed option fits, and you can run it | Argo CD, cert-manager, External Secrets Operator, Backstage |
| **Buy a product** | It saves more engineering time than it costs, and you can leave it | A commercial portal, an observability vendor |
| **Build** | It's specific to your organization and nothing fits | The golden path templates, your shared charts and components, the glue |

The question for anything you build: what happens when the two people who wrote it leave? If the answer is "nobody can change it," buy or simplify.

## The platform's interfaces are APIs

Everything a product team depends on is an API, whatever its form: a template's questions, a chart's values, a component's inputs, a module's variables, a custom resource's spec. Treat each like one:

- **Version it** with semver, and let users pin: `container-image@1.0.0`, `web-app` chart `0.2.0`.
- **Keep it compatible** within a major version. Add optional values with safe defaults; don't rename or remove. The web-app chart's generalization (new `container` and `probes` values, defaulting to the old behavior) was a minor version for exactly this reason: every existing environment renders the same.
- **Validate inputs** and fail with clear messages: a values schema, typed component inputs, template validators. Invalid input should fail at the first command, not at deploy.
- **Document it** where users look: the chart's values table, the component's README, the template's questions.
- **Test it from the user's side.** The golden path's [check.sh](examples/check.sh) tests the chart through a generated service, not just on its own.

## Changing and retiring things

Platforms accumulate old ways: an old pipeline, a deprecated chart version, a legacy cluster. Retiring them is platform work, done the way the [product owner's deprecation guide](../product-owner/04-roadmaps-and-stakeholders.md#deprecations-and-migrations) describes: make the new way better first, announce with a date and a reason, make migrating easy (an update merge request opened for every team is best), track who's left, stop new use, then switch off on the date.

Two platform-specific tools help:

- **The catalog** tells you who uses what, if services record their template, component, and chart versions.
- **Automated update merge requests** do most of a migration for teams: `copier update`, a version bump, or a codemod, opened in each repository for the owning team to review and merge.

## Run the platform as a product in production

The platform is production for every team on it: if the pipeline component breaks, nobody deploys.

- **SLOs for the platform's own capabilities:** pipeline success rate excluding user errors, time to provision, cluster availability, template success. Publish them ([platform service definition](templates/platform-service-definition.md)).
- **On-call and incidents** like any service, with users told quickly when something's wrong ([on-call](../manager/04-on-call-and-team-health.md), [incident reviews](../manager/templates/README.md)).
- **Releases users can trust:** test platform changes the way users experience them (the golden path's checks run a generated service through the chart and pipeline), release in versions, roll out gradually, and announce changes in release notes ([template](../product-owner/templates/release-notes.md)).
- **A support model:** where users ask, who answers, how fast, and how questions become docs or backlog items. A question asked three times is a documentation bug.

## The platform team

Team design is covered in [Structuring platform teams](../manager/07-structuring-platform-teams.md). What's specific to building a platform:

- **Product skills on the team,** not just infrastructure skills: someone who does user research, writes well, and measures outcomes ([product owner](../product-owner/README.md)).
- **Time with users,** every week: office hours, pairing on onboarding, sitting with a team through a deploy.
- **A contribution model:** other teams can propose changes to templates, charts, and components by merge request, reviewed by the platform team. DORA recommends extensibility so the platform doesn't become a bottleneck.
- **Dogfooding:** the platform team's own services go through the golden path. Pain they feel gets fixed fast.

## Next

[Adoption and measurement](07-adoption-and-measurement.md).
