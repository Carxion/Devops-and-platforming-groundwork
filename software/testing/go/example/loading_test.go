package pricing_test

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"example.com/pricing"
)

func TestLoadItemsFromTestdata(t *testing.T) {
	// testdata/ is ignored by the go tool, and tests run with the package
	// directory as the working directory, so a relative path works.
	f, err := os.Open(filepath.Join("testdata", "cart.csv"))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = f.Close() }()

	got, err := pricing.LoadItems(f)
	if err != nil {
		t.Fatal(err)
	}
	want := []pricing.Item{{SKU: "apple", UnitPriceCents: 50, Quantity: 3}, {SKU: "pear", UnitPriceCents: 75, Quantity: 1}}
	if !reflect.DeepEqual(got, want) { // compare slices and structs field by field
		t.Errorf("LoadItems() = %+v, want %+v", got, want)
	}
}

func TestLoadItemsErrors(t *testing.T) {
	tests := []struct {
		name, csv, wantMsg string
	}{
		{"bad number", "sku,unit_price_cents,quantity\napple,50,3\npear,lots,1\n", "line 3"},
		{"wrong header", "sku,quantity\napple,3\n", "header"},
		{"invalid item", "sku,unit_price_cents,quantity\napple,50,0\n", "line 2"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := pricing.LoadItems(strings.NewReader(tt.csv)) // a string as an io.Reader: no file needed
			if !errors.Is(err, pricing.ErrInvalid) || !strings.Contains(err.Error(), tt.wantMsg) {
				t.Errorf("err = %v, want ErrInvalid mentioning %q", err, tt.wantMsg)
			}
		})
	}
}

func TestLoadItemsFromATempFile(t *testing.T) {
	// t.TempDir() is a fresh directory, deleted when the test ends.
	path := filepath.Join(t.TempDir(), "cart.csv")
	if err := os.WriteFile(path, []byte("sku,unit_price_cents,quantity\nkiwi,20,5\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	data, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = data.Close() }()
	items, err := pricing.LoadItems(data)
	if err != nil || len(items) != 1 || items[0].TotalCents() != 100 {
		t.Errorf("LoadItems() = %+v, %v", items, err)
	}
}
