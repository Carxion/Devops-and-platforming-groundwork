# Troubleshooting

[← Helm](README.md)

Symptom by symptom. The error messages are real, from Helm 4.3 in the [lab](lab/README.md).

**First, for anything that went wrong in a cluster:**

```sh
helm status <release> -n <ns>                 # the current revision, its status, and its resources
helm history <release> -n <ns>                # what happened, revision by revision
helm get values <release> -n <ns> --all       # the values actually used
helm get manifest <release> -n <ns>           # what was applied
kubectl -n <ns> get events --sort-by=.lastTimestamp | tail -20
```

## Upgrades

### `another operation (install/upgrade/rollback) is in progress`

```text
Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress
```

Either another Helm command is running on the same release (two pipelines at once), or one was interrupted (a canceled job, a lost connection) and left the release in `pending-upgrade`, `pending-install`, or `pending-rollback`.

- **Another run in progress:** wait for it. Prevent it by serializing deploys per environment (a GitLab [`resource_group`](../gitlab/07-environments-and-deployments.md#one-deployment-at-a-time), or your CI system's equivalent), and never mark deploy jobs interruptible.
- **Stuck in pending:** check `helm history`. Roll back to the last `deployed` revision, which clears the pending state: `helm rollback <release> <revision> -n <ns>`. A stuck `pending-install` with no good revision can only be uninstalled.

### `field is immutable`

```text
Error: UPGRADE FAILED: server-side apply failed for object sample-apps/web-app apps/v1, Kind=Deployment:
Deployment.apps "web-app" is invalid: spec.selector: Invalid value:
{"matchLabels":{"app.kubernetes.io/instance":"web-app-v2","app.kubernetes.io/name":"web-app"}}: field is immutable
```

The chart changed something Kubernetes won't change in place: most often a Deployment's or StatefulSet's `spec.selector` (here, a label in the library's selector set), sometimes a Service's `clusterIP` or a Job's template. Fix the chart so selector labels never change ([selector labels](03-writing-charts.md#selector-labels-never-change)). If the change is deliberate, it's a breaking chart release: the resource has to be deleted and recreated (`--force-replace` does that, with downtime), or released under a new name.

### `exists and cannot be imported into the current release`

A resource the chart creates already exists and wasn't created by this release. The message lists the labels and annotations Helm expects. Adopt it with `--take-ownership`, or remove it if it's left over ([Adopting existing resources](07-deploying-and-operating.md#adopting-existing-resources)).

### The upgrade timed out and rolled back

```text
Error: UPGRADE FAILED: release demo failed, and has been rolled back due to rollback-on-failure being set:
resource Deployment/sample-apps/demo-web-app not ready. status: InProgress, message: Pending termination: 1
```

The new pods never became ready within `--timeout`. Find out why on the next attempt, or by reproducing without `--rollback-on-failure` in a non-production environment:

```sh
kubectl -n <ns> get pods -l app.kubernetes.io/instance=<release>
kubectl -n <ns> describe pod <pod>          # image pull errors, admission rejections, scheduling
kubectl -n <ns> logs <pod> --previous       # a crash, from the last restart
```

Common causes: an image or digest that doesn't exist, a failing readiness probe, a pod rejected by Pod Security admission, not enough capacity or quota. If the rollout is healthy but slow, the timeout is too short.

### The upgrade succeeded, but the app is broken

Without `--wait`, Helm 4 returns as soon as the resources are created, before any pod starts. Always pass `--wait` (or `--rollback-on-failure`, which implies it) in pipelines ([Wait](07-deploying-and-operating.md#wait-and-roll-back-automatically)).

## Values

### My values didn't apply, or values from last time disappeared

| Cause | Check | Fix |
|---|---|---|
| An upgrade with some values flags starts from the chart's defaults | `helm get values <release>` after the upgrade lists only what the last command passed | Pass every values file on every upgrade ([the reset](01-basics.md#values-in-order)) |
| A misspelled or misplaced key, silently ignored | `helm template` with your file: the setting isn't in the output | Compare with `helm show values`; a schema with `additionalProperties: false` turns this into an error |
| `--set` made it the wrong type | The schema error below, or a number where a string was expected | `--set-string key=value`, or a values file with quotes |
| A later `-f` or `--set` overrode it | The order on the command line | Later wins; put the most specific last |

### Values don't meet the schema

```text
Error: UPGRADE FAILED: values don't meet the specifications of the schema(s) in the following chart(s):
web-app:
- at '/config/A': got number, want string
```

The path says where. Here, `--set config.A=2` made `2` a number, and the chart's schema wants strings for config: use `--set-string config.A=2`. For `additional properties 'x' not allowed`, the key doesn't exist in the chart: usually a typo, or a value from a different chart version. For your own chart with dependencies, it can also mean the schema doesn't list the key Helm adds for each dependency ([A values schema](03-writing-charts.md#a-values-schema)).

## Templates

### `nil pointer evaluating interface {}`

```text
Error: web-app/templates/x.yaml:1:10
  executing "web-app/templates/x.yaml" at <.Values.missing.enabled>:
    nil pointer evaluating interface {}.enabled
```

The template reads a key below one that doesn't exist (`.Values.missing` is empty, so `.enabled` has nothing to read from). Give the parent a default in `values.yaml`, guard it with `{{ with .Values.missing }}`, or read it with `dig "missing" "enabled" false .Values`.

### `YAML parse error ... mapping values are not allowed in this context`

The rendered output isn't valid YAML, almost always indentation. Render with `--debug` to see the output Helm couldn't parse, and check each `toYaml` and `include` is piped to `nindent` with the right number:

```sh
helm template x ./chart --debug --show-only templates/deployment.yaml
```

### A resource renders, but in the wrong namespace

`helm template` without `-n` renders `namespace: default`, and charts that don't set `metadata.namespace` leave it to whatever applies the output. Pass `-n` when rendering, and [write the namespace into every resource](03-writing-charts.md#write-the-namespace-into-every-resource).

### `helm lint` fails on something it used to pass

`--strict` treats warnings as errors, and new Helm versions add checks. Read the message; it's usually a real problem (a deprecated API, a missing required field). `[INFO]` lines (such as "icon is recommended") never fail a lint.

## Dependencies

| Error | Fix |
|---|---|
| `found in Chart.yaml, but missing in charts/ directory` | Run `helm dependency build` (CI) or `helm dependency update` (after changing dependencies) |
| `the lock file (Chart.lock) is out of sync with the dependencies file (Chart.yaml)` | Run `helm dependency update` and commit the new `Chart.lock` |
| A named template isn't found (`no template "platform-lib.labels" associated with template "gotpl"`) | The library isn't in `charts/` (build dependencies), or the name is wrong; names are case-sensitive and global |

## Registries and plugins

| Symptom | Fix |
|---|---|
| `registry login currently only supports registry hostname, not a repository path` | Helm 4 takes the host only: `helm registry login registry.example.com`, not a URL with a scheme or path |
| `http: server gave HTTP response to HTTPS client` | The registry has no TLS. Use TLS; for a local lab registry only, add `--plain-http` to `push`, `pull`, `show`, and `install` |
| `unauthorized` on push | The login expired (ECR and ACR tokens last hours), or the token can't write to that path |
| `plugin source does not support verification` | Helm 4 verifies plugins; installing from a Git repository needs `--verify=false`, or install from a verified release archive |
| `Error: plugin "diff" exited with error` after its output | The plugin exited non-zero: often only because a pipe after it closed early (`\| head`). With `--detailed-exitcode`, it also exits non-zero when there are changes, which is useful in CI |

## Next

Back to the [Helm guides](README.md), or the [examples](examples/README.md).
