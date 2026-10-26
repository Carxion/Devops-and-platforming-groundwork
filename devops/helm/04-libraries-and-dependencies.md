# Library charts and dependencies

[← Helm](README.md)

Charts can use other charts in two ways: as a **library**, which shares named templates and renders nothing itself, or as a **subchart**, a complete chart installed as part of the parent's release. This guide covers both, how dependencies are declared and locked, and when an umbrella chart helps or hurts. The [example charts](examples/charts/) share a library, `platform-lib`.

## Library charts

When several charts repeat the same blocks (labels, security contexts, a service account, a disruption budget), each copy drifts from the others, and a fix has to be made in every chart. A library chart holds those blocks once:

```yaml
# platform-lib/Chart.yaml
apiVersion: v2
name: platform-lib
type: library     # renders nothing on its own; can't be installed
version: 1.0.0
```

Its templates are all named templates, in files starting with `_`:

```yaml
{{/* platform-lib/templates/_security.tpl */}}
{{- define "platform-lib.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}
```

Application charts depend on it and include its templates:

```yaml
# web-app/templates/deployment.yaml
          securityContext:
            {{- include "platform-lib.containerSecurityContext" . | nindent 12 }}
```

`platform-lib` provides, for the [web-app](examples/charts/web-app/) and [worker](examples/charts/worker/) charts:

| Template | Gives |
|---|---|
| `platform-lib.name`, `.fullname`, `.chart` | Names, truncated to Kubernetes' 63-character limit |
| `platform-lib.labels`, `.selectorLabels` | The recommended `app.kubernetes.io/*` labels, and the stable subset to select on |
| `platform-lib.image` | The image reference, by digest, failing if the digest is missing |
| `platform-lib.podSecurityContext`, `.containerSecurityContext` | The Pod Security "restricted" settings: UID 10001, `RuntimeDefault` seccomp, no privilege escalation, read-only root filesystem, no capabilities |
| `platform-lib.serviceAccount`, `.podDisruptionBudget` | Whole resources, identical in every workload |
| `platform-lib.dnsEgressRule` | The NetworkPolicy egress rule for CoreDNS, so a chart works in a default-deny namespace |

A library runs in the **including chart's context**: `.Values`, `.Release`, and `.Chart` are the application chart's. That's why `platform-lib.labels` puts the web-app chart's name and version on web-app's resources, and why the library can read `.Values.image.digest` without having values of its own.

What belongs in a library: what must be the same everywhere (security contexts, labels, the policy rules your platform requires). What doesn't: anything a team might reasonably need to differ. A library that tries to template whole Deployments with dozens of options becomes a chart nobody can read, configured through another chart.

**Changing a library changes every chart that uses it,** on the charts' next release. Version it like any shared dependency, and remember that a change to labels or selectors in a library is a breaking change for every chart.

## Declaring dependencies

Dependencies go in `Chart.yaml`:

```yaml
dependencies:
  - name: platform-lib
    version: 1.0.0                          # exact, or a range like ~1.0.0
    repository: file://../platform-lib      # a path, a repository URL, or oci://...
  - name: postgresql
    version: 16.7.4
    repository: oci://registry.example.com/charts
    condition: postgresql.enabled           # only included when this value is true
```

```sh
helm dependency update ./web-app   # resolve versions, write Chart.lock, download into charts/
helm dependency build ./web-app    # download exactly what Chart.lock says (what CI should run)
helm dependency list ./web-app     # what's declared, and whether it's present
```

- **Commit `Chart.lock`, ignore `charts/`.** The lock file records the exact versions and a digest; `helm dependency build` rebuilds `charts/` from it, the way a package manager rebuilds from a lock file. The repository's `.gitignore` ignores the examples' `charts/` directories.
- **`file://` dependencies** are for charts developed together in one repository, like the examples. Published charts should depend on published versions.
- **Ranges** (`~1.0.0`, `^1.2.0`) are resolved when you run `update`, and fixed in `Chart.lock` until you run it again.

## Subcharts

A dependency that's an application chart is installed as part of the parent's release: its resources are created, upgraded, and rolled back with the parent's.

```yaml
# The parent's values.yaml: values for a subchart go under its name.
postgresql:
  enabled: true
  auth:
    database: items
```

| Mechanism | Does |
|---|---|
| Values under the subchart's name | Override the subchart's defaults |
| `global:` | Values every chart and subchart can read as `.Values.global.x` |
| `condition: postgresql.enabled` | Include the subchart only when the value is true |
| `tags:` | Turn groups of subcharts on and off together |
| `alias:` | Install the same chart twice under different names |
| `import-values:` | Pull a subchart's exported values into the parent |

A parent can't see a subchart's values (except through `import-values`), and a subchart can't see its parent's (except `global`). Named templates, though, are shared across all of them, which is why every name is prefixed with its chart's name.

## Umbrella charts

An **umbrella chart** has few or no templates of its own; it exists to install a set of subcharts together: an application and its database, or a whole environment.

They're tempting and usually regretted for anything but small, tightly coupled sets:

- **One release for everything:** one failed subchart fails the whole upgrade, and a rollback rolls back all of them.
- **Versions move together:** upgrading one component means releasing the umbrella.
- **Values nest a level deeper,** and errors point at the umbrella, not at the chart that failed.

For a platform made of independent pieces, install each chart as its own release, and use a GitOps tool or `helmfile` to manage the set ([Deploying and operating](07-deploying-and-operating.md#helm-with-gitops)). Keep umbrella charts for components that are only ever deployed together.

## Choosing

| Need | Use |
|---|---|
| The same templates in several charts | A library chart |
| A service that needs its own small database in dev | A subchart behind a `condition`, off in production (where a managed database is used) |
| A third-party component the app depends on | A separate release, installed and upgraded on its own schedule |
| Several services that are always deployed together, at matching versions | An umbrella chart, kept small |
| Many independent releases across clusters | Argo CD or Flux, one release each |

## Next

[Testing charts](05-testing-charts.md).
