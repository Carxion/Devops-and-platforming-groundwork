# Software

[← DevOps and Platforming Groundwork](../README.md)

Material for engineers building and testing the software that runs on the platform: programming languages with working boilerplate, API contracts, testing at every layer, and how tests fit into delivery pipelines.

| Folder | What it is | Start with |
|---|---|---|
| [containers/](containers/README.md) | How containers work, then Docker and Podman: architecture, command references, Dockerfiles, Compose, pods, Quadlet, and a hardening guide for each engine | [How containers work](containers/01-how-containers-work.md) |
| [git/](git/README.md) | Git 101: setup and SSH signing, branching and conflicts, complex commands broken down, recovering from almost anything, and code review with repository settings, every recipe tested on Git 2.34 and later | [Basics](git/01-basics.md) |
| [python/](python/README.md) | Python 101: language essentials, Python for operations (files, commands, HTTP, cloud SDKs, CLIs, concurrency), and projects and tooling (uv, ruff, mypy, pytest, containers), with a CLI and a FastAPI service as boilerplate and five [operational tools](python/examples/README.md) | [Setup](python/README.md#setup) |
| [go/](go/README.md) | Go 101: language essentials, Go for operations (CLIs, HTTP clients and servers, JSON, goroutines and context, slog), and projects and tooling (modules, testing, golangci-lint, govulncheck, cross-compiling, containers), with the same CLI and service as boilerplate and the same five [operational tools](go/examples/README.md) | [Setup](go/README.md#setup) |
| [testing/](testing/README.md) | How to write unit tests: principles, test doubles, and coverage, then pytest (Python) and the `testing` package (Go), each with a runnable example project on the same domain | [Unit testing](testing/README.md) |
| [api-testing/](api-testing/README.md) | An OpenAPI contract for the serverless item API the Terraform stacks deploy, with a reference server and Postman, Schemathesis, k6, and Locust tests that run locally or against AWS and Azure | [Quick start](api-testing/README.md#quick-start-local) |

The [glossary](../GLOSSARY.md#software-engineering) covers software engineering, architecture, and API terms. Building and shipping containers is in [containers/](containers/README.md), and observability for applications (instrumenting with OpenTelemetry, SLOs) is in [devops/observability](../devops/observability/README.md).

The Python and Go boilerplate projects implement the same CLI and the same API, and the operational examples implement the same five tools, so the languages can be compared on identical problems. The [API contract tests](api-testing/README.md) run against both API implementations (locally; see each items-api README). More is planned for this folder, including CI/CD pipelines in GitLab CI and Jenkins. See the [roadmap](../ROADMAP.md).

## What operations teams build

Most code written by platform, DevOps, and SRE teams falls into a handful of categories. The table shows which language usually fits each one and where this repo has a working example.

| Category | Typical jobs | Usual choice | In this repo |
|---|---|---|---|
| Automation and glue | Bulk cloud changes, scheduled reports, data fixes, calling several APIs in sequence | Python (or [Bash](../devops/bash/README.md) when it's a few commands) | [tag-audit](python/examples/README.md) |
| Inventory and compliance audits | Untagged or unowned resources, old access keys, public buckets, open security groups, expiring certificates | Python for reports and spreadsheets; Go when it ships as a tool to many teams | tag-audit, certcheck |
| Health checks and synthetic probes | HTTP, TLS, and DNS checks from outside the service | Go for long-running agents; either for scripts | certcheck, probe-exporter, [healthcheck](python/boilerplate/healthcheck/README.md) |
| Prometheus exporters | Expose a metric nothing else measures: queue depth, license usage, a business count | Go (node_exporter and blackbox_exporter are Go); Python's prometheus-client is fine for small ones | probe-exporter |
| Webhook receivers and ChatOps | Route alerts, react to CI or Git events, chat slash commands | Either | alert-relay |
| Log and data processing | Summarize logs, find error spikes, move data between systems | Python for analysis; Go for high-volume, always-on processing | logstats |
| Internal CLIs | Tools every engineer runs: environment setup, deploy helpers, access requests | Go (one binary, no runtime to install) | [healthcheck](go/boilerplate/healthcheck/README.md) |
| Internal APIs and portals | Self-service platform APIs: request a database, create a project | Python (FastAPI) or Go (net/http) | [items-api](api-testing/README.md) in both |
| Kubernetes controllers and admission webhooks | Operators that manage a resource's lifecycle, policy webhooks | Go ([Kubebuilder](https://book.kubebuilder.io/), controller-runtime); Python has [Kopf](https://kopf.readthedocs.io/) | Planned; see the [roadmap](../ROADMAP.md) |
| Infrastructure-as-code extensions | Terraform providers, Ansible modules, Pulumi programs | Go for Terraform providers ([Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)); Python for Ansible modules; either for Pulumi | — |
| Cleanup and housekeeping jobs | Snapshot and image retention, stale branches, orphaned volumes | Either, run as a scheduled job | — |

Whatever the category, the same habits make operational code safe to run unattended:

- **Exit codes are the interface:** 0 means fine, 1 means a finding, 2 means a usage error, so cron, CI, and Kubernetes can act on the result.
- **Machine-readable output:** offer `--output json` (or CSV for people) so other tools can consume the results.
- **Credentials from the environment or the platform:** read them from environment variables or an SSO profile or workload identity, never from arguments or files in the repo.
- **Bounded everything:** set timeouts, request size limits, and concurrency limits.
- **Retries only where they help:** retry network errors and 5xx with backoff, but not 4xx.
- **Clean shutdown on SIGTERM:** containers and Kubernetes stop processes this way.
- **Tests that run offline:** use local servers, generated certificates, and fake clouds.
