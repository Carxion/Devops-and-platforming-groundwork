# Platform engineering examples

[← Platform engineering](../README.md)

| Example | What it is |
|---|---|
| [golden-path-python-service](golden-path-python-service/README.md) | A golden path as a Copier template: a new Python HTTP service with code, tests, a hardened image, a GitLab pipeline that builds, scans, and deploys, values for the platform's shared Helm chart, a Backstage catalog entry, TechDocs, and CODEOWNERS |
| [check.sh](check.sh) | Tests the golden path end to end, as a team would use it |

## Run the check

Needs Docker. The cluster step also needs the [Helm lab](../../devops/helm/lab/README.md) running; without it, that step is skipped.

```sh
devops/helm/lab/lab.sh up                  # optional: adds the cluster deploy
platform-engineering/examples/check.sh
```

| Step | Checks |
|---|---|
| Generate | The template, released as v1.0.0 in a Git repository, generates `orders-api`; an invalid name is rejected; every file is there |
| The service's own checks | `uv sync --locked`, ruff format and lint, mypy strict, pytest; the catalog entry is a valid Backstage Component |
| Update | A template v1.1.0 adds a file; `copier update` brings it into the service, keeps the team's own edit, records v1.1.0, and the tests still pass |
| Image | `docker build`, then `/healthz` and `/` answer, running as UID 10001 |
| Platform chart | The [web-app chart](../../devops/helm/examples/charts/web-app/) renders with the service's `deploy/dev.yaml` and `deploy/production.yaml`; helm lint and kubeconform pass |
| Cluster | The image, pushed to the lab registry, deploys by digest with the platform chart into a namespace with Pod Security "restricted" and default-deny networking, is named after the service, and passes `helm test` |

The generated service is left in `platform-engineering/examples/out/` (git-ignored) to look at.
