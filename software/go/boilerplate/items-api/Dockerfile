# syntax=docker/dockerfile:1
#
# Static binary in a distroless image: no shell, no package manager, non-root.
#
#   docker build -t items-api-go software/go/boilerplate/items-api
#   docker run --rm -p 127.0.0.1:8080:8080 items-api-go

FROM --platform=$BUILDPLATFORM golang:1.27-alpine@sha256:b8c9b82affbbb82a020bbcf998dad2ba9516944ac7e883524642a481a9505e9c AS build
WORKDIR /src
COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
ARG TARGETOS TARGETARCH VERSION=dev
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags "-s -w" -o /out/items-api .

FROM gcr.io/distroless/static-debian13:nonroot@sha256:18f4cc26c9ffa7f20a359298be7deadac5c607c8e03a02b8119f1a5fc2f82c99

LABEL org.opencontainers.image.title="items-api-go" \
      org.opencontainers.image.source="https://github.com/Carxion/Devops-and-platforming-groundwork" \
      org.opencontainers.image.licenses="CC-BY-4.0"

COPY --from=build /out/items-api /items-api
USER 65532:65532
EXPOSE 8080
# No HEALTHCHECK: there's no shell in the image. Orchestrators probe /healthz.
ENTRYPOINT ["/items-api"]
