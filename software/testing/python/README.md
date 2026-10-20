# Unit testing in Python

[← Unit testing](../README.md)

How to write unit tests with [pytest](https://docs.pytest.org/), the standard test runner for Python. Every technique here is used in the [example project](example/README.md), which you can run and change: `cd example && uv sync && uv run pytest`.

## Your first test

pytest finds tests by name: files called `test_*.py` (or `*_test.py`), and in them, functions starting with `test_`. A test is a function with plain `assert` statements:

```python
from pricing import Item, subtotal


def test_subtotal_adds_every_line() -> None:
    items = [Item("apple", 50, 3), Item("pear", 75)]
    assert subtotal(items) == 225
```

```sh
uv run pytest                      # every test under tests/
uv run pytest tests/test_items.py  # one file
uv run pytest -k discount          # tests whose name contains "discount"
uv run pytest -x                   # stop at the first failure
uv run pytest --lf                 # rerun only the tests that failed last time
uv run pytest -v                   # one line per test
```

When an assert fails, pytest shows the values on both sides, so `assert result == 150` failing prints what `result` actually was. No special assertion methods are needed.

Lay out a project with the code in `src/` and the tests in `tests/` ([project layout](../../python/03-projects-and-tooling.md#project-layout)). Installing the project (`uv sync` does this) makes `import pricing` work from the tests.

## Exceptions

Use `pytest.raises` to check that code fails the way it should. `match` is a regular expression searched for in the error message:

```python
def test_expired_code_is_refused(codes, clock) -> None:
    with pytest.raises(PricingError, match="expired on 2026-01-01"):
        apply_discount(1000, "OLD20", codes, clock=lambda: clock)
```

The test fails if the block doesn't raise, or raises a different exception type. Check the message when it's part of the behavior (a user has to understand it), and escape regex characters: `match=r"cart\.csv line 3"`.

## Many cases: parametrize

One test function, run once per row, each reported as its own test:

```python
@pytest.mark.parametrize(
    ("sku", "price", "quantity", "message"),
    [
        ("", 100, 1, "sku must not be empty"),
        ("apple", -1, 1, "price must not be negative"),
        ("apple", 100, 0, "quantity must be at least 1"),
    ],
    ids=["empty sku", "negative price", "zero quantity"],
)
def test_invalid_items_are_rejected(sku, price, quantity, message) -> None:
    with pytest.raises(PricingError, match=message):
        Item(sku, price, quantity)
```

`ids` names each case in the output (`test_invalid_items_are_rejected[negative price]`), so a failure says exactly which one broke. Adding a case is adding a row.

## Fixtures: setup that tests share

A fixture is a function that provides something a test needs. A test asks for it by naming it as an argument:

```python
@pytest.fixture
def codes() -> dict[str, Discount]:
    return {
        "SAVE10": Discount(percent=10, expires=datetime(2026, 12, 31, tzinfo=UTC)),
        "OLD20": Discount(percent=20, expires=datetime(2026, 1, 1, tzinfo=UTC)),
    }


def test_valid_code_takes_percent_off(codes, clock) -> None:
    assert apply_discount(1000, "SAVE10", codes, clock=lambda: clock) == 900
```

- **Each test gets a fresh value** by default, so one test changing it can't affect another.
- **Put shared fixtures in `conftest.py`** in the tests folder; pytest loads it automatically, and every test file can use them ([conftest.py](example/tests/conftest.py)).
- **Teardown with `yield`:** code after the `yield` runs after the test, even if it failed. The example's local HTTP server starts before `yield` and shuts down after.
- **Scope** (`@pytest.fixture(scope="session")`) shares an expensive fixture across tests, at the cost of independence: only for things tests don't change.

### Built-in fixtures

| Fixture | Gives | Example |
|---|---|---|
| `tmp_path` | A fresh empty directory (a `pathlib.Path`), removed later | [test_loading.py](example/tests/test_loading.py) |
| `monkeypatch` | Change environment variables, attributes, or dictionaries for one test, undone afterwards | `monkeypatch.setenv("TAX_URL", "...")` in [test_cli.py](example/tests/test_cli.py) |
| `capsys` | Capture what the code prints: `capsys.readouterr().out` and `.err` | [test_cli.py](example/tests/test_cli.py) |
| `caplog` | Capture log records | `assert "retrying" in caplog.text` |

## Time: inject a clock

Code that calls `datetime.now()` gives a different answer every run, so tests can't check it exactly. Pass the clock in instead:

```python
def apply_discount(amount_cents, code, codes, clock=system_clock):
    discount = codes[code]
    if clock() >= discount.expires:          # "now" comes from the clock it was given
        raise PricingError("expired")
    ...

# in a test: a clock that always says the same thing
apply_discount(1000, "SAVE10", codes, clock=lambda: datetime(2026, 10, 20, 12, 0, tzinfo=UTC))
```

The test can then check the exact boundary: one second before expiry passes, the moment of expiry fails ([test_discounts.py](example/tests/test_discounts.py)).

## Dependencies: fakes and mocks

The cart's tax comes from an HTTP service. Unit tests replace it.

**A fake** is a small working implementation, often the clearest choice:

```python
class FakeRates:
    def __init__(self, rates: dict[str, float]) -> None:
        self.rates = rates
        self.calls: list[str] = []

    def rate(self, region: str) -> float:
        self.calls.append(region)        # it records calls too, so tests can check them
        return self.rates[region]


def test_total_adds_tax_for_the_region(rates: FakeRates) -> None:
    assert total([Item("apple", 1000)], "CA", rates) == 1073
    assert rates.calls == ["CA"]
```

The real client and the fake both match the `TaxRates` protocol (a class with a `rate(region)` method), so `total()` accepts either, and mypy checks it.

**A mock** from `unittest.mock` is quicker for one-off checks of an interaction, or for making a call fail:

```python
from unittest.mock import Mock

def test_tax_service_is_asked_once_with_the_region() -> None:
    rates = Mock()
    rates.rate.return_value = 0.0
    total([Item("apple", 500)], "OR", rates)
    rates.rate.assert_called_once_with("OR")

def test_tax_service_failure_propagates() -> None:
    rates = Mock()
    rates.rate.side_effect = TimeoutError("tax service timed out")   # the call raises this
    with pytest.raises(TimeoutError):
        total([Item("apple", 500)], "OR", rates)
```

Use `Mock(spec=SomeClass)` (or `create_autospec`) so the mock rejects methods the real class doesn't have; a plain `Mock` accepts any misspelled method name and the test passes anyway.

**`unittest.mock.patch`** replaces a name inside a module for one test (`with patch("pricing.urllib.request.urlopen") as fake: ...`). It works when code can't be changed to accept a dependency, but it ties the test to where the code imports things; passing the dependency in is cleaner.

**And test the real thing once:** the fake proves `total()` works, but not that `HttpTaxRates` really speaks HTTP. The example runs a real HTTP server on a free local port for that ([test_tax.py](example/tests/test_tax.py)), which is still fast and needs no network.

## Command-line programs

Write `main()` to take the arguments and return the exit code, instead of reading `sys.argv` and calling `sys.exit()` directly. Then tests call it like a function:

```python
def test_prints_the_total(cart, rates, capsys) -> None:
    assert main([str(cart), "CA"], rates=rates) == 0
    assert capsys.readouterr().out == "10.73\n"
```

## Floating point

Compare floats with `pytest.approx`, never `==`: `0.1 + 0.2 == 0.3` is false in every language that uses binary floating point. For money, avoid floats entirely and count whole cents, as the example does.

## Markers

```python
@pytest.mark.slow                      # a custom marker, declared in pyproject.toml
def test_full_import(): ...

@pytest.mark.skipif(sys.platform == "win32", reason="needs a POSIX shell")
def test_shell_out(): ...

@pytest.mark.xfail(reason="known bug: issue 412", strict=True)
def test_rounding_of_negative_tax(): ...
```

`uv run pytest -m "not slow"` skips slow tests for a quick run. `strict=True` on `xfail` fails the suite when the bug is fixed, so you remember to remove the marker. `--strict-markers` (set in the example's `pyproject.toml`) turns a misspelled marker into an error.

## Coverage

```sh
uv run pytest --cov --cov-report=term-missing   # with pytest-cov
```

```text
Name                      Stmts   Miss Branch BrPart  Cover   Missing
src\pricing\__init__.py      88      1     22      0    99%   61
```

`Missing` lists the uncovered lines (here, the real clock, which tests replace on purpose). The example's `pyproject.toml` turns on branch coverage and fails the run below 90%. `--cov-report=html` writes a browsable report to `htmlcov/`.

## Checklist for a new test

- [ ] Its name says the behavior: `test_expired_code_is_refused`
- [ ] Arrange, act, assert; one behavior
- [ ] No network, real clock, shared state, or files outside `tmp_path`
- [ ] Error cases check the exception type and, where it matters, the message
- [ ] It fails when the code is wrong (break the code briefly and watch it fail)
