# Self-service and abstractions

[← Platform engineering](README.md)

Self-service is the defining property of a platform: users do what they need, immediately, without asking anyone. This guide covers the interfaces a platform can offer, choosing how much to hide, replacing gates with guardrails, and moving off ticket-ops.

## Interfaces

The CNCF white paper lists the interfaces platforms offer: web portals, project templates, self-service APIs, and command-line tools. In practice:

| Interface | Example | Good for | Watch out for |
|---|---|---|---|
| **Templates** | `copier copy`, a repository template, a Backstage software template | Creating things: a service, a library, a pipeline | Drift after creation ([day 2](03-golden-paths.md#day-2-keeping-services-on-the-path)) |
| **Git (pull or merge requests)** | Add a values file, a Terraform module call, or a team entry to a platform repository; automation applies it on merge | Changes that benefit from review and history: access, environments, shared infrastructure | Slow if a person has to approve every routine request; automate the checks so approval is quick |
| **Code the team owns** | A CI/CD component, a Terraform module, a Helm chart referenced from the team's repository | Building blocks teams compose | Versioning and breaking changes ([platform APIs](06-building-and-running-the-platform.md#the-platforms-interfaces-are-apis)) |
| **Kubernetes APIs** | A custom resource (`kind: Database`) that an operator or Crossplane turns into real resources | Platforms already centered on Kubernetes; declarative, GitOps-friendly | Operators are software to build and run; start with existing ones |
| **CLI** | `platform new service`, `platform db create` | Developers who live in the terminal; scripting | Another tool to install and version |
| **Portal** | Backstage: forms over the same templates and APIs | Discovery, the catalog, people who don't use the CLI | Building the portal before the capabilities behind it ([Portals](05-developer-portals-and-catalogs.md)) |
| **API** | REST or GraphQL over the platform's capabilities | Other tools and automation | Only worth it when something needs to call it |

Most platforms combine a few: templates for creation, Git for configuration, components and modules for building blocks, a portal for discovery. **The interface should match how users already work.** A team that does everything through merge requests will use a merge request; ask them to open a portal and they'll ask a colleague instead.

Whatever the interface, two things matter most: **it works without the platform team** (no hidden manual step), and **it gives clear feedback** when something fails. DORA found clear feedback on task outcomes to be the platform capability most associated with a good user experience.

## Choosing the level of abstraction

Every capability can be offered at different heights:

| Level | The user writes | Example | Good when |
|---|---|---|---|
| **Raw** | Full manifests, cloud resources | A Kubernetes namespace and kubectl access | The team has the expertise and needs full control |
| **Building blocks** | Values for a reusable module | The [web-app chart](../devops/helm/examples/charts/web-app/), a Terraform module | Most teams: control over settings, platform owns the structure |
| **Intent** | What they want, not how | `kind: WebService` with a name, image, and "needs a database" | Many teams, a narrow set of workload shapes, and a platform team that can run the machinery |
| **Fully managed** | Nothing beyond their code | A PaaS or serverless runtime | The workload fits the product's model |

Higher abstractions remove more cognitive load and more control. The right level depends on the users and the workload, and a platform often offers more than one: building blocks for most teams, raw access (with guardrails) for teams that need it.

Abstractions leak. When something breaks, the user needs to see what's underneath: the rendered manifests (`helm get manifest`), the pod's events, the cloud resource's state. **Design every abstraction to be inspectable,** and teach users the one level below the one they use. An abstraction that can't be inspected turns every failure into a ticket.

## Guardrails, not gates

A gate is a person approving a change; a guardrail is an automated control that keeps the change safe and lets it through ([definitions](02-concepts-and-terms.md#guardrails-and-gates)). Moving controls from gates to guardrails is often the biggest speedup a platform delivers, and it's usually welcomed by the people who ran the gates, who were doing repetitive reviews.

| Gate today | Guardrail instead | In this repository |
|---|---|---|
| Security reviews every new service's manifests | Admission policy rejects pods that aren't non-root, read-only, and capability-free | Pod Security "restricted" in the [namespace baseline](../devops/kubernetes/README.md) |
| Network team approves firewall rules | Default-deny NetworkPolicy; the chart opens only what the service declares | The [web-app chart's](../devops/helm/examples/charts/web-app/) policy |
| Change board approves production deploys | Protected branches, reviewed merge requests, automated tests, a manual deploy step, automatic rollback | The [golden path's pipeline](examples/golden-path-python-service/) |
| Someone checks images for vulnerabilities | The pipeline scans before pushing and fails on fixable criticals | The [container-image component](../devops/gitlab/examples/components/README.md) |
| Cloud team reviews every IaC change | Policy as code in the pipeline; least-privilege pipeline roles | checkov, [gitlab-oidc](../devops/terraform/aws/gitlab-oidc/) roles |
| Finance reviews new resources | Budgets, quotas, and tagging enforced by policy | Namespace ResourceQuota, [budgets](../devops/aws/cloudformation/README.md) |

Keep a gate where judgment is the point (a new kind of data processing, a novel architecture) and make it fast: a clear request format, a named owner, and a response time.

## Ending ticket-ops

Moving a capability from tickets to self-service, one at a time:

1. **Group the tickets** the platform team receives. Pick the largest group that's routine (the answer is usually the same).
2. **Write down what a person does** for each one: the checks, the commands, the decisions.
3. **Turn the checks into guardrails,** and the commands into automation behind an interface users already use (a merge request is often the easiest first step).
4. **Keep the ticket path open briefly,** answering each new ticket with a link to the self-service way.
5. **Measure:** tickets of that kind per week, and time from need to done. The goal is both near zero.

The work is rarely the automation; it's agreeing with the owners of each check (security, networking, finance) that a guardrail is an acceptable replacement for their review. Bring them the evidence: what the review actually catches, and how the guardrail catches it.

## Next

[Developer portals and catalogs](05-developer-portals-and-catalogs.md).
