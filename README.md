# DevOps and Platforming Groundwork

**Practical, tested material for the people who build, run, and lead cloud platforms.**

An onboarding checklist for tech leads taking over an existing program, and hands-on guides for the architects, engineers, and managers around them: infrastructure as code, Kubernetes, AWS and Azure, observability, Linux, containers, API testing, and running the team. Commands and code here aren't just written down: CI runs them, against real CLIs, real Linux distributions, and real containers.

License: [CC BY 4.0](LICENSE) · Maintainer: Dominick Bolanos

---

## Start here, by role

| You are | Start with | Then |
|---|---|---|
| **A tech lead** stepping into an existing program | The [onboarding checklist](tech-lead/README.md): what to learn, who to talk to, how to evaluate what you inherit, and what to deliver in 90 days | Its phase view and templates, and the DevOps material each section points to |
| **A DevOps or platform engineer** | [devops/](devops/README.md): Bash and Docker 101, then Terraform, Kubernetes, your cloud, and observability | The [complex commands](devops/bash/07-complex-commands.md) and the [observability lab](devops/observability/local-stack/README.md) |
| **A software engineer** | [software/](software/README.md): API contracts and testing at every layer | Building images in [Docker 101](devops/docker/README.md), and instrumenting services in [observability](devops/observability/README.md) |
| **An architect** designing cloud and platform foundations | [architect/](architect/README.md): the ten questions for any design, then quality attributes and trade-offs, foundations, reliability, security, delivery, observability, cost, and portability | The [architecture review checklist](architect/templates/architecture-review-checklist.md) and the tested implementations in [devops/](devops/README.md) |
| **A manager** of a DevOps, platform, or SRE team | [Your first 90 days](manager/00-first-90-days.md), then the rest of [manager/](manager/README.md): one-on-ones, hiring, planning and metrics, on-call health, stakeholders, and templates | The [tech lead checklist](tech-lead/README.md) sections on stakeholders and evaluating problems |
| **New to all of it** | The [glossary](GLOSSARY.md) | [Bash basics](devops/bash/01-basics.md) and [Docker basics](devops/docker/01-basics.md) |

## Everything in the repository

### [tech-lead/](tech-lead/)

| Path | What it is |
|---|---|
| [README.md](tech-lead/README.md) | The onboarding checklist: access, stakeholders, evaluating problems, cloud, IaC, CI, CD, DevSecOps, observability, 30/60/90-day deliverables, best practices, and references |
| [Assessing an inherited system](tech-lead/assessing-an-inherited-system.md) | How to do the assessment: map the system, follow a change and an incident, read the history, interview, score risks, present findings |
| [Worked example](tech-lead/worked-example.md) | A fictional program through all 90 days, with every deliverable filled in |
| [Design reviews and RFCs](tech-lead/design-reviews-and-rfcs.md) | When to write a design doc, how to write one, and how to run a useful review |
| [Migrations and cutovers](tech-lead/migrations-and-cutovers.md) | Planning migrations, safe patterns (strangler fig, expand and contract, parallel run), data, and cutover day |
| [Working with product and leadership](tech-lead/working-with-product-and-leadership.md) | Business framing, scope negotiation, presenting a roadmap, disagreement |
| [checklists/](tech-lead/checklists/) | The same items by phase (W1, 30, 60, 90), and as a CSV for trackers |
| [templates/](tech-lead/templates/README.md) | Stakeholder map, first-conversation questions, system inventory, metrics baseline, risk and findings registers, RACI, findings report, roadmap, ADR, RFC, cutover runbook, weekly status |

### [devops/](devops/README.md)

| Path | What it is |
|---|---|
| [bash/](devops/bash/README.md) | Bash 101 for RHEL and Ubuntu, regex, complex commands broken down, administration, and a tested server setup script library |
| [docker/](devops/docker/README.md) | Docker 101, Dockerfiles, Compose, security, Podman on RHEL, troubleshooting, example images |
| [terraform/](devops/terraform/README.md) | Reference AWS and Azure stacks with tests, setup, operations, and troubleshooting |
| [kubernetes/](devops/kubernetes/README.md) | Hardened sample apps and a namespace baseline, with administration and troubleshooting commands |
| [aws/](devops/aws/README.md), [azure/](devops/azure/README.md) | CLI operations guides, CloudFormation and Bicep templates |
| [observability/](devops/observability/README.md) | Prometheus guide, Grafana 101, SLO alerting, a Compose lab, CloudWatch and Azure Monitor |

### [software/](software/README.md)

| Path | What it is |
|---|---|
| [api-testing/](software/api-testing/README.md) | OpenAPI contract, reference server, and Postman, Schemathesis, k6, and Locust tests |

### [architect/](architect/README.md)

| Path | What it is |
|---|---|
| [Thinking like an architect](architect/01-thinking-like-an-architect.md) | Quality attributes, trade-offs, reversible and irreversible decisions, constraints, fitness functions, Well-Architected |
| [Cloud foundations](architect/02-cloud-foundations.md) | Landing zones: account structure, identity, network, guardrails, logging, environments |
| [Reliability and disaster recovery](architect/03-reliability-and-disaster-recovery.md) | Targets, failure domains, DR strategies, blast radius, data |
| [Security architecture](architect/04-security-architecture.md) | Zero trust, identity, segmentation, data protection, supply chain, detection, threat modeling |
| [Delivery and IaC architecture](architect/05-delivery-architecture.md) | Pipeline principles, promotion, GitOps, IaC state boundaries, policy as code, golden paths |
| [Observability and operations](architect/06-observability-and-operations.md) | Operability requirements, the telemetry pipeline, signal ownership, SLO design, incident tooling |
| [Cost architecture](architect/07-cost-architecture.md) | Unit cost, the big cost levers, commitments, spot capacity, sustainability |
| [Portability and multi-cloud](architect/08-portability-and-multi-cloud.md) | Lock-in as a trade-off, levels of portability, hybrid, multi-cloud done well, exit plans |
| [templates/](architect/templates/) | Architecture review checklist, decision matrix, quality attribute requirements |

### [manager/](manager/README.md)

| Path | What it is |
|---|---|
| [Your first 90 days](manager/00-first-90-days.md) | A W1/30/60/90 checklist for taking over a DevOps, platform, or SRE team |
| [Running the team](manager/01-running-the-team.md) | One-on-ones, expectations, feedback, growth, rituals, written culture |
| [Hiring and onboarding](manager/02-hiring-and-onboarding.md) | Roles, structured interviews, work samples, a new engineer's first 90 days |
| [Planning and metrics](manager/03-planning-and-metrics.md) | Run, improve, and build work; roadmaps; technical debt; the DORA metrics |
| [On-call and team health](manager/04-on-call-and-team-health.md) | Sustainable rotations, alert hygiene, incident reviews, burnout |
| [Stakeholders and communication](manager/05-stakeholders-and-communication.md) | Status updates, decisions, escalation, making the platform's value visible |
| [Performance and promotions](manager/06-performance-and-promotions.md) | Goals, fair reviews, supporting someone who's struggling, promotion cases |
| [Structuring platform teams](manager/07-structuring-platform-teams.md) | Team size, ownership, platform as a product, Team Topologies |
| [Budget, vendors, and contracts](manager/08-budget-vendors-and-contracts.md) | Cloud cost, choosing and managing vendors, contractors |
| [templates/](manager/templates/README.md) | One-on-ones, career ladder, interview scorecard and question bank, onboarding plan, quarterly planning, on-call policy, incident review, team charter |

### Across the repository

| Path | What it is |
|---|---|
| [GLOSSARY.md](GLOSSARY.md) | About 350 terms across software engineering, architecture, APIs, DevOps, Linux, cloud, security, observability, data, cost, and delivery, plus an AWS and Azure service equivalents table |
| [ROADMAP.md](ROADMAP.md) | What's covered, and what's planned next |
| [CHANGELOG.md](CHANGELOG.md) | Notable changes |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to suggest corrections and additions |
| [scripts/](scripts/) | The repository's own checks: checklist generation, CLI command validation, the observability lab check |
| [.github/workflows/](.github/workflows/) | CI for everything above |

## How it's checked

| Area | CI runs |
|---|---|
| Documentation | Markdown lint, spelling, link checking, and every `aws` and `az` command checked against the real CLIs |
| Terraform | fmt, validate, `terraform test` with mocked providers, tflint, checkov |
| Kubernetes | Kustomize render, kubeconform, checkov |
| CloudFormation and Bicep | cfn-lint, Bicep build and lint, checkov |
| API testing | Spectral, Newman, Schemathesis, k6, and Locust against the reference server |
| Observability | promtool rule tests, config validation, and the full lab started and checked end to end |
| Bash | ShellCheck, shfmt, Bats, and the server baseline applied in Ubuntu, Rocky Linux, and AlmaLinux containers |
| Docker | Hadolint, builds, Trivy scans, the Compose example with a smoke test, a container audit |

## Ground rules for this repository

Everything here is generic. It contains no customer, employer, or program-specific information, and examples use documentation addresses and placeholder names. Bring your organization's own policies and contracts to bear on anything you adapt, and never copy filled-in templates back into a public repository. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to help.
