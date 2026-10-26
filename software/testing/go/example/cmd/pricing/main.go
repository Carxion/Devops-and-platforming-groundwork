// Command pricing prints a cart's total: pricing ITEMS.csv REGION.
// Tax rates come from the service at $TAX_URL.
package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"example.com/pricing"
)

// run is main without the os.Exit, so tests can call it with their own
// arguments, output, and tax service.
func run(ctx context.Context, args []string, stdout, stderr io.Writer, rates pricing.TaxRates) int {
	if len(args) != 2 {
		fmt.Fprintln(stderr, "usage: pricing ITEMS.csv REGION")
		return 2
	}
	f, err := os.Open(args[0]) //nolint:gosec // G703: reading the file the user named is the point
	if err != nil {
		fmt.Fprintln(stderr, "pricing:", err)
		return 1
	}
	defer func() { _ = f.Close() }()
	items, err := pricing.LoadItems(f)
	if err != nil {
		fmt.Fprintln(stderr, "pricing:", err)
		return 1
	}
	cents, err := pricing.Total(ctx, pricing.Order{Items: items, Region: args[1]}, rates, nil, time.Now)
	if err != nil {
		fmt.Fprintln(stderr, "pricing:", err)
		return 1
	}
	fmt.Fprintf(stdout, "%d.%02d\n", cents/100, cents%100)
	return 0
}

func main() {
	rates := pricing.HTTPTaxRates{BaseURL: os.Getenv("TAX_URL"), Client: &http.Client{Timeout: 5 * time.Second}}
	os.Exit(run(context.Background(), os.Args[1:], os.Stdout, os.Stderr, rates))
}
