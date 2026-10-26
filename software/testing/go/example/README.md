# Pricing: a unit testing example in Go

[← Unit testing in Go](../README.md)

The same small pricing package as the [Python example](../../python/example/README.md): line items, discount codes that expire, tax from an external service, and items loaded from CSV. Each test file shows techniques from the [guide](../README.md):

| Test file | Shows |
|---|---|
| [items_test.go](items_test.go) | Plain comparisons, table-driven tests and subtests, `t.Parallel`, `errors.Is` |
| [discounts_test.go](discounts_test.go) | Injecting a clock, `t.Helper`, testing a boundary |
| [tax_test.go](tax_test.go) | A fake through an interface, and `httptest.NewServer` for the real client |
| [loading_test.go](loading_test.go) | `testdata/`, `strings.NewReader` as a file, `t.TempDir`, `reflect.DeepEqual` |
| [example_test.go](example_test.go) | A runnable example, a benchmark, and a fuzz test |
| [cmd/pricing/main_test.go](cmd/pricing/main_test.go) | Testing a CLI through a `run` function with captured output |

```sh
cd software/testing/go/example
go test ./...                                    # run the tests
go test -cover ./...                             # with coverage
go test -run '^$' -bench . -benchmem .           # only the benchmark
go test -run '^$' -fuzz FuzzLoadItems -fuzztime 30s .   # fuzz for 30 seconds
gofmt -l . && go vet ./... && golangci-lint run ./...
```
