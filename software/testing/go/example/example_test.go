package pricing_test

import (
	"fmt"
	"strings"
	"testing"

	"example.com/pricing"
)

// An Example function is documentation that's also a test: go test runs it
// and compares what it prints with the Output comment. It appears in go doc.
func ExampleSubtotal() {
	items := []pricing.Item{
		{SKU: "apple", UnitPriceCents: 50, Quantity: 3},
		{SKU: "pear", UnitPriceCents: 75, Quantity: 1},
	}
	fmt.Println(pricing.Subtotal(items))
	// Output: 225
}

// A benchmark measures speed: go test -bench=. -benchmem
// b.Loop (Go 1.24 and later) runs the body as many times as needed for a stable result.
func BenchmarkSubtotal(b *testing.B) {
	items := make([]pricing.Item, 1000)
	for i := range items {
		items[i] = pricing.Item{SKU: "sku", UnitPriceCents: i, Quantity: 2}
	}
	for b.Loop() {
		pricing.Subtotal(items)
	}
}

// A fuzz test feeds generated input to find crashes: go test -fuzz=FuzzLoadItems -fuzztime=30s
// Without -fuzz, it runs only the seed inputs below, as a normal test.
func FuzzLoadItems(f *testing.F) {
	f.Add("sku,unit_price_cents,quantity\napple,50,3\n")
	f.Add("sku,unit_price_cents,quantity\n")
	f.Add("")
	f.Fuzz(func(t *testing.T, input string) {
		items, err := pricing.LoadItems(strings.NewReader(input))
		if err != nil {
			return // rejecting bad input is fine; panicking isn't
		}
		for _, it := range items {
			if it.Validate() != nil {
				t.Errorf("LoadItems returned an invalid item: %+v", it)
			}
		}
	})
}
