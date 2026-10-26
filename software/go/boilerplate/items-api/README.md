# items-api (Go)

[← Go](../../README.md)

The [Items API](../../../api-testing/openapi/items-api.yaml) in Go, using only the standard library: boilerplate for an HTTP service with a contract, tests, and a small production image. The same API in Python is in [../../../python/boilerplate/items-api](../../../python/boilerplate/items-api/), and CI runs the shared [contract tests](../../../api-testing/README.md) against both.

```sh
go run .                                  # listens on :8080; PORT and LOG_LEVEL configure it
go test -race ./...
golangci-lint run ./...

docker build -t items-api-go .
docker run --rm -p 127.0.0.1:8080:8080 items-api-go
schemathesis run ../../../api-testing/openapi/items-api.yaml --url http://127.0.0.1:8080 --checks all
```

| File | Shows |
|---|---|
| [main.go](main.go) | Configuration from environment variables, JSON logging with `slog`, server timeouts, graceful shutdown on SIGTERM |
| [internal/api/api.go](internal/api/api.go) | Go 1.22+ routing patterns (`GET /items/{id}`), a catch-all that returns a JSON 405 with the right `Allow` header, `http.MaxBytesReader` for body limits, JSON helpers, request-logging middleware |
| [internal/api/store.go](internal/api/store.go) | Storage behind an interface, an in-memory implementation safe for concurrent use with `sync.RWMutex`, copies so callers can't change stored data |
| [internal/api/api_test.go](internal/api/api_test.go) | `httptest.NewRecorder` tests of the whole handler, table-driven error cases |
| [Dockerfile](Dockerfile) | Multi-stage build, cross-compilation for multi-architecture images, a static binary in distroless running as non-root: about 17 MB |

**Why the catch-all route?** Go's router answers a wrong method with a plain-text 405. The contract's errors are JSON, so a pattern without a method (`/items/{id}`) catches every other method and answers in JSON with `Allow: DELETE, GET, PUT`. The Python version needed the same fix; Schemathesis found it there.
