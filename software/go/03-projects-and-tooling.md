# Projects and tooling

[← Go 101](README.md)

Go's tooling is mostly built in: formatting, testing, benchmarking, race detection, documentation, dependency management, and cross-compilation all come with `go`. This guide covers project layout and the handful of extra tools worth adding. The [boilerplate](README.md#boilerplate) projects use all of it, and CI runs it on every change.

## Modules and layout

A **module** is a versioned collection of packages, defined by `go.mod`:

```text
items-api/
├── go.mod                  # module path and Go version (and dependencies, if any)
├── go.sum                  # checksums of every dependency (commit it; absent with no dependencies)
├── main.go                 # package main: the program's entry point
└── internal/
    └── api/                # package api: importable only from inside this module
        ├── api.go
        ├── api_test.go     # tests live next to the code
        └── store.go
```

```sh
go mod init example.com/items-api    # create go.mod; the path is how others import it
```

Conventions:

- **`internal/`** for packages that aren't a public API: the compiler forbids imports from outside the module, so you can change them freely.
- **`cmd/<name>/main.go`** when one module builds several programs; a single `main.go` at the root when it builds one.
- **Small, focused packages** named for what they provide (`check`, `api`), not `utils`.
- **No `src/` directory,** and no layout copied from a large project before it's needed. Start flat; split when a package gets hard to read.

## Dependencies

```sh
go get github.com/some/module@v1.4.0   # add or change a dependency (updates go.mod and go.sum)
go mod tidy                            # add missing and remove unused dependencies
go list -m all                         # every dependency, with versions
go list -m -u all                      # which have updates
```

- `go.sum` records the checksum of every module version; Go verifies downloads against it and against the public checksum database, so a tampered module fails to build. Commit it.
- Prefer the standard library: both boilerplate projects have no dependencies at all. Each dependency is code you didn't review that you now have to keep patched.
- Dependabot and Renovate both understand `go.mod`.

## Formatting and vetting

```sh
gofmt -l .        # list files that aren't formatted (empty output means all are)
gofmt -w .        # format them
go vet ./...      # the compiler's checks for suspicious code: bad format strings, copied locks, unreachable code
```

`./...` means "this package and everything below it". There's no style debate in Go: `gofmt` is the style.

## Linting: golangci-lint

[golangci-lint](https://golangci-lint.run/) runs many linters in one pass. The boilerplate's [.golangci.yml](boilerplate/healthcheck/.golangci.yml) enables the standard set plus:

| Linter | Catches |
|---|---|
| errcheck (standard) | Errors that were ignored |
| staticcheck (standard) | Bugs, simplifications, deprecated APIs |
| gosec | Security problems: file paths from input, weak crypto, unsafe permissions |
| bodyclose | HTTP response bodies not closed |
| noctx | HTTP requests without a `context` |
| errorlint | Errors compared with `==` instead of `errors.Is`, or wrapped without `%w` |
| revive | Style: doc comments on exported names, naming |

```sh
golangci-lint run ./...
```

When a finding is a deliberate choice, suppress it on that line with the reason: `//nolint:gosec // G304: opening the file the user named is the point of -file`. The boilerplate's config also excludes `fmt.Fprint*` from errcheck: a CLI that can't write to its own output has nothing useful left to do.

## Testing

```go
func TestURL(t *testing.T) {
	tests := []struct {
		name   string
		url    string
		wantOK bool
	}{
		{"healthy", srv.URL + "/ok", true},
		{"server error", srv.URL + "/broken", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) { // each row is a named subtest
			if got := URL(t.Context(), client, tt.url, 200); got.OK != tt.wantOK {
				t.Errorf("URL(%q).OK = %v; want %v", tt.url, got.OK, tt.wantOK)
			}
		})
	}
}
```

```sh
go test ./...                     # all tests
go test -run TestURL/healthy ./...   # one test or subtest
go test -race ./...               # with the race detector (needs cgo)
go test -cover ./...              # coverage summary
go test -count=1 ./...            # bypass the test cache
```

- **Table-driven tests** (above) are the Go idiom: adding a case is adding a row.
- **`net/http/httptest`** gives you a real local server (`httptest.NewServer`) or an in-memory recorder (`httptest.NewRecorder`), so HTTP code is tested without a network. Both boilerplates use them.
- **`t.TempDir()`, `t.Context()`, `t.Cleanup()`** handle temporary files, cancellation, and teardown.
- **Always run `-race` in CI.** Data races are the bugs concurrent code is most likely to have and least likely to show in ordinary tests.
- **Contract tests** run against the running service: the [api-testing suite](../api-testing/README.md) does this for the items API in CI.

## Vulnerability checking: govulncheck

```sh
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...
```

`govulncheck` checks your dependencies and the Go standard library against the Go vulnerability database, and reports only vulnerabilities in code your program **actually calls**, which cuts the noise of dependency scanners dramatically. Run it in CI, and rebuild with a patched Go release when it flags the standard library.

## Building and containers

```sh
go build -o bin/items-api .
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags "-s -w" -o bin/items-api-arm64 .
```

| Flag | Does |
|---|---|
| `CGO_ENABLED=0` | Pure Go, statically linked: runs without a C library, on distroless or scratch |
| `GOOS`, `GOARCH` | Target operating system and CPU: cross-compiling needs nothing else installed |
| `-trimpath` | Remove local file paths from the binary (reproducible builds, no leaked paths) |
| `-ldflags "-s -w"` | Strip debug symbols: a smaller binary |
| `-ldflags "-X main.version=1.2.0"` | Set a variable at build time |

The [items-api Dockerfile](boilerplate/items-api/Dockerfile) builds in a full Go image and copies only the binary into distroless: about 17 MB, with no shell or package manager for an attacker to use. The [Dockerfiles guide](../../devops/docker/02-dockerfiles.md) explains the pattern, including multi-architecture builds.

## In CI

This repository's [lint workflow](../../.github/workflows/lint.yml) runs `gofmt` and golangci-lint on every project. A full Go pipeline adds `go vet`, `go test -race`, and govulncheck, then builds the items-api image and runs Schemathesis and Newman against the container; here those run locally.
