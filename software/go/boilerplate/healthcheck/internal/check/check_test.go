package check

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// newServer starts a local test server: /ok answers 200, /broken 500, /slow waits.
func newServer(t *testing.T) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/broken":
			w.WriteHeader(http.StatusInternalServerError)
		case "/slow":
			select {
			case <-time.After(time.Second):
			case <-r.Context().Done():
			}
		}
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestURL(t *testing.T) {
	srv := newServer(t)
	client := &http.Client{Timeout: 200 * time.Millisecond}

	// Table-driven tests: one row per case, run as named subtests.
	tests := []struct {
		name       string
		url        string
		expect     int
		wantOK     bool
		wantStatus int
		wantErr    bool
	}{
		{"healthy", srv.URL + "/ok", 200, true, 200, false},
		{"server error is unhealthy", srv.URL + "/broken", 200, false, 500, false},
		{"expected status can change", srv.URL + "/broken", 500, true, 500, false},
		{"timeout is a failure, not a panic", srv.URL + "/slow", 200, false, 0, true},
		{"connection refused", "http://127.0.0.1:1/", 200, false, 0, true},
		{"file scheme refused", "file:///etc/passwd", 200, false, 0, true},
		{"not a URL", "not-a-url", 200, false, 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := URL(context.Background(), client, tt.url, tt.expect)
			if got.OK != tt.wantOK || got.Status != tt.wantStatus || (got.Error != "") != tt.wantErr {
				t.Errorf("URL(%q) = %+v; want ok=%v status=%d err=%v", tt.url, got, tt.wantOK, tt.wantStatus, tt.wantErr)
			}
		})
	}
}

func TestAllKeepsOrder(t *testing.T) {
	srv := newServer(t)
	urls := []string{srv.URL + "/broken", srv.URL + "/ok", srv.URL + "/ok"}

	got := All(context.Background(), http.DefaultClient, urls, 200, 3)

	want := []bool{false, true, true}
	for i, r := range got {
		if r.URL != urls[i] || r.OK != want[i] {
			t.Errorf("result %d = %+v; want url %s ok=%v", i, r, urls[i], want[i])
		}
	}
}

func TestAllStopsWhenCancelled(t *testing.T) {
	srv := newServer(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // already cancelled: no request should succeed

	for _, r := range All(ctx, http.DefaultClient, []string{srv.URL + "/ok"}, 200, 1) {
		if r.OK {
			t.Errorf("got OK for a cancelled context: %+v", r)
		}
	}
}
