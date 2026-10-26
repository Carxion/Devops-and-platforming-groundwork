# Writing charts

[← Helm](README.md)

A chart is a directory of templates that Helm renders with values into Kubernetes manifests. This guide covers a chart's structure, designing its values, the template language, and the patterns that make a chart safe to upgrade. It uses the [web-app chart](examples/charts/web-app/) throughout; read it alongside.

## Start from structure, not from `helm create`

`helm create demo` scaffolds a working chart: a Deployment, Service, Ingress, HTTPRoute, HPA, service account, a test, and helpers. It's a useful reference for the conventions, but most of it is options you don't need yet. For your own service, start smaller: copy only what the service needs, and add options when someone needs them. Every value is something to document, test, and keep working.

```text
web-app/
├── Chart.yaml            name, version, appVersion, dependencies
├── Chart.lock            the exact dependency versions (generated; commit it)
├── values.yaml           default values, documented
├── values.schema.json    what values are allowed
├── .helmignore           files left out of the package (tests, editor files)
├── templates/
│   ├── NOTES.txt         printed after install and upgrade
│   ├── _helpers.tpl      named templates (files starting with _ render nothing)
│   ├── deployment.yaml   one resource per file, named after its kind
│   ├── service.yaml
│   ├── ...
│   └── tests/            helm test hooks
└── tests/                helm-unittest suites (not packaged)
```

## Chart.yaml

```yaml
apiVersion: v2              # Helm 3 and 4 charts
name: web-app
description: A stateless HTTP service with the platform's hardened defaults.
type: application           # or library (renders nothing; see the next guide)
version: 0.1.0              # the chart's version: bump on every change
appVersion: "6.15.0"        # what it deploys by default; quote it
kubeVersion: ">=1.30.0-0"   # installs fail fast on older clusters
dependencies:
  - name: platform-lib
    version: 1.0.0
    repository: file://../platform-lib
```

`version` and `appVersion` are independent: a template fix changes `version` only; a new release of the software changes `appVersion` (and `version`). [Packaging](06-packaging-and-releasing.md#version-and-appversion) covers when to bump which part.

## Designing values

Values are the chart's interface. Treat them like an API: easy to change additively, painful to change otherwise.

- **Production-shaped defaults.** The chart's own defaults should be safe to run in production (non-root, resources set, probes on), and environments change size and wiring. A chart whose defaults are dev settings gets deployed to production with dev settings.
- **Document every value** with a comment in `values.yaml`. It's the first place people look ([helm show values](02-using-charts.md#find-and-inspect)).
- **`enabled` flags for optional resources** (`ingress.enabled`, `autoscaling.enabled`), and nested objects for related settings.
- **camelCase keys**, starting lowercase, as the [Helm best practices](https://helm.sh/docs/chart_best_practices/values/) recommend. No hyphens: `.Values.my-key` isn't valid template syntax.
- **Pass structured Kubernetes fields through** (`resources`, `tolerations`, `podLabels`) instead of inventing a value for each sub-field.
- **No secrets in values.** Values are stored in the release Secret and in Git ([Secrets](07-deploying-and-operating.md#secrets)).
- **Quote strings that look like numbers or booleans** in values files (`"true"`, `"0123"`). YAML turns them into other types otherwise.

## Templates

Templates use Go's `text/template` language with the [Sprig](https://masterminds.github.io/sprig/) function library and a few Helm additions. Anything between `{{ }}` is evaluated; everything else is copied as is.

### Built-in objects

| Object | Holds |
|---|---|
| `.Values` | The merged values |
| `.Release` | `.Name`, `.Namespace`, `.Revision`, `.IsInstall`, `.IsUpgrade`, `.Service` (`Helm`) |
| `.Chart` | `Chart.yaml`'s fields: `.Name`, `.Version`, `.AppVersion` |
| `.Capabilities` | The cluster's Kubernetes version and API versions (`.Capabilities.APIVersions.Has "policy/v1"`) |
| `.Template` | The current template's `.Name` and `.BasePath` |
| `.Files` | Other files in the chart: `.Files.Get "config/app.conf"` |

### Functions worth knowing

| Function | Use |
|---|---|
| `quote` | Make a value a YAML string: `value: {{ .Values.x \| quote }}` |
| `default` | A fallback: `{{ .Values.name \| default .Chart.Name }}` |
| `required` | Fail with a message when a value is missing: `{{ required "image.digest is required" .Values.image.digest }}` |
| `fail` | Fail for any reason: `{{ fail "maxReplicas must be at least minReplicas" }}` |
| `toYaml` + `nindent` | Insert a structure, indented: `{{- toYaml .Values.resources \| nindent 12 }}` |
| `include` | Render a named template, so it can be piped: `{{ include "platform-lib.labels" . \| nindent 4 }}` |
| `tpl` | Render a value as a template (for values that contain `{{ }}`) |
| `sha256sum` | A checksum, for the [config pattern](#roll-pods-when-config-changes) |
| `dig` | Read a nested value that may not exist, without an error: `dig "a" "b" "default" .Values` |
| `lookup` | Read a live object from the cluster. Returns nothing in `helm template` and `--dry-run=client`; avoid it for anything the chart can't work without |

### Control flow

```yaml
{{- if .Values.ingress.enabled }}          # render this file only when ingress is on
apiVersion: networking.k8s.io/v1
kind: Ingress
...
{{- end }}

  {{- with .Values.ingress.annotations }}  # only if non-empty; . is now the annotations
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}

data:
  {{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

Inside `with` and `range`, `.` changes. Use `$` for the top level: `{{ $.Release.Name }}`.

### Whitespace

`{{-` trims whitespace (including the newline) before the tag, and `-}}` after it. Most rendering bugs are indentation: a `toYaml` block at the wrong depth, or a line glued to the previous one. The habits that avoid them:

- Put control tags (`if`, `with`, `range`, `end`) on their own lines, as `{{-`.
- Insert blocks with `{{- ... | nindent N }}` on their own line, where `N` is the indentation the block needs. `nindent` adds the newline itself, which is why the tag trims the one before it.
- Render and look: `helm template x . --show-only templates/deployment.yaml`.

## Named templates

Templates defined with `define` in files starting with `_` (by convention `_helpers.tpl`) render nothing themselves; other templates `include` them. Prefix the name with the chart's name, because named templates are global across a chart and all its dependencies:

```yaml
{{- define "platform-lib.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-lib.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

Use `include`, not `template`: `include` returns a string you can pipe to `nindent`; `template` can't be piped. The example charts get their names, labels, and security contexts from the [platform-lib library](04-libraries-and-dependencies.md).

## Patterns that make a chart safe to upgrade

### Selector labels never change

A Deployment's `spec.selector` is immutable. If a chart puts a changing label in it (the chart version, the app version), the next upgrade fails with `field is immutable`. Select on name and instance only, and put everything else in the full label set:

```yaml
selector:
  matchLabels:
    {{- include "platform-lib.selectorLabels" . | nindent 6 }}   # name and instance only
template:
  metadata:
    labels:
      {{- include "platform-lib.labels" . | nindent 8 }}          # plus version, chart, part-of
```

### Leave replicas to the autoscaler

If a Deployment sets `replicas` and an HPA also scales it, every upgrade resets the replica count to the chart's number, briefly undoing the autoscaler. Omit `replicas` when autoscaling is on:

```yaml
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
```

### Roll pods when config changes

A Deployment doesn't restart when a ConfigMap it reads changes. Put a checksum of the rendered ConfigMap in the pod template, so a config change changes the pod template and rolls the pods:

```yaml
template:
  metadata:
    annotations:
      checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

The lab's check upgrades with a new config value and confirms a new ReplicaSet appears.

### Write the namespace into every resource

Helm installs into `--namespace`, but a manifest without `metadata.namespace` goes wherever the tool applying it points: `helm template | kubectl apply`, Argo CD, and policy scanners all treat it as `default`. Set it explicitly on every namespaced resource:

```yaml
metadata:
  name: {{ include "platform-lib.fullname" . }}
  namespace: {{ .Release.Namespace }}
```

checkov's "default namespace" check flagged every resource in the example charts until they did this.

### Fail early on bad input

Validate in templates what a schema can't express, and give the reason:

```yaml
{{- if lt (int .Values.autoscaling.maxReplicas) (int .Values.autoscaling.minReplicas) }}
{{- fail "autoscaling.maxReplicas must be at least autoscaling.minReplicas" }}
{{- end }}
```

A failed render stops the install before anything changes in the cluster.

## NOTES.txt

`templates/NOTES.txt` is rendered and printed after every install and upgrade. Use it to say how to reach what was installed and how to check it, as the [web-app notes](examples/charts/web-app/templates/NOTES.txt) do. Keep it short and specific to the values used.

## A values schema

`values.schema.json` (JSON Schema) is checked on every install, upgrade, lint, and template. A value that doesn't match fails before anything renders:

```text
$ helm template x ./web-app --set replicas=3
Error: values don't meet the specifications of the schema(s) in the following chart(s):
web-app:
- at '': additional properties 'replicas' not allowed
```

The example schemas:

- **Reject unknown keys** (`"additionalProperties": false`). Without it, a typo (`replicas` for `replicaCount`) is silently ignored, which is the most common values mistake.
- **Constrain formats** where a mistake is dangerous: the image digest must match `^sha256:[a-f0-9]{64}$`, so a tag can't be passed where a digest belongs.
- **Require** what the chart can't run without: `image`, `resources` with requests and a memory limit.
- **Allow the keys Helm adds itself.** Helm adds a key for each dependency (`platform-lib`, even for a library chart) and `global`. With `additionalProperties: false`, list them, or the chart's own lint fails, as the example's first lint did.

## Debugging templates

| Command | For |
|---|---|
| `helm lint --strict .` | Structure, and warnings treated as errors |
| `helm template x . --show-only templates/deployment.yaml` | One file's output |
| `helm template x . --debug` | Rendered output even when it isn't valid YAML, to see where it went wrong |
| `helm template x . -f environments/dev/web-app.yaml` | Exactly what an environment gets |
| `helm install x . --dry-run=server` | Render and validate against the cluster's API, without applying |

## Next

[Library charts and dependencies](04-libraries-and-dependencies.md).
