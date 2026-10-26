# GitLab lab

[← GitLab](../README.md)

A throwaway GitLab in Docker Compose, for testing pipelines before they reach a real instance. It's what the [examples](../examples/README.md) and the guides' pipelines are checked against.

| Service | Is |
|---|---|
| `gitlab` | GitLab CE 19.5.1 at http://127.0.0.1:8929, with its container registry at `gitlab.local:5050` (reachable from jobs) |
| `runner` | GitLab Runner 19.5.1 with two Docker-executor runners: `lab-docker` for untagged jobs, and `lab-image-build`, tagged `image-build`, with the relaxed seccomp profile Buildah needs ([why](../05-runners.md#building-container-images)) |
| `moto` | A fake AWS API at `http://moto:5000`, for the Terraform example's plan and apply |
| `lab-files` | Writes the registry configuration every job gets: Buildah's short-name aliases, and permission to use the lab registry over plain HTTP |

## Use

Needs Docker with about 6 GB of free memory, and Python 3 and Git for the check script.

```sh
devops/gitlab/lab/lab.sh up              # start, wait (3 to 5 minutes the first time), create a token, register runners
python scripts/check_gitlab_examples.py  # every scenario: about 15 minutes, mostly image builds
python scripts/check_gitlab_examples.py lint python   # or some of them
devops/gitlab/lab/lab.sh status
devops/gitlab/lab/lab.sh down            # remove everything, including volumes and credentials
```

Sign in at http://127.0.0.1:8929 as `root` with the password in `.env.lab` (created on first `up`, git-ignored, next to `lab.sh`) to look at the projects, pipelines, registry, and environments the check creates.

## What the check does

| Scenario | Pushes | Expects |
|---|---|---|
| `components` | [examples/components](../examples/components/) as `platform/ci-components` | The test image builds, scans, and pushes on `main`; tag `1.0.0` creates a release |
| `python` | The [Python Items API](../../../software/python/boilerplate/items-api/) with the [Python pipeline](../examples/python-service/.gitlab-ci.yml) | Every job passes on `main`; GitLab parsed the test, coverage, and code quality reports; the image is in the registry. A second push to a branch with an open MR creates one MR pipeline and no branch pipeline |
| `go` | The [Go Items API](../../../software/go/boilerplate/items-api/) with the [Go pipeline](../examples/go-service/.gitlab-ci.yml) | The same, for Go |
| `terraform` | [aws/network-vpc](../../terraform/aws/network-vpc/) with the [Terraform pipeline](../examples/terraform/.gitlab-ci.yml) | On `main`, the checks and the OIDC plan pass and the pipeline waits on the manual apply; playing it applies against moto. An MR pipeline plans |
| `lint` | Nothing | Every example, and every block in the guides that starts with `# .gitlab-ci.yml`, passes the CI Lint API with a simulated pipeline |

Rerunning is safe: the check commits on top of each project (the default branch is protected, so it never force-pushes) and recreates the component release.

## Lab-only settings

Each exists only because the lab runs on plain HTTP on one machine. Don't copy them to a real instance:

- `registry_external_url 'http://...'` and the `insecure = true` registry entry: real registries use TLS.
- `ci_id_tokens_issuer_url 'https://gitlab.local'`: ID tokens need an `https` issuer. A real instance on `https` has one; a private one also needs its keys reachable by the cloud ([ID tokens](../06-variables-secrets-and-cloud-access.md#id-tokens-oidc)).
- The runner container mounts the host's Docker socket to start job containers. Fine on a laptop; on a shared host it gives every job control of the daemon.
- `AWS_ENDPOINT_URL` and `AWS_ENDPOINT_URL_STS` project variables point the Terraform jobs at moto. The STS one matters: without it, role assumption goes to the real AWS.
