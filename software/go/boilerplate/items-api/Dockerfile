# syntax=docker/dockerfile:1
#
# Static binary in a distroless image: no shell, no package manager, non-root.
#
#   docker build -t items-api-go software/go/boilerplate/items-api
#   docker run --rm -p 127.0.0.1:8080:8080 items-api-go

FROM --platform=$BUILDPLATFORM golang:1.27-alpine@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS build
WORKDIR /src
COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
ARG TARGETOS TARGETARCH VERSION=dev
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags "-s -w" -o /out/items-api .

FROM gcr.io/distroless/static-debian13:nonroot@sha256:25ac8f0c3b2334a9eb05452266bd4697864a8c8ef0ef71e5e6480d7f92868329

LABEL org.opencontainers.image.title="items-api-go" \
      org.opencontainers.image.source="https://github.com/Carxion/Devops-and-platforming-groundwork" \
      org.opencontainers.image.licenses="CC-BY-4.0"

COPY --from=build /out/items-api /items-api
USER 65532:65532
EXPOSE 8080
# No HEALTHCHECK: there's no shell in the image. Orchestrators probe /healthz.
ENTRYPOINT ["/items-api"]
