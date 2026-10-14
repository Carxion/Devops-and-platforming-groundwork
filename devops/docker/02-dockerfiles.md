# Dockerfiles

[← Docker 101](README.md)

A Dockerfile is the recipe for an image. Good ones produce images that are small, rebuild fast, run as non-root, and contain nothing an attacker could use. The two [examples](examples/) show every practice here; this page explains why each line is there.

## Instructions

| Instruction | Does |
|---|---|
| `FROM image AS name` | The base image; each `FROM` starts a new stage |
| `RUN cmd` | Run a command at build time, and save the filesystem change as a layer |
| `COPY src dest` | Copy files from the build context (or another stage, with `--from`) |
| `WORKDIR /app` | Set the working directory, creating it if needed |
| `ENV KEY=value` | An environment variable, at build time and in the running container |
| `ARG NAME=default` | A build-time variable (`--build-arg NAME=value`); not in the final image's environment |
| `USER 10001:10001` | The user for later instructions and the running container |
| `EXPOSE 8080` | Documents the listening port. Doesn't publish it; `-p` does that. |
| `HEALTHCHECK CMD ...` | A command Docker runs to decide if the container is healthy |
| `ENTRYPOINT [...]` | The program the container runs |
| `CMD [...]` | Default arguments to the entrypoint (or the command, if there's no entrypoint); replaced by arguments to `docker run` |
| `LABEL key=value` | Metadata, such as the OCI `org.opencontainers.image.*` labels |

## Practices, line by line

### Pin the base image

```dockerfile
FROM python:3.14-slim@sha256:a2b82f3c48559aa0a8446d9af49826b6e2b2016f4cd2afabfe6013ec53729170
```

The tag is for people; the digest is what's pulled. Without the digest, `python:3.14-slim` can be a different image tomorrow, and a rebuild changes what you ship without a code change. Get a digest with `docker buildx imagetools inspect python:3.14-slim` or `docker image inspect --format '{{index .RepoDigests 0}}' python:3.14-slim`, and let Dependabot or Renovate propose updates (the repository's [dependabot.yml](../../.github/dependabot.yml) is the place to add the `docker` ecosystem).

**Choose a small base:** `-slim` variants of language images, `alpine` (tiny, but musl libc can surprise Python and Node native modules), Red Hat's UBI (`ubi9/ubi-minimal`) where RHEL support matters, or distroless (no shell at all) for compiled languages.

### Order layers from least to most frequently changed

```dockerfile
COPY go.mod go.sum ./
RUN go mod download          # cached until go.mod or go.sum changes
COPY . .
RUN go build ...             # reruns when any source file changes
```

Docker reuses a cached layer if the instruction and its inputs are unchanged, and rebuilds every layer after the first change. Copying the dependency manifest and installing dependencies *before* copying the source means a code edit doesn't reinstall every dependency. The same pattern works for `requirements.txt`, `package.json` with `package-lock.json`, and `pom.xml`.

### Clean up in the same layer

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
```

Each `RUN` is a layer, and a file deleted in a later layer still takes space in the earlier one. Install and clean in one `RUN`. `--no-install-recommends` (Debian and Ubuntu) and `dnf install -y --setopt=install_weak_deps=False ... && dnf clean all` (RHEL and UBI) skip optional extras.

### Multi-stage builds

```dockerfile
FROM golang:1.27-alpine@sha256:... AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app .

FROM gcr.io/distroless/static-debian13:nonroot@sha256:...
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
```

Build with all the compilers and tools you need, then copy only the result into a minimal runtime image. The [Go example](examples/go-hello/Dockerfile) goes from a ~300 MB build image to a ~16 MB runtime with no shell, no package manager, and no compiler for an attacker to use. For interpreted languages, use a build stage to install dependencies (and compile native modules), then copy the installed packages into a slim runtime stage.

### BuildKit features

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=cache,target=/root/.cache/go-build go build ...   # a cache that persists between builds, not stored in the image
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci        # a secret available only during this RUN, never in a layer
COPY --chmod=0444 app.py ./                                        # set permissions while copying
```

```sh
docker build --secret id=npmrc,src=$HOME/.npmrc -t app .
```

**Never put secrets in `ENV`, `ARG`, or a `COPY`'d file.** They stay in the image's layers and history (`docker history --no-trunc` shows `ARG` values), and anyone who can pull the image can read them. Use `--mount=type=secret` at build time, and inject secrets at run time from the orchestrator's secret store.

### Run as a non-root user

```dockerfile
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
USER 10001:10001
```

By default, a container's processes run as root. Container root isn't quite host root, but it's close enough that any escape is a full host compromise. A fixed, numeric UID lets Kubernetes verify `runAsNonRoot` without looking inside the image, and matches the `runAsUser: 10001` in the [Kubernetes samples](../kubernetes/README.md). Distroless images have a `nonroot` user (65532) built in.

Copy application files owned by root and read-only to the app user (`COPY --chmod=0444`, or `--chown=root:root`), so a compromised process can't rewrite its own code.

### Exec form, and signals

```dockerfile
ENTRYPOINT ["python", "items_server.py"]     # exec form: the app is PID 1
ENTRYPOINT python items_server.py            # shell form: /bin/sh is PID 1, and the app never sees SIGTERM
```

`docker stop` sends SIGTERM to PID 1 and waits 10 seconds before SIGKILL. With the shell form, the shell is PID 1 and doesn't forward the signal, so every stop takes 10 seconds and kills the app mid-request.

Even in exec form, **PID 1 is special**: the kernel doesn't apply default signal actions to it, so a program that doesn't explicitly handle SIGTERM ignores it. This repository's Python reference server did exactly that: `docker compose down` reported `exited with code 137` (killed) until it got a SIGTERM handler. The fixes, in order of preference: handle SIGTERM in the application (graceful shutdown, as the [Go example](examples/go-hello/main.go) does), or run with `docker run --init` (or `init: true` in Compose), which puts a tiny init process in front that forwards signals.

### Health checks

```dockerfile
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/healthz || exit 1
```

Docker and Compose use it to report `healthy` or `unhealthy`, and Compose's `depends_on: condition: service_healthy` waits for it. Kubernetes ignores it and uses its own probes. Slim and distroless images often lack `curl`: use the language runtime (as the [items-api example](examples/items-api/Dockerfile) does with Python) or leave it out and rely on the orchestrator.

### The build context and .dockerignore

`docker build` sends the *context* (the directory argument) to the builder. Everything in it can end up in the image through a careless `COPY . .`, including `.git`, `.env` files, local credentials, and gigabytes of `node_modules`. A `.dockerignore` keeps them out. The safest form is an allowlist, as in the [Go example](examples/go-hello/.dockerignore):

```text
*
!go.mod
!go.sum
!*.go
```

### Labels

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/Carxion/Devops-and-platforming-groundwork" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.version="${VERSION}"
```

The [OCI annotation keys](https://github.com/opencontainers/image-spec/blob/main/annotations.md) let registries and scanners link an image back to its source and commit.

## Multi-architecture images

ARM servers (AWS Graviton, Azure Cobalt and Ampere) are cheaper per unit of work for many workloads, and laptops are often ARM. Build one image name that works on both:

```sh
docker buildx create --use --name multiarch           # a builder that supports multiple platforms
docker buildx build --platform linux/amd64,linux/arm64 \
  -t registry.example.com/team/go-hello:1.0.0 --push devops/docker/examples/go-hello
docker buildx imagetools inspect registry.example.com/team/go-hello:1.0.0   # one manifest list, two images
```

For compiled languages, cross-compile in the build stage (`FROM --platform=$BUILDPLATFORM`, with `GOOS=$TARGETOS GOARCH=$TARGETARCH`, as the Go example does) instead of emulating the other architecture, which is many times slower.

## Lint and scan

```sh
docker run --rm -i hadolint/hadolint:v2.15.1 < Dockerfile                  # Dockerfile best-practice linter
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.75.0 image \
  --severity HIGH,CRITICAL --ignore-unfixed myapp:1.0                       # known vulnerabilities in the image
```

Hadolint runs in CI on every Dockerfile in this repository; run Trivy after each build. On the first scan of the items-api image, Trivy found four HIGH vulnerabilities, all in libraries bundled inside `pip`, which the app doesn't use at run time. Removing pip from the final image removed all four: **the best vulnerability fix is not shipping the component.** See [Security](06-security.md) for signing and SBOMs.

## Checklist

- [ ] Base image small and pinned by digest; updates proposed automatically
- [ ] Dependencies installed before the source is copied, for caching
- [ ] Multi-stage: no compilers, package managers, or build tools in the final image
- [ ] Runs as a fixed, numeric, non-root UID; code read-only to it
- [ ] No secrets in `ENV`, `ARG`, or copied files; `.dockerignore` as an allowlist
- [ ] Exec-form `ENTRYPOINT`; SIGTERM handled, or `--init`
- [ ] Health check, or orchestrator probes
- [ ] OCI labels for source and revision
- [ ] Hadolint clean; Trivy (or equivalent) gating fixable HIGH and CRITICAL findings
