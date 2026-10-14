# Projects and tooling

[← Python 101](README.md)

How to set up a Python project so it's reproducible, consistent, tested, and shippable. The two [boilerplate](README.md#boilerplate) projects use every tool here, and CI lints them with ruff on every change.

## Project layout

```text
healthcheck/
├── pyproject.toml          # metadata, dependencies, and tool settings, in one file
├── uv.lock                 # every dependency, pinned to exact versions and hashes (commit it)
├── README.md
├── src/
│   └── healthcheck/        # the package: importable as "healthcheck"
│       ├── __init__.py
│       ├── __main__.py     # makes "python -m healthcheck" work
│       ├── cli.py
│       └── checker.py
└── tests/
    └── test_healthcheck.py
```

The **`src/` layout** keeps the package out of the project root, so tests run against the installed package, not whatever happens to be in the current directory. It catches packaging mistakes (a missing file, a wrong import) before users do.

## pyproject.toml

One file replaces the old `setup.py`, `requirements.txt`, and per-tool config files. The [healthcheck pyproject.toml](boilerplate/healthcheck/pyproject.toml) has:

| Section | Holds |
|---|---|
| `[project]` | Name, version, Python version range, runtime `dependencies` |
| `[project.scripts]` | Command-line entry points: `healthcheck = "healthcheck.cli:main"` creates a `healthcheck` command |
| `[dependency-groups]` | Development-only dependencies (linters, test tools), installed by `uv sync` but not by users of the package |
| `[build-system]` | How to build the package (here, hatchling) |
| `[tool.ruff]`, `[tool.mypy]`, `[tool.pytest.ini_options]` | Each tool's settings |

## Dependencies with uv

```sh
uv init --package myproject     # new project with a src/ layout
uv add httpx                    # runtime dependency: updates pyproject.toml and uv.lock
uv add --dev pytest             # development dependency
uv remove httpx
uv sync                         # make .venv match uv.lock exactly
uv sync --frozen                # in CI: fail instead of updating a stale lock file
uv lock --upgrade               # update the lock to the newest versions the constraints allow
uv run pytest                   # run a command in the project environment
uv tree                         # the dependency tree
```

- **Commit `uv.lock`.** It pins every transitive dependency to an exact version and hash, so CI, colleagues, and the container image all get identical packages.
- **Constrain loosely in `pyproject.toml`** (`httpx>=0.28`), and let the lock file pin exactly. Upgrade deliberately, with `uv lock --upgrade` in a pull request, and let Dependabot or Renovate propose it.
- **Fewer dependencies is better.** Each one is code you didn't review, can break, and must be patched. The healthcheck tool has none.

## Lint and format: ruff

[ruff](https://docs.astral.sh/ruff/) is both a linter and a formatter, and replaces flake8, isort, black, pyupgrade, and parts of bandit:

```sh
uv run ruff check .             # lint
uv run ruff check --fix .       # fix what can be fixed automatically
uv run ruff format .            # format (black-compatible)
uv run ruff format --check .    # in CI: fail if anything isn't formatted
```

The rule sets the boilerplate enables, in `[tool.ruff.lint] select`:

| Code | Rules | Catches |
|---|---|---|
| E, W, F | pycodestyle, pyflakes | Style errors, unused imports and variables, undefined names |
| I | isort | Import order |
| B | bugbear | Likely bugs: mutable defaults, `except` that hides errors |
| UP | pyupgrade | Old syntax that newer Python simplifies |
| S | bandit | Security: `shell=True`, `yaml.load`, hard-coded passwords, unsafe URLs |
| SIM | simplify | Needlessly complex code |
| RUF | ruff-specific | Assorted correctness checks |

When a rule is wrong for one line, suppress it there with a reason: `# noqa: S310 (scheme checked above)`.

## Type checking: mypy

```sh
uv run mypy                     # uses [tool.mypy] in pyproject.toml
```

With `strict = true`, mypy requires type hints on every function and checks them all. It's stricter work up front, and catches whole classes of bugs before run time: `None` where a value was expected, wrong argument types, misspelled attributes. While writing the items API, strict mode caught a case where a framework value could be `None` that the tests didn't cover.

## Tests: pytest

```python
import pytest

def test_healthy_endpoint(server: str) -> None:        # "server" is a fixture
    assert check_url(f"{server}/ok").ok

@pytest.mark.parametrize("url", ["file:///etc/passwd", "not-a-url"])
def test_non_http_schemes_are_refused(url: str) -> None:   # one test, run once per value
    assert not check_url(url).ok

def test_usage_error() -> None:
    with pytest.raises(SystemExit) as exc:                 # assert that something raises
        main([])
    assert exc.value.code == 2
```

```sh
uv run pytest                   # all tests
uv run pytest -k timeout        # tests whose name matches
uv run pytest -x                # stop at the first failure
uv run pytest --lf              # rerun only last run's failures
```

- **Fixtures** set up what tests need (a temporary directory with `tmp_path`, a local HTTP server, a test client) and clean up afterward. See [test_healthcheck.py](boilerplate/healthcheck/tests/test_healthcheck.py).
- **Test behavior through public interfaces,** not internals: call `main()` and check the exit code and output; send HTTP requests and check responses.
- **No network in unit tests:** run a local server (`http.server` on port 0) or use the framework's test client, as both boilerplates do. Tests that depend on the internet fail randomly.
- **Contract tests** run against the real, running service: the [api-testing suite](../api-testing/README.md) does this for the items API in CI.

## Containerizing

The [items-api Dockerfile](boilerplate/items-api/Dockerfile) shows the pattern for Python services:

1. **Build stage:** copy `pyproject.toml` and `uv.lock` first and install dependencies (cached until they change), then copy the source and install the project, into a virtual environment.
2. **Runtime stage:** a clean slim image, a non-root user, pip removed, and only the virtual environment copied across.

The [Dockerfiles guide](../../devops/docker/02-dockerfiles.md) explains each practice. Python images are larger than Go's (about 210 MB against 17 MB for the same API here) because they carry the interpreter and libraries.

## Pre-commit checks

Run these locally before pushing (CI runs only the ruff checks):

```sh
uv run ruff format . && uv run ruff check --fix . && uv run mypy && uv run pytest
```

Or install [pre-commit](https://pre-commit.com/) to run ruff on every commit automatically.

## In CI

This repository's [lint workflow](../../.github/workflows/lint.yml) runs ruff (lint and format check) on every project. A full Python pipeline adds `uv sync --frozen`, mypy, and pytest, then builds the items-api image and runs Schemathesis and Newman against the container; here those run locally.
