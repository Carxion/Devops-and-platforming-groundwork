# 4. Testing and linting

[← Go 101](README.md)

Every check a Go project should run, what each one catches, how to configure it, and how to run them all on every commit and in CI. [Projects and tooling](03-projects-and-tooling.md) introduces the tools; this guide is the full reference. For *writing* tests, see [Unit testing in Go](../testing/go/README.md).

## The checks, in order

| # | Check | Tool | Catches | Typical time |
|---|---|---|---|---|
| 1 | Formatting | `gofmt -l` (or `goimports`) | Non-standard layout; unsorted or unused imports with goimports | Under a second |
| 2 | Module tidiness | `go mod tidy -diff` | `go.mod` or `go.sum` out of step with the imports | Seconds |
| 3 | Vetting | `go vet` | Suspicious code the compiler accepts: wrong `Printf` arguments, copied locks, unreachable code | Seconds |
| 4 | Linting | `golangci-lint run` | Ignored errors, bugs, security problems, style (dozens of linters in one pass) | Seconds to a minute |
| 5 | Tests | `go test -race -cover` | Wrong behavior, data races, untested code | Seconds |
| 6 | Vulnerabilities | `govulncheck` | Known vulnerabilities in dependencies and the standard library that your code actually calls | Seconds |
| 7 | Contract and integration tests | Schemathesis, Newman, Docker | The running service against its API ([API testing](../api-testing/README.md)) | Minutes |

```sh
test -z "$(gofmt -l .)" && go mod tidy -diff && go vet ./... && golangci-lint run ./... \
  && go test -race -cover ./... && govulncheck ./...
```

## Formatting: gofmt and goimports

```sh
gofmt -l .                  # list files that aren't formatted (prints nothing when clean)
gofmt -w .                  # format in place
gofmt -d .                  # show the diff
go run golang.org/x/tools/cmd/goimports@latest -w .   # gofmt, plus add missing and remove unused imports
```

There are no options to argue about: every Go project is formatted the same way. Set your editor to run `gofmt` (or `goimports`, through gopls) on save. `gofmt -l` doesn't fail on its own, so CI checks that its output is empty.

## Module tidiness

```sh
go mod tidy -diff          # Go 1.23 and later: show what tidy would change, and exit non-zero if anything
go mod verify              # downloaded modules match go.sum
```

`go.mod` lists the modules your code imports; `go.sum` holds their checksums. `tidy -diff` in CI catches an import added without updating them, or a dependency left over after its last use was removed.

## Vetting: go vet

```sh
go vet ./...
```

`go vet` runs analyzers that find code which compiles but is almost certainly wrong: a `Printf` format that doesn't match its arguments, a `sync.Mutex` copied by value, a struct tag with a typo, a `context` cancel function never called. It has no false positives worth suppressing; fix what it reports. `go test` runs a subset of vet automatically.

## Linting: golangci-lint

[golangci-lint](https://golangci-lint.run/) runs many linters in one pass, with one configuration file. The configuration used by every Go project in this repository ([example](../testing/go/example/.golangci.yml)):

```yaml
version: "2"
linters:
  default: standard            # errcheck, govet, ineffassign, staticcheck, unused
  enable:
    - bodyclose                # HTTP response bodies must be closed
    - errorlint                # wrap and compare errors correctly (%w, errors.Is/As)
    - gosec                    # security problems
    - misspell
    - noctx                    # HTTP requests must carry a context
    - revive                   # style, the successor to golint
    - unconvert                # unnecessary type conversions
  exclusions:
    rules:
      - path: _test\.go
        linters: [errcheck, gosec]   # tests may ignore errors from writing test responses
formatters:
  enable: [gofmt, goimports]
```

```sh
golangci-lint run ./...              # lint
golangci-lint run --fix ./...        # apply fixes that linters can make
golangci-lint fmt                    # run the configured formatters
golangci-lint linters                # which linters are enabled
```

When a finding is a deliberate choice, suppress it on the line with the linter and the reason: `//nolint:gosec // G703: reading the file the user named is the point`.

**Build it with a new enough Go.** golangci-lint and govulncheck analyze your code with the Go version they were built with, and refuse code that needs a newer one ("the Go language version (go1.26) used to build golangci-lint is lower than the targeted Go version (1.27)"). Use a release binary or the official GitHub Action, which match current Go; or, with `go run tool@version`, set `GOTOOLCHAIN` to your module's Go version: `GOTOOLCHAIN=go1.27.2 go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.14.0 run ./...`.

## Tests: go test

```sh
go test ./...                          # every package
go test -race ./...                    # with the race detector (needs cgo: a C compiler)
go test -cover ./...                   # coverage per package
go test -coverprofile=cover.out ./... && go tool cover -func=cover.out   # coverage per function
go test -count=1 ./...                 # ignore cached results
go test -shuffle=on ./...              # random order, to find tests that depend on each other
go test -timeout 2m ./...              # fail instead of hanging (the default is 10 minutes)
go test -run '^$' -bench . -benchmem   # only benchmarks
go test -run '^$' -fuzz FuzzLoadItems -fuzztime 30s .   # fuzz one target
```

| Flag | Does |
|---|---|
| `-race` | Instruments memory accesses to detect data races. Slower; run it in CI, always, for code with goroutines |
| `-cover`, `-coverprofile` | Coverage; `go tool cover -html=cover.out` shows it line by line |
| `-count=1` | Run even if a cached result exists (tests are cached when nothing they depend on changed) |
| `-shuffle=on` | Random test order; prints the seed so a failing order can be repeated |
| `-failfast` | Stop after the first failing test |
| `-json` | Machine-readable output, for tools like gotestsum |

For CI reports, [gotestsum](https://github.com/gotestyourself/gotestsum) runs `go test` and writes JUnit XML: `go run gotest.tools/gotestsum@latest --junitfile junit.xml -- -race ./...`.

## Vulnerabilities: govulncheck

```sh
go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...
```

govulncheck checks your dependencies **and the Go standard library** against the Go vulnerability database, and reports only vulnerabilities in code your program actually calls, with the call path. That makes it far quieter than scanners that flag every vulnerable module in `go.sum`.

A standard library finding means **upgrade Go**, not your code. While these guides were being written, govulncheck flagged a `net/http` vulnerability in Go 1.27.0 through the example's `http.Client.Do` call; Go 1.27.2 fixed it, and the same command was clean on 1.27.2. In CI, `actions/setup-go` with `go-version-file: go.mod` installs the latest patch release of the version in `go.mod`, which picks up such fixes automatically.

## On every commit: pre-commit

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: gofmt
        name: gofmt
        entry: sh -c 'test -z "$(gofmt -l .)" || { gofmt -l .; exit 1; }'
        language: system
        types: [go]
        pass_filenames: false
      - id: go-vet
        name: go vet
        entry: go vet ./...
        language: system
        types: [go]
        pass_filenames: false
```

Keep hooks fast (formatting, vet); leave golangci-lint, the race detector, and govulncheck to CI, which can't be skipped with `--no-verify`.

## In CI

GitLab CI, with test results in the merge request:

```yaml
# .gitlab-ci.yml
go-checks:
  image: golang:1.27
  script:
    - test -z "$(gofmt -l .)" || { gofmt -l .; exit 1; }
    - go mod tidy -diff
    - go vet ./...
    - go run github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.14.0 run ./...
    - go run gotest.tools/gotestsum@v1.13.0 --junitfile junit.xml -- -race -coverprofile=cover.out ./...
    - go tool cover -func=cover.out | tail -1
    - go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...
  coverage: '/total:\s+\(statements\)\s+(\d+.\d+)%/'
  artifacts:
    when: always
    reports:
      junit: junit.xml
```

GitHub Actions:

```yaml
jobs:
  go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full commit SHA>
      - uses: actions/setup-go@<full commit SHA>
        with:
          go-version-file: go.mod
      - run: test -z "$(gofmt -l .)"
      - run: go vet ./... && go test -race -cover ./...
      - uses: golangci/golangci-lint-action@<full commit SHA>
        with:
          version: v2.14.0
      - run: go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...
```

This repository's [lint.yml](../../.github/workflows/lint.yml) runs gofmt and golangci-lint on every Go module.

## Common findings and fixes

| Finding | Means | Fix |
|---|---|---|
| errcheck: error return value not checked | An ignored error | Handle it; for a deliberate ignore, `_ = f.Close()` (inside `defer func() { ... }()`) |
| gosec G304 / G703: file path from input | Opening a path that came from outside | Validate or confine the path; if reading the user's file is the point, `//nolint:gosec` with that reason |
| noctx: request without context | `http.Get(url)` can't be canceled | `http.NewRequestWithContext(ctx, ...)`; in tests, `t.Context()` |
| bodyclose: response body not closed | A leaked connection | `defer resp.Body.Close()` right after checking the error |
| errorlint: comparing errors with `==` | Fails for wrapped errors | `errors.Is(err, ErrX)`; wrap with `%w`, not `%v` |
| govet copylocks | A struct containing a mutex passed by value | Pass a pointer |
| `-race`: "DATA RACE" | Two goroutines touch the same memory, at least one writing, without synchronization | A mutex, a channel, or an atomic; never ignore it |
| `-race` on Windows or Alpine: "requires cgo" | The race detector needs a C compiler | Run with `CGO_ENABLED=1` and gcc installed (`apk add gcc musl-dev` on Alpine), or in CI on Linux |
| Tool refuses: "lower than the targeted Go version" | The tool was built with an older Go than the module needs | Use a current release binary, or `GOTOOLCHAIN=<your Go version>` with `go run` |

## Next

Back to the [Go overview](README.md), or on to [Unit testing in Go](../testing/go/README.md).
