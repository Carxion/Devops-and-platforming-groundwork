# Developer portals and catalogs

[← Platform engineering](README.md)

An internal developer portal is a website in front of the platform: a catalog of what exists and who owns it, templates to create new things, documentation, and status from other tools. It's useful, popular, and frequently built too early. This guide covers the software catalog, Backstage's model, templates and docs in a portal, scorecards, and when a portal is worth it.

## Portal and platform are different things

The portal is an interface *to* the platform ([definitions](02-concepts-and-terms.md#internal-developer-portal)). It doesn't create self-service; it presents it. A portal over a platform that still runs on tickets gives developers a form to wait behind. Build the capabilities first (templates that work, pipelines that deploy, guardrails that replace reviews), and add a portal when finding and using them has become the problem.

## The software catalog

The catalog answers questions every organization asks, usually at a bad time:

- **Who owns this service?** During an incident, or when a vulnerability lands.
- **What depends on it?** Before a change or a deprecation.
- **What do we have?** For audits, cost reviews, and migrations.

[Backstage](https://backstage.io/docs/overview/what-is-backstage)'s catalog model is the de facto standard. Each entity is described in YAML, usually in a `catalog-info.yaml` in the entity's own repository, so ownership lives next to the code and changes through review:

| Kind | Is |
|---|---|
| `Component` | A piece of software: a service, website, or library |
| `API` | An interface a component provides (OpenAPI, AsyncAPI, GraphQL, gRPC) |
| `Resource` | Infrastructure a component needs: a database, a bucket, a queue |
| `System` | A set of components and resources that together provide a capability |
| `Domain` | Related systems sharing a business area |
| `Group`, `User` | Teams and people, usually synced from the identity provider |
| `Template` | A software template, for the scaffolder |
| `Location` | A pointer to more catalog files |

A `Component` needs a `type`, a `lifecycle` (`experimental`, `production`, `deprecated`), and an `owner`. The golden path example generates one:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  description: Takes and tracks orders.
  annotations:
    gitlab.com/project-slug: apps/orders-api
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: experimental
  owner: group:team-orders
  system: sample-apps
```

Annotations connect the entity to other tools (its repository, its docs, its pipelines, its dashboards), which plugins then show on the entity's page.

What makes a catalog trustworthy:

- **Generated, not filled in.** The golden path creates the entry with the service, so it exists from the first commit. Catalogs that rely on teams remembering to register go stale.
- **Owners are teams, not people.** People move; `group:team-orders` survives a reorganization better, and the group's members come from the identity provider.
- **Checked.** A pipeline job or scorecard that flags services without an owner, or owners that no longer exist.
- **Discovered, as a backstop.** Scanning the repository host and cloud accounts for things that aren't in the catalog finds what slipped through.

## Templates in the portal

Backstage's **Software Templates** (the scaffolder) put a form in front of creating things: fill in a name and owner, and it creates the repository, generates the content, registers the catalog entry, and can call other actions. A template is itself a catalog entity (`kind: Template`) with parameters and steps.

Keep the template's content usable outside the portal: the [example](examples/golden-path-python-service/) is a Copier template that runs from a terminal, in CI, and could sit behind a scaffolder form. That way the golden path doesn't depend on the portal, the template can be tested on its own (as [check.sh](examples/check.sh) does), and `copier update` keeps working after creation, which one-shot scaffolding can't.

## Docs in the portal

**TechDocs** renders Markdown from each repository (with MkDocs) and shows it on the entity's page. The golden path generates `mkdocs.yml` and `docs/`, so every service starts with an overview and an operating page. Docs next to the code get updated with the code; docs in a separate wiki drift.

## Scorecards

A scorecard shows each service against the platform's standards: owner set, docs present, on a supported runtime, on the latest template and chart versions, no critical vulnerabilities, an SLO defined. They're good for:

- **Showing teams where they stand,** with a link to how to fix each item.
- **Targeting the platform's work:** a standard most services fail is usually a platform problem, not a team problem.
- **Tracking migrations:** the share of services on the new version.

Keep the checks few, automatic, and actionable. A scorecard turned into a league table produces gaming; one that points to a golden path fix produces improvements.

## When a portal is worth it

| Signs you need one | Signs you don't yet |
|---|---|
| Developers can't find which services exist, who owns them, or where their docs are | A few dozen services, and everyone knows who owns what |
| Several golden paths and capabilities, and people don't know they exist | One golden path that isn't finished |
| Information is spread across many tools, and people visit five to answer one question | The pain is that things are slow or need tickets, not that they're hard to find |
| You can staff it: a portal is a product, with plugins to build, upgrade, and support | Nobody has time to keep it current |

Backstage is open source and highly extensible, which also makes it a software project to run: a TypeScript application, plugins, upgrades, and a database. Hosted Backstage offerings and commercial portals (Port, Cortex, OpsLevel, among others) trade that work for a subscription. Whatever you choose, the catalog format and the templates should outlive it.

## Next

[Building and running the platform](06-building-and-running-the-platform.md).
