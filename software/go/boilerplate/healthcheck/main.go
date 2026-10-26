// Command healthcheck checks that HTTP endpoints answer with the expected
// status, in parallel.
//
// Usage:
//
//	healthcheck [flags] URL...
//	healthcheck -file urls.txt -output json
//
// Exit codes: 0 all healthy, 1 at least one failed, 2 bad usage.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"text/tabwriter"
	"time"

	"example.com/healthcheck/internal/check"
)

const (
	exitOK     = 0
	exitFailed = 1
	exitUsage  = 2
)

// version is set at build time: go build -ldflags "-X main.version=1.2.3"
var version = "dev"

func main() {
	// Cancel in-flight checks on Ctrl-C or SIGTERM.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	os.Exit(run(ctx, os.Args[1:], os.Stdout, os.Stderr))
}

// run holds all the logic, taking its inputs and outputs as parameters so
// tests can call it directly and check the exit code and output.
func run(ctx context.Context, args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("healthcheck", flag.ContinueOnError)
	fs.SetOutput(stderr)
	file := fs.String("file", "", "read URLs from a file, one per line (# comments allowed)")
	timeout := fs.Duration("timeout", 5*time.Second, "timeout per request")
	expect := fs.Int("expect-status", http.StatusOK, "healthy HTTP status")
	concurrency := fs.Int("concurrency", 8, "requests in parallel")
	output := fs.String("output", "text", "output format: text or json")
	verbose := fs.Bool("verbose", false, "debug logging to stderr")
	showVersion := fs.Bool("version", false, "print the version and exit")
	fs.Usage = func() {
		fmt.Fprintln(stderr, "Usage: healthcheck [flags] URL...")
		fs.PrintDefaults()
	}
	if err := fs.Parse(args); err != nil {
		return exitUsage
	}
	if *showVersion {
		fmt.Fprintln(stdout, "healthcheck", version)
		return exitOK
	}

	level := slog.LevelWarn
	if *verbose {
		level = slog.LevelDebug
	}
	logger := slog.New(slog.NewTextHandler(stderr, &slog.HandlerOptions{Level: level}))

	urls := fs.Args()
	if *file != "" {
		fromFile, err := readURLFile(*file)
		if err != nil {
			fmt.Fprintln(stderr, "healthcheck:", err)
			return exitUsage
		}
		urls = append(urls, fromFile...)
	}
	switch {
	case len(urls) == 0:
		fmt.Fprintln(stderr, "healthcheck: give at least one URL, or -file")
		return exitUsage
	case *timeout <= 0 || *concurrency < 1:
		fmt.Fprintln(stderr, "healthcheck: -timeout must be positive and -concurrency at least 1")
		return exitUsage
	case *output != "text" && *output != "json":
		fmt.Fprintln(stderr, "healthcheck: -output must be text or json")
		return exitUsage
	}

	logger.Debug("checking", "urls", len(urls), "concurrency", *concurrency)
	client := &http.Client{Timeout: *timeout}
	results := check.All(ctx, client, urls, *expect, *concurrency)

	if *output == "json" {
		enc := json.NewEncoder(stdout)
		enc.SetIndent("", "  ")
		if err := enc.Encode(results); err != nil {
			fmt.Fprintln(stderr, "healthcheck:", err)
			return exitFailed
		}
	} else {
		printText(stdout, results)
	}

	for _, r := range results {
		if !r.OK {
			return exitFailed
		}
	}
	return exitOK
}

func readURLFile(path string) ([]string, error) {
	f, err := os.Open(path) //nolint:gosec // G304: opening the file the user named is the point of -file
	if err != nil {
		return nil, fmt.Errorf("can't read URL file: %w", err)
	}
	defer func() { _ = f.Close() }()

	var urls []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		urls = append(urls, line)
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("reading %s: %w", path, err)
	}
	if len(urls) == 0 {
		return nil, errors.New("URL file has no URLs")
	}
	return urls, nil
}

func printText(w io.Writer, results []check.Result) {
	// tabwriter aligns columns, like column -t.
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	for _, r := range results {
		state, detail := "OK", fmt.Sprint(r.Status)
		if !r.OK {
			state = "FAIL"
		}
		if r.Status == 0 {
			detail = r.Error
		}
		fmt.Fprintf(tw, "%s\t%s\t%s\t%d ms\n", state, r.URL, detail, r.ElapsedMS)
	}
	_ = tw.Flush()
}
