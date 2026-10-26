# GitLab

[← DevOps](../README.md)

GitLab 101 and GitLab CI/CD: how GitLab is organized, then pipelines from a first job to reusable components, runners, cloud access without stored keys, deployments, and pipeline security. Everything here was run against a real GitLab (CE 19.5 with Runner 19.5) in the [lab](lab/README.md): every [example pipeline](examples/README.md) ran to the expected result, and every complete pipeline in the guides passed GitLab's own linter with a simulated pipeline.

| Guide | Covers |
|---|---|
| [GitLab 101](01-basics.md) | Offerings and tiers, groups and projects, roles, tokens and keys, merge requests, protected branches, day-one settings, the `glab` CLI, and GitHub-to-GitLab terms |
| [CI/CD basics](02-ci-cd-basics.md) | How a pipeline is created, the parts of `.gitlab-ci.yml`, predefined variables, artifacts, caches, reports, `needs`, and running and watching pipelines |
| [When jobs run](03-rules-and-pipeline-types.md) | Pipeline sources, `workflow:rules`, merge request pipelines without duplicates, `rules`, manual jobs, schedules, parent-child and multi-project pipelines, auto-cancel, and matrix jobs |
| [Reusing pipeline code](04-reusing-pipeline-code.md) | `default`, `extends`, anchors and `!reference`, `include` in all its forms, CI/CD components and the Catalog, and how to choose |
| [Runners](05-runners.md) | Hosted and self-managed runners, scopes and executors, registering with authentication tokens, `config.toml`, tags, building images without privileged mode, and runner security |
| [Variables, secrets, and cloud access](06-variables-secrets-and-cloud-access.md) | Variable settings and precedence, ID tokens (OIDC) to AWS, Azure, and Vault, the `secrets` keyword, and the job token |
| [Environments and deployments](07-environments-and-deployments.md) | Environments and tiers, deployment gates in each tier, `resource_group`, review apps, rollback, and the Terraform pipeline walked through |
| [Pipeline security](08-pipeline-security.md) | Who can run what with which credentials, a hardening checklist, the security scanners and their tiers, and pinning what pipelines pull in |
| [Troubleshooting](09-troubleshooting.md) | Symptom by symptom: pipelines that don't start, stuck jobs, empty variables, rules surprises, image builds, and cloud authentication |

## Examples and lab

| Path | What it is |
|---|---|
| [examples/](examples/README.md) | Reference pipelines: a CI/CD component that builds, scans, and pushes images; the Python and Go Items APIs; and Terraform on AWS with OIDC plan and a manual apply |
| [lab/](lab/README.md) | A throwaway GitLab, two runners, and a fake AWS in Docker Compose, and how to run every check against it |
| [../terraform/aws/gitlab-oidc](../terraform/aws/gitlab-oidc/), [../terraform/azure/gitlab-oidc](../terraform/azure/gitlab-oidc/) | The cloud side of OIDC: AWS roles and Entra ID applications that trust one GitLab project, plan from branches and apply from one protected branch |

## A suggested path

1. Read [GitLab 101](01-basics.md) and set up a project the way [day one](01-basics.md#day-one-settings-for-a-project) describes.
2. Work through [CI/CD basics](02-ci-cd-basics.md) and [When jobs run](03-rules-and-pipeline-types.md), then copy the [Python](examples/python-service/.gitlab-ci.yml) or [Go](examples/go-service/.gitlab-ci.yml) pipeline into a project.
3. Before anything deploys: [Variables, secrets, and cloud access](06-variables-secrets-and-cloud-access.md), [Environments and deployments](07-environments-and-deployments.md), and [Pipeline security](08-pipeline-security.md).
4. When several projects copy the same jobs, move them into [components](04-reusing-pipeline-code.md#cicd-components).

## Tiers

GitLab comes in Free, Premium, and Ultimate tiers. The guides say when a feature needs a paid tier; everything else works on Free, including all the example pipelines. On GitLab.com, Free namespaces get 400 compute minutes a month on hosted runners; self-managed runners don't use them.

## Checks

| Check | Where | Runs |
|---|---|---|
| Every example pipeline, end to end, against GitLab CE 19.5 | [check_gitlab_examples.py](../../scripts/check_gitlab_examples.py) and the [lab](lab/README.md) | Locally |
| Every example and every complete pipeline in these guides, through the CI Lint API with a simulated pipeline | The same script's `lint` scenario | Locally |
| The `gitlab-oidc` Terraform stacks: `terraform test` with mocked providers, tflint, checkov | [terraform README](../terraform/README.md#checks-and-tested-versions) | Locally; fmt and tflint in CI |
| Markdown lint, spelling, links; ShellCheck and shfmt on the lab script | [lint.yml](../../.github/workflows/lint.yml) | CI |

> **Status.** GitLab 19.5 and GitLab Runner 19.5, checked October 2026. Sources: the [GitLab documentation](https://docs.gitlab.com/) and the [CI/CD YAML reference](https://docs.gitlab.com/ci/yaml/).
