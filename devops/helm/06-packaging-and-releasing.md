# Packaging and releasing

[← Helm](README.md)

A chart is released by packaging it into a versioned `.tgz` and pushing it to a registry, where anyone installing it gets exactly that version. This guide covers versioning, packaging, OCI registries, installing by digest, signing, and a pipeline that does it on every merge. The [lab](lab/README.md) publishes the example charts to a local registry with [publish-charts.sh](examples/publish-charts.sh), and installs one back by digest.

## version and appVersion

| Field | Is | Changes when |
|---|---|---|
| `version` | The chart's own version, [semver](https://semver.org/) | Anything in the chart changes, every time |
| `appVersion` | The version of what the chart deploys, for information | The default image moves to a new release of the software |

Bump `version` by what a chart user has to do:

| Bump | When | Examples |
|---|---|---|
| **Patch** (0.1.0 → 0.1.1) | Nothing for users to change | A template fix, a new comment, a default image patch release |
| **Minor** (0.1.1 → 0.2.0) | New, optional things | A new value with a safe default, a new optional resource |
| **Major** (0.2.0 → 1.0.0) | Users may have to change values or plans | A renamed or removed value, a changed default that alters behavior, changed selector labels, a new required value |

Before 1.0.0, semver treats every release as possibly breaking; move to 1.0.0 when other teams depend on the chart. **Never republish a version:** once `0.1.0` is out, changing it means `0.1.1`. Registries can be configured to allow overwriting; don't rely on it, and [publish-charts.sh](examples/publish-charts.sh) refuses to.

## Package

```sh
helm dependency build ./charts/web-app     # from Chart.lock
helm package ./charts/web-app --destination packages/
# packages/web-app-0.1.0.tgz
```

`helm package --version 0.1.1 --app-version 6.15.1` overrides the fields from `Chart.yaml` at packaging time, for pipelines that set versions from tags; prefer keeping `Chart.yaml` the source of truth, so the version in Git and the version in the registry match. `.helmignore` keeps tests and editor files out of the package.

## Push to an OCI registry

Charts go into the same OCI registries as images. Log in with the host only (Helm 4 rejects a path or scheme), then push to a path; Helm adds the chart name:

```sh
helm registry login registry.example.com --username "$USER" --password-stdin <<<"$TOKEN"
helm push packages/web-app-0.1.0.tgz oci://registry.example.com/charts
```

```text
Pushed: registry.example.com/charts/web-app:0.1.0
Digest: sha256:b914a81df3b7118e4e21d4918975b3c21cf58293cf5b2122b767b9fcbf61386f
```

| Registry | Log in | Push to |
|---|---|---|
| **GitLab** (in CI) | `echo "$CI_REGISTRY_PASSWORD" \| helm registry login "$CI_REGISTRY" --username "$CI_REGISTRY_USER" --password-stdin` | `oci://$CI_REGISTRY_IMAGE/charts` |
| **Amazon ECR** | `aws ecr get-login-password \| helm registry login --username AWS --password-stdin 111122223333.dkr.ecr.us-east-1.amazonaws.com` | `oci://111122223333.dkr.ecr.us-east-1.amazonaws.com/charts`. Create the repository `charts/web-app` first, as for an image repository |
| **Azure Container Registry** | `helm registry login <name>.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password-stdin <<<"$(az acr login --name <name> --expose-token --output tsv --query accessToken)"` | `oci://<name>.azurecr.io/charts` |
| **GitHub** | `echo "$GITHUB_TOKEN" \| helm registry login ghcr.io --username "$GITHUB_ACTOR" --password-stdin` | `oci://ghcr.io/<owner>/charts` |

In pipelines, use the CI system's short-lived credentials (the GitLab job token, an OIDC role for ECR, a workload identity for ACR) rather than stored passwords ([GitLab OIDC](../gitlab/06-variables-secrets-and-cloud-access.md#id-tokens-oidc)).

Classic HTTP repositories (an `index.yaml` and `.tgz` files on a web server, GitHub Pages, or GitLab's Helm package registry) still work, with `helm repo add`. Use them when consumers can't use OCI yet; otherwise OCI is simpler, with one registry, one authentication, and digests.

## Install by digest

A tag (`0.1.0`) is a name a registry could be made to point elsewhere; a digest is the content's hash and can't. Pin deployments that matter to the digest the push printed:

```sh
helm install web-app oci://registry.example.com/charts/web-app@sha256:b914a81df3b7118e4e21d4918975b3c21cf58293cf5b2122b767b9fcbf61386f \
  -n sample-apps -f environments/prod-eks/web-app.yaml --wait
```

The lab's check publishes the charts, then installs web-app this way.

## Signing

Signing lets anyone installing a chart check it came from your pipeline and hasn't changed.

- **Sigstore (cosign), for OCI charts.** A chart in an OCI registry is an artifact like an image, so `cosign sign <registry>/charts/web-app@<digest>` signs it. In CI, sign *keyless*: the job's OIDC token is the identity, recorded in a public transparency log, with no keys to manage. Verify with the identity you expect:

  ```sh
  cosign verify registry.gitlab.com/example-group/charts/charts/web-app@sha256:b914... \
    --certificate-identity "https://gitlab.com/example-group/charts//.gitlab-ci.yml@refs/heads/main" \
    --certificate-oidc-issuer "https://gitlab.com"
  ```

- **Helm provenance files, with PGP.** `helm package --sign --key <name> --keyring <keyring>` writes a `.prov` file next to the package; `helm verify` and `helm install --verify` check it. It predates OCI and needs a PGP key to manage; prefer cosign for OCI charts.

An admission controller (Kyverno, the Sigstore policy-controller) can then require signed images in the cluster; chart signatures are checked before install, by whoever or whatever runs Helm.

## A release pipeline

A GitLab pipeline for a repository of charts: render, lint, and unit test every chart with every environment's values, validate the rendered manifests, then on the default branch publish each new chart version to the project's container registry and sign it.

```text
charts/<name>/                   the charts (one may be a library)
environments/<env>/<name>.yaml   values per environment
publish-charts.sh                from devops/helm/examples
```

```yaml
# .gitlab-ci.yml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH

stages: [test, publish]

variables:
  CHARTS: web-app worker          # application charts with environment values
  K8S_VERSION: 1.34.0             # the version your clusters run

default:
  interruptible: true

.helm:
  image:
    name: alpine/helm:4.3.1
    entrypoint: [""]

render-and-test:
  extends: .helm
  stage: test
  variables:
    HELM_PLUGINS: $CI_PROJECT_DIR/.helm-plugins
    UNITTEST_VERSION: 1.2.1
    UNITTEST_SHA256: 48e86ecc1467b009630e5954375e5d8494139f73b466df5fe8c04fa45b634939
  script:
    # The unit test plugin from its release archive, checked against a pinned checksum.
    - mkdir -p "$HELM_PLUGINS/unittest" rendered
    - wget -qO unittest.tgz "https://github.com/helm-unittest/helm-unittest/releases/download/v${UNITTEST_VERSION}/helm-unittest-linux-amd64-${UNITTEST_VERSION}.tgz"
    - echo "${UNITTEST_SHA256}  unittest.tgz" | sha256sum -c -
    - tar -xzf unittest.tgz -C "$HELM_PLUGINS/unittest"
    - |
      for chart in $CHARTS; do
        helm dependency build "charts/$chart"
        helm lint --strict "charts/$chart"
        helm unittest "charts/$chart"
        for values in environments/*/"$chart".yaml; do
          env="$(basename "$(dirname "$values")")"
          helm lint --strict "charts/$chart" -f "$values"
          helm template "$chart" "charts/$chart" -n "$chart" -f "$values" > "rendered/$chart-$env.yaml"
        done
      done
  artifacts:
    paths: [rendered/]
    expire_in: 1 week

kubeconform:
  stage: test
  needs: [render-and-test]
  image:
    name: ghcr.io/yannh/kubeconform:v0.8.0-alpine
    entrypoint: [""]
  script:
    - /kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" rendered/*.yaml

publish:
  extends: .helm
  stage: publish
  interruptible: false            # never cancel halfway through a publish
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  id_tokens:
    SIGSTORE_ID_TOKEN:            # cosign's keyless identity: this job, on this branch
      aud: sigstore
  variables:
    COSIGN_YES: "true"
  script:
    - apk add --no-cache cosign
    - echo "$CI_REGISTRY_PASSWORD" | helm registry login "$CI_REGISTRY" --username "$CI_REGISTRY_USER" --password-stdin
    - echo "$CI_REGISTRY_PASSWORD" | cosign login "$CI_REGISTRY" --username "$CI_REGISTRY_USER" --password-stdin
    - bash publish-charts.sh charts "oci://$CI_REGISTRY_IMAGE/charts" | tee published.txt
    - |
      # Sign each version this run published, by digest.
      while read -r status name _version digest; do
        if [ "$status" = published ]; then
          cosign sign "$CI_REGISTRY_IMAGE/charts/$name@$digest"
        fi
      done < published.txt
```

What it relies on:

- **Versions bumped in merge requests.** `publish-charts.sh` skips versions already in the registry, so a chart change without a version bump is never published. Add `ct lint --target-branch main` to the test stage to fail merge requests that change a chart without bumping its version.
- **The job token's registry credentials** (`CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD`): nothing stored.
- **Signing identity:** the certificate names the project, the pipeline file, and the branch. Consumers verify against exactly that.

The commands in the test stage are the ones [check.sh](lab/check.sh) runs in the lab; the publish logic is the same script, tested there against a local registry, including that a second run publishes nothing. The pipeline itself passes GitLab's CI Lint with a simulated pipeline in the [GitLab lab](../gitlab/lab/README.md).

## Next

[Deploying and operating](07-deploying-and-operating.md).
