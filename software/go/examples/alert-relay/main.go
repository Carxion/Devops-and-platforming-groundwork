// Command alert-relay forwards Alertmanager webhooks to a chat channel.
//
//	RELAY_TOKEN=... CHAT_WEBHOOK_URL=https://hooks.example.com/... alert-relay -port 9102
//
// Alertmanager posts alert groups to POST /alertmanager. The relay checks a
// shared bearer token, formats a readable message, and posts {"text": "..."}
// to an incoming-webhook URL (the format Slack-compatible webhooks accept),
// retrying with backoff. Standard library only.
package main

import (
	"bytes"
	"context"
	"crypto/subtle"
	"encoding/json"
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
)

const maxBody = 1 << 20 // 1 MiB

// Payload is the part of Alertmanager's webhook body the relay uses.
type Payload struct {
	Status       string            `json:"status"`
	CommonLabels map[string]string `json:"commonLabels"`
	Alerts       []Alert           `json:"alerts"`
}

// Alert is one alert in a group.
type Alert struct {
	Status      string            `json:"status"`
	Labels      map[string]string `json:"labels"`
	Annotations map[string]string `json:"annotations"`
}

// FormatMessage renders one message per group: a header line, then one line per alert.
func FormatMessage(p Payload) string {
	status := strings.ToUpper(p.Status)
	if status == "" {
		status = "UNKNOWN"
	}
	name := p.CommonLabels["alertname"]
	if name == "" {
		name = "alert"
	}
	var b strings.Builder
	fmt.Fprintf(&b, "[%s:%d] %s", status, len(p.Alerts), name)
	if sev := p.CommonLabels["severity"]; sev != "" {
		fmt.Fprintf(&b, " (severity=%s)", sev)
	}
	for _, a := range p.Alerts {
		summary := a.Annotations["summary"]
		if summary == "" {
			summary = a.Annotations["description"]
		}
		fmt.Fprintf(&b, "\n- %s", summary)
		instance := a.Labels["instance"]
		if instance == "" {
			instance = a.Labels["job"]
		}
		if instance != "" {
			fmt.Fprintf(&b, " [%s]", instance)
		}
		if rb := a.Annotations["runbook_url"]; rb != "" {
			fmt.Fprintf(&b, "\n  runbook: %s", rb)
		}
	}
	return b.String()
}

// Relay receives alerts and forwards them.
type Relay struct {
	Token    string
	ChatURL  string
	Client   *http.Client
	Attempts int
	Sleep    func(time.Duration) // time.Sleep; replaced in tests
	Log      *slog.Logger
}

// errPermanent marks a failure that retrying won't fix.
var errPermanent = errors.New("rejected")

func (r *Relay) postOnce(ctx context.Context, body []byte) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, r.ChatURL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("%w: %w", errPermanent, err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := r.Client.Do(req)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 64*1024))
	switch {
	case resp.StatusCode < 300:
		return nil
	case resp.StatusCode < 500:
		return fmt.Errorf("%w: status %d", errPermanent, resp.StatusCode)
	default:
		return fmt.Errorf("status %d", resp.StatusCode)
	}
}

// Forward posts the text to the chat webhook, retrying network errors and 5xx
// with exponential backoff.
func (r *Relay) Forward(ctx context.Context, text string) error {
	body, err := json.Marshal(map[string]string{"text": text})
	if err != nil {
		return err
	}
	for attempt := 1; ; attempt++ {
		err = r.postOnce(ctx, body)
		if err == nil || errors.Is(err, errPermanent) || attempt >= r.Attempts {
			return err
		}
		r.Log.Warn("chat webhook failed, retrying", "attempt", attempt, "err", err)
		r.Sleep(time.Duration(500<<(attempt-1)) * time.Millisecond)
	}
}

func reply(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": message})
}

// Handler returns the relay's routes.
func (r *Relay) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		reply(w, http.StatusOK, "ok")
	})
	mux.HandleFunc("POST /alertmanager", func(w http.ResponseWriter, req *http.Request) {
		// Constant-time comparison, so the token can't be guessed byte by byte from timing.
		supplied := strings.TrimPrefix(req.Header.Get("Authorization"), "Bearer ")
		if subtle.ConstantTimeCompare([]byte(supplied), []byte(r.Token)) != 1 {
			reply(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		var p Payload
		if err := json.NewDecoder(http.MaxBytesReader(w, req.Body, maxBody)).Decode(&p); err != nil {
			if _, ok := errors.AsType[*http.MaxBytesError](err); ok {
				reply(w, http.StatusRequestEntityTooLarge, "too large")
				return
			}
			reply(w, http.StatusBadRequest, "invalid payload")
			return
		}
		if p.Alerts == nil {
			reply(w, http.StatusBadRequest, "invalid payload")
			return
		}
		if err := r.Forward(req.Context(), FormatMessage(p)); err != nil {
			r.Log.Error("chat webhook failed", "err", err)
			// 5xx makes Alertmanager retry the notification later.
			reply(w, http.StatusBadGateway, "chat webhook failed")
			return
		}
		reply(w, http.StatusOK, "forwarded")
	})
	return mux
}

func run(ctx context.Context, args []string, getenv func(string) string, stderr io.Writer) int {
	fs := flag.NewFlagSet("alert-relay", flag.ContinueOnError)
	fs.SetOutput(stderr)
	host := fs.String("host", "", "address to listen on (default all interfaces)")
	port := fs.Int("port", 9102, "port to listen on")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	// Secrets and endpoints from the environment, never from arguments (visible in ps).
	token, chatURL := getenv("RELAY_TOKEN"), getenv("CHAT_WEBHOOK_URL")
	if len(token) < 16 {
		fmt.Fprintln(stderr, "alert-relay: set RELAY_TOKEN to a shared secret of at least 16 characters")
		return 2
	}
	if !strings.HasPrefix(chatURL, "https://") && !strings.HasPrefix(chatURL, "http://") {
		fmt.Fprintln(stderr, "alert-relay: set CHAT_WEBHOOK_URL to the chat incoming-webhook URL")
		return 2
	}

	log := slog.New(slog.NewTextHandler(stderr, nil))
	relay := &Relay{
		Token: token, ChatURL: chatURL, Attempts: 3, Sleep: time.Sleep, Log: log,
		Client: &http.Client{Timeout: 5 * time.Second},
	}
	srv := &http.Server{
		Addr:              net.JoinHostPort(*host, strconv.Itoa(*port)),
		Handler:           relay.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
	}
	serveErr := make(chan error, 1)
	go func() { serveErr <- srv.ListenAndServe() }()
	log.Info("listening", "addr", srv.Addr)

	select {
	case err := <-serveErr:
		log.Error("server failed", "err", err)
		return 1
	case <-ctx.Done():
	}
	// Finish in-flight requests, then exit.
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("shutdown", "err", err)
		return 1
	}
	log.Info("stopped")
	return 0
}

func main() {
	// Stop cleanly on SIGTERM (docker stop, Kubernetes) as well as Ctrl-C.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	code := run(ctx, os.Args[1:], os.Getenv, os.Stderr)
	stop()
	os.Exit(code)
}
