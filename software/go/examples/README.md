# Go operational examples

[← Go 101](../README.md)

Five small tools of the kind every operations team ends up writing. Each one is a single `main.go` with its tests next to it, in one module. They're built the same way in Python ([software/python/examples](../../python/examples/README.md)), so you can compare the two languages. Their JSON output and exit codes match the Python versions.

| Command | What it does | Shows you how to |
| --- | --- | --- |
| [`certcheck`](certcheck/main.go) | Reports TLS certificate expiry for a list of hosts; exits 1 inside the warning window | Verify TLS with `crypto/tls`, fan out with `sync.WaitGroup.Go` and a semaphore, and keep results in order |
| [`logstats`](logstats/main.go) | Summarizes nginx and Apache access logs: status mix, top routes, 5xx ratio, peak minute | Use `regexp` with named groups (and work around RE2's lack of lookahead), `bufio.Scanner` with long lines, and `compress/gzip` |
| [`probe-exporter`](probe-exporter/main.go) | Probes HTTP endpoints and serves the results at `/metrics` | Use `client_golang` with your own registry, a ticker loop, and graceful shutdown on SIGTERM |
| [`alert-relay`](alert-relay/main.go) | Receives Alertmanager webhooks and posts a readable message to a chat incoming webhook | Write a webhook receiver with method-aware routing, `MaxBytesReader`, constant-time token checks, and retries that tell permanent failures from temporary ones |
| [`tag-audit`](tag-audit/main.go) | Lists AWS resources missing required tags; outputs text, JSON, or CSV | Use AWS SDK v2 paginators and the default credential chain, and test against an interface instead of the cloud |

Only `probe-exporter` (client_golang) and `tag-audit` (AWS SDK for Go v2) use modules outside the standard library.

## Build and run

```sh
cd software/go/examples
go build -o bin/ ./...            # all five binaries into bin/

bin/certcheck -warn-days 30 example.com example.org
bin/logstats -top 5 /var/log/nginx/access.log
bin/probe-exporter -port 9101 https://example.com/ &    # then: curl localhost:9101/metrics
RELAY_TOKEN="$(openssl rand -hex 24)" CHAT_WEBHOOK_URL=https://hooks.example.com/... bin/alert-relay
bin/tag-audit -require Owner -require Environment -output csv   # uses your AWS profile or SSO session

GOOS=linux GOARCH=arm64 go build -o bin/linux-arm64/ ./...      # cross-compile for another platform
```

Go's `flag` package stops at the first argument that isn't a flag, so put flags before the targets: `certcheck -warn-days 30 example.com`, not `certcheck example.com -warn-days 30`.

## Check them

```sh
gofmt -l .                        # lists unformatted files; prints nothing when clean
go vet ./...
go test -race ./...
golangci-lint run ./...
go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

The tests need no network access and no cloud account:

- certcheck runs against an `httptest` TLS server with a certificate generated for each test.
- probe-exporter probes `httptest` servers, then scrapes its own handler.
- alert-relay sends to a fake chat server that can fail on demand, which exercises the retries.
- tag-audit runs against a two-page fake of the Tagging API.

CI runs gofmt and golangci-lint ([lint.yml](../../../.github/workflows/lint.yml)); run the tests locally.

## Using them for real

- **Run on a schedule:** run certcheck and tag-audit from cron, a Kubernetes CronJob, or a scheduled pipeline, and alert on a non-zero exit. Exit codes work as the interface: 0 means fine, 1 means a finding, 2 means a usage or configuration error.
- **Prefer existing tools:** for HTTP and TLS probing in production, the [Prometheus Blackbox exporter](https://github.com/prometheus/blackbox_exporter) already does what probe-exporter does. Write your own exporter for things nothing else measures.
- **Ship them as small images:** each binary is static with `CGO_ENABLED=0`, so it fits in a distroless image. The [items API Dockerfile](../boilerplate/items-api/Dockerfile) shows the pattern.
- **Keep secrets out of arguments:** alert-relay reads its token and webhook URL from the environment, because command-line arguments show up in `ps`.
- **Use the narrowest permissions:** tag-audit needs only `tag:GetResources`.
