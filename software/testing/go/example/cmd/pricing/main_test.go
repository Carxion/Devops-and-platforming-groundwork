package main

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type flatRate float64

func (r flatRate) Rate(context.Context, string) (float64, error) { return float64(r), nil }

func TestRun(t *testing.T) {
	cart := filepath.Join(t.TempDir(), "cart.csv")
	if err := os.WriteFile(cart, []byte("sku,unit_price_cents,quantity\napple,1000,1\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	tests := []struct {
		name       string
		args       []string
		wantCode   int
		wantStdout string
		wantStderr string
	}{
		{"prints the total", []string{cart, "CA"}, 0, "10.73\n", ""},
		{"wrong arguments", []string{"only-one"}, 2, "", "usage: pricing"},
		{"missing file", []string{filepath.Join(t.TempDir(), "nope.csv"), "CA"}, 1, "", "pricing: "},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer // capture output instead of printing it
			code := run(context.Background(), tt.args, &stdout, &stderr, flatRate(0.0725))
			if code != tt.wantCode {
				t.Errorf("exit code = %d, want %d", code, tt.wantCode)
			}
			if stdout.String() != tt.wantStdout {
				t.Errorf("stdout = %q, want %q", stdout.String(), tt.wantStdout)
			}
			if !strings.Contains(stderr.String(), tt.wantStderr) {
				t.Errorf("stderr = %q, want it to contain %q", stderr.String(), tt.wantStderr)
			}
		})
	}
}
