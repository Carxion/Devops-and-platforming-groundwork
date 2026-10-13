# DevOps and Platforming Groundwork

**Practical, tested material for the people who build, run, and lead cloud platforms.**

An onboarding checklist for tech leads taking over an existing program, and hands-on guides for the engineers and managers around them: infrastructure as code, Kubernetes, AWS and Azure, observability, Linux, containers, API testing, and running the team. Commands and code here aren't just written down: CI runs them, against real CLIs, real Linux distributions, and real containers.

License: [CC BY 4.0](LICENSE) · Maintainer: Dominick Bolanos

---

## Start here, by role

| You are | Start with | Then |
|---|---|---|
| **A tech lead** stepping into an existing program | The [onboarding checklist](tech-lead/README.md): what to learn, who to talk to, how to evaluate what you inherit, and what to deliver in 90 days | Its phase view and templates, and the DevOps material each section points to |
| **A DevOps or platform engineer** | [devops/](devops/README.md): Bash and Docker 101, then Terraform, Kubernetes, your cloud, and observability | The [complex commands](devops/bash/07-complex-commands.md) and the [observability lab](devops/observability/local-stack/README.md) |
| **A software engineer** | [software/](software/README.md): API contracts and testing at every layer | Building images in [Docker 101](devops/docker/README.md), and instrumenting services in [observability](devops/observability/README.md) |
| **A manager** of a DevOps, platform, or SRE team | [manager/](manager/README.md): one-on-ones, hiring, planning and metrics, on-call health, stakeholders | The [tech lead checklist](tech-lead/README.md) sections on stakeholders and evaluating problems |
| **New to all of it** | The [glossary](GLOSSARY.md) | [Bash basics](devops/bash/01-basics.md) and [Docker basics](devops/docker/01-basics.md) |

## Everything in the repository

### [tech-lead/](tech-lead/)

| Path | What it is |
|---|---|
| [README.md](tech-lead/README.md) | The onboarding checklist: access, stakeholders, evaluating problems, cloud, IaC, CI, CD, DevSecOps, observability, 30/60/90-day deliverables, best practices, and references |
| [checklists/](tech-lead/checklists/) | The same items by phase (W1, 30, 60, 90), and as a CSV for trackers |
| [templates/](tech-lead/templates/) | Stakeholder map, first-conversation questions, findings register, ADR, weekly status |

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

### [manager/](manager/README.md)

| Path | What it is |
|---|---|
| [Running the team](manager/01-running-the-team.md) | One-on-ones, expectations, feedback, growth, rituals, written culture |
| [Hiring and onboarding](manager/02-hiring-and-onboarding.md) | Roles, structured interviews, work samples, a new engineer's first 90 days |
| [Planning and metrics](manager/03-planning-and-metrics.md) | Run, improve, and build work; roadmaps; technical debt; the DORA metrics |
| [On-call and team health](manager/04-on-call-and-team-health.md) | Sustainable rotations, alert hygiene, incident reviews, burnout |
| [Stakeholders and communication](manager/05-stakeholders-and-communication.md) | Status updates, decisions, escalation, making the platform's value visible |

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
