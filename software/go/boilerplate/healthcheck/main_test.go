package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func newServer(t *testing.T) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/broken" {
			w.WriteHeader(http.StatusInternalServerError)
		}
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestRunExitCodes(t *testing.T) {
	srv := newServer(t)
	tests := []struct {
		name string
		args []string
		want int
	}{
		{"all healthy", []string{srv.URL + "/ok"}, exitOK},
		{"one failed", []string{srv.URL + "/ok", srv.URL + "/broken"}, exitFailed},
		{"no URLs", []string{}, exitUsage},
		{"unknown flag", []string{"-nope"}, exitUsage},
		{"bad output", []string{"-output", "xml", srv.URL}, exitUsage},
		{"version", []string{"-version"}, exitOK},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			if got := run(context.Background(), tt.args, &stdout, &stderr); got != tt.want {
				t.Errorf("run(%v) = %d; want %d (stderr: %s)", tt.args, got, tt.want, stderr.String())
			}
		})
	}
}

func TestRunJSONOutput(t *testing.T) {
	srv := newServer(t)
	var stdout, stderr bytes.Buffer
	run(context.Background(), []string{"-output", "json", srv.URL + "/ok"}, &stdout, &stderr)

	var results []struct {
		OK     bool `json:"ok"`
		Status int  `json:"status"`
	}
	if err := json.Unmarshal(stdout.Bytes(), &results); err != nil {
		t.Fatalf("output isn't JSON: %v\n%s", err, stdout.String())
	}
	if len(results) != 1 || !results[0].OK || results[0].Status != 200 {
		t.Errorf("got %+v", results)
	}
}

func TestRunReadsURLFile(t *testing.T) {
	srv := newServer(t)
	path := filepath.Join(t.TempDir(), "urls.txt")
	content := "# production\n" + srv.URL + "/ok\n\n" + srv.URL + "/ok\n"
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	if got := run(context.Background(), []string{"-file", path}, &stdout, &stderr); got != exitOK {
		t.Errorf("exit %d; stderr: %s", got, stderr.String())
	}
	if n := strings.Count(stdout.String(), "OK"); n != 2 {
		t.Errorf("want 2 OK lines, got %d:\n%s", n, stdout.String())
	}
}
