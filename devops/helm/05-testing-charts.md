# Testing charts

[← Helm](README.md)

A chart can be wrong in several different ways: invalid templates, valid templates that produce invalid manifests, valid manifests that are insecure, logic that does the wrong thing for some values, and manifests that are fine on paper but don't work in a cluster. Each layer below catches a different kind. The [lab's check script](lab/check.sh) runs all of them on the example charts.

| Layer | Catches | Needs a cluster |
|---|---|---|
| `helm lint --strict` | Template errors, schema violations, missing chart fields, warnings | No |
| Render, then kubeconform | Manifests the Kubernetes API would reject: wrong fields, wrong types, deprecated APIs | No |
| Render, then checkov (or another policy tool) | Insecure settings: root, privilege escalation, missing limits, default namespace | No |
| helm-unittest | Logic: what renders for which values, and which values must fail | No |
| chart-testing (`ct lint`) | Chart metadata, YAML style, version bumps, across every changed chart | No |
| Install on a real cluster, `helm test` | Whether it actually runs: admission policies, network policies, probes, the app answering | Yes |

## Lint with every set of values

`helm lint` renders the chart and checks the result. Run it with `--strict` (warnings fail) and with each environment's values, because templates that only render with some values break only in those environments:

```sh
helm dependency build ./web-app
helm lint --strict ./web-app
for env in dev prod-eks prod-aks; do
  helm lint --strict ./web-app -f "environments/$env/web-app.yaml"
done
```

## Render and validate

Render every combination you deploy, and validate what comes out:

```sh
helm template web-app ./web-app -n sample-apps -f environments/prod-eks/web-app.yaml > rendered/web-app-prod-eks.yaml
kubeconform -strict -summary -kubernetes-version 1.34.0 rendered/*.yaml
checkov -d rendered --framework kubernetes
```

- **kubeconform** checks each manifest against the Kubernetes API's schemas. `-strict` rejects unknown fields, which catches misspelled and mis-indented keys the API server would otherwise silently drop. Validate against the version your clusters run; manifests for custom resources need their schemas added with `-schema-location`.
- **checkov** checks for insecure settings. Justified exceptions go on the resource as annotations with a reason (`checkov.io/skip1: CKV_K8S_11=No CPU limit by design...`), so the reason travels with the template. The examples pass with 20 annotated skips. Other policy tools (Kyverno's CLI, Conftest with OPA policies) fit in the same place.
- **Pass `-n`** when rendering for validation; without it, everything renders into `default`.

## Unit tests with helm-unittest

[helm-unittest](https://github.com/helm-unittest/helm-unittest) is a Helm plugin that renders templates with given values and asserts on the output, without a cluster. Tests are YAML files in the chart's `tests/` directory (left out of the package by `.helmignore`):

```yaml
# web-app/tests/deployment_test.yaml
suite: deployment
templates:
  - templates/deployment.yaml
  - templates/configmap.yaml       # rendered too, because the checksum includes it
tests:
  - it: leaves replicas to the HPA when autoscaling is on
    template: templates/deployment.yaml
    asserts:
      - notExists:
          path: spec.replicas

  - it: sets replicas when autoscaling is off
    template: templates/deployment.yaml
    set:
      autoscaling.enabled: false
      replicaCount: 2
    asserts:
      - equal:
          path: spec.replicas
          value: 2

  - it: rejects a tag where a digest should be
    set:
      image:
        digest: latest
    asserts:
      - failedTemplate:
          errorPattern: sha256
```

```sh
helm plugin install https://github.com/helm-unittest/helm-unittest --version v1.2.1 --verify=false
helm unittest ./web-app
```

```text
### Chart [ web-app ] .
 PASS  autoscaling and disruption budget  tests/autoscaling_test.yaml
 PASS  deployment                         tests/deployment_test.yaml
 PASS  ingress and network policy         tests/ingress_and_network_test.yaml
Charts:      1 passed, 1 total
Test Suites: 3 passed, 3 total
Tests:       24 passed, 24 total
```

Helm 4 verifies plugin signatures by default. Installing from a Git repository can't be verified, so without `--verify=false` it fails with `plugin source does not support verification`. Skipping verification means trusting the source at that version; the lab's image instead downloads the plugin's release archive and checks it against a pinned checksum.

What to test:

- **Every value that changes structure:** each `enabled` flag on and off, autoscaling on and off, optional blocks present and absent.
- **The guarantees the chart makes:** the security contexts, digest-pinned images, selectors that don't change, a NetworkPolicy that selects only this release.
- **The inputs that must fail:** a missing digest, ingress without a class, `maxReplicas` below `minReplicas`. A test that the chart *rejects* bad input is as important as one that it accepts good input.

Assertions you'll use most: `equal`, `notExists` / `exists`, `matchRegex`, `contains` (an item in a list), `lengthEqual`, `hasDocuments` (`count: 0` for a resource that shouldn't render), and `failedTemplate` with `errorPattern`.

Write paths that contain brackets in block style (`path: 'spec.containers[0].image'`). In a YAML flow mapping (`{path: spec.containers[0].image, ...}`) the brackets break parsing, which is how the examples' first run failed.

**Check the tests can fail.** Make a deliberate breaking change (in the lab, setting `readOnlyRootFilesystem: false` in the library) and confirm a test catches it. A suite that has never failed hasn't been shown to test anything.

## chart-testing

[chart-testing](https://github.com/helm/chart-testing) (`ct`) is built for repositories with many charts. `ct lint` runs helm lint, checks `Chart.yaml` against a schema, and runs yamllint on the chart's files; in a pull request it finds the charts that changed against the target branch and checks that each one's version was bumped. `ct install` installs each changed chart into a cluster (with each values file in its `ci/` directory) and runs its tests.

```sh
ct lint --target-branch main                         # in CI: the charts that changed
ct lint --charts charts/web-app,charts/worker \
  --validate-maintainers=false --check-version-increment=false   # specific charts, no Git diff
```

It needs `yamllint` and `yamale` installed. Its yamllint rules are stricter than most editors: inline comments need two spaces before the `#`, which the examples' values files failed until fixed.

## On a real cluster

Nothing above proves the chart works. Install it on a disposable cluster that's configured like your real ones, with the same admission policies and network policies, and exercise the lifecycle. The [lab](lab/README.md) uses kind with [devops/kubernetes](../kubernetes/README.md)' namespace baseline, Pod Security "restricted" and a default-deny NetworkPolicy, and checks:

| Step | Shows |
|---|---|
| `helm install ... --wait` | Every pod passes admission and becomes ready |
| `helm test` | The app answers, from inside the namespace, through its NetworkPolicy |
| `helm upgrade` with a config change | A new revision, and the checksum rolled the pods |
| An upgrade to an image that doesn't exist, with `--rollback-on-failure` | Helm waits, gives up at the timeout, and rolls back to the working revision |
| `helm rollback <release> 1` | Rolling back to an earlier revision restores its config |
| `helm package`, `helm push`, install by digest | The published chart is the tested one |

### helm test

A test is a pod (usually) with the `helm.sh/hook: test` annotation; `helm test` creates it and passes if it exits 0. The web-app chart's test requests `/readyz` from the service:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ $name }}
  namespace: {{ .Release.Namespace }}
  annotations:
    helm.sh/hook: test
    helm.sh/hook-delete-policy: before-hook-creation
spec:
  restartPolicy: Never
  securityContext:
    {{- include "platform-lib.podSecurityContext" . | nindent 4 }}
  containers:
    - name: readyz
      image: {{ printf "%s:%s@%s" .Values.tests.image.repository .Values.tests.image.tag .Values.tests.image.digest }}
      command: ["wget", "-q", "-O-", "-T", "5", "http://{{ include "platform-lib.fullname" . }}:{{ .Values.service.port }}/readyz"]
```

Test pods have to meet the same rules as the app: in a "restricted" namespace, a test pod without the hardened security context is rejected at admission. Under a default-deny NetworkPolicy, it also needs its own policy allowing egress to the app, which the chart creates as a test hook with a lower `helm.sh/hook-weight`, so it exists before the pod.

## In a pipeline

On every merge request: lint with each environment's values, render and validate, unit tests, and `ct lint`. These need no cluster and take well under a minute. Before release: install on a disposable cluster (kind in the pipeline, or a shared test cluster), `helm test`, and an upgrade from the previous released version. [Packaging and releasing](06-packaging-and-releasing.md#a-release-pipeline) has a pipeline.

## Next

[Packaging and releasing](06-packaging-and-releasing.md).
