# Pricing: a unit testing example in Python

[← Unit testing in Python](../README.md)

A small module that prices a shopping cart: line items, discount codes that expire, tax from an external service, and items loaded from a CSV file. It's small on purpose, so the tests are the interesting part. Each test file shows techniques from the [guide](../README.md):

| Test file | Shows |
|---|---|
| [test_items.py](tests/test_items.py) | Plain asserts, testing exceptions, `parametrize`, `approx` |
| [test_discounts.py](tests/test_discounts.py) | Injecting a clock to test time, fixtures |
| [test_tax.py](tests/test_tax.py) | A hand-written fake, `unittest.mock`, and a local HTTP server for the real client |
| [test_loading.py](tests/test_loading.py) | `tmp_path` for files, testing error messages |
| [test_cli.py](tests/test_cli.py) | Testing a command-line entry point with `capsys` and `monkeypatch` |
| [conftest.py](tests/conftest.py) | Fixtures shared by every test file |

The same module and tests in Go are in [../../go/example](../../go/example/README.md).

```sh
cd software/testing/python/example
uv sync
uv run pytest                                  # run the tests
uv run pytest --cov --cov-report=term-missing  # with coverage (fails under 90%)
uv run ruff check . && uv run ruff format --check . && uv run mypy
```
