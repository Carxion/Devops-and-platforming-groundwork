package main

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const sample = `203.0.113.9 - - [13/Oct/2026:08:00:01 +0000] "GET /items/17 HTTP/1.1" 200 512 "-" "curl/8.5.0"
203.0.113.9 - - [13/Oct/2026:08:00:02 +0000] "GET /items/42?full=1 HTTP/1.1" 200 1024 "-" "curl/8.5.0"
198.51.100.4 - alice [13/Oct/2026:08:00:30 +0000] "POST /items HTTP/1.1" 201 64 "-" "app/1.0"
198.51.100.4 - - [13/Oct/2026:08:01:05 +0000] "GET /items/9b2f1c3e-0a4d-4e5f-8a6b-7c8d9e0f1a2b HTTP/1.1" 404 - "-" "app/1.0"
192.0.2.7 - - [13/Oct/2026:08:01:10 +0000] "DELETE /items/17 HTTP/1.1" 503 0 "-" "app/1.0"
this line is not a log line
`

func TestRoute(t *testing.T) {
	cases := map[string]string{
		"/items/17":         "/items/{id}",
		"/items/17/notes/3": "/items/{id}/notes/{id}",
		"/items/17/42":      "/items/{id}/{id}",
		"/items?page=2":     "/items",
		"/items/9b2f1c3e-0a4d-4e5f-8a6b-7c8d9e0f1a2b": "/items/{uuid}",
		"/v2/items": "/v2/items", // a digit inside a segment is not an ID
	}
	for in, want := range cases {
		if got := route(in); got != want {
			t.Errorf("route(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestAnalyze(t *testing.T) {
	s := NewStats()
	if err := analyze(strings.NewReader(sample), s); err != nil {
		t.Fatal(err)
	}
	if s.Requests != 5 || s.Unparsed != 1 || s.BytesSent != 512+1024+64 {
		t.Fatalf("requests=%d unparsed=%d bytes=%d", s.Requests, s.Unparsed, s.BytesSent)
	}
	if s.Routes["GET /items/{id}"] != 2 {
		t.Errorf("routes = %v", s.Routes)
	}
	if s.ErrorRatio() != 0.2 {
		t.Errorf("error ratio = %v", s.ErrorRatio())
	}
	sum := s.Summary(3)
	if sum.PeakMinute == nil || *sum.PeakMinute != (Peak{"13/Oct/2026:08:00", 3}) {
		t.Errorf("peak = %+v", sum.PeakMinute)
	}
	if len(sum.TopServerErrors) != 1 || sum.TopServerErrors[0] != (Pair{"503 DELETE /items/{id}", 1}) {
		t.Errorf("server errors = %v", sum.TopServerErrors)
	}
}

func TestEmptyInput(t *testing.T) {
	s := NewStats()
	if s.ErrorRatio() != 0 || s.Summary(5).PeakMinute != nil {
		t.Fatal("empty input should give zero ratio and no peak")
	}
}

func TestReadsGzipAndPlain(t *testing.T) {
	dir := t.TempDir()
	plain := filepath.Join(dir, "access.log")
	if err := os.WriteFile(plain, []byte(sample), 0o600); err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	gz.Write([]byte(sample))
	gz.Close()
	zipped := filepath.Join(dir, "access.log.1.gz")
	if err := os.WriteFile(zipped, buf.Bytes(), 0o600); err != nil {
		t.Fatal(err)
	}
	var out, errOut bytes.Buffer
	if code := run([]string{"-output", "json", plain, zipped}, nil, &out, &errOut); code != 0 {
		t.Fatalf("exit %d: %s", code, errOut.String())
	}
	var got map[string]any
	if err := json.Unmarshal(out.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if got["requests"] != 10.0 {
		t.Errorf("requests = %v, want 10", got["requests"])
	}
	// Pairs encode as ["name", count], matching the Python version.
	if !strings.Contains(out.String(), `[
      "GET /items/{id}",
      4
    ]`) {
		t.Errorf("top_routes not encoded as pairs:\n%s", out.String())
	}
}

func TestErrorBudget(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run([]string{"-max-error-ratio", "0.5"}, strings.NewReader(sample), &out, &errOut); code != 0 {
		t.Errorf("exit %d, want 0 under budget", code)
	}
	if code := run([]string{"-max-error-ratio", "0.1"}, strings.NewReader(sample), &out, &errOut); code != 1 {
		t.Errorf("exit %d, want 1 over budget", code)
	}
	if !strings.Contains(out.String(), "5xx ratio: 20.00%") {
		t.Errorf("output %q", out.String())
	}
}
