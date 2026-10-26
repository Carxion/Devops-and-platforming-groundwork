# Deploying and operating

[← Helm](README.md)

Installing a chart once is easy; running it for years, through upgrades, failures, and people changing things by hand, is the real work. This guide covers the deploy command pipelines should use, waiting and automatic rollback in Helm 4, values per environment, hooks, secrets, previewing changes, history and rollback, adopting existing resources, and running Helm under a GitOps tool.

## The deploy command

```sh
helm upgrade --install web-app oci://registry.example.com/charts/web-app \
  --version 0.1.0 \
  --namespace sample-apps \
  -f environments/prod-eks/web-app.yaml \
  --set image.digest="$IMAGE_DIGEST" \
  --wait --timeout 5m \
  --rollback-on-failure \
  --history-max 20
```

| Part | Why |
|---|---|
| `upgrade --install` | One command whether or not the release exists, so the pipeline doesn't need to know |
| `--version` (or `@sha256:...`) | The exact chart that was tested ([pin versions](02-using-charts.md#pin-versions)) |
| `--namespace`, without `--create-namespace` | Namespaces carry policy (quotas, Pod Security, network defaults); create them deliberately, not as a side effect ([namespace baseline](../kubernetes/README.md)) |
| `-f` for the environment, `--set` only for what changes per run | Reviewed configuration in Git; the pipeline supplies the build's image digest |
| `--wait --timeout` | Succeed only when the workloads are ready ([below](#wait-and-roll-back-automatically)) |
| `--rollback-on-failure` | A failed upgrade returns to the last working revision instead of staying half deployed |
| `--history-max` | Revisions kept; each is a Secret holding the chart and values |

## Wait, and roll back automatically

**Helm 4 doesn't wait unless you ask.** Without `--wait`, `install` and `upgrade` return once the resources are accepted by the API server (the default strategy is `hookOnly`: wait for hooks, nothing else). The pods may still be pulling images, crashing, or failing their probes, and the pipeline reports success.

| Flag | Waits for |
|---|---|
| (none) | Hooks only. Resources are created and Helm returns |
| `--wait` (same as `--wait=watcher`) | Every resource to become ready, judged by kstatus: Deployments rolled out with ready replicas, Jobs complete, and so on |
| `--wait=legacy` | Helm 3's readiness checks, for charts that depend on their exact behavior |
| `--wait-for-jobs` | Jobs to complete too |
| `--rollback-on-failure` | Turns on `--wait` (watcher), and rolls back if the upgrade fails or times out. Helm 3 called it `--atomic`, which still works with a deprecation warning |

What a failed upgrade looks like with `--rollback-on-failure`, from the lab, upgrading to an image digest that doesn't exist:

```text
Error: UPGRADE FAILED: release demo failed, and has been rolled back due to rollback-on-failure being set:
resource Deployment/sample-apps/demo-web-app not ready. status: InProgress, message: Pending termination: 1
context deadline exceeded

$ helm history demo -n sample-apps
REVISION  STATUS      DESCRIPTION
1         superseded  Install complete
2         failed      Upgrade "demo" failed: resource Deployment/sample-apps/demo-web-app not ready. ...
3         deployed    Rollback to 1
```

The pipeline fails (which is right), and the release is back on revision 1's manifests as revision 3. Because the Deployment uses `maxUnavailable: 0`, the old pods kept serving throughout.

**Choose the timeout from the slowest real rollout,** not the default 5 minutes: replicas × (image pull + startup + readiness), with headroom. A timeout shorter than a healthy rollout rolls back good releases.

## Values per environment

Layer values from general to specific, and keep each layer in Git:

```text
chart's values.yaml                 production-shaped defaults
environments/<env>/web-app.yaml     size, ingress, identity for one environment
--set image.digest=...              the one thing each pipeline run decides
```

- **Pass every layer on every upgrade.** An upgrade with any values flags starts from the chart's defaults, not from the release's current values ([the reset](01-basics.md#values-in-order)).
- **Keep environment files small:** only what differs. The [example files](examples/environments/) are a dozen lines each.
- **Promote by changing the digest** (or chart version) in a reviewed change to the environment's values or pipeline, not by editing a cluster.

## Hooks

Hooks are resources Helm creates at a point in the lifecycle instead of managing them with the release. Annotate any resource:

```yaml
metadata:
  annotations:
    helm.sh/hook: pre-upgrade,pre-install       # when
    helm.sh/hook-weight: "0"                    # order among hooks, lowest first
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
```

| Hook | Runs |
|---|---|
| `pre-install`, `post-install` | Before or after the release's resources are created |
| `pre-upgrade`, `post-upgrade` | Before or after an upgrade's resources are applied |
| `pre-rollback`, `post-rollback` | Around a rollback |
| `pre-delete`, `post-delete` | Around an uninstall |
| `test` | When `helm test` runs ([Testing](05-testing-charts.md#helm-test)) |

The common use is a database migration Job as `pre-upgrade` (and `pre-install`): Helm waits for it to complete, and a failed migration stops the upgrade before the new pods start. Things to know:

- **Hook resources aren't part of the release.** Helm doesn't upgrade, roll back, or uninstall them. Clean them up with `hook-delete-policy`, or they pile up and the next run fails because the name exists.
- **A rollback doesn't undo a migration.** Write migrations so the previous version still works against the new schema (expand, migrate, contract), as the tech lead's [migrations guide](../../tech-lead/migrations-and-cutovers.md) describes.
- **GitOps tools treat hooks differently** ([below](#helm-with-gitops)).

## Secrets

Values aren't secret: they live in Git, in pipeline logs when passed with `--set`, and in the release's Secret, readable by anyone who can read Secrets in the namespace ([state](01-basics.md#where-helm-keeps-state)). Keep secrets out of values entirely:

| Approach | How | Notes |
|---|---|---|
| **External Secrets Operator** | The chart renders an `ExternalSecret` naming a path in AWS Secrets Manager, Azure Key Vault, or Vault; the operator creates and refreshes the Kubernetes Secret | The chart holds only references. The default choice on EKS and AKS |
| **Secrets Store CSI driver** | The chart mounts secrets from the cloud's vault as files | Nothing stored in a Kubernetes Secret unless you opt in |
| **Sealed Secrets** | Encrypted Secrets in Git, decrypted by a controller in the cluster | Ties secrets to one cluster's key |
| **helm-secrets with SOPS** | Encrypted values files, decrypted when Helm runs | Simple, but the decrypted values still end up in the release Secret |

Whatever the approach, the workload reads a Kubernetes Secret or mounted file it doesn't create: the chart references `existingSecret: web-app-db` instead of taking a password as a value. Workload identity (EKS Pod Identity, AKS workload identity) removes the need for many secrets altogether; the [example environments](examples/environments/) set it up through `podLabels` and `serviceAccount.annotations`.

## See the change before making it

`helm diff` (a plugin) shows what an upgrade would change, resource by resource, against what's in the cluster:

```sh
helm diff upgrade web-app ./charts/web-app -n sample-apps -f environments/dev/web-app.yaml --set config.PODINFO_UI_MESSAGE=Changed
```

```diff
sample-apps, web-app, ConfigMap (v1) has changed:
  # Source: web-app/templates/configmap.yaml
  ...
-   PODINFO_UI_MESSAGE: "Hello from dev"
+   PODINFO_UI_MESSAGE: "Changed"
```

(Unchanged lines around each change are shown too; trimmed here.)

Run it in merge request pipelines against each environment, and post the output on the merge request, so reviewers see the effect on the cluster and not just the template change. `helm upgrade --dry-run=server` validates the rendered manifests against the cluster's API without applying them.

## History and rollback

```sh
helm history web-app -n sample-apps
helm rollback web-app 1 -n sample-apps --wait     # re-apply revision 1, as a new revision
```

- A rollback re-applies an earlier revision's manifests **and values** as a new revision. The lab rolls back to revision 1 and checks its config is live again.
- **What it doesn't roll back:** CRDs, data, hook side effects (migrations), and anything outside the release.
- **Roll forward when you can.** Re-deploying the previous chart version and digest through the normal pipeline keeps Git, the pipeline, and the cluster in agreement; `helm rollback` is for when the pipeline itself is the problem, at 3 a.m.

## Adopting existing resources

`helm install` fails if a resource it would create already exists and isn't Helm's. From the lab, with a ConfigMap created by hand first:

```text
Error: INSTALLATION FAILED: unable to continue with install: ConfigMap "web-app" in namespace "sample-apps" exists
and cannot be imported into the current release: invalid ownership metadata; label validation error: missing key
"app.kubernetes.io/managed-by": must be set to "Helm"; annotation validation error: missing key
"meta.helm.sh/release-name": must be set to "web-app"; annotation validation error: missing key
"meta.helm.sh/release-namespace": must be set to "sample-apps"
```

To bring existing resources under a release:

- **`--take-ownership`** (Helm 4): adopt them as part of the install or upgrade. In the lab, the same install with this flag succeeded and added the ownership annotations.
- Or label and annotate them first, which is what Helm checks: label `app.kubernetes.io/managed-by=Helm`, annotations `meta.helm.sh/release-name=<release>` and `meta.helm.sh/release-namespace=<namespace>`.

Check with `helm diff` or `--dry-run=server` first: adopting a resource means the chart's version of it replaces what's there.

## Uninstall

`helm uninstall <release> -n <ns>` deletes everything the release created. Keep in mind:

- Resources annotated `helm.sh/resource-policy: keep` survive, by design (often PersistentVolumeClaims and CRDs).
- PersistentVolumeClaims created by StatefulSets aren't part of the release and stay.
- `--keep-history` keeps the release record, so `helm history` still works and a reinstall can roll back to it.

## Helm with GitOps

A GitOps tool deploys what Git says, continuously, instead of a pipeline running `helm upgrade` once. Both major tools use Helm charts, differently:

| | Argo CD | Flux |
|---|---|---|
| **How it uses Helm** | Renders the chart with `helm template`, then applies and tracks the manifests itself. Helm doesn't manage the release | The helm-controller runs real Helm installs and upgrades from a `HelmRelease` resource |
| **`helm list`** | Shows nothing; the Application is the record | Shows the release, as if installed by hand |
| **Hooks** | Mapped to Argo CD's own hooks: most work, `pre-rollback` and `post-rollback` don't | Run by Helm, as usual |
| **Rollback** | Sync to an earlier Git revision | Configurable remediation on failure; or revert in Git |

Either way, the chart and the values files are the same ones the pipeline used, which is the point of keeping environment values in files. With GitOps, the deploy pipeline's last step becomes "change the version or digest in Git", and the tool does the rest. For a set of releases without a GitOps tool, `helmfile` declares many releases and their values in one file.

### Helm and Kustomize together

When a third-party chart needs one change it doesn't expose as a value (an extra label, a patched field), Helm 4 can pass the rendered manifests through a **post-renderer plugin**, such as one that runs Kustomize. Use it sparingly: every patch is something the chart's next version can break silently. Prefer asking upstream for a value, or Argo CD's and Kustomize's own Helm support, where the patch lives next to the chart reference.

## Next

[Troubleshooting](08-troubleshooting.md).
