# Golden path: Python service

[← Examples](../README.md) · [Golden paths](../../03-golden-paths.md#the-example-a-python-service)

A [Copier](https://copier.readthedocs.io/en/stable/) template for a new Python HTTP service on the platform. Put this folder in its own repository (for example `platform/golden-paths/python-service`), tag releases, and teams create services with:

```sh
uv tool install copier
copier copy --trust https://gitlab.example.com/platform/golden-paths/python-service.git orders-api
```

and keep them current with:

```sh
cd orders-api
copier update --trust
```

`--trust` allows the template's one task, `uv lock`, which writes the service's lock file. Copier, uv, and Git are the prerequisites.

## Questions

| Question | Default | Used for |
|---|---|---|
| `service_name` | (required) | Repository, package, image, Helm release, catalog entry. Lowercase letters, digits, and hyphens |
| `description` | A service on the platform's Python golden path. | README, catalog, docs |
| `owner` | `team-example` | CODEOWNERS and the catalog's owner |
| `system` | `sample-apps` | The catalog system |
| `lifecycle` | `experimental` | The catalog lifecycle |
| `gitlab_group` | `apps` | Catalog annotation and CODEOWNERS |
| `ci_components` | `platform/ci-components` | Where the [container-image component](../../../devops/gitlab/examples/components/README.md) lives |
| `platform_charts`, `platform_chart_version` | `registry.example.com/platform/charts`, `0.2.0` | The [web-app chart](../../../devops/helm/examples/charts/web-app/) the service deploys with |

## What a generated service gets

See [Golden paths](../../03-golden-paths.md#the-example-a-python-service) for the full table and the reasoning: copied code, tests, Dockerfile, and docs the team owns; a pipeline that references the platform's component; deploy values that reference the platform's chart by version; a catalog entry and CODEOWNERS from the first commit.

## Testing changes to the template

Run [../check.sh](../check.sh) after any change. It generates a service, runs that service's own checks, releases a new template version and updates the service to it, builds and runs the image, renders the platform chart with the service's values, and, with the Helm lab up, deploys it to a hardened cluster and runs `helm test`. The generated service must pass its own pipeline's checks: a template that hands teams a failing pipeline isn't a golden path.
