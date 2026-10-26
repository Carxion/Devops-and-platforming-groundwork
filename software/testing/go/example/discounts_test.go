package pricing_test

import (
	"errors"
	"strings"
	"testing"
	"time"

	"example.com/pricing"
)

// now is one fixed moment for every test, so results never depend on when tests run.
var now = time.Date(2026, 10, 20, 12, 0, 0, 0, time.UTC)

// fixedClock returns a Clock that always reports t: the Go version of injecting the time.
func fixedClock(t time.Time) pricing.Clock { return func() time.Time { return t } }

// testCodes builds fresh test data. A helper that takes *testing.T calls
// t.Helper(), so failures point at the test that called it, not at the helper.
func testCodes(t *testing.T) map[string]pricing.Discount {
	t.Helper()
	return map[string]pricing.Discount{
		"SAVE10": {Percent: 10, Expires: time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC)},
		"OLD20":  {Percent: 20, Expires: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)},
	}
}

func TestApplyDiscount(t *testing.T) {
	codes := testCodes(t)
	tests := []struct {
		name    string
		amount  int
		code    string
		want    int
		wantErr string // empty means no error expected
	}{
		{"valid code", 1000, "SAVE10", 900, ""},
		{"case-insensitive", 1000, "save10", 900, ""},
		{"rounds down to whole cents", 999, "SAVE10", 899, ""},
		{"expired code", 1000, "OLD20", 0, "expired on 2026-01-01"},
		{"unknown code", 1000, "NOPE", 0, "unknown discount code: NOPE"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := pricing.ApplyDiscount(tt.amount, tt.code, codes, fixedClock(now))
			if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("err = %v, want one containing %q", err, tt.wantErr)
				}
				if !errors.Is(err, pricing.ErrInvalid) {
					t.Errorf("err = %v, want it to wrap ErrInvalid", err)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Errorf("ApplyDiscount() = %d, want %d", got, tt.want)
			}
		})
	}
}

func TestCodeExpiresAtExactlyItsExpiryTime(t *testing.T) {
	// Boundaries are where bugs live: test the moment before and the moment of.
	codes := testCodes(t)
	expiry := codes["SAVE10"].Expires
	if _, err := pricing.ApplyDiscount(1000, "SAVE10", codes, fixedClock(expiry.Add(-time.Second))); err != nil {
		t.Errorf("one second before expiry: %v, want no error", err)
	}
	if _, err := pricing.ApplyDiscount(1000, "SAVE10", codes, fixedClock(expiry)); err == nil {
		t.Error("at the expiry time: no error, want expired")
	}
}
