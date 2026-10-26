# healthcheck (Go)

[← Go](../../README.md)

A command-line tool that checks HTTP endpoints in parallel and exits non-zero if any are unhealthy. It's boilerplate for an operations CLI in Go: copy the layout, replace the logic. The same tool in Python is in [../../../python/boilerplate/healthcheck](../../../python/boilerplate/healthcheck/), for comparison.

```sh
go run . https://example.com/ https://example.org/
go run . -file urls.txt -output json -timeout 3s
go test -race ./...                       # tests (no network needed)
golangci-lint run ./...
go build -ldflags "-X main.version=1.0.0" -o healthcheck .   # one static binary, no runtime needed
```

| File | Shows |
|---|---|
| [main.go](main.go) | `flag` parsing, logic in `run()` taking its arguments and output writers so tests can call it, `slog` logging to stderr, text (`tabwriter`) or JSON output, exit codes, cancellation on Ctrl-C and SIGTERM, a version set at build time |
| [internal/check/check.go](internal/check/check.go) | An `internal` package (importable only within this module), errors turned into results, requests carrying a `context`, bounded concurrency with a buffered channel and `sync.WaitGroup` |
| [internal/check/check_test.go](internal/check/check_test.go) | Table-driven tests with subtests, `httptest.Server` for a real local server, a cancelled-context test |
| [main_test.go](main_test.go) | Testing exit codes and output through `run()`, temporary files with `t.TempDir()` |
| [.golangci.yml](.golangci.yml) | golangci-lint v2 with the standard linters plus security, error-handling, and HTTP checks |

No dependencies outside the standard library. The [Go guides](../../README.md) explain each choice.
