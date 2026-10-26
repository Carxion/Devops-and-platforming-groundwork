# syntax=docker/dockerfile:1
#
# Multi-stage build: compile in a full Go image, ship only the binary in a
# distroless image with no shell, package manager, or libc. The result is a
# few megabytes, runs as non-root, and has almost nothing to patch.
#
#   docker build -t go-hello --build-arg VERSION=1.0.0 devops/docker/examples/go-hello
#   docker run --rm -p 8080:8080 go-hello
#
# Multi-architecture (with buildx):
#   docker buildx build --platform linux/amd64,linux/arm64 -t registry.example.com/go-hello:1.0.0 --push devops/docker/examples/go-hello

# --- Build stage --------------------------------------------------------------
# $BUILDPLATFORM: compile natively on the build machine, even when targeting
# another architecture (Go cross-compiles; no emulation needed).
FROM --platform=$BUILDPLATFORM golang:1.27-alpine@sha256:b8c9b82affbbb82a020bbcf998dad2ba9516944ac7e883524642a481a9505e9c AS build

WORKDIR /src

# Dependencies first, source second: this layer is reused from cache until
# go.mod changes, so editing code doesn't re-download modules.
COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
ARG VERSION=dev
ARG TARGETOS TARGETARCH
# CGO_ENABLED=0: a static binary that needs no libc, so it runs on distroless/static.
# -trimpath and -s -w: reproducible paths and a smaller binary without debug symbols.
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/go-hello .

# --- Runtime stage ------------------------------------------------------------
# distroless/static:nonroot has CA certificates, time zone data, /etc/passwd
# with a nonroot user (65532), and nothing else.
FROM gcr.io/distroless/static-debian13:nonroot@sha256:18f4cc26c9ffa7f20a359298be7deadac5c607c8e03a02b8119f1a5fc2f82c99

LABEL org.opencontainers.image.title="go-hello" \
      org.opencontainers.image.source="https://github.com/Carxion/Devops-and-platforming-groundwork"

COPY --from=build /out/go-hello /go-hello
USER 65532:65532
EXPOSE 8080
# No HEALTHCHECK: there's no shell or curl in the image to run one. Use the
# orchestrator's probes against /healthz instead (Kubernetes, ECS, Compose
# from another container).
ENTRYPOINT ["/go-hello"]
