# Go 101

[← Software](../README.md)

Go is the language much of the cloud-native world is written in: Kubernetes, Docker, Terraform, Prometheus, Grafana's backends, and most of the tools in [devops/](../../devops/README.md). It compiles to a single static binary with no runtime to install, starts instantly, handles concurrency well, and has a small, stable language with excellent tooling built in. This folder takes you from the basics to a tested, linted, containerized service.

> **Status.** CI checks formatting (gofmt) and runs golangci-lint on the boilerplate projects and the operational examples. They also pass `go vet`, tests with the race detector, and govulncheck, and the items API container passes the shared [API contract](../api-testing/openapi/items-api.yaml) tests with Schemathesis and Newman; run those locally ([how](../../CONTRIBUTING.md#running-the-tests-locally)).

## Learning path

| # | Guide | You'll be able to |
|---|---|---|
| 1 | [Language essentials](01-language-essentials.md) | Read and write Go: types, slices and maps, control flow, functions and multiple returns, errors, structs and methods, interfaces, generics basics |
| 2 | [Go for operations](02-go-for-operations.md) | Build CLIs, call HTTP APIs and serve them, work with JSON, files, and commands, use goroutines, channels, and context safely, and log with slog |
| 3 | [Projects and tooling](03-projects-and-tooling.md) | Lay out a module, manage dependencies, test (table-driven, httptest, race detector), lint, check for vulnerabilities, cross-compile, and containerize |
| 4 | [Testing and linting](04-testing-and-linting.md) | Run every check and know what it catches: gofmt, `go mod tidy -diff`, `go vet`, golangci-lint, `go test` flags, govulncheck, pre-commit, and CI with reports in GitLab and GitHub |

## Boilerplate

| Project | What it is |
|---|---|
| [boilerplate/healthcheck](boilerplate/healthcheck/README.md) | A command-line tool that checks HTTP endpoints in parallel, using only the standard library |
| [boilerplate/items-api](boilerplate/items-api/README.md) | The [Items API](../api-testing/README.md) with the standard library's router, graceful shutdown, structured logging, and a 17 MB distroless image |

The same two projects exist in [Python](../python/README.md), so you can compare the languages on the same problems.

## Operational examples

[examples/](examples/README.md) has five working tools of the kind operations teams write all the time, each built the same way in Python:

| Tool | Job |
|---|---|
| certcheck | Warn before TLS certificates expire |
| logstats | Summarize web access logs and gate on a 5xx error budget |
| probe-exporter | Expose endpoint health as Prometheus metrics |
| alert-relay | Forward Alertmanager alerts to a chat webhook |
| tag-audit | Find AWS resources missing required tags |

For the wider picture of what teams build in each language, see [what operations teams build](../README.md#what-operations-teams-build).

For writing unit tests (fixtures, fakes, table-driven tests, and more), see [Unit testing in Go](../testing/go/README.md).

## Setup

```sh
# Install Go from https://go.dev/dl/, or: brew install go, winget install GoLang.Go
# On RHEL and Ubuntu the distribution's package often lags; use the official tarball:
curl -fsSLO https://go.dev/dl/go1.27.2.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.27.2.linux-amd64.tar.gz
export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"

go version
cd software/go/boilerplate/healthcheck
go run . https://example.com/       # compile and run
go test ./...                       # test every package
go build -o healthcheck .           # one binary; copy it anywhere with the same OS and CPU
```

Each module's `go.mod` names the Go version it needs; newer Go toolchains can download an older or newer toolchain automatically when a module asks for it.

Editor support comes from `gopls`, the official language server (the Go extension for VS Code installs it).

## When to choose Go

| Good fit | Consider something else |
|---|---|
| CLIs to distribute to many machines: one binary, no runtime | Quick one-off scripts and glue: [Bash](../../devops/bash/README.md) or [Python](../python/README.md) |
| Network services, proxies, agents, Kubernetes controllers and operators | Data analysis and notebooks: Python |
| High concurrency: many simultaneous connections or tasks | Prototypes where the problem is still unclear |
| Small, secure container images (distroless or scratch) | Heavy use of a library that only exists in another ecosystem |
| Tools that should start instantly and use little memory | |
