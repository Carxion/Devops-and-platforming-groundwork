# Unit testing in Go

[← Unit testing](../README.md)

Go's testing tools are built in: the `testing` package and `go test` need nothing installed. Every technique here is used in the [example project](example/README.md): `cd example && go test ./...`.

## Your first test

Tests live next to the code, in files ending `_test.go`, in functions named `TestXxx` that take a `*testing.T`:

```go
package pricing_test

import (
	"testing"

	"example.com/pricing"
)

func TestLineTotalIsPriceTimesQuantity(t *testing.T) {
	item := pricing.Item{SKU: "apple", UnitPriceCents: 50, Quantity: 3}

	got := item.TotalCents()

	if got != 150 {
		t.Errorf("TotalCents() = %d, want 150", got)
	}
}
```

```sh
go test ./...                          # every package
go test -run TestSubtotal ./...        # tests whose name matches a regular expression
go test -run 'TestSubtotal/one_line' .  # one subtest (spaces in names become underscores)
go test -v ./...                       # every test's name and result
go test -count=1 ./...                 # bypass the test cache
```

There are no assertion helpers in the standard library: you compare with `if`, and report with `t.Errorf` (mark the test failed and keep going) or `t.Fatalf` (mark it failed and stop this test). The Go convention for messages is `Func(input) = got, want want`, so every failure reads the same way.

**`package pricing_test` or `package pricing`?** Tests in the external `_test` package can only use exported names: they test the package as callers see it, which is usually what you want. Tests in the same package can reach unexported functions; use them sparingly, for internals with logic worth testing directly.

## Table-driven tests

The Go idiom for many cases: a slice of structs, one per case, each run as a named subtest with `t.Run`:

```go
func TestSubtotal(t *testing.T) {
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
```

Adding a case is adding a row, and each row passes or fails on its own in the output (`TestSubtotal/one_line`). Since Go 1.22, each loop iteration has its own `tt`, so closures and parallel subtests capture the right case without the old `tt := tt` line.

## Errors

Check the kind of error with `errors.Is` (or `errors.As` for typed errors), not by comparing message text:

```go
err := tt.item.Validate()
if !errors.Is(err, pricing.ErrInvalid) {
	t.Errorf("Validate() = %v, want an error wrapping ErrInvalid", err)
}
```

That works because the code wraps a sentinel error with `%w`: `fmt.Errorf("%w: sku must not be empty", ErrInvalid)`. Check the message too (with `strings.Contains`) when its content matters to a user, such as the line number of a bad CSV row.

## Helpers, cleanup, and temporary files

| Call | Does |
|---|---|
| `t.Helper()` | Marks a function as a test helper, so a failure inside it is reported at the line in the test that called it |
| `t.Cleanup(func)` | Runs the function when the test (and its subtests) finish, even on failure: closing servers, removing state |
| `t.TempDir()` | A fresh directory, removed automatically |
| `t.Context()` | A context canceled when the test ends (Go 1.24 and later): pass it to code that takes a `context.Context` |
| `t.Setenv(key, value)` | Set an environment variable for this test, restored afterwards |
| `t.Parallel()` | Run this test or subtest in parallel with other parallel tests |
| `t.Skip("reason")` | Skip, for example when an external tool isn't installed |

Files a test reads go in a `testdata/` directory next to the test: the go tool ignores it when building, and tests run with the package directory as the working directory, so `os.Open("testdata/cart.csv")` works.

## Time: inject a clock

Pass the time in, as a function, instead of calling `time.Now()` inside the code:

```go
type Clock func() time.Time

func ApplyDiscount(amountCents int, code string, codes map[string]Discount, now Clock) (int, error) {
	d := codes[code]
	if !now().Before(d.Expires) { // "now" comes from the clock it was given
		return 0, ErrInvalid
	}
	return amountCents * (100 - d.Percent) / 100, nil
}
```

In a test:

```go
fixed := func() time.Time { return time.Date(2026, 10, 20, 12, 0, 0, 0, time.UTC) }
got, err := pricing.ApplyDiscount(1000, "SAVE10", codes, fixed)
```

The test can then check the boundary exactly: one second before expiry, and the moment of expiry ([discounts_test.go](example/discounts_test.go)). Go 1.25's `testing/synctest` package goes further, giving tests a fake clock for code with timers and goroutines.

## Dependencies: fakes through interfaces

Accept an interface for anything external, and tests pass a fake. Go interfaces are satisfied implicitly, so a fake is just a type with the right methods; no mocking library is needed:

```go
type TaxRates interface {
	Rate(ctx context.Context, region string) (float64, error)
}

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
```

One fake covers the normal case (return a rate), the failure case (set `err`), and checking the interaction (read `calls`). Keep interfaces small and define them where they're used, not next to the implementation: `Total` needs only `Rate`, so that's all the interface asks for.

## HTTP: httptest

`net/http/httptest` tests HTTP code for real without the network:

- **`httptest.NewServer(handler)`** starts a real server on a free local port, for testing an HTTP client. The example tests the real `HTTPTaxRates` client against one ([tax_test.go](example/tax_test.go)).
- **`httptest.NewRecorder()`** captures a handler's response in memory, for testing your own handlers without a server.

```go
srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, `{"rate": 0.0725}`)
}))
t.Cleanup(srv.Close)
client := pricing.HTTPTaxRates{BaseURL: srv.URL, Client: srv.Client()}
```

## Command-line programs

Put `main`'s logic in `run(ctx, args, stdout, stderr, ...) int`, and keep `main` to the `os.Exit` call. Tests call `run` with their own arguments and `bytes.Buffer`s for output, then check the exit code and what was printed ([cmd/pricing/main_test.go](example/cmd/pricing/main_test.go)).

## Comparing values

`==` works for numbers, strings, and simple structs. For slices, maps, and nested structs, use `reflect.DeepEqual` (standard library), or the widely used `github.com/google/go-cmp/cmp`, whose `cmp.Diff(want, got)` prints exactly which field differs. Never compare floats with `==` when they come from arithmetic; check `math.Abs(got-want) < 1e-9`, or use whole numbers (the example counts cents).

## Examples, benchmarks, and fuzzing

All three live in `_test.go` files, run by `go test`:

```go
// An Example is documentation that's also a test: the printed output must match.
func ExampleSubtotal() {
	fmt.Println(pricing.Subtotal([]pricing.Item{{SKU: "apple", UnitPriceCents: 50, Quantity: 3}}))
	// Output: 150
}

// A benchmark: go test -bench=. -benchmem
func BenchmarkSubtotal(b *testing.B) {
	items := make([]pricing.Item, 1000)
	for b.Loop() {                // Go 1.24 and later
		pricing.Subtotal(items)
	}
}

// A fuzz test: go test -fuzz=FuzzLoadItems -fuzztime=30s
func FuzzLoadItems(f *testing.F) {
	f.Add("sku,unit_price_cents,quantity\napple,50,3\n")   // seed inputs
	f.Fuzz(func(t *testing.T, input string) {
		items, err := pricing.LoadItems(strings.NewReader(input))
		if err != nil {
			return // rejecting bad input is fine; panicking isn't
		}
		for _, it := range items {
			if it.Validate() != nil {
				t.Errorf("returned an invalid item: %+v", it)
			}
		}
	})
}
```

- **Examples** appear in `go doc` and on pkg.go.dev, and can never go stale, because they're run.
- **Benchmarks** report time and allocations per operation. Compare before and after a change with `benchstat`.
- **Fuzzing** generates inputs to find crashes and broken invariants. Without `-fuzz`, the seed inputs run as an ordinary test; with it, the fuzzer runs until stopped, and any input that fails is saved to `testdata/fuzz/` to become a permanent test case. Fuzz parsers and anything that handles untrusted input. On the example, 15 seconds of fuzzing ran about two million inputs.

## Race detector and coverage

```sh
go test -race ./...                                  # find data races (needs cgo: a C compiler)
go test -cover ./...                                 # coverage per package
go test -coverprofile=cover.out ./... && go tool cover -html=cover.out   # which lines ran, in a browser
go test -shuffle=on ./...                            # random test order, to find hidden dependencies between tests
```

Always run `-race` in CI for code with goroutines: races are the bugs concurrent code is most likely to have and least likely to show in ordinary runs.

## Checklist for a new test

- [ ] Its name says the behavior: `TestCodeExpiresAtExactlyItsExpiryTime`
- [ ] Table-driven when there's more than one case, with named subtests
- [ ] Failure messages in the form `Func(input) = got, want want`
- [ ] Errors checked with `errors.Is` or `errors.As`
- [ ] No network, real clock, or shared state; files under `t.TempDir()` or `testdata/`
- [ ] It fails when the code is wrong (break the code briefly and watch it fail)
