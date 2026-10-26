package pricing_test

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/pricing"
)

// fakeRates is a fake: a working, in-memory TaxRates. Go interfaces are
// satisfied implicitly, so any type with a Rate method works; no mocking
// library needed. It also records calls, so tests can check them.
type fakeRates struct {
	rates map[string]float64
	err   error
	calls []string
}

func (f *fakeRates) Rate(_ context.Context, region string) (float64, error) {
	f.calls = append(f.calls, region)
	if f.err != nil {
		return 0, f.err
	}
	return f.rates[region], nil
}

func TestTotalAddsTaxForTheRegion(t *testing.T) {
	rates := &fakeRates{rates: map[string]float64{"CA": 0.0725}}
	order := pricing.Order{Items: []pricing.Item{{SKU: "apple", UnitPriceCents: 1000, Quantity: 1}}, Region: "CA"}

	got, err := pricing.Total(t.Context(), order, rates, nil, fixedClock(now))

	if err != nil {
		t.Fatal(err)
	}
	if got != 1073 { // 1000 + 72.5 tax, rounded half up
		t.Errorf("Total() = %d, want 1073", got)
	}
	if len(rates.calls) != 1 || rates.calls[0] != "CA" {
		t.Errorf("tax service calls = %v, want [CA]", rates.calls)
	}
}

func TestTaxAppliesAfterTheDiscount(t *testing.T) {
	rates := &fakeRates{rates: map[string]float64{"CA": 0.0725}}
	order := pricing.Order{Items: []pricing.Item{{SKU: "apple", UnitPriceCents: 1000, Quantity: 1}}, Region: "CA", Code: "SAVE10"}
	got, err := pricing.Total(t.Context(), order, rates, testCodes(t), fixedClock(now))
	if err != nil || got != 965 { // 900 + 65.25 tax
		t.Errorf("Total() = %d, %v; want 965, nil", got, err)
	}
}

func TestEmptyCartIsRefusedBeforeCallingTheService(t *testing.T) {
	rates := &fakeRates{}
	_, err := pricing.Total(t.Context(), pricing.Order{Region: "CA"}, rates, nil, fixedClock(now))
	if !errors.Is(err, pricing.ErrInvalid) {
		t.Errorf("err = %v, want ErrInvalid", err)
	}
	if len(rates.calls) != 0 {
		t.Errorf("tax service was called %d times, want 0", len(rates.calls))
	}
}

func TestTaxServiceFailurePropagates(t *testing.T) {
	timeout := errors.New("tax service timed out")
	rates := &fakeRates{err: timeout}
	order := pricing.Order{Items: []pricing.Item{{SKU: "apple", UnitPriceCents: 500, Quantity: 1}}, Region: "OR"}
	if _, err := pricing.Total(t.Context(), order, rates, nil, fixedClock(now)); !errors.Is(err, timeout) {
		t.Errorf("err = %v, want the service's error", err)
	}
}

// The fake proves Total works; these prove HTTPTaxRates really speaks HTTP.
// httptest.NewServer starts a real server on a free local port, closed by t.Cleanup.
func taxServer(t *testing.T) string {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/rates/CA":
			fmt.Fprint(w, `{"rate": 0.0725}`)
		case "/rates/XX":
			fmt.Fprint(w, `{"rate": 7.25}`)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	return srv.URL
}

func TestHTTPClient(t *testing.T) {
	base := taxServer(t)
	client := pricing.HTTPTaxRates{BaseURL: base, Client: http.DefaultClient}

	t.Run("reads the rate", func(t *testing.T) {
		got, err := client.Rate(t.Context(), "CA")
		if err != nil || got != 0.0725 {
			t.Errorf("Rate(CA) = %v, %v; want 0.0725, nil", got, err)
		}
	})
	t.Run("rejects an implausible rate", func(t *testing.T) {
		if _, err := client.Rate(t.Context(), "XX"); !errors.Is(err, pricing.ErrInvalid) {
			t.Errorf("err = %v, want ErrInvalid", err)
		}
	})
	t.Run("reports a missing region", func(t *testing.T) {
		if _, err := client.Rate(t.Context(), "ZZ"); err == nil {
			t.Error("Rate(ZZ): no error, want status 404")
		}
	})
	t.Run("requires an http URL", func(t *testing.T) {
		bad := pricing.HTTPTaxRates{BaseURL: "file:///etc/passwd", Client: http.DefaultClient}
		if _, err := bad.Rate(t.Context(), "CA"); !errors.Is(err, pricing.ErrInvalid) {
			t.Errorf("err = %v, want ErrInvalid", err)
		}
	})
}
