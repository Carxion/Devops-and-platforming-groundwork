# Language essentials

[← Go 101](README.md)

Enough Go to read and write real programs. The language is small on purpose: there's usually one obvious way to do something. [A Tour of Go](https://go.dev/tour/) is the best interactive introduction, and [Effective Go](https://go.dev/doc/effective_go) explains the idioms.

## A complete program

```go
package main

import "fmt"

func main() {
	fmt.Println("hello")
}
```

Every file starts with a `package` clause; `package main` with a `func main()` is a program. Unused imports and unused local variables are compile errors, which keeps code clean. Formatting is not a matter of taste: `gofmt` decides, with tabs for indentation.

## Variables and types

```go
var port int = 8080          // explicit
name := "web-01"             // := declares and infers the type (inside functions only)
load, healthy := 0.75, true  // several at once
const maxRetries = 3         // constant

var count int                // zero value: 0; "" for strings, false, nil for pointers/slices/maps
s := strconv.Itoa(port)      // int to string; strconv.Atoi parses, returning an error
f := float64(port) / 3       // conversions are always explicit
```

Basic types: `bool`, `string`, `int` (and sized `int64`, `uint8`...), `float64`, `byte` (alias for `uint8`), `rune` (a Unicode code point). Strings are immutable byte sequences, usually UTF-8.

## Slices and maps

```go
hosts := []string{"web-01", "web-02"}    // a slice: a growable view over an array
hosts = append(hosts, "web-03")          // append may reallocate: always assign the result
first, rest := hosts[0], hosts[1:]       // index and slice
fmt.Println(len(hosts), first, rest)

for i, h := range hosts {                // index and value; use _ to ignore one
	fmt.Println(i, h)
}

tags := map[string]string{"env": "prod", "team": "platform"}
tags["owner"] = "alice"
owner, ok := tags["owner"]               // "comma ok": ok is false if the key is missing
delete(tags, "team")
for k, v := range tags {                 // map iteration order is random, on purpose
	fmt.Println(k, v)
}

counts := make(map[string]int)           // make an empty map before writing to it
counts["200"]++                          // missing keys read as the zero value
```

The `slices` and `maps` packages add common operations: `slices.Contains`, `slices.Sort`, `slices.Index`, `maps.Keys`, `maps.Clone`.

## Control flow

```go
if load > 0.9 {
	level = "critical"
} else if load > 0.7 {
	level = "warning"
}

if err := check(); err != nil { // a statement before the condition, scoped to the if
	return err
}

for i := 0; i < 3; i++ {} // the only loop keyword is for
for retries < 3 {}        // "while"
for {}                    // forever, until break or return
for i := range 3 {}       // range over an integer (Go 1.22+)

switch {
case status >= 500:
	result = "server error"
case status == 404:
	result = "missing"
default:
	result = "ok"
}
```

`switch` cases don't fall through, so no `break` is needed.

## Functions and multiple returns

```go
func divide(a, b float64) (float64, error) {
	if b == 0 {
		return 0, errors.New("division by zero")
	}
	return a / b, nil
}
```

Calling it:

```go
result, err := divide(10, 2)
if err != nil {
	log.Fatal(err)
}
```

Functions return several values; the last is conventionally an `error`. Functions are values too: they can be passed, returned, and closed over (closures).

## Errors

Go has no exceptions. Errors are values, returned and checked explicitly:

```go
data, err := os.ReadFile("/etc/app/config.json")
if err != nil {
	// Wrap with context using %w, so callers can still inspect the cause.
	return fmt.Errorf("loading config: %w", err)
}

// Check for a specific error anywhere in the wrapped chain
if errors.Is(err, os.ErrNotExist) {
	// use defaults
}

// Extract a specific error type
var pathErr *fs.PathError
if errors.As(err, &pathErr) {
	fmt.Println("failed path:", pathErr.Path)
}
```

- **Handle every error** or return it with context. Ignoring one needs an explicit `_ =`, which reviewers and linters notice.
- **Add context as errors go up:** "loading config: open /etc/app/config.json: no such file or directory" tells you exactly what failed.
- `panic` is for programming errors that can't happen in a correct program, not for ordinary failures.

## Structs and methods

```go
type Endpoint struct {
	Name    string        `json:"name"`    // struct tags control JSON encoding
	URL     string        `json:"url"`
	Timeout time.Duration `json:"timeout"`
}

// A method with a pointer receiver can modify the struct.
func (e *Endpoint) SetDefaults() {
	if e.Timeout == 0 {
		e.Timeout = 5 * time.Second
	}
}
```

Using it:

```go
ep := Endpoint{Name: "api", URL: "https://example.com/"}
ep.SetDefaults()
```

Names starting with a capital letter are **exported** (visible outside the package); lowercase names are private to the package. There are no classes or inheritance; compose structs by embedding them instead.

## Interfaces

An interface lists methods; any type with those methods satisfies it automatically, with no `implements` declaration:

```go
type Store interface {
	Get(id string) (Item, bool)
	Put(id string, item Item)
}

// MemoryStore satisfies Store just by having the methods.
func (s *MemoryStore) Get(id string) (Item, bool) { /* ... */ }
func (s *MemoryStore) Put(id string, item Item)   { /* ... */ }
```

Keep interfaces small and define them where they're used, not where they're implemented. `io.Reader` (one method) and `error` (one method) are the most important interfaces in Go. The [items API](boilerplate/items-api/internal/api/store.go) uses a `Store` interface so a database can replace the in-memory store.

## Pointers

```go
x := 10
p := &x     // p points to x
*p = 20     // x is now 20
```

Pass a pointer when a function must modify its argument, or to avoid copying a large struct. There's no pointer arithmetic, and memory is garbage-collected.

## Generics

```go
// Map applies f to every element: works for any element types T and U.
func Map[T, U any](items []T, f func(T) U) []U {
	out := make([]U, 0, len(items))
	for _, item := range items {
		out = append(out, f(item))
	}
	return out
}
```

Calling it, with the types inferred:

```go
lengths := Map([]string{"a", "bb"}, func(s string) int { return len(s) })
```

Use generics for general-purpose containers and algorithms (the `slices` and `maps` packages are built on them). Most application code doesn't need them.

## defer

```go
f, err := os.Open(path)
if err != nil {
	return err
}
defer f.Close() // runs when the function returns, however it returns
```

`defer` is how Go guarantees cleanup: closing files, response bodies, and unlocking mutexes. Deferred calls run in reverse order.

## Idioms worth knowing

| Instead of | Write |
|---|---|
| Ignoring an error | Handle it, or `return fmt.Errorf("doing x: %w", err)` |
| `if err != nil { return err }` with no context | Wrap it: `fmt.Errorf("reading %s: %w", path, err)` |
| A large interface defined up front | A small interface defined by the code that uses it |
| Getters named `GetName()` | `Name()` |
| Package names like `utils` or `common` | Names that say what the package provides: `check`, `store` |
| `panic` for expected failures | Return an `error` |
| Comments that restate the code | Doc comments on exported names, starting with the name: `// Store is...` |
