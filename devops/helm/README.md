# Helm

[← DevOps](../README.md)

Helm 101 through writing, testing, publishing, and running your own charts. Helm packages Kubernetes manifests as **charts**: templates plus default values, versioned, and installed as **releases** that Helm can upgrade and roll back as a unit. Everything here was run against Helm 4.3 in the [lab](lab/README.md), a kind cluster with the same namespace baseline as [devops/kubernetes](../kubernetes/README.md): Pod Security "restricted" and default-deny networking.

| Guide | Covers |
|---|---|
| [Helm 101](01-basics.md) | Charts, releases, and repositories; installing Helm; the everyday commands, with real output; where Helm keeps release state; what changed in Helm 4 |
| [Using charts](02-using-charts.md) | Finding, inspecting, and pinning third-party charts; values files; repositories and OCI registries; CRDs; verifying what you install |
| [Writing charts](03-writing-charts.md) | Chart structure, `Chart.yaml`, designing values, templates and functions, named templates, whitespace, the config checksum, `NOTES.txt`, and a values schema |
| [Library charts and dependencies](04-libraries-and-dependencies.md) | Library charts, dependencies and `Chart.lock`, conditions, global values, umbrella charts, and when to use which |
| [Testing charts](05-testing-charts.md) | `helm lint`, rendering with kubeconform and checkov, helm-unittest, chart-testing, `helm test` hooks, and testing on a real cluster |
| [Packaging and releasing](06-packaging-and-releasing.md) | `version` and `appVersion`, packaging, OCI registries (GitLab, ECR, ACR), installing by digest, signing, and a release pipeline |
| [Deploying and operating](07-deploying-and-operating.md) | Install and upgrade flags in Helm 4, waiting and automatic rollback, values per environment, hooks, secrets, `helm diff`, history and rollback, and Helm with GitOps |
| [Troubleshooting](08-troubleshooting.md) | Symptom by symptom: stuck releases, immutable fields, ownership conflicts, lost values, template errors, schema failures, registries |

## Examples and lab

| Path | What it is |
|---|---|
| [examples/charts/platform-lib](examples/charts/platform-lib/) | A library chart: the labels, hardened security contexts, service account, PDB, and DNS egress rule every workload shares |
| [examples/charts/web-app](examples/charts/web-app/) | The [web app](../kubernetes/apps/web-app/) as a chart: probes, graceful shutdown, zone spreading, HPA, PDB, NetworkPolicy, ingress for ALB or AKS app routing, a values schema, a `helm test` hook, and 27 unit tests. Generic: the golden path in [platform-engineering](../../platform-engineering/README.md) deploys other services with it |
| [examples/charts/worker](examples/charts/worker/) | The [worker](../kubernetes/apps/worker/) as a chart, on the same library |
| [examples/environments](examples/environments/) | Values files for dev, production on EKS, and production on AKS |
| [lab/](lab/README.md) | A kind cluster, an OCI registry, and a tools image with every tool pinned, plus [check.sh](lab/check.sh), which runs every check |

## A suggested path

1. [Helm 101](01-basics.md), then install a public chart with [Using charts](02-using-charts.md).
2. Start the [lab](lab/README.md) and install the [web-app chart](examples/charts/web-app/) into it.
3. [Writing charts](03-writing-charts.md) and [Library charts](04-libraries-and-dependencies.md), reading the example charts alongside.
4. Before a chart reaches a shared cluster: [Testing](05-testing-charts.md), [Packaging](06-packaging-and-releasing.md), and [Deploying and operating](07-deploying-and-operating.md).

## Helm or Kustomize

The repository has both, deploying the same apps: [Kustomize](../kubernetes/README.md) in `devops/kubernetes`, and Helm here.

| | Kustomize | Helm |
|---|---|---|
| **Model** | Plain YAML, patched per environment | Templates, rendered from values |
| **What you review** | The manifests themselves | Templates and values; the manifests only after rendering |
| **Releases** | None: `kubectl apply` | Versioned releases with history, rollback, and hooks |
| **Distribution** | Git | Versioned packages in registries |
| **Best for** | Your own apps, in your own repositories | Software installed by many teams or organizations, with many options; third-party software |

Most platforms use both: Helm for third-party software and shared charts, Kustomize (or plain manifests) for a team's own services. Argo CD and Flux deploy either ([Deploying and operating](07-deploying-and-operating.md#helm-with-gitops)).

## Checks

| Check | Runs |
|---|---|
| `helm lint --strict` with every environment's values; chart-testing lint (Chart.yaml schema, yamllint) | [lab.sh check](lab/README.md), no cluster needed |
| Every rendering through kubeconform (strict, Kubernetes 1.34) and checkov | The same |
| helm-unittest: 32 tests, including expected failures | The same |
| Install with `--wait`, `helm test` through default-deny NetworkPolicy, upgrade, automatic rollback of a failing upgrade, manual rollback, `helm diff`, package, push to an OCI registry, install by digest | `lab.sh check`, after `lab.sh up` |
| Markdown lint, spelling, links; ShellCheck and shfmt on the lab scripts; Hadolint on the tools image | CI ([lint.yml](../../.github/workflows/lint.yml)) |

> **Status.** Helm 4.3.1 with Kubernetes 1.34 (kind), helm-unittest 1.2.1, chart-testing 3.15.0, kubeconform 0.8.0, and checkov 3.3, checked October 2026. Sources: the [Helm documentation](https://helm.sh/docs/), the [chart best practices](https://helm.sh/docs/chart_best_practices/), and each tool's own documentation.
