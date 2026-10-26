# GitLab CI/CD examples

[← GitLab](../README.md)

Reference pipelines, each run end to end in the [lab](../lab/README.md) against GitLab CE 19.5. Copy one to the root of a project and adjust it; the comments at the top of each say what it expects.

| Example | For | Shows |
|---|---|---|
| [components/](components/README.md) | A component project, such as `platform/ci-components` | A CI/CD component (`container-image`) with typed inputs that builds an image with Buildah, scans it with Trivy before it leaves the pipeline, and pushes it with Skopeo; a pipeline that tests the component at the commit under test and releases on semver tags |
| [python-service/.gitlab-ci.yml](python-service/.gitlab-ci.yml) | The [Python Items API](../../../software/python/boilerplate/items-api/) | uv with a lock-file-keyed cache; ruff, mypy, pytest, and pip-audit with code quality, test, and coverage reports; the component for the image, with `needs` added to its build job |
| [go-service/.gitlab-ci.yml](go-service/.gitlab-ci.yml) | The [Go Items API](../../../software/go/boilerplate/items-api/) | gofmt, `go vet`, golangci-lint with a code quality report, race-detector tests with gotestsum, govulncheck; the same component |
| [terraform/.gitlab-ci.yml](terraform/.gitlab-ci.yml) | One Terraform root module on AWS, such as [network-vpc](../../terraform/aws/network-vpc/) | fmt, validate, offline tests, and IaC scanning; plan with a read-only OIDC role, shown in the MR; a manual apply of the saved plan with a separate role, in a `production` environment, one at a time |

All four use the same `workflow:rules`, so each push gets exactly one pipeline: a merge request pipeline when an MR is open, otherwise a branch or tag pipeline ([why](../03-rules-and-pipeline-types.md#merge-request-pipelines-without-duplicates)).

## Before using them

- The service pipelines include `$CI_SERVER_FQDN/platform/ci-components/container-image@1.0.0`. Put the [component project](components/README.md) at that path, tag `1.0.0`, or change the path.
- Their image build job asks for a runner tagged `image-build`, which must allow Buildah's user namespace ([Building container images](../05-runners.md#building-container-images)). On GitLab.com's hosted runners, remove `build_tags` instead.
- The Terraform pipeline needs the roles from [aws/gitlab-oidc](../../terraform/aws/gitlab-oidc/) and four CI/CD variables, listed at the top of the file. For Azure, swap the `.aws-oidc` template for the `.azure-oidc` one in [Variables, secrets, and cloud access](../06-variables-secrets-and-cloud-access.md#azure), with the identities from [azure/gitlab-oidc](../../terraform/azure/gitlab-oidc/).

## What testing them found

The lab check runs these as real pipelines, and several first versions failed in ways worth knowing about. Each fix is in the example, and the [troubleshooting guide](../09-troubleshooting.md) has the details:

- Buildah failed under Docker's default seccomp profile: builds now go to a runner tagged for them.
- Trivy can't read an OCI archive tarball: the component now passes an OCI layout directory.
- The Go image's pinned base had a fixable HIGH vulnerability; the scan blocked the push until the digest was updated.
- `TF_VAR_` variables leaked into `terraform test` and broke it: inputs now come from a file variable passed only to `plan`.
- The IaC scanner didn't run in merge request pipelines until `AST_ENABLE_MR_PIPELINES` was set.
