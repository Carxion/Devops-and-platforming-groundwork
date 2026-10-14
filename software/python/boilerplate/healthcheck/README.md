# healthcheck (Python)

[← Python](../../README.md)

A small command-line tool that checks HTTP endpoints in parallel and exits non-zero if any are unhealthy. It's boilerplate for an operations CLI: copy the layout, replace the logic. The same tool in Go is in [../../../go/boilerplate/healthcheck](../../../go/boilerplate/healthcheck/), for comparison.

```sh
uv sync                                    # create .venv and install dev tools from uv.lock
uv run healthcheck https://example.com/ https://example.org/
uv run healthcheck --file urls.txt --output json --timeout 3
uv run pytest                              # tests (no network needed)
uv run ruff check . && uv run ruff format --check .
uv run mypy
```

| File | Shows |
|---|---|
| [pyproject.toml](pyproject.toml) | Project metadata, a console-script entry point, dev dependencies as a group, and ruff, mypy (strict), and pytest settings in one place |
| [src/healthcheck/cli.py](src/healthcheck/cli.py) | `argparse` with help and validation, logging to stderr and results to stdout, text or JSON output, meaningful exit codes |
| [src/healthcheck/checker.py](src/healthcheck/checker.py) | Logic separate from the CLI, a frozen dataclass result, errors turned into results instead of exceptions, a thread pool for parallel I/O, URL scheme validation |
| [tests/test_healthcheck.py](tests/test_healthcheck.py) | pytest with a fixture that runs a real local HTTP server, parametrized tests, testing exit codes and output |

It uses only the standard library, so installing it pulls in nothing and there's nothing to patch. The [Python guides](../../README.md) explain each choice.
