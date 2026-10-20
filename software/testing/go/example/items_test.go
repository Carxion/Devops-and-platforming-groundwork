// Tests live next to the code, in files ending _test.go. This file uses the
// package name pricing_test (an "external" test package), so it can only use
// what's exported: it tests the package the way callers see it.
package pricing_test

import (
	"errors"
	"testing"

	"example.com/pricing"
)

func TestLineTotalIsPriceTimesQuantity(t *testing.T) {
	// Arrange, act, assert.
	item := pricing.Item{SKU: "apple", UnitPriceCents: 50, Quantity: 3}

	got := item.TotalCents()

	if got != 150 {
		t.Errorf("TotalCents() = %d, want 150", got) // Errorf: report and keep going
	}
}

func TestSubtotal(t *testing.T) {
	// A table-driven test: each row is a case, run as a named subtest.
	tests := []struct {
		name  string
		items []pricing.Item
		want  int
	}{
		{"empty cart", nil, 0},
		{"one line", []pricing.Item{{SKU: "pear", UnitPriceCents: 75, Quantity: 1}}, 75},
		{"several lines", []pricing.Item{
			{SKU: "apple", UnitPriceCents: 50, Quantity: 3},
			{SKU: "pear", UnitPriceCents: 75, Quantity: 1},
		}, 225},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := pricing.Subtotal(tt.items); got != tt.want {
				t.Errorf("Subtotal() = %d, want %d", got, tt.want)
			}
		})
	}
}

func TestInvalidItemsAreRejected(t *testing.T) {
	tests := []struct {
		name string
		item pricing.Item
	}{
		{"empty sku", pricing.Item{SKU: "", UnitPriceCents: 100, Quantity: 1}},
		{"negative price", pricing.Item{SKU: "apple", UnitPriceCents: -1, Quantity: 1}},
		{"zero quantity", pricing.Item{SKU: "apple", UnitPriceCents: 100, Quantity: 0}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel() // independent cases can run at the same time
			err := tt.item.Validate()
			// Check the kind of error with errors.Is, not by comparing message text.
			if !errors.Is(err, pricing.ErrInvalid) {
				t.Errorf("Validate() = %v, want an error wrapping ErrInvalid", err)
			}
		})
	}
}

func TestValidItemPasses(t *testing.T) {
	if err := (pricing.Item{SKU: "apple", UnitPriceCents: 0, Quantity: 1}).Validate(); err != nil {
		t.Fatalf("Validate() = %v, want nil (free items are allowed)", err) // Fatalf: stop this test
	}
}
