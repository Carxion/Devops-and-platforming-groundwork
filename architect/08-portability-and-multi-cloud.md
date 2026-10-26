# Portability, hybrid, and multi-cloud

[← Architect](README.md)

"Avoid lock-in" and "go multi-cloud" are among the most expensive things an architect can recommend without a clear reason. Portability always costs something: features, speed, operational effort, or money. This guide covers when it's worth paying for, how much portability you actually need, and how to design hybrid and multi-cloud estates that work.

## Lock-in is a trade-off, not a defect

Every choice creates some lock-in: a cloud provider, a database, a CI system, even a programming language. The question isn't how to avoid it, but **what switching would cost, and whether that cost is worth reducing now.**

Using a provider's managed services (serverless functions, managed databases, managed Kubernetes, identity) usually gets more done with fewer people, at the price of higher switching cost. Avoiding them (running everything on generic VMs or containers to stay portable) often means operating more yourself, more slowly, for a migration that may never happen.

A useful way to decide: **estimate the likelihood you'll need to move, and the cost of moving later, against the cost of portability now.** For most workloads, the honest answer is to use the managed services and keep a plan for leaving.

## Reasons for multi-cloud, good and weak

| Reason | Assessment |
|---|---|
| A capability only one provider offers well (a specific AI service, a data platform) | Good: use each provider for what it's best at, with clear boundaries |
| Customer or contract requirements (a customer requires a specific cloud) | Good, if real and documented |
| Regulatory or sovereignty requirements | Good, if the requirement actually demands it |
| An acquisition brought a second cloud | Common reality: manage both well rather than migrating for its own sake |
| Negotiating leverage on price | Weak: credible only if you could really move, which is expensive to maintain |
| Resilience against a whole provider failing | Usually weak: multi-region within one provider covers most failure scenarios at far lower cost and complexity; true cross-provider failover is very expensive to build and test |
| "Avoiding lock-in" in general | Weak on its own: name the specific risk |

## Levels of portability

Choose the level deliberately, per workload:

| Level | Means | Cost |
|---|---|---|
| **None** | Fully native services; re-architect to move | Lowest now; highest switching cost |
| **Portable skills and patterns** | Common tools and practices (Terraform, Kubernetes, OpenTelemetry, containers) even while using native services | Low; reduces the people cost of any future move |
| **Portable application layer** | Applications in containers with standard interfaces; data and platform services native | Moderate; application code moves, infrastructure is rebuilt |
| **Portable everything** | Only services available everywhere (Kubernetes, self-run databases, open-source everything) | High: you run much more yourself |
| **Active multi-cloud** | Running the same workload on several providers at once | Very high: everything above, plus cross-cloud networking, data replication, and operating both |

Most organizations get the best value from the second or third level: **portable skills, standard interfaces, and an exit plan**, while using managed services where they help.

## Standards that keep options open cheaply

- **Containers and Kubernetes** for application packaging and runtime ([Docker](../software/containers/docker/README.md), [Kubernetes](../devops/kubernetes/README.md))
- **Terraform or OpenTofu** across providers, with provider-specific modules behind consistent interfaces ([reference stacks for AWS and Azure](../devops/terraform/README.md))
- **OpenTelemetry** for telemetry, so the observability backend can change ([observability](../devops/observability/README.md))
- **OIDC and SAML** for identity federation, rather than provider-specific identity in applications
- **Standard protocols and formats** at boundaries: HTTP APIs with OpenAPI ([API contracts](../software/api-testing/README.md#the-contract)), PostgreSQL-compatible databases, S3-compatible object storage APIs where they fit
- **Your data in documented, exportable formats,** with tested exports

## Hybrid: cloud and on-premises

Hybrid estates are common and often permanent. Design for:

- **Connectivity:** redundant private links (Direct Connect, ExpressRoute) or VPNs, with a non-overlapping address plan ([Cloud foundations](02-cloud-foundations.md#network))
- **Identity:** one identity provider across both, with federation to each cloud
- **DNS:** consistent resolution between environments
- **Latency and dependencies:** chatty calls across the link are slow and fragile; keep tightly coupled components together
- **Consistent operations:** the same deployment, monitoring, and security tooling across both where possible, so on-premises doesn't become the unmaintained half
- **Management planes** that extend cloud tools on-premises (Azure Arc, AWS Systems Manager and Outposts), where they reduce the number of toolsets

## Multi-cloud done well

If you do run on several clouds:

- **Divide by workload, not by component:** each system runs entirely on one provider. Splitting one system across providers multiplies latency, data transfer cost, and failure modes.
- **One way of doing each thing:** the same IaC tool, CI/CD, observability, and security tooling across providers, with provider-specific modules underneath.
- **Central identity and governance:** one identity provider, consistent guardrails expressed in each provider's policy system ([SCPs and Azure Policy](02-cloud-foundations.md#guardrails)), consistent tagging.
- **Skills:** each provider needs real expertise on the team; shallow knowledge of two clouds is riskier than deep knowledge of one.
- **Cross-reference services** carefully: equivalent services differ in important details ([AWS and Azure equivalents](../GLOSSARY.md#aws-and-azure-equivalents)).

## Exit plans

For each critical dependency on a provider or vendor, keep a short, written exit plan:

- What would trigger leaving (price, failure, acquisition, regulation)?
- What would move, to what, and roughly how long it would take?
- Where is the data, and how is it exported? When was an export last tested?
- Which contracts have notice periods or exit terms?

An exit plan you've thought through is most of the value of portability, at a fraction of the cost.

## Review questions

- What specific risk is portability in this design protecting against? How likely is it?
- What does portability cost here, in features, effort, and money?
- If we had to leave this provider or service, how long would it take, and where is the data?
- Does any single system span providers? Why?
- Is the team deep enough in each provider it uses?
