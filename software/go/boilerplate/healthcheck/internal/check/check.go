// Package check checks HTTP endpoints. It's separate from main so it can be
// tested without the command line, and reused by other programs.
package check

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
)

// Result is the outcome of checking one URL.
type Result struct {
	URL       string `json:"url"`
	OK        bool   `json:"ok"`
	Status    int    `json:"status,omitempty"`
	ElapsedMS int64  `json:"elapsed_ms"`
	Error     string `json:"error,omitempty"`
}

// ErrScheme is returned for URLs that aren't http or https.
var ErrScheme = errors.New("only http and https URLs")

// URL sends a GET to one URL and reports whether it answered with the expected
// status. It never returns an error: network problems become a failed Result,
// so one bad endpoint can't stop the others from being checked.
func URL(ctx context.Context, client *http.Client, url string, expect int) Result {
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		return Result{URL: url, Error: ErrScheme.Error()}
	}
	start := time.Now()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return Result{URL: url, Error: fmt.Sprintf("bad request: %v", err)}
	}
	req.Header.Set("User-Agent", "healthcheck/0.1")

	resp, err := client.Do(req)
	elapsed := time.Since(start).Milliseconds()
	if err != nil {
		return Result{URL: url, ElapsedMS: elapsed, Error: err.Error()}
	}
	// Always close the body, or the connection can't be reused (and leaks).
	defer func() { _ = resp.Body.Close() }()

	return Result{URL: url, OK: resp.StatusCode == expect, Status: resp.StatusCode, ElapsedMS: elapsed}
}

// All checks every URL with at most concurrency requests in flight. Results
// are in the same order as urls.
func All(ctx context.Context, client *http.Client, urls []string, expect, concurrency int) []Result {
	results := make([]Result, len(urls))
	concurrency = max(1, concurrency)

	// A buffered channel as a semaphore limits how many goroutines run at once;
	// the WaitGroup waits for all of them. Each goroutine writes only its own
	// index of results, so no mutex is needed.
	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup
	for i, u := range urls {
		wg.Go(func() {
			sem <- struct{}{}
			defer func() { <-sem }()
			results[i] = URL(ctx, client, u, expect)
		})
	}
	wg.Wait()
	return results
}
