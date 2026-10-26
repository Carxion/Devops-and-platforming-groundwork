package main

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

const token = "test-token-0123456789"

const alert = `{
  "version": "4", "status": "firing", "receiver": "on-call",
  "commonLabels": {"alertname": "HighErrorRate", "severity": "page"},
  "alerts": [
    {"status": "firing", "labels": {"alertname": "HighErrorRate", "instance": "api-1:8080"},
     "annotations": {"summary": "5xx ratio above 5% for 10 minutes",
                     "runbook_url": "https://runbooks.example.com/high-error-rate"}},
    {"status": "firing", "labels": {"alertname": "HighErrorRate", "job": "api"},
     "annotations": {"description": "second replica"}}
  ]
}`

// fakeChat records messages and can fail the next N requests with 503.
type fakeChat struct {
	mu       sync.Mutex
	received []string
	failNext int
}

func (f *fakeChat) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.failNext > 0 {
		f.failNext--
		w.WriteHeader(http.StatusServiceUnavailable)
		return
	}
	var body map[string]string
	_ = json.NewDecoder(r.Body).Decode(&body)
	f.received = append(f.received, body["text"])
}

func setup(t *testing.T) (*fakeChat, *httptest.Server) {
	t.Helper()
	chat := &fakeChat{}
	chatSrv := httptest.NewServer(chat)
	t.Cleanup(chatSrv.Close)
	relay := &Relay{
		Token: token, ChatURL: chatSrv.URL, Attempts: 3,
		Client: chatSrv.Client(), Sleep: func(time.Duration) {}, // no real backoff in tests
		Log: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
	relaySrv := httptest.NewServer(relay.Handler())
	t.Cleanup(relaySrv.Close)
	return chat, relaySrv
}

func post(t *testing.T, url, body, auth string) int {
	t.Helper()
	req, err := http.NewRequestWithContext(t.Context(), http.MethodPost, url, strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	if auth != "" {
		req.Header.Set("Authorization", "Bearer "+auth)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	return resp.StatusCode
}

func TestFormatMessage(t *testing.T) {
	var p Payload
	if err := json.Unmarshal([]byte(alert), &p); err != nil {
		t.Fatal(err)
	}
	text := FormatMessage(p)
	for _, want := range []string{
		"[FIRING:2] HighErrorRate (severity=page)\n",
		"- 5xx ratio above 5% for 10 minutes [api-1:8080]",
		"runbook: https://runbooks.example.com/high-error-rate",
		"- second replica [api]",
	} {
		if !strings.Contains(text, want) {
			t.Errorf("message missing %q:\n%s", want, text)
		}
	}
}

func TestForwardsAlert(t *testing.T) {
	chat, relay := setup(t)
	if code := post(t, relay.URL+"/alertmanager", alert, token); code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	if len(chat.received) != 1 || !strings.HasPrefix(chat.received[0], "[FIRING:2] HighErrorRate") {
		t.Errorf("chat received %q", chat.received)
	}
}

func TestRetriesThenSucceeds(t *testing.T) {
	chat, relay := setup(t)
	chat.failNext = 2
	if code := post(t, relay.URL+"/alertmanager", alert, token); code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	if len(chat.received) != 1 {
		t.Errorf("chat received %d messages", len(chat.received))
	}
}

func TestGivesUpWith502(t *testing.T) {
	chat, relay := setup(t)
	chat.failNext = 3
	if code := post(t, relay.URL+"/alertmanager", alert, token); code != http.StatusBadGateway {
		t.Fatalf("status %d, want 502", code)
	}
}

func TestRejectsBadToken(t *testing.T) {
	chat, relay := setup(t)
	for _, auth := range []string{"", "wrong-token-0123456789"} {
		if code := post(t, relay.URL+"/alertmanager", alert, auth); code != http.StatusUnauthorized {
			t.Errorf("token %q: status %d, want 401", auth, code)
		}
	}
	if len(chat.received) != 0 {
		t.Error("an unauthorized alert reached chat")
	}
}

func TestRejectsBadPayload(t *testing.T) {
	_, relay := setup(t)
	for _, body := range []string{"not json", "[]", `{"alerts": "nope"}`, `{}`} {
		if code := post(t, relay.URL+"/alertmanager", body, token); code != http.StatusBadRequest {
			t.Errorf("body %q: status %d, want 400", body, code)
		}
	}
	big := `{"alerts": [], "status": "` + strings.Repeat("x", maxBody) + `"}`
	if code := post(t, relay.URL+"/alertmanager", big, token); code != http.StatusRequestEntityTooLarge {
		t.Errorf("oversized body: status %d, want 413", code)
	}
}

func TestRoutes(t *testing.T) {
	_, relay := setup(t)
	if code := post(t, relay.URL+"/other", "{}", token); code != http.StatusNotFound {
		t.Errorf("unknown path: status %d, want 404", code)
	}
	req, _ := http.NewRequestWithContext(t.Context(), http.MethodGet, relay.URL+"/healthz", nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("healthz: status %d", resp.StatusCode)
	}
}

func TestRequiresConfig(t *testing.T) {
	env := map[string]string{"RELAY_TOKEN": "short", "CHAT_WEBHOOK_URL": "https://hooks.example.com/x"}
	var stderr strings.Builder
	if code := run(t.Context(), nil, func(k string) string { return env[k] }, &stderr); code != 2 {
		t.Errorf("exit %d, want 2 with a short token", code)
	}
}
