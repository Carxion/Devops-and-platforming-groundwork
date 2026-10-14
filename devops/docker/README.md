# Docker 101

Containers package an application with everything it needs to run, so it behaves the same on a laptop, in CI, and in production. This folder goes from the first `docker run` to production-ready images and hosts: writing Dockerfiles, Compose, networking and storage, the complex commands you'll need for inspection and cleanup, security, Podman on RHEL, and troubleshooting.

> **Status.** CI lints every Dockerfile with Hadolint and the scripts with ShellCheck and shfmt. Building the images, scanning them with Trivy (failing on fixable HIGH or CRITICAL findings), and running the [Compose example](examples/compose.yaml) end to end (both services start hardened, the API reports healthy, and the k6 smoke test from [api-testing](../../software/api-testing/README.md) passes) run locally with the commands below.

## Learning path

| # | Guide | You'll be able to |
|---|---|---|
| 1 | [Basics](01-basics.md) | Explain images, containers, layers, and registries; run, inspect, and stop containers |
| 2 | [Dockerfiles](02-dockerfiles.md) | Write small, fast-building, non-root images with multi-stage builds, and know why each line is there |
| 3 | [Compose](03-compose.md) | Run multi-container applications with health-checked startup order, profiles, and overrides |
| 4 | [Networking and storage](04-networking-and-storage.md) | Connect containers, publish ports safely, and keep data in volumes |
| 5 | [Complex commands, broken down](05-complex-commands.md) | Use format templates, filters, and jq to inspect and clean up, with each part explained |
| 6 | [Security](06-security.md) | Harden images and runtime settings, scan and sign images, and avoid the mistakes that give away the host |
| 7 | [Podman and RHEL](07-podman-and-rhel.md) | Run containers on RHEL the supported way: rootless Podman, SELinux labels, and systemd with Quadlet |
| 8 | [Troubleshooting](08-troubleshooting.md) | Find out why a container exits, can't connect, runs out of space, or won't build |

Install Docker on a server with [devops/bash/scripts/install-docker.sh](../bash/scripts/install-docker.sh) (Ubuntu and RHEL, or Podman on RHEL), or Docker Desktop on a workstation.

## Examples

| Path | Shows |
|---|---|
| [examples/items-api/Dockerfile](examples/items-api/Dockerfile) | A Python service: pinned base by digest, non-root numeric user, read-only code, no pip, health check, exec-form entrypoint |
| [examples/go-hello/](examples/go-hello/) | A Go service with a multi-stage build, build cache mounts, cross-compilation for multi-architecture images, and a distroless runtime of about 16 MB |
| [examples/compose.yaml](examples/compose.yaml) | Both services with a shared hardened settings block (read-only, no capabilities, resource limits, log rotation), health-checked startup, and a test container that makes the file a CI check |

```sh
# Build and run everything, then run the smoke test (exits with the test's result)
docker compose -f devops/docker/examples/compose.yaml up --build --exit-code-from smoke-test
docker compose -f devops/docker/examples/compose.yaml down
```

## Scripts

| Script | What it does |
|---|---|
| [scripts/docker-audit.sh](scripts/docker-audit.sh) | Flags risky settings on running containers: root user, privileged, Docker socket mounted, host network, added capabilities, writable root filesystem, no limits, no health check, ports open on every interface. `--strict` exits 1 on HIGH findings, for cron or CI. |
| [scripts/docker-cleanup.sh](scripts/docker-cleanup.sh) | Reclaims disk space safely: previews by default, removes only with `--apply`, filters by age, and never touches running containers or named volumes |

The [observability lab](../observability/local-stack/README.md) is a larger Compose example: seven services wired together with provisioned configuration.
