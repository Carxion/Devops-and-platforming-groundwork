package main

import (
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/client_golang/prometheus/testutil"
)

func target(t *testing.T) string {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/ok" {
			w.WriteHeader(http.StatusInternalServerError)
		}
	}))
	t.Cleanup(srv.Close)
	return srv.URL
}

func closedPort(t *testing.T) string {
	t.Helper()
	l, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().String()
}

func quiet() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

func TestProbeResults(t *testing.T) {
	base := target(t)
	down := "http://" + closedPort(t) + "/"
	reg := prometheus.NewRegistry()
	p := NewProber([]string{base + "/ok", base + "/broken", down}, reg, 2*time.Second, quiet())
	p.RunOnce(t.Context())

	check := func(g *prometheus.GaugeVec, target string, want float64) {
		t.Helper()
		if got := testutil.ToFloat64(g.WithLabelValues(target)); got != want {
			t.Errorf("%s = %v, want %v", target, got, want)
		}
	}
	check(p.success, base+"/ok", 1)
	check(p.status, base+"/ok", 200)
	check(p.success, base+"/broken", 0)
	check(p.status, base+"/broken", 500)
	check(p.success, down, 0)
	check(p.status, down, 0)
	if got := testutil.ToFloat64(p.runs); got != 1 {
		t.Errorf("runs = %v, want 1", got)
	}
}

// TestMetricsEndpoint checks what Prometheus sees when it scrapes the exporter.
func TestMetricsEndpoint(t *testing.T) {
	base := target(t)
	reg := prometheus.NewRegistry()
	NewProber([]string{base + "/ok"}, reg, 2*time.Second, quiet()).RunOnce(t.Context())

	exporter := httptest.NewServer(promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))
	defer exporter.Close()
	req, err := http.NewRequestWithContext(t.Context(), http.MethodGet, exporter.URL, nil)
	if err != nil {
		t.Fatal(err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	for _, want := range []string{
		`probe_success{target="` + base + `/ok"} 1`,
		"# TYPE probe_duration_seconds gauge",
		"probe_runs_total 1",
	} {
		if !strings.Contains(string(body), want) {
			t.Errorf("metrics missing %q:\n%s", want, body)
		}
	}
}

func TestRejectsNonHTTPTargets(t *testing.T) {
	var stderr strings.Builder
	if code := run(t.Context(), []string{"ftp://example.com"}, &stderr); code != 2 {
		t.Errorf("exit %d, want 2", code)
	}
}
