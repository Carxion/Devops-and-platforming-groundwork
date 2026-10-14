# syntax=docker/dockerfile:1
#
# Static binary in a distroless image: no shell, no package manager, non-root.
#
#   docker build -t items-api-go software/go/boilerplate/items-api
#   docker run --rm -p 127.0.0.1:8080:8080 items-api-go

FROM --platform=$BUILDPLATFORM golang:1.27-alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS build
WORKDIR /src
COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
ARG TARGETOS TARGETARCH VERSION=dev
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags "-s -w" -o /out/items-api .

FROM gcr.io/distroless/static-debian13:nonroot@sha256:e2e927ec666bae08560abb3c55d0659eceabb657f56b6782ab500a9fc7f555e3

LABEL org.opencontainers.image.title="items-api-go" \
      org.opencontainers.image.source="https://github.com/Carxion/Devops-and-platforming-groundwork" \
      org.opencontainers.image.licenses="CC-BY-4.0"

COPY --from=build /out/items-api /items-api
USER 65532:65532
EXPOSE 8080
# No HEALTHCHECK: there's no shell in the image. Orchestrators probe /healthz.
ENTRYPOINT ["/items-api"]
