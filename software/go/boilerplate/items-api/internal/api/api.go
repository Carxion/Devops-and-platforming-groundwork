// Package api is the HTTP layer of the Items API. The contract is
// software/api-testing/openapi/items-api.yaml; the api-testing suite checks
// this implementation against it in CI.
package api

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"regexp"
	"time"
)

// MaxBodyBytes is the largest request body accepted (256 KiB).
const MaxBodyBytes = 256 * 1024

var validID = regexp.MustCompile(`^[A-Za-z0-9._-]{1,128}$`)

// Handler serves the Items API.
type Handler struct {
	store  Store
	logger *slog.Logger
}

// New returns the API as an http.Handler, with request logging.
func New(store Store, logger *slog.Logger) http.Handler {
	h := &Handler{store: store, logger: logger}
	mux := http.NewServeMux()
	// Go 1.22+ patterns: method and path variables in the pattern itself.
	mux.HandleFunc("GET /items/{id}", h.getItem)
	mux.HandleFunc("PUT /items/{id}", h.putItem)
	mux.HandleFunc("DELETE /items/{id}", h.deleteItem)
	// Any other method on an item: a JSON 405 listing what is allowed. More
	// specific patterns (with a method) win over this one.
	mux.HandleFunc("/items/{id}", methodNotAllowed("DELETE, GET, PUT"))
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		writeError(w, http.StatusNotFound, "not found")
	})
	return h.logRequests(mux)
}

func (h *Handler) getItem(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	item, found := h.store.Get(id)
	if !found {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	item["id"] = id
	writeJSON(w, http.StatusOK, item)
}

func (h *Handler) putItem(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	// MaxBytesReader stops reading past the limit, so a huge body can't
	// exhaust memory.
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, MaxBodyBytes))
	if err != nil {
		if maxErr := (*http.MaxBytesError)(nil); errors.As(err, &maxErr) {
			writeError(w, http.StatusRequestEntityTooLarge, "body too large")
			return
		}
		writeError(w, http.StatusBadRequest, "could not read body")
		return
	}
	var data any
	if err := json.Unmarshal(body, &data); err != nil { // an empty body is invalid JSON
		writeError(w, http.StatusBadRequest, "body must be JSON")
		return
	}
	item, isObject := data.(map[string]any)
	if !isObject {
		writeError(w, http.StatusBadRequest, "body must be a JSON object")
		return
	}
	delete(item, "id") // the path is the ID
	h.store.Put(id, item)
	writeJSON(w, http.StatusOK, map[string]string{"id": id})
}

func (h *Handler) deleteItem(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	h.store.Delete(id)
	w.WriteHeader(http.StatusNoContent)
}

// pathID returns the {id} path value, or writes a 400 and returns false.
func pathID(w http.ResponseWriter, r *http.Request) (string, bool) {
	id := r.PathValue("id")
	if !validID.MatchString(id) {
		writeError(w, http.StatusBadRequest, "invalid id")
		return "", false
	}
	return id, true
}

func methodNotAllowed(allow string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Allow", allow)
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	// The status is already sent, so an encoding error can only be logged by
	// the caller's middleware; there's nothing more to tell the client.
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

// statusRecorder captures the status code for the request log.
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// logRequests logs one structured line per request.
func (h *Handler) logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		h.logger.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}
