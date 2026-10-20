# Unit testing

[← Software](../README.md)

How to write unit tests that catch real bugs, run in seconds, and don't break every time the code is refactored. This page covers the ideas that apply in any language; the [Python](python/README.md) and [Go](go/README.md) guides show them in practice, each with a runnable example project on the same small domain (pricing a shopping cart), so the two languages can be compared side by side.

| Guide | Covers | Example |
|---|---|---|
| [Unit testing in Python](python/README.md) | pytest: asserts, fixtures and `conftest.py`, `parametrize`, exceptions, `tmp_path`, `monkeypatch`, `capsys`, fakes and `unittest.mock`, coverage | [python/example](python/example/README.md): 31 tests, 99% branch coverage |
| [Unit testing in Go](go/README.md) | The `testing` package: table-driven tests and subtests, helpers, fakes through interfaces, `httptest`, `testdata`, examples, benchmarks, fuzzing, coverage | [go/example](go/example/README.md): table-driven tests, a benchmark, and a fuzz test |

Running the linters and test tools in a project, and in CI, is covered in each language's folder: [Python testing and linting](../python/04-testing-and-linting.md) and [Go testing and linting](../go/04-testing-and-linting.md).

## What a unit test is

A unit test checks one piece of behavior in isolation, quickly, with no network, database, or shared state. "Unit" means a unit of behavior (calculating a discount, parsing a file, rejecting bad input), not necessarily one function or class.

| Kind | Checks | Speed | Example in this repository |
|---|---|---|---|
| **Unit** | One behavior, with its dependencies replaced by fakes | Milliseconds | These examples; the [boilerplate](../python/boilerplate/healthcheck/README.md) tests |
| **Integration** | Pieces working together, with real dependencies (a database, a local server) | Seconds | The HTTP client tests here, against a local server |
| **Contract** | A running service against its API specification | Seconds to minutes | [API testing](../api-testing/README.md): Schemathesis and Newman |
| **End to end** | The whole system, as a user would use it | Minutes | The [Compose smoke test](../containers/docker/04-compose.md) |

Most tests should be unit tests: they're fast enough to run on every save, and when one fails it points at the problem. A few integration and end-to-end tests check that the pieces really fit.

## Good unit tests

- **Fast.** The whole suite in seconds, so people run it constantly. Slow tests get skipped.
- **Independent.** Each test sets up what it needs; tests pass in any order, alone or together. Shared mutable state between tests is the most common cause of tests that fail "randomly."
- **Repeatable.** The same result every time, anywhere: no real clock, network, random numbers without a seed, or dependence on the machine's files. Flaky tests teach people to ignore failures.
- **Self-checking.** Pass or fail without a person reading output.
- **Clear when they fail.** The test's name and message say what broke: `test_expired_code_is_refused` failing tells you more than `test_discount_3`.

## Structure: arrange, act, assert

```text
arrange:  set up the input and the world (an item, a fixed clock, a fake service)
act:      call the code under test, once
assert:   check the result
```

Keep each test to one behavior. A test that checks five things fails for five reasons, and the first failure hides the rest.

## What to test

- **Behavior, not implementation.** Test what the code does through its public interface (the result, the error, the output), not how it does it internally. Tests tied to private details break on every refactor, even when behavior is unchanged.
- **The normal case, the edge cases, and the error cases.** Empty input, one item, many items; zero, negative, and very large numbers; the boundary itself (a code that expires *at* this moment); invalid input and the error message a user will see.
- **Boundaries especially:** off-by-one bugs live at `<` versus `<=`. The examples test the second before expiry and the exact second of expiry.
- **Bugs, before you fix them.** Write a test that reproduces the bug, watch it fail, then fix the code. The test keeps the bug from coming back.

What not to unit test: third-party libraries (they have their own tests), trivial getters, and generated code.

## Design for testing

Code is easy to test when everything that varies comes in from outside:

| Instead of | Pass in | So tests can |
|---|---|---|
| Reading the clock inside the function | A clock (a function that returns the time) | Use a fixed time, and test expiry exactly |
| Calling a web service directly | An interface or protocol for the service | Use a fake that returns chosen answers, instantly |
| Opening a file by a hard-coded path | A path, or a reader | Use a temporary file, or a string |
| Printing to the console and calling `exit` | Output streams, and return an exit code | Capture the output and check the code |

Both examples are written this way: `total()` takes the tax service and the clock as arguments, and the command-line entry point is a `run`/`main` function that returns an exit code instead of exiting. Code that's hard to test is usually telling you it does too much in one place.

## Test doubles

Replacements for real dependencies, from simplest to most elaborate:

| Double | Is | Use for |
|---|---|---|
| **Dummy** | A value that's passed but never used | Filling a required argument |
| **Stub** | Returns fixed answers | "When asked for CA's rate, say 7.25%" |
| **Fake** | A working, simplified implementation | An in-memory tax service or database; usually the best choice |
| **Spy** | A stub or fake that records how it was called | Checking the service was called once, with "CA" |
| **Mock** | Pre-programmed with expectations it verifies | When the interaction itself is the behavior being tested |

Prefer fakes. Tests that mock everything end up checking that the code calls what it calls, and break on harmless refactoring. Mock at the edges of your system (network, clock, filesystem), not between your own classes. And test the real adapter once, against something real but local: both examples test the real HTTP client against a local server.

## Coverage

Coverage measures which lines (and branches) the tests ran. It finds code no test touches; it doesn't prove the tested code is right, because a test can run a line without checking its result.

- **Use it to find gaps,** not as a target to hit. 100% coverage of trivial code is worth less than good tests of the tricky parts.
- **Measure branch coverage,** not just lines: an `if` with no test for its false path shows as fully covered by line.
- **A floor in CI is reasonable** (the Python example fails below 90%) to stop coverage quietly falling.

## Test-driven development

TDD writes the test first: write a failing test for the next small piece of behavior, write the least code that passes it, then refactor with the tests as a safety net. Repeat. It keeps code testable by construction, and keeps the tests honest (you've seen each one fail). It's a useful habit for logic with clear inputs and outputs, and a good way to fix bugs (the failing test reproduces the bug), even if you don't use it for everything.
