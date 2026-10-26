# Roadmap

What this repository covers today, and the areas planned next. Material is organized by audience: [tech-lead/](tech-lead/README.md), [architect/](architect/README.md), [solutions-architect/](solutions-architect/README.md), [devops/](devops/README.md), [software/](software/README.md), [manager/](manager/README.md), [scrum-master/](scrum-master/README.md), and [product-owner/](product-owner/README.md). New areas go in the folder whose readers need them most. The [guide](tech-lead/README.md) is the backbone: each new area should help a tech lead do something its checklist asks for, with material that's tested, not just written.

Proposals and priorities are discussed in issues; open one with the [new item template](.github/ISSUE_TEMPLATE/new-item.yml) to suggest an area or argue for reordering. See [what "done" means](#definition-of-done-for-a-new-area) before starting one.

## Covered today

| Area | Where | Checked by (CI lints every area; the tests run locally) |
|---|---|---|
| Tech lead onboarding checklist, phase view, tracker CSV | [tech-lead/](tech-lead/README.md), [tech-lead/checklists/](tech-lead/checklists/) | Lint, spelling, links, generated-file freshness |
| Copy-ready templates | [tech-lead/templates/](tech-lead/templates/) | Lint |
| Glossary | [GLOSSARY.md](GLOSSARY.md) | Lint, spelling |
| Terraform reference stacks (AWS, Azure) | [devops/terraform/](devops/terraform/) | fmt, validate, `terraform test`, tflint, checkov |
| Kubernetes sample apps and operations | [devops/kubernetes/](devops/kubernetes/) | Kustomize render, kubeconform, checkov |
| AWS and Azure CLI guides, CloudFormation and Bicep | [devops/aws/](devops/aws/), [devops/azure/](devops/azure/) | Every `aws`/`az` command checked against the real CLIs; cfn-lint, Bicep, checkov |
| Python and Go 101, with CLI and API boilerplate and five operational tools in each language (certificate expiry, log statistics, a Prometheus exporter, an alert relay, a tag audit) | [software/python/](software/python/README.md), [software/go/](software/go/README.md) | Lint, types, tests, govulncheck, contract tests and Trivy on both API images; tool tests run offline against local servers and fake clouds |
| Unit testing, and testing and linting for Python and Go | [software/testing/](software/testing/README.md), [Python](software/python/04-testing-and-linting.md), [Go](software/go/04-testing-and-linting.md) | ruff, gofmt, golangci-lint in CI; pytest and `go test` with coverage, benchmarks, and fuzzing locally |
| API testing | [software/api-testing/](software/api-testing/) | Spectral, Newman, Schemathesis, k6, Locust against a reference server |
| Observability: Prometheus, Grafana, OpenTelemetry, CloudWatch, Azure Monitor | [devops/observability/](devops/observability/) | promtool rule tests, config validation, the full lab started and checked end to end |
| Git 101 and code review: setup and signing, branching, complex commands broken down, recovery, review practices and repository settings | [software/git/](software/git/README.md) | Every recipe run against real repositories on Git 2.34 (Ubuntu 22.04), Ubuntu 24.04, and Rocky 9, including filter-repo; ShellCheck and shfmt |
| Ansible: the server baseline as roles for RHEL and Ubuntu, Vault and secrets managers, CI in GitHub, GitLab, and Jenkins, fleet operations | [devops/ansible/](devops/ansible/README.md) | yamllint, ansible-lint (production profile), Molecule converge, idempotence, and verify on Ubuntu 22.04 and 24.04, Rocky 9, and AlmaLinux 9 |
| Bash and Linux administration (RHEL and Ubuntu) | [devops/bash/](devops/bash/) | ShellCheck, shfmt, Bats, server baseline applied in Ubuntu 22.04 and 24.04, Rocky 9, and AlmaLinux 9 containers |
| Containers: how they work, Docker, and Podman | [software/containers/](software/containers/README.md) | Hadolint, builds, Trivy, Compose run with a smoke test, container audit |
| Scrum master: first 90 days, five guides on Scrum and flow for interrupt-driven platform teams, six templates | [scrum-master/](scrum-master/README.md) | Lint, spelling, links |
| Product owner: first 90 days, five guides on running a platform as a product, six templates | [product-owner/](product-owner/README.md) | Lint, spelling, links |
| Managing DevOps and platform teams: first 90 days, eight guides, eight templates | [manager/](manager/README.md) | Lint, spelling, links |
| Tech lead guides: assessment method, worked example, design reviews, migrations, working with leadership | [tech-lead/](tech-lead/README.md) | Lint, spelling, links |
| Architecture considerations: eight guides and three templates | [architect/](architect/README.md) | Lint, spelling, links |
| Solutions architect: first 90 days, six guides on discovery, design, stakeholders, proposals, and presenting, six templates | [solutions-architect/](solutions-architect/README.md) | Lint, spelling, links |

## Phase 1: next

The gaps a new tech lead hits first.

| Area | Why | What it would contain | Builds on |
|---|---|---|---|
| **CI/CD pipelines in GitLab CI and Jenkins** | Section [5](tech-lead/README.md#5-continuous-integration) and [6](tech-lead/README.md#6-continuous-delivery-and-deployment) of the guide are tool-neutral, and the repository's own CI is GitHub Actions only. Many programs run GitLab or Jenkins. | Reference pipelines for the sample apps in all three systems: build, test, scan, sign, deploy with environment gates. Short-lived cloud credentials from each CI system (GitLab and Jenkins OIDC to AWS and Azure). Shared libraries, runners and agents, caching, and pipeline security. | [api-testing](software/api-testing/), [docker](software/containers/docker/README.md), the `github-oidc` Terraform stacks |
| **Helm and GitOps** | The Kubernetes samples are plain Kustomize; most programs deploy with Helm or Argo CD | A Helm chart for the web app alongside the Kustomize version, Argo CD (or Flux) application definitions, environment promotion through Git, progressive delivery with canaries | [kubernetes](devops/kubernetes/), [observability](devops/observability/) for canary analysis |
| **Secrets management** | Leaked and long-lived credentials are the most common cloud breach path | Vault, AWS Secrets Manager, and Azure Key Vault side by side; External Secrets Operator for Kubernetes; SOPS for files in Git; rotation runbooks; secret scanning in CI | [terraform](devops/terraform/), [kubernetes](devops/kubernetes/), the regex [secret patterns](devops/bash/03-regex.md#aws-access-key-id-for-secret-scanning) |

### For managers

Done: a first-90-days checklist, eight guides (including performance and promotions, structuring platform teams, and budget and vendors), and eight templates. Next: remote and distributed teams, leading through organizational change, and a manager's guide to security and compliance responsibilities (access reviews, audits, incident obligations).

### For architects

Done: the [architect](architect/README.md) guides and templates. Next: reference architectures (diagrams with the decisions behind them) for the stacks in `devops/terraform`, a data architecture guide (data stores, replication, analytics platforms), and an event-driven and integration architecture guide.

### For tech leads

Done: [Assessing an inherited system](tech-lead/assessing-an-inherited-system.md), a [worked example](tech-lead/worked-example.md), guides on design reviews, migrations, and working with product and leadership, and templates for every 30/60/90 deliverable. Next: technical strategy and writing a technical vision, mentoring and growing engineers as a tech lead, and leading incident response.

## Phase 2: after that

| Area | Why | What it would contain |
|---|---|---|
| **Software supply chain** | Section [7](tech-lead/README.md#7-devsecops) asks for SBOMs, signing, and provenance | SBOM generation and storage, cosign keyless signing from each CI system, SLSA provenance, admission policies that verify signatures (Kyverno, policy-controller), dependency update policy |
| **Policy as code** | Guardrails that run in CI catch problems before review does | OPA and Conftest for Terraform plans and Kubernetes manifests, Kyverno policies for the sample namespace, mapping to Azure Policy and AWS SCPs already in the repository |
| **Incident management and on-call** | Section [8](tech-lead/README.md#8-observability-and-operations) asks for runbooks and postmortems | Severity matrix, incident roles and communication templates, runbook and postmortem templates, an on-call handbook, and game-day exercises using the [observability lab](devops/observability/local-stack/README.md) |
| **Backup and disaster recovery** | Untested restores are a top finding in inherited systems | RPO and RTO worksheets, backup and restore runbooks for the reference stacks' data stores, restore tests that run in CI, region failover exercises |
| **TLS, PKI, and certificates** | Expired certificates are a classic avoidable outage | How TLS works in practice, ACME and cert-manager, internal CAs, certificate inventory and expiry monitoring (building on the certcheck [examples](software/python/examples/README.md)), mutual TLS |
| **Kubernetes operators and controllers** | Platform teams extend Kubernetes for self-service; operators are where Go is most often required | The controller pattern and reconcile loops, a small operator built with Kubebuilder and the same idea in Python with Kopf, admission webhooks, testing with envtest and kind |
| **Databases** | Most incidents eventually involve one | PostgreSQL operations: backups and point-in-time recovery, migrations in pipelines, connection pooling, managed service differences on AWS and Azure, performance triage |

## Phase 3: later

| Area | Notes |
|---|---|
| **Google Cloud** | A third cloud with the same depth as AWS and Azure: CLI guide with commands checked by CI, Terraform stacks, and the cross-cloud tables extended |
| **Platform engineering** | Internal developer platforms and golden paths: templates, a service catalog (Backstage), self-service infrastructure, measuring developer experience |
| **FinOps in depth** | Tag enforcement, cost allocation and showback, anomaly alerts, commitment planning, unit cost dashboards built on the observability stack |
| **Resilience testing** | Chaos experiments with AWS Fault Injection Service, Azure Chaos Studio, and LitmusChaos against the sample apps, tied to the SLOs |
| **Service mesh** | When a mesh is worth its cost, mutual TLS, traffic shifting, and mesh telemetry, with Istio or Linkerd on the sample cluster |
| **Threat modeling and security testing** | A workshop kit (STRIDE on the reference architectures), preparing for penetration tests, and fixing what they find |
| **Windows Server and PowerShell** | For mixed estates: the Bash 101 equivalent for PowerShell, and Windows containers |
| **Running AI workloads** | GPU nodes, model serving, evaluation in pipelines, and the cost and data-handling questions they raise |

## Definition of done for a new area

An area joins "Covered today" when:

- [ ] It answers questions a tech lead has while working through the [checklist](tech-lead/README.md), and the relevant checklist sections link to it.
- [ ] Every command and configuration has been run, not just written: linted in CI, and validated and where possible executed by tests anyone can run locally ([how](CONTRIBUTING.md#running-the-tests-locally)). Commands for cloud CLIs pass [check_cli_commands.py](scripts/check_cli_commands.py).
- [ ] Factual claims come from primary sources (vendor documentation, standards bodies), checked for the current version.
- [ ] It follows the repository's rules in [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md): no program-specific information, secure defaults, plain language.
- [ ] New terms are in the [glossary](GLOSSARY.md), and the change is in the [CHANGELOG](CHANGELOG.md).
