// Command probe-exporter is a Prometheus exporter that probes HTTP endpoints.
//
//	probe-exporter -port 9101 -interval 30s https://example.com/ https://example.org/healthz
//
// It probes each target on an interval and serves the results at /metrics:
//
//	probe_success{target="..."}            1 if the target answered with a 2xx or 3xx
//	probe_http_status_code{target="..."}   the last status code (0 if no answer)
//	probe_duration_seconds{target="..."}   how long the last probe took
//
// In production, the Prometheus Blackbox exporter does this and more; this is
// the pattern for writing an exporter of your own, for anything Prometheus
// can't see yet.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Prober holds the metrics and probes targets. It takes its own registry, so
// tests are isolated from each other.
type Prober struct {
	targets  []string
	client   *http.Client
	log      *slog.Logger
	success  *prometheus.GaugeVec
	status   *prometheus.GaugeVec
	duration *prometheus.GaugeVec
	runs     prometheus.Counter
}

// NewProber registers the probe metrics with reg.
func NewProber(targets []string, reg prometheus.Registerer, timeout time.Duration, log *slog.Logger) *Prober {
	p := &Prober{
		targets: targets,
		client:  &http.Client{Timeout: timeout},
		log:     log,
		success: prometheus.NewGaugeVec(prometheus.GaugeOpts{
			Name: "probe_success", Help: "Whether the last probe succeeded",
		}, []string{"target"}),
		status: prometheus.NewGaugeVec(prometheus.GaugeOpts{
			Name: "probe_http_status_code", Help: "HTTP status of the last probe",
		}, []string{"target"}),
		duration: prometheus.NewGaugeVec(prometheus.GaugeOpts{
			Name: "probe_duration_seconds", Help: "Duration of the last probe",
		}, []string{"target"}),
		runs: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "probe_runs_total", Help: "Probe rounds completed",
		}),
	}
	reg.MustRegister(p.success, p.status, p.duration, p.runs)
	return p
}

// Probe requests one target and records the result.
func (p *Prober) Probe(ctx context.Context, target string) {
	start := time.Now()
	code := 0
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err == nil {
		req.Header.Set("User-Agent", "probe-exporter/0.1")
		var resp *http.Response
		resp, err = p.client.Do(req)
		if err == nil {
			code = resp.StatusCode
			// Drain a little so the connection can be reused, then close.
			_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 64*1024))
			_ = resp.Body.Close()
		}
	}
	if err != nil {
		p.log.Warn("probe failed", "target", target, "err", err)
	}
	p.duration.WithLabelValues(target).Set(time.Since(start).Seconds())
	p.status.WithLabelValues(target).Set(float64(code))
	success := 0.0
	if code >= 200 && code < 400 {
		success = 1
	}
	p.success.WithLabelValues(target).Set(success)
}

// RunOnce probes every target once.
func (p *Prober) RunOnce(ctx context.Context) {
	for _, t := range p.targets {
		p.Probe(ctx, t)
	}
	p.runs.Inc()
}

func run(ctx context.Context, args []string, stderr io.Writer) int {
	fs := flag.NewFlagSet("probe-exporter", flag.ContinueOnError)
	fs.SetOutput(stderr)
	port := fs.Int("port", 9101, "port for /metrics")
	interval := fs.Duration("interval", 30*time.Second, "time between probe rounds")
	timeout := fs.Duration("timeout", 5*time.Second, "timeout per probe")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	targets := fs.Args()
	if len(targets) == 0 {
		fmt.Fprintln(stderr, "probe-exporter: give at least one http or https URL")
		return 2
	}
	for _, t := range targets {
		if !strings.HasPrefix(t, "http://") && !strings.HasPrefix(t, "https://") {
			fmt.Fprintln(stderr, "probe-exporter: targets must be http or https URLs:", t)
			return 2
		}
	}

	log := slog.New(slog.NewTextHandler(stderr, nil))
	reg := prometheus.NewRegistry()
	prober := NewProber(targets, reg, *timeout, log)

	mux := http.NewServeMux()
	mux.Handle("GET /metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))
	srv := &http.Server{
		Addr:              net.JoinHostPort("", strconv.Itoa(*port)),
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	serveErr := make(chan error, 1)
	go func() { serveErr <- srv.ListenAndServe() }()
	log.Info("serving /metrics", "port", *port, "targets", len(targets), "interval", interval.String())

	// Probe now, then on every tick, until a signal cancels ctx.
	ticker := time.NewTicker(*interval)
	defer ticker.Stop()
	for {
		prober.RunOnce(ctx)
		select {
		case <-ticker.C:
		case err := <-serveErr:
			log.Error("server failed", "err", err)
			return 1
		case <-ctx.Done():
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			if err := srv.Shutdown(shutdownCtx); err != nil && !errors.Is(err, http.ErrServerClosed) {
				log.Error("shutdown", "err", err)
			}
			log.Info("stopped")
			return 0
		}
	}
}

func main() {
	// Stop cleanly on SIGTERM (docker stop, Kubernetes) as well as Ctrl-C.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	code := run(ctx, os.Args[1:], os.Stderr)
	stop()
	os.Exit(code)
}
