# DevOps and Platforming Groundwork

**Practical, tested material for the people who build, run, and lead cloud platforms.**

An onboarding checklist for tech leads taking over an existing program, and hands-on guides for the architects, engineers, managers, scrum masters, and product owners around them: Git, infrastructure as code, configuration management, Kubernetes, AWS and Azure, observability, Linux, containers, API testing, and running the team. Commands and code here aren't just written down: they've been run, against real CLIs, real Linux distributions, and real containers, and CI lints them on every change.

License: [CC BY 4.0](LICENSE) · Maintainer: Dominick Bolanos

---

## Start here, by role

| You are | Start with | Then |
|---|---|---|
| **A tech lead** stepping into an existing program | The [onboarding checklist](tech-lead/README.md): what to learn, who to talk to, how to evaluate what you inherit, and what to deliver in 90 days | Its phase view and templates, and the DevOps material each section points to |
| **A DevOps or platform engineer** | [devops/](devops/README.md): Bash 101 and [containers](software/containers/README.md), then GitLab CI/CD, Ansible, Terraform, Kubernetes, your cloud, and observability | The [complex commands](devops/bash/07-complex-commands.md) and the [observability lab](devops/observability/local-stack/README.md) |
| **A software engineer** | [software/](software/README.md): Git 101, Python and Go 101 with boilerplate and operational tools, unit testing and linting, API contracts, and testing at every layer | Building and hardening images in [containers](software/containers/README.md), and instrumenting services in [observability](devops/observability/README.md) |
| **An architect** designing cloud and platform foundations | [architect/](architect/README.md): the ten questions for any design, then quality attributes and trade-offs, foundations, reliability, security, delivery, observability, cost, and portability | The [architecture review checklist](architect/templates/architecture-review-checklist.md) and the tested implementations in [devops/](devops/README.md) |
| **A solutions architect** turning a business problem into an agreed solution | [solutions-architect/](solutions-architect/README.md): the role, discovery and requirements, designing the solution, working with stakeholders, preparing a proposal, and presenting | Its [templates](solutions-architect/templates/README.md), and the [architect](architect/README.md) guides for what makes a design sound |
| **A manager** of a DevOps, platform, or SRE team | [Your first 90 days](manager/00-first-90-days.md), then the rest of [manager/](manager/README.md): one-on-ones, hiring, planning and metrics, on-call health, stakeholders, and templates | The [tech lead checklist](tech-lead/README.md) sections on stakeholders and evaluating problems |
| **A scrum master** or agile coach for a platform team | [Your first 90 days](scrum-master/00-first-90-days.md), then the rest of [scrum-master/](scrum-master/README.md): Scrum for interrupt-driven teams, running the events, flow metrics, impediments, and templates | The [product owner](product-owner/README.md) and [manager](manager/README.md) guides, to agree who does what |
| **A product owner** of a platform or internal tool | [Your first 90 days](product-owner/00-first-90-days.md), then the rest of [product-owner/](product-owner/README.md): the platform as a product, backlog, prioritization, roadmaps, and measuring outcomes | [Structuring platform teams](manager/07-structuring-platform-teams.md) and the [DORA metrics](manager/03-planning-and-metrics.md#measuring-delivery-the-dora-metrics) |
| **New to all of it** | The [glossary](GLOSSARY.md) | [Git basics](software/git/01-basics.md), [Bash basics](devops/bash/01-basics.md), and [how containers work](software/containers/01-how-containers-work.md) |

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
| [gitlab/](devops/gitlab/README.md) | GitLab 101 and GitLab CI/CD: pipelines, rules, components, runners, OIDC to AWS and Azure, deployments, pipeline security, and reference pipelines run end to end in a local GitLab |
| [ansible/](devops/ansible/README.md) | Ansible from ad hoc commands to tested roles: the server baseline for RHEL and Ubuntu, Vault and secrets managers, Molecule, CI in GitHub, GitLab, and Jenkins |
| [terraform/](devops/terraform/README.md) | Reference AWS and Azure stacks with tests, setup, operations, and troubleshooting |
| [kubernetes/](devops/kubernetes/README.md) | Hardened sample apps and a namespace baseline, with administration and troubleshooting commands |
| [aws/](devops/aws/README.md), [azure/](devops/azure/README.md) | CLI operations guides, CloudFormation and Bicep templates |
| [observability/](devops/observability/README.md) | Prometheus guide, Grafana 101, SLO alerting, a Compose lab, CloudWatch and Azure Monitor |

### [software/](software/README.md)

| Path | What it is |
|---|---|
| [containers/](software/containers/README.md) | How containers work (namespaces, cgroups, layers, OCI, the runtime stack), then Docker and Podman: architecture, command references, hardening guides, Compose, pods, Quadlet, Buildah and Skopeo |
| [git/](software/git/README.md) | Git 101: setup and signing, branching, complex commands broken down, recovery, code review and repository settings, all tested |
| [python/](software/python/README.md) | Python 101 and boilerplate: a standard-library CLI and a FastAPI service, with uv, ruff, mypy, pytest, and a container image, plus five operational tools |
| [go/](software/go/README.md) | Go 101 and boilerplate: the same CLI and service with the standard library, golangci-lint, the race detector, govulncheck, and a distroless image, plus the same five tools |
| [testing/](software/testing/README.md) | Unit testing: principles and test doubles, then pytest and Go's `testing` package with runnable examples (fixtures, fakes, table-driven tests, httptest, benchmarks, fuzzing) |
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

### [solutions-architect/](solutions-architect/README.md)

| Path | What it is |
|---|---|
| [Your first 90 days](solutions-architect/00-first-90-days.md) | A W1/30/60/90 checklist for joining a vendor, consultancy, or internal team as a solutions architect |
| [The role](solutions-architect/01-the-role.md) | What a solutions architect owns, how it differs from other architect roles, and the arc of an engagement |
| [Discovery and requirements](solutions-architect/02-discovery-and-requirements.md) | Problem before solution, what to find out, running sessions, turning notes into requirements, traps |
| [Designing the solution](solutions-architect/03-designing-the-solution.md) | Real options, choosing between them, reference architectures, diagrams, proofs of concept, estimating, RAID |
| [Working with stakeholders](solutions-architect/04-working-with-stakeholders.md) | Who's in the room, building trust, scope and expectations, disagreement, handing over to delivery |
| [Preparing a proposal](solutions-architect/05-preparing-a-proposal.md) | Structure, the executive summary, scope and assumptions, pricing, RFP responses, review |
| [Presenting the solution](solutions-architect/06-presenting.md) | Outcome first, the story, slides, diagrams, demos, whiteboarding, questions and objections, remote |
| [templates/](solutions-architect/templates/README.md) | Discovery guide, solution design, proof-of-concept plan, proposal, presentation plan, delivery handover |

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

### [scrum-master/](scrum-master/README.md)

| Path | What it is |
|---|---|
| [Your first 90 days](scrum-master/00-first-90-days.md) | A W1/30/60/90 checklist for joining a DevOps, platform, or SRE team as its scrum master |
| [Scrum for platform teams](scrum-master/01-scrum-for-platform-teams.md) | The framework in brief, handling interrupts, and when Kanban or a hybrid fits better |
| [Running the events](scrum-master/02-running-the-events.md) | Planning, the daily scrum, refinement, review, and retrospective, with what goes wrong |
| [Flow and metrics](scrum-master/03-flow-and-metrics.md) | WIP, throughput, cycle time, work item age, why velocity misleads, Monte Carlo forecasting |
| [Impediments and team health](scrum-master/04-impediments-and-team-health.md) | Finding and escalating impediments, working agreements, psychological safety, health checks |
| [Working across teams](scrum-master/05-working-across-teams.md) | Dependencies, scaling, coaching stances, and working with the other roles |
| [templates/](scrum-master/templates/README.md) | Sprint planning, retrospective formats, working agreement, definition of done, impediment log, team health check |

### [product-owner/](product-owner/README.md)

| Path | What it is |
|---|---|
| [Your first 90 days](product-owner/00-first-90-days.md) | A W1/30/60/90 checklist for taking on a platform or internal tool as its product owner |
| [The platform as a product](product-owner/01-the-platform-as-a-product.md) | The accountabilities, the platform's users, discovery, the product goal, the thinnest viable platform |
| [Backlog management](product-owner/02-backlog-management.md) | A healthy backlog, user stories, acceptance criteria, splitting work, technical and operations work |
| [Prioritization](product-owner/03-prioritization.md) | Cost of delay and WSJF, RICE, MoSCoW, Kano, run/improve/build, and saying no |
| [Roadmaps and stakeholders](product-owner/04-roadmaps-and-stakeholders.md) | Now/next/later, outcomes over outputs, OKRs, stakeholders, deprecations and migrations |
| [Measuring outcomes](product-owner/05-measuring-outcomes.md) | Adoption, developer experience (SPACE, DevEx), DORA, surveys, SLOs, experiments |
| [templates/](product-owner/templates/README.md) | Product goal canvas, user story, prioritization worksheet, roadmap, user interview guide, release notes |

### Across the repository

| Path | What it is |
|---|---|
| [GLOSSARY.md](GLOSSARY.md) | About 420 terms across software engineering, architecture, APIs, DevOps, Linux, cloud, security, observability, data, cost, and delivery, plus an AWS and Azure service equivalents table |
| [ROADMAP.md](ROADMAP.md) | What's covered, and what's planned next |
| [CHANGELOG.md](CHANGELOG.md) | Notable changes |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to suggest corrections and additions |
| [scripts/](scripts/) | The repository's own checks: checklist generation, CLI command validation, the observability lab check |
| [.github/workflows/](.github/workflows/) | CI: one lint workflow for everything above |

## How it's checked

**On every push and pull request**, [lint.yml](.github/workflows/lint.yml) runs fast static checks only:

| Job | Checks |
|---|---|
| Docs | Markdown lint, spelling, links, and that the generated checklists match the README |
| Shell | ShellCheck and shfmt on the Bash, Docker, and Git scripts |
| Ansible | yamllint, syntax checks, ansible-lint (production profile) |
| Python | ruff lint and format check on every project |
| Go | gofmt and golangci-lint on every module |
| Terraform | `terraform fmt -check` and tflint |
| Dockerfiles | Hadolint on every Dockerfile |

**Locally**, before changing an area, run its tests. Each was run and passed when the area was written, and [CONTRIBUTING.md](CONTRIBUTING.md#running-the-tests-locally) lists the commands:

| Area | Tests |
|---|---|
| Terraform | `terraform validate`, `terraform test` with mocked providers, checkov |
| GitLab CI/CD | Every example pipeline run end to end in a local GitLab CE with real runners and a fake AWS, and every complete pipeline in the guides through GitLab's CI Lint API |
| Kubernetes | Kustomize render, kubeconform, checkov |
| AWS and Azure | Every `aws` and `az` command checked against the real CLIs; cfn-lint, Bicep build and lint, checkov |
| API testing | Spectral, Newman, Schemathesis, k6, and Locust against the reference server |
| Python and Go | mypy, pytest, `go vet`, race-detector tests, govulncheck, and the API contract tests and Trivy against the built images |
| Observability | promtool rule tests, config validation, and the full lab started and checked end to end |
| Bash | Bats, and the server baseline applied in Ubuntu, Rocky Linux, and AlmaLinux containers |
| Docker | Image builds, Trivy scans, the Compose example with a smoke test, a container audit |
| Ansible | Molecule: the baseline applied to Ubuntu and RHEL-family containers, applied again with no changes, and verified |
| Git | Every recipe in the guides run against real repositories on Git 2.34 and later |

## Ground rules for this repository

Everything here is generic. It contains no customer, employer, or program-specific information, and examples use documentation addresses and placeholder names. Bring your organization's own policies and contracts to bear on anything you adapt, and never copy filled-in templates back into a public repository. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to help.
