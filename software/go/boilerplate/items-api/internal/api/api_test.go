package api

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// do sends one request to a fresh handler (or the given one) and returns the recorder.
func do(t *testing.T, h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequestWithContext(t.Context(), method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func newHandler() http.Handler {
	return New(NewMemoryStore(), slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func decode(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var v map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &v); err != nil {
		t.Fatalf("body isn't a JSON object: %v: %q", err, rec.Body.String())
	}
	return v
}

func TestItemLifecycle(t *testing.T) {
	h := newHandler()

	if rec := do(t, h, "PUT", "/items/order-1", `{"status":"pending","quantity":3}`); rec.Code != 200 {
		t.Fatalf("PUT = %d", rec.Code)
	}
	rec := do(t, h, "GET", "/items/order-1", "")
	got := decode(t, rec)
	if rec.Code != 200 || got["id"] != "order-1" || got["status"] != "pending" || got["quantity"] != 3.0 {
		t.Fatalf("GET = %d %v", rec.Code, got)
	}

	// PUT replaces the whole item, it doesn't merge.
	do(t, h, "PUT", "/items/order-1", `{"status":"shipped"}`)
	if got := decode(t, do(t, h, "GET", "/items/order-1", "")); got["quantity"] != nil {
		t.Errorf("PUT merged instead of replacing: %v", got)
	}

	// DELETE is idempotent.
	for range 2 {
		if rec := do(t, h, "DELETE", "/items/order-1", ""); rec.Code != 204 {
			t.Fatalf("DELETE = %d", rec.Code)
		}
	}
	rec = do(t, h, "GET", "/items/order-1", "")
	if rec.Code != 404 || decode(t, rec)["error"] != "not found" {
		t.Errorf("GET after DELETE = %d %s", rec.Code, rec.Body.String())
	}
}

func TestIDInBodyIsIgnored(t *testing.T) {
	h := newHandler()
	do(t, h, "PUT", "/items/a", `{"id":"other","x":1}`)
	if got := decode(t, do(t, h, "GET", "/items/a", "")); got["id"] != "a" {
		t.Errorf("id = %v; want a", got["id"])
	}
}

func TestRejectsBadInput(t *testing.T) {
	big := `{"x":"` + strings.Repeat("a", MaxBodyBytes) + `"}`
	tests := []struct {
		name   string
		method string
		path   string
		body   string
		want   int
	}{
		{"array body", "PUT", "/items/a", `[1,2]`, 400},
		{"string body", "PUT", "/items/a", `"text"`, 400},
		{"not JSON", "PUT", "/items/a", `not json`, 400},
		{"empty body", "PUT", "/items/a", ``, 400},
		{"too large", "PUT", "/items/a", big, 413},
		{"invalid id (space)", "GET", "/items/has%20space", "", 400},
		{"invalid id (too long)", "GET", "/items/" + strings.Repeat("a", 129), "", 400},
		{"unsupported method", "POST", "/items/a", `{}`, 405},
		{"unknown path", "GET", "/nope", "", 404},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := do(t, newHandler(), tt.method, tt.path, tt.body)
			if rec.Code != tt.want {
				t.Fatalf("%s %s = %d; want %d", tt.method, tt.path, rec.Code, tt.want)
			}
			if _, ok := decode(t, rec)["error"]; !ok {
				t.Errorf("error response has no error field: %s", rec.Body.String())
			}
		})
	}
}

func TestMethodNotAllowedListsMethods(t *testing.T) {
	rec := do(t, newHandler(), "OPTIONS", "/items/a", "")
	if got := rec.Header().Get("Allow"); got != "DELETE, GET, PUT" {
		t.Errorf("Allow = %q", got)
	}
}

func TestHealthz(t *testing.T) {
	if rec := do(t, newHandler(), "GET", "/healthz", ""); rec.Code != 200 {
		t.Errorf("healthz = %d", rec.Code)
	}
}
