# Golden paths

[← Platform engineering](README.md)

A golden path is the opinionated, supported way to do a common thing, end to end ([definition](02-concepts-and-terms.md#golden-path)). It's the most visible part of a platform, and the easiest to get wrong: a template that scaffolds a service and walks away, or a path so rigid nobody can use it. This guide covers what makes a good one, how to design and build it, how to keep services on it after day one, and the [tested example](examples/golden-path-python-service/) in this folder.

## What a good golden path has

| Property | Means | Missing it looks like |
|---|---|---|
| **End to end** | From "I need a service" to running in production, observed, with an owner | A repository template, after which the team works out the pipeline, deploy, and monitoring alone |
| **Opinionated** | Decisions made, with reasons: language version, layout, pipeline, image, deploy method, logging, health checks | A menu of twenty options, which is a different kind of work for the team |
| **Supported** | The platform team keeps it working and answers questions, with a known response time | "It's in the template repo; good luck" |
| **Secure and compliant by default** | The controls the organization needs are already in, so using the path *is* compliance | A security review at the end that finds what the path should have prevented |
| **Fast to start** | A working, deployed service in minutes to hours | A week of tickets |
| **Leavable** | Documented escape hatches for each part, and an honest statement of what support you lose off the path | A [golden cage](08-anti-patterns.md#the-golden-cage) |
| **Kept current** | Improvements reach services already on the path | Hundreds of copies of last year's best practice ([drift](02-concepts-and-terms.md#template-drift)) |
| **Documented as a journey** | A tutorial that walks the path, step by step, plus reference docs | A README that lists files |

Spotify's golden paths began as step-by-step tutorials (in their portal, Backstage) for the most common tasks, before any automation. A clear, tested tutorial is a valid first version; automate the steps people get wrong.

## Choosing the first one

Pick the path that combines **frequency** (how often teams do it) and **pain** (how long it takes, how often it goes wrong, how many tickets it needs). For most organizations, that's "a new HTTP service, to production." Others worth considering: adding a database to a service, a new event consumer, a scheduled job, a static website.

Find it from evidence:

- **Follow the journey yourself:** create a service from nothing, with only the docs, and time each step ([first 90 days](00-first-90-days.md#2-what-exists)).
- **Count the variants:** how many pipeline styles, Dockerfiles, and deploy methods exist for the same kind of service. Many variants means high fragmentation and high payoff.
- **Read the requests:** group the platform team's tickets; the largest groups are steps a path should automate.

Build one path well before starting a second. A platform with five half-finished paths has five support burdens and no success story.

## Designing it with its users

Write the path's definition before building it ([template](templates/golden-path-definition.md)), with two or three of the teams who'll use it:

- **Who it's for, and who it isn't.** "Stateless HTTP services in Python on Kubernetes" is designable; "all services" isn't.
- **What it decides,** and why, in the users' terms. Each decision is a question the team no longer has to answer.
- **What the team still owns:** the code, its tests, its configuration values, its on-call.
- **The escape hatches:** for each part (code layout, image, pipeline, deploy), what leaving looks like and what support goes with it.
- **How it stays current:** how services get the path's improvements.
- **How success is measured:** time to first deploy, the number of teams on it, what they say ([Adoption and measurement](07-adoption-and-measurement.md)).

## Building it from what exists

A golden path is mostly integration: the pipeline, image pattern, chart, and policies usually exist somewhere; the path makes them one coherent, tested route. Build each part so it can be used alone too ([composability](02-concepts-and-terms.md#composability)).

| Part | Copy or reference | Why |
|---|---|---|
| Application code, tests, Dockerfile | **Copy** into the new project | The team owns and changes them from day one |
| Pipeline logic | **Reference**: a versioned CI/CD component or shared library | One fix reaches every service on its next pipeline |
| Deploy configuration | **Reference** a shared chart or module; the service supplies values | The platform owns the hardened manifests; teams own the settings |
| Policies and guardrails | **Enforce** in the platform: admission, pipeline checks, cloud policy | They apply whether or not a team uses the path |
| Catalog entry and docs | **Copy**, with the owner filled in | The service appears in the catalog from its first commit |

The rule of thumb: copy what the team should own; reference what the platform should keep improving. Every line you copy is a line that drifts.

## The example: a Python service

[golden-path-python-service](examples/golden-path-python-service/) is a [Copier](https://copier.readthedocs.io/en/stable/) template built from the rest of this repository. One command, with a few questions:

```sh
copier copy --trust <template-repository> orders-api
# service_name: orders-api
# owner: team-orders
# system: sample-apps
# ...
```

gives a team:

| File | From | Gives |
|---|---|---|
| `src/`, `tests/`, `pyproject.toml`, `uv.lock` | Copied | A FastAPI service with `/healthz` and `/readyz`, JSON logging, strict typing, and tests; dependencies locked for this service |
| `Dockerfile` | Copied | The platform's non-root, two-stage image pattern, base images pinned by digest |
| `.gitlab-ci.yml` | Copied, mostly references | Lint, type check, and test with reports in the MR; the platform's [container-image component](../devops/gitlab/examples/components/README.md) builds, scans, and pushes; deploys to dev automatically and production manually, with `--wait` and automatic rollback |
| `deploy/dev.yaml`, `deploy/production.yaml` | Copied | Values for the platform's shared [web-app chart](../devops/helm/examples/charts/web-app/), which the service references by version; the hardened manifests stay the platform's |
| `catalog-info.yaml` | Copied | Its Backstage catalog entry, with the owner |
| `docs/`, `mkdocs.yml` | Copied | TechDocs: how to run, change, and operate it |
| `CODEOWNERS` | Copied | The team reviews everything; the platform team also reviews pipeline and deploy changes |
| `.copier-answers.yml` | Generated | Which template version it came from, for updates |

[check.sh](examples/check.sh) tests the path the way a team would use it, and found real problems while it was written:

| Check | Caught |
|---|---|
| Generate a service, then run its own pipeline's checks (locked dependencies, ruff, mypy, pytest) | The first version generated code that failed its own formatter: a golden path that hands teams a failing pipeline on day one |
| Reject an invalid service name | Names that would break image, release, and DNS names later |
| Release a new template version, then `copier update` a service with local edits | Whether improvements arrive without losing the team's changes |
| Build the image and call `/healthz` and `/` as a non-root user | The image actually runs |
| Render the shared chart with the service's values; lint and kubeconform | The values fit the chart's schema |
| Install on a kind cluster with Pod Security "restricted" and default-deny, then `helm test` | The first version named everything `orders-api-web-app`: a shared chart names resources after itself unless the service sets `nameOverride`. And the chart had to be generalized first; it had podinfo's port and command built in |

That last row is the general lesson: **a golden path isn't done until a generated service has gone all the way to a production-like environment.** Each part can pass its own tests and the path still fail at the joins.

## Day 2: keeping services on the path

Most of a service's life comes after it's created. Three mechanisms keep golden path improvements flowing to existing services:

1. **References, not copies,** for what the platform owns: the CI/CD component version, the chart version. Bumping them is a one-line change, which tools like Renovate can propose automatically.
2. **Template updates** for what was copied. Copier records the template version in `.copier-answers.yml`; `copier update` applies the template's changes since then as a three-way merge, keeping the team's own edits. The example's check releases a v1.1.0 that adds a file, updates a service with a local change, and confirms both survive.
3. **Automated merge requests** for changes that need code edits: a job that runs `copier update` (or a codemod) across services and opens a merge request in each, which the owning team reviews.

Then measure it: what share of services are on the latest template version, component version, and chart version? That number is the golden path's day-2 health.

## Escape hatches in practice

Design leaving into the path, part by part, and say what it costs:

| Step off by | Keep | Lose |
|---|---|---|
| Changing the application code and dependencies | Everything | Nothing: it's yours |
| Writing your own Dockerfile | Pipeline, scanning, deploy, catalog | The platform's image updates; you patch your base images |
| Adding pipeline jobs | Everything else | Nothing, as long as the component's jobs stay |
| Replacing the deploy chart | Pipeline, image, catalog | Platform support for the manifests; you keep them compliant with the guardrails |
| Not using the path at all | The guardrails, which apply anyway | Templates, updates, and platform support |

The guardrails apply on and off the path, so leaving it is a trade of convenience and support, never of safety. That's what makes it safe to allow.

## Next

[Self-service and abstractions](04-self-service-and-abstractions.md).
