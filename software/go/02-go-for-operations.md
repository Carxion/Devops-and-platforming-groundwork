# Go for operations

[← Go 101](README.md)

The parts of Go that operations tooling and services use every day: command-line flags, HTTP clients and servers, JSON, files and commands, concurrency with goroutines and context, and structured logging. All of it is in the standard library; both [boilerplate](README.md#boilerplate) projects use nothing else.

## Command-line tools

The standard `flag` package covers most tools. The [healthcheck main.go](boilerplate/healthcheck/main.go) shows a pattern worth copying: put the logic in a `run` function that takes the arguments and output writers, and returns an exit code. `main` just wires it to the real process, and tests call `run` directly.

```go
func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	os.Exit(run(ctx, os.Args[1:], os.Stdout, os.Stderr))
}

func run(ctx context.Context, args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("healthcheck", flag.ContinueOnError)
	timeout := fs.Duration("timeout", 5*time.Second, "timeout per request")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	// ... fs.Args() holds the positional arguments
	return 0
}
```

- `flag.Duration` parses values like `500ms`, `5s`, `2m` directly.
- Exit codes: 0 success, 1 failure, 2 usage, the same as the [Bash](../../devops/bash/04-scripting.md) and [Python](../python/02-python-for-operations.md#command-line-interfaces) conventions.
- For tools with subcommands (`tool create`, `tool delete`), libraries such as cobra are the common choice (kubectl, Docker, and many others use it).

## HTTP clients

```go
client := &http.Client{Timeout: 10 * time.Second} // never use a client with no timeout

req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://api.example.com/items/order-1001", nil)
if err != nil {
	return err
}
req.Header.Set("Authorization", "Bearer "+token)

resp, err := client.Do(req)
if err != nil {
	return fmt.Errorf("calling items API: %w", err)
}
defer resp.Body.Close() // always, or connections leak

if resp.StatusCode != http.StatusOK {
	return fmt.Errorf("items API: unexpected status %s", resp.Status)
}
var item map[string]any
if err := json.NewDecoder(resp.Body).Decode(&item); err != nil {
	return fmt.Errorf("decoding item: %w", err)
}
```

`http.DefaultClient` and `http.Get` have **no timeout**: a hung server hangs your program. Create a client with one, and reuse it (it pools connections).

## HTTP servers

Go 1.22's router supports methods and path variables in patterns, so most services need no framework:

```go
mux := http.NewServeMux()
mux.HandleFunc("GET /items/{id}", func(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	// ...
})

srv := &http.Server{
	Addr:              ":8080",
	Handler:           mux,
	ReadHeaderTimeout: 5 * time.Second, // protect against slow clients
	ReadTimeout:       15 * time.Second,
	WriteTimeout:      15 * time.Second,
}
```

The [items API](boilerplate/items-api/) adds the rest of a production service: request size limits with `http.MaxBytesReader`, JSON error responses, logging middleware, a health endpoint, and **graceful shutdown**, so `docker stop` and Kubernetes rolling updates don't cut off requests in progress:

```go
ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
defer stop()
go srv.ListenAndServe()
<-ctx.Done()                                    // wait for a signal
shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
defer cancel()
srv.Shutdown(shutdownCtx)                        // stop accepting, finish in-flight requests
```

## JSON

```go
type Item struct {
	ID       string   `json:"id"`
	Status   string   `json:"status"`
	Quantity int      `json:"quantity,omitempty"` // left out when zero
	Tags     []string `json:"tags,omitempty"`
	Internal string   `json:"-"`                  // never encoded
}

data, err := json.Marshal(item)              // struct to JSON bytes
err = json.Unmarshal(data, &item)            // JSON bytes to struct
json.NewEncoder(os.Stdout).Encode(item)      // streams: to writers and from readers
```

Decode into structs when you know the shape (fields are typed and checked); into `map[string]any` when you don't. Unknown fields are ignored unless you use a `Decoder` with `DisallowUnknownFields()`.

## Files and commands

```go
data, err := os.ReadFile("/etc/app/config.json")
err = os.WriteFile("out.json", data, 0o600)  // permissions in octal
entries, err := os.ReadDir("/var/log/app")
err = os.MkdirAll("out/reports", 0o755)

// Line by line, for large files
f, err := os.Open("access.log")
defer f.Close()
scanner := bufio.NewScanner(f)
for scanner.Scan() {
	line := scanner.Text()
	_ = line
}

// Running a command: arguments as a list, never through a shell
out, err := exec.CommandContext(ctx, "systemctl", "is-active", "nginx").Output()
```

`exec.Command` runs the program directly, with no shell, so arguments can't inject commands.

## Concurrency: goroutines, channels, and context

A **goroutine** is a lightweight thread: `go f()` runs `f` concurrently. Thousands are cheap. The hard part is coordinating them, and Go gives three tools:

| Tool | Use for |
|---|---|
| `sync.WaitGroup` | Wait for a group of goroutines to finish |
| Channels | Pass values between goroutines, or limit concurrency (a buffered channel as a semaphore) |
| `context.Context` | Cancel work and set deadlines across goroutines and API calls |

The healthcheck's [check.All](boilerplate/healthcheck/internal/check/check.go) combines all three, checking many URLs with bounded concurrency:

```go
results := make([]Result, len(urls))
sem := make(chan struct{}, concurrency) // at most `concurrency` slots
var wg sync.WaitGroup
for i, u := range urls {
	wg.Go(func() { // Go 1.25+: starts the goroutine and tracks it
		sem <- struct{}{}        // take a slot (blocks when all are taken)
		defer func() { <-sem }() // give it back
		results[i] = URL(ctx, client, u, expect)
	})
}
wg.Wait()
```

Each goroutine writes only its own index of `results`, so no mutex is needed. When goroutines **do** share data, protect it with a `sync.Mutex` (or `sync.RWMutex`, as the [items API store](boilerplate/items-api/internal/api/store.go) does), and run tests with `-race` to catch the cases you missed.

**Pass a `context.Context` as the first argument** to anything that does I/O or might take a while. Cancelling it (Ctrl-C, a timeout, a client disconnecting) stops the work everywhere it's passed:

```go
ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
defer cancel()
req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil) // aborted when ctx ends
```

## Logging with slog

```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
logger.Info("request", "method", r.Method, "path", r.URL.Path, "status", 200, "duration_ms", 12)
// {"time":"...","level":"INFO","msg":"request","method":"GET","path":"/items/a","status":200,"duration_ms":12}
```

`log/slog` writes structured logs (key-value pairs, or JSON) that log systems parse without regexes. Use the JSON handler for services, the text handler for CLIs, and put a trace or request ID in every line for services ([observability](../../devops/observability/README.md#logs-that-help)).

## Cloud SDKs

Both clouds have official Go SDKs, and both find credentials without keys in code: the AWS SDK's default config chain (environment, shared config and SSO, instance or pod role) and Azure's `azidentity.NewDefaultAzureCredential` (managed identity, workload identity, `az login`).

```go
// AWS SDK for Go v2
cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
client := s3.NewFromConfig(cfg)
paginator := s3.NewListObjectsV2Paginator(client, &s3.ListObjectsV2Input{Bucket: aws.String("example-bucket")})
for paginator.HasMorePages() {
	page, err := paginator.NextPage(ctx)
	if err != nil {
		return err
	}
	for _, obj := range page.Contents {
		fmt.Println(*obj.Key, *obj.Size)
	}
}
```

## Building and shipping

```sh
go build -o healthcheck .                                   # for this machine
GOOS=linux GOARCH=arm64 go build -o healthcheck-linux-arm64 .   # cross-compile, no extra tools needed
CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=1.2.0" .   # static, smaller, versioned
```

A static binary (`CGO_ENABLED=0`) runs on any Linux of that architecture, including a container image with nothing else in it ([items-api Dockerfile](boilerplate/items-api/Dockerfile)).
