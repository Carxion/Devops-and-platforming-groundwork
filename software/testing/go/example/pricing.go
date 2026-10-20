// Package pricing prices a shopping cart: line items, expiring discount codes,
// and tax.
//
// It's written to be tested: everything that varies from run to run (the
// current time, the tax service, files) comes in as an argument or an
// interface, so tests can supply their own.
package pricing

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// ErrInvalid is wrapped by every error caused by bad input, so callers can
// check for it with errors.Is.
var ErrInvalid = errors.New("invalid")

// Item is one line in a cart. Prices are in whole cents.
type Item struct {
	SKU            string
	UnitPriceCents int
	Quantity       int
}

// Validate reports whether the item makes sense.
func (i Item) Validate() error {
	switch {
	case i.SKU == "":
		return fmt.Errorf("%w: sku must not be empty", ErrInvalid)
	case i.UnitPriceCents < 0:
		return fmt.Errorf("%w: %s: price must not be negative", ErrInvalid, i.SKU)
	case i.Quantity < 1:
		return fmt.Errorf("%w: %s: quantity must be at least 1", ErrInvalid, i.SKU)
	}
	return nil
}

// TotalCents is the price of the whole line.
func (i Item) TotalCents() int { return i.UnitPriceCents * i.Quantity }

// Subtotal is the sum of every line, in cents.
func Subtotal(items []Item) int {
	sum := 0
	for _, it := range items {
		sum += it.TotalCents()
	}
	return sum
}

// Discount is a percentage off, valid until Expires.
type Discount struct {
	Percent int
	Expires time.Time
}

// Clock returns the current time. Tests pass a fixed one.
type Clock func() time.Time

// ApplyDiscount returns the amount after the discount, rounded down to whole cents.
func ApplyDiscount(amountCents int, code string, codes map[string]Discount, now Clock) (int, error) {
	d, ok := codes[strings.ToUpper(code)]
	if !ok {
		return 0, fmt.Errorf("%w: unknown discount code: %s", ErrInvalid, code)
	}
	if !now().Before(d.Expires) {
		return 0, fmt.Errorf("%w: discount code %s expired on %s", ErrInvalid, code, d.Expires.Format("2006-01-02"))
	}
	return amountCents * (100 - d.Percent) / 100, nil
}

// TaxRates returns the tax rate for a region: the HTTP client, or a fake in tests.
type TaxRates interface {
	Rate(ctx context.Context, region string) (float64, error)
}

// HTTPTaxRates fetches rates from GET {BaseURL}/rates/{region} -> {"rate": 0.08}.
type HTTPTaxRates struct {
	BaseURL string
	Client  *http.Client
}

// Rate asks the service for a region's rate.
func (h HTTPTaxRates) Rate(ctx context.Context, region string) (float64, error) {
	if !strings.HasPrefix(h.BaseURL, "http://") && !strings.HasPrefix(h.BaseURL, "https://") {
		return 0, fmt.Errorf("%w: base URL must be an http or https URL", ErrInvalid)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(h.BaseURL, "/")+"/rates/"+region, nil)
	if err != nil {
		return 0, err
	}
	resp, err := h.Client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("tax service: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("tax service: %s: status %d", region, resp.StatusCode)
	}
	var body struct {
		Rate float64 `json:"rate"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return 0, fmt.Errorf("tax service: %w", err)
	}
	if body.Rate < 0 || body.Rate >= 1 {
		return 0, fmt.Errorf("%w: implausible tax rate for %s: %v", ErrInvalid, region, body.Rate)
	}
	return body.Rate, nil
}

// Order is everything Total needs.
type Order struct {
	Items  []Item
	Region string
	Code   string // optional discount code
}

// Total is the subtotal, minus any discount, plus tax, in cents (tax rounded half up).
func Total(ctx context.Context, o Order, rates TaxRates, codes map[string]Discount, now Clock) (int, error) {
	if len(o.Items) == 0 {
		return 0, fmt.Errorf("%w: cart is empty", ErrInvalid)
	}
	amount := Subtotal(o.Items)
	if o.Code != "" {
		var err error
		if amount, err = ApplyDiscount(amount, o.Code, codes, now); err != nil {
			return 0, err
		}
	}
	rate, err := rates.Rate(ctx, o.Region)
	if err != nil {
		return 0, err
	}
	return amount + int(math.Floor(float64(amount)*rate+0.5)), nil
}

// LoadItems reads a CSV with the columns sku, unit_price_cents, quantity.
func LoadItems(r io.Reader) ([]Item, error) {
	rows, err := csv.NewReader(r).ReadAll()
	if err != nil {
		return nil, fmt.Errorf("%w: %w", ErrInvalid, err)
	}
	if len(rows) == 0 || strings.Join(rows[0], ",") != "sku,unit_price_cents,quantity" {
		return nil, fmt.Errorf("%w: header must be sku,unit_price_cents,quantity", ErrInvalid)
	}
	items := make([]Item, 0, len(rows)-1)
	for i, row := range rows[1:] {
		line := i + 2
		price, err1 := strconv.Atoi(row[1])
		qty, err2 := strconv.Atoi(row[2])
		if err := errors.Join(err1, err2); err != nil {
			return nil, fmt.Errorf("%w: line %d: %w", ErrInvalid, line, err)
		}
		it := Item{SKU: row[0], UnitPriceCents: price, Quantity: qty}
		if err := it.Validate(); err != nil {
			return nil, fmt.Errorf("line %d: %w", line, err)
		}
		items = append(items, it)
	}
	return items, nil
}
