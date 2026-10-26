# Using charts

[← Helm](README.md)

Most Helm use is installing charts other people wrote: an ingress controller, cert-manager, a database operator, metrics-server. This guide covers finding a chart, reading it before you trust it, pinning it, configuring it with values files, and keeping it up to date. The commands were run in the [lab](lab/README.md), which installs metrics-server exactly this way.

## Where charts come from

| Source | Address | Add it with |
|---|---|---|
| **OCI registry** | `oci://ghcr.io/stefanprodan/charts/podinfo` | Nothing: use the `oci://` reference directly. Log in first if it's private (`helm registry login <host>`) |
| **HTTP repository** | `https://kubernetes-sigs.github.io/metrics-server/`, serving an `index.yaml` | `helm repo add <name> <url>`, then `helm repo update` |
| **A directory or `.tgz`** | `./charts/web-app`, `web-app-0.1.0.tgz` | Nothing |

OCI is where the ecosystem is moving: charts sit in the same registries as images, with the same authentication, replication, and scanning, and can be pinned by digest. Many projects publish both. [Artifact Hub](https://artifacthub.io/) indexes public charts from both kinds of source; `helm search hub <term>` searches it from the command line.

## Find and inspect

```sh
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update metrics-server
helm search repo metrics-server --versions
```

```text
NAME                           CHART VERSION  APP VERSION  DESCRIPTION
metrics-server/metrics-server  3.14.0         0.9.0        Metrics Server is a scalable, efficient source ...
metrics-server/metrics-server  3.13.1         0.8.1        Metrics Server is a scalable, efficient source ...
metrics-server/metrics-server  3.13.0         0.8.0        Metrics Server is a scalable, efficient source ...
```

Before installing anything, read it. A chart runs whatever its templates produce in your cluster, often with cluster-wide permissions:

| Command | Shows |
|---|---|
| `helm show chart <chart> --version <v>` | `Chart.yaml`: maintainers, source, Kubernetes version range, and often a changelog in annotations |
| `helm show readme <chart> --version <v>` | The README |
| `helm show values <chart> --version <v>` | Every value and its default: the real documentation of what you can configure |
| `helm show crds <chart> --version <v>` | Custom resource definitions it installs |
| `helm pull <chart> --version <v> --untar` | The whole chart, to read the templates |
| `helm template <name> <chart> --version <v> -f values.yaml` | Exactly what it would apply, with your values |

The questions worth answering from that: what ClusterRoles and ClusterRoleBindings does it create, and with which verbs? Which images does it run, from where, and can you pin them? Does it run as non-root, with the security context your namespaces require? Does it install CRDs, webhooks, or anything outside its namespace?

OCI charts work the same way, with the reference in place of `repo/chart`:

```sh
helm show chart oci://ghcr.io/stefanprodan/charts/podinfo
```

```text
Pulled: ghcr.io/stefanprodan/charts/podinfo:6.15.0
Digest: sha256:ff3d3e14728f75476ed4d43c14f80d52d81d36bc16906843463d464c6146f0d8
apiVersion: v1
appVersion: 6.15.0
description: Podinfo Helm chart for Kubernetes
...
```

(`apiVersion: v1` is an old chart format from Helm 2; Helm 4 still installs it.)

## Pin versions

**Always pass `--version`.** Without it, Helm takes the newest version available when the command runs, so the same command installs different software next month. For OCI charts, pin the digest too where you can: `oci://ghcr.io/stefanprodan/charts/podinfo@sha256:ff3d...` can't change, and a tag can.

Pin the images inside the chart as well. Most charts take `image.tag` (sometimes `image.digest`) in their values; set them explicitly instead of inheriting the chart's default, so a chart upgrade and an image upgrade are separate decisions.

## Configure with a values file

Keep each environment's configuration for a chart in a file, in Git, next to the version it's for:

```yaml
# platform/metrics-server/values.yaml: chart metrics-server/metrics-server 3.14.0
replicas: 2
args:
  - --kubelet-insecure-tls        # only where kubelets use self-signed certificates, like kind
resources:
  requests:
    cpu: 100m
    memory: 200Mi
```

Then install and upgrade with the same command:

```sh
helm upgrade --install metrics-server metrics-server/metrics-server \
  --version 3.14.0 -n kube-system -f platform/metrics-server/values.yaml --wait
```

- **Only set what you change.** Copying the whole `values.yaml` into your file freezes every default at today's value, so you never get the chart's fixes and can't tell which settings were deliberate.
- **Check your keys exist.** A misspelled key is usually ignored silently. `helm template` with your file, and a look at the output, catches most of them; charts with a values schema reject unknown keys ([schemas](03-writing-charts.md#a-values-schema)).
- **Pass every values file on every upgrade.** An upgrade with any values flags starts from the chart's defaults, not from what's installed ([the reset](01-basics.md#values-in-order)).

## Upgrading a third-party chart

Chart upgrades are where breaking changes hide: renamed values, new defaults, removed resources, CRD changes.

1. **Read the changelog** between your version and the target: the chart's `CHANGELOG.md`, release notes, or the `artifacthub.io/changes` annotation in `helm show chart`.
2. **Diff the rendered manifests** with your values, before touching the cluster:

   ```sh
   helm diff upgrade metrics-server metrics-server/metrics-server \
     --version 3.14.0 -n kube-system -f platform/metrics-server/values.yaml
   ```

   [helm-diff](https://github.com/databus23/helm-diff) is a plugin; the lab's tools image includes it. Without it, compare `helm get manifest <release>` with `helm template` of the new version.
3. **Upgrade a non-production cluster first,** with `--wait`, and check the software works, not just that pods are running.
4. **Move one major version at a time** when the changelog says so; some charts need a migration step between majors.

Let a dependency tool such as Renovate open merge requests for new chart versions in your values files or Argo CD and Flux manifests, so upgrades arrive reviewed and one at a time.

## CRDs

Charts install custom resource definitions in one of two ways:

- **A `crds/` directory.** Helm installs these before anything else on `install`, and **never upgrades or deletes them**. Upgrading such a chart leaves the old CRDs in place; apply new CRDs yourself (`helm show crds <chart> --version <v> | kubectl apply --server-side -f -`) before upgrading the chart.
- **As templates**, usually behind a value (`crds.enabled: true`). Helm upgrades them with the chart, and uninstalling the chart deletes them, **with every custom resource of that type in the cluster**. Charts that do this often set `helm.sh/resource-policy: keep` on them; check before you uninstall.

Whichever the chart uses, treat a CRD change as a cluster-wide change: every namespace's resources of that kind are affected.

## Verify what you install

- **Provenance files.** Charts signed with `helm package --sign` come with a `.prov` file; `helm install --verify` (or `helm verify <chart.tgz>`) checks it against a keyring you trust.
- **Signatures on OCI charts.** Many projects sign OCI charts with Sigstore; `cosign verify <registry>/<chart>@<digest>`, with the expected identity, checks one before you use it ([Signing](06-packaging-and-releasing.md#signing)).
- **Mirror what you depend on.** Copy the charts and images you use into your own registry, scanned and pinned, so an upstream deletion or compromise doesn't reach your clusters directly.

## Next

[Writing charts](03-writing-charts.md).
