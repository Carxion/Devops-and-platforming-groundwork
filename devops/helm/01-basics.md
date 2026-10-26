# Helm 101

[← Helm](README.md)

Helm is a package manager for Kubernetes. A **chart** is a package: templates for Kubernetes manifests, default values, and metadata. Installing a chart into a cluster creates a **release**, which Helm tracks so it can show, upgrade, roll back, and uninstall everything the chart created as one unit. This guide covers the concepts, installing Helm, and the commands you'll use every day. The output shown is real, from the [lab](lab/README.md).

## Concepts

| Term | Is |
|---|---|
| **Chart** | A directory (or a `.tgz` of one) with `Chart.yaml`, `values.yaml`, and `templates/`. Versioned with semver |
| **Values** | The inputs a chart's templates read. The chart has defaults in `values.yaml`; you override them per install |
| **Release** | One installation of a chart in a namespace, with a name (`web-app`). The same chart can be installed many times under different names |
| **Revision** | Each install, upgrade, or rollback of a release gets a new revision number; Helm keeps the history |
| **Repository** | Where charts are published: an OCI registry (`oci://registry.example.com/charts`), or a classic HTTP repository with an `index.yaml` |
| **Hook** | A resource Helm runs at a point in the release lifecycle (before an upgrade, for a test) instead of managing it as part of the release |

Helm renders templates **on your machine** (or in the pipeline), then sends the resulting manifests to the Kubernetes API. Nothing runs in the cluster for Helm itself; release history is stored as Secrets in the release's namespace.

## Install Helm

| Platform | Command |
|---|---|
| macOS | `brew install helm` |
| Windows | `winget install Helm.Helm` |
| Linux | Your distribution's package, or the [release binaries](https://github.com/helm/helm/releases) with their checksums |

Use the same Helm minor version as your pipelines, and pin it there. Helm uses your current kubeconfig context, like `kubectl`; check it before anything that changes a cluster:

```sh
helm version
kubectl config current-context
```

## The everyday commands

Installing the example chart into the lab, with the dev values:

```sh
helm install demo ./web-app -n sample-apps -f environments/dev/web-app.yaml --wait
```

```text
NAME: demo
LAST DEPLOYED: Mon Oct 26 02:05:48 2026
NAMESPACE: sample-apps
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
demo-web-app 6.15.0 is deployed to namespace sample-apps (revision 1).
...
```

The `NOTES` are the chart's `NOTES.txt`, rendered: how to reach what was just installed.

| Command | Does |
|---|---|
| `helm install <release> <chart> -n <ns> -f values.yaml` | Install a chart as a new release |
| `helm upgrade <release> <chart> -n <ns> -f values.yaml` | Upgrade it to a new chart version or new values. `--install` creates the release if it doesn't exist, which is what pipelines use |
| `helm list -n <ns>` (`-A` for all namespaces) | Releases, their revision, status, chart, and app version |
| `helm status <release> -n <ns>` | The current revision's status, notes, and resources |
| `helm history <release> -n <ns>` | Every revision, with what happened |
| `helm get values <release> -n <ns>` | The values you supplied; `--all` for the merged result |
| `helm get manifest <release> -n <ns>` | The manifests Helm applied for the current revision |
| `helm rollback <release> <revision> -n <ns>` | Re-apply an earlier revision, as a new revision |
| `helm uninstall <release> -n <ns>` | Delete the release and everything it created |
| `helm template <release> <chart> -f values.yaml` | Render the manifests without a cluster |
| `helm test <release> -n <ns>` | Run the chart's test hooks |

What the lab shows for each:

```text
$ helm list -n sample-apps
NAME  NAMESPACE    REVISION  UPDATED                                  STATUS    CHART          APP VERSION
demo  sample-apps  1         2026-10-26 02:05:48.820255991 +0000 UTC  deployed  web-app-0.1.0  6.15.0

$ helm get values demo -n sample-apps
USER-SUPPLIED VALUES:
autoscaling:
  maxReplicas: 2
  minReplicas: 1
config:
  PODINFO_UI_MESSAGE: Hello from dev
podDisruptionBudget:
  enabled: false

$ helm history demo -n sample-apps
REVISION  UPDATED                   STATUS      CHART          APP VERSION  DESCRIPTION
1         Mon Oct 26 02:05:48 2026  superseded  web-app-0.1.0  6.15.0       Install complete
2         Mon Oct 26 02:05:52 2026  deployed    web-app-0.1.0  6.15.0       Upgrade complete
```

`CHART` is the chart's own version and `APP VERSION` the version of the software it deploys; they change independently ([Packaging](06-packaging-and-releasing.md#version-and-appversion)).

### Values, in order

Values are merged, later sources winning:

1. The chart's `values.yaml`
2. A parent chart's values for it, if it's a dependency
3. Each `-f` / `--values` file, in order
4. Each `--set`, `--set-string`, `--set-file`, `--set-json`, in order

Prefer files, kept in Git, to `--set`: a file is reviewed and repeatable; a `--set` in someone's shell history is neither. Use `--set` for the one thing that changes per run, like an image digest in a pipeline.

**On upgrade, values are reset unless you pass none.** If an upgrade has any `-f` or `--set`, Helm starts again from the chart's defaults plus what you passed now, not from what the release had. The lab shows it: after installing with the dev file, an upgrade with only `--set` loses everything the dev file set:

```text
$ helm upgrade demo ./web-app -n sample-apps --set config.PODINFO_UI_MESSAGE=x
$ helm get values demo -n sample-apps
USER-SUPPLIED VALUES:
config:
  PODINFO_UI_MESSAGE: x
```

Always pass the full set of values files on every upgrade, as pipelines do. `--reuse-values` and `--reset-then-reuse-values` exist, but they make the result depend on history nobody can see in Git.

## Where Helm keeps state

Each revision is a Secret in the release's namespace:

```text
$ kubectl -n sample-apps get secrets -l owner=helm,name=demo
NAME                         TYPE                 DATA   AGE
sh.helm.release.v1.demo.v1   helm.sh/release.v1   1      8s
sh.helm.release.v1.demo.v2   helm.sh/release.v1   1      5s
sh.helm.release.v1.demo.v3   helm.sh/release.v1   1      4s
```

- Each holds the chart, the values, and the rendered manifests, compressed. **Values are readable** by anyone who can read Secrets in the namespace, which is one more reason [secrets don't belong in values](07-deploying-and-operating.md#secrets).
- Helm keeps 10 revisions by default (`--history-max` on upgrade changes it).
- Releases belong to a namespace: `helm list` without `-n` shows the current context's namespace only.

## What changed in Helm 4

Helm 4 (November 2025) kept charts compatible: Helm 3 charts (`apiVersion: v2`) install unchanged. What users notice:

| Change | Means |
|---|---|
| `--atomic` is now `--rollback-on-failure`, `--force` is now `--force-replace` | The old flags still work, with a warning: `Flag --atomic has been deprecated, use --rollback-on-failure instead` |
| **`--wait` changed.** Without the flag, Helm waits for hooks only (`hookOnly`); `--wait` means `watcher`, which watches resources become ready using kstatus | Install and upgrade return as soon as the resources are created unless you pass `--wait`. Pipelines should always pass it ([Deploying](07-deploying-and-operating.md#wait-and-roll-back-automatically)) |
| New releases use **server-side apply** | `--server-side` defaults to `auto`: new releases use server-side apply, existing releases keep the method they used |
| Post-renderers are plugins | `--post-renderer` takes a plugin's name, not a path to an executable |
| Plugins are verified | `helm plugin install` checks a plugin's signature by default |
| `helm registry login` takes a host only | `helm registry login registry.example.com`, not a URL with a path or scheme |
| Install OCI charts by digest | `helm install x oci://registry.example.com/charts/web-app@sha256:...` |

Helm 3 still gets fixes for a while (3.22 was released alongside 4.3), but new work should use 4.

## Next

[Using charts](02-using-charts.md).
