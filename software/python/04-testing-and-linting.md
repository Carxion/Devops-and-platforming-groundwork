# 4. Testing and linting

[← Python 101](README.md)

Every check a Python project should run, what each one catches, how to configure it, and how to run them all on every commit and in CI. [Projects and tooling](03-projects-and-tooling.md) introduces the tools; this guide is the full reference. For *writing* tests, see [Unit testing in Python](../testing/python/README.md).

## The checks, in order

Run the cheapest first: there's no point running a five-minute test suite on code that doesn't format.

| # | Check | Tool | Catches | Typical time |
|---|---|---|---|---|
| 1 | Formatting | `ruff format --check` | Inconsistent layout | Under a second |
| 2 | Linting | `ruff check` | Bugs, unused code, import order, security smells, outdated syntax | Under a second |
| 3 | Type checking | `mypy` | Wrong types, `None` where a value was expected, misspelled attributes | Seconds |
| 4 | Lock file | `uv lock --check` | `pyproject.toml` changed without updating `uv.lock` | Under a second |
| 5 | Unit tests and coverage | `pytest --cov` | Wrong behavior; untested code | Seconds |
| 6 | Dependency vulnerabilities | `pip-audit` | Installed packages with known vulnerabilities | Seconds |
| 7 | Contract and integration tests | Schemathesis, Newman, Docker | The running service against its API ([API testing](../api-testing/README.md)) | Minutes |

```sh
uv run ruff format --check . && uv run ruff check . && uv run mypy && uv lock --check \
  && uv run pytest --cov && uv run --with pip-audit pip-audit --skip-editable
```

## Formatting and linting: ruff

Ruff does both jobs, which are different: **the formatter** rewrites layout (indentation, quotes, line breaks) and has almost no options; **the linter** reports rule violations, some of which it can fix.

```sh
uv run ruff format .              # rewrite files
uv run ruff format --check .      # CI: fail if anything would change
uv run ruff format --diff .       # show what would change
uv run ruff check .               # report
uv run ruff check --fix .         # fix what's safe to fix automatically
uv run ruff check --statistics .  # count findings by rule, for adopting ruff on an old codebase
uv run ruff rule B006             # explain a rule
```

Configure it in `pyproject.toml`:

```toml
[tool.ruff]
line-length = 100
target-version = "py312"          # the oldest Python you support; enables the right upgrades

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "UP", "S", "SIM", "PT", "RUF"]

[tool.ruff.lint.per-file-ignores]
"tests/*" = ["S101"]              # pytest uses plain assert
```

| Code | Rule set | Catches |
|---|---|---|
| E, W, F | pycodestyle, pyflakes | Style errors, unused imports and variables, undefined names |
| I | isort | Import order. `from flask import jsonify, Flask` fails: names sort uppercase first, so `Flask, jsonify` |
| B | bugbear | Likely bugs: mutable default arguments, `except` that hides errors, loop variables in closures |
| UP | pyupgrade | Old syntax newer Python simplifies: `Optional[str]` to `str \| None` |
| S | bandit | Security: `shell=True`, `yaml.load`, hard-coded passwords, `assert` in production code, unsafe URLs |
| SIM | simplify | Needlessly complex code |
| PT | flake8-pytest-style | pytest misuse: `pytest.raises(Exception)` too broad without `match`, wrongly structured `parametrize` |
| RUF | ruff | Assorted correctness checks |

Start strict on new projects. On an existing project, enable rule sets one at a time and fix them in separate commits. Suppress a finding only on its line, with the reason: `# noqa: S310 (scheme checked in __init__)`.

## Type checking: mypy

```sh
uv run mypy                       # uses [tool.mypy] in pyproject.toml
```

```toml
[tool.mypy]
strict = true                     # every function annotated, no implicit Any, and more
files = ["src", "tests"]          # check the tests too: they're code

[[tool.mypy.overrides]]
module = ["some_untyped_library.*"]
ignore_missing_imports = true     # for libraries without type information
```

Type the tests as well: mypy then checks that fakes match the protocol they stand in for, as the [testing example](../testing/python/example/README.md)'s `FakeRates` does. Install type stubs for libraries that need them (`types-requests`, `boto3-stubs[s3]`) as dev dependencies.

## Tests and coverage: pytest

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-ra --strict-markers"  # summary of skips and failures; misspelled markers are errors
markers = ["slow: tests that take more than a second"]

[tool.coverage.run]
branch = true                     # count both sides of every if
source = ["pricing"]

[tool.coverage.report]
show_missing = true
fail_under = 90
```

```sh
uv run pytest                                             # all tests
uv run pytest -x --lf                                     # stop at the first failure; rerun last failures
uv run pytest -m "not slow"                               # skip slow tests
uv run pytest --cov --cov-report=term-missing             # coverage, with uncovered line numbers
uv run pytest --junitxml=junit.xml --cov --cov-report=xml # reports for CI
uv run pytest -n auto                                     # in parallel (with the pytest-xdist plugin)
```

| Flag | Does |
|---|---|
| `--junitxml=junit.xml` | A JUnit report: GitLab and most CI systems show failed tests from it in the merge request |
| `--cov-report=xml` | A Cobertura coverage report: GitLab shows covered and uncovered lines in the diff |
| `--durations=10` | The ten slowest tests, to find what's slowing the suite down |
| `-p no:randomly` / `-p randomly` | With pytest-randomly, run tests in random order to find hidden dependencies between them |

## Dependencies: the lock file and vulnerabilities

```sh
uv lock --check                                       # uv.lock matches pyproject.toml
uv sync --frozen                                      # CI: install exactly the lock file, never update it
uv run --with pip-audit pip-audit --skip-editable     # known vulnerabilities in installed packages
uv lock --upgrade-package requests                    # update one dependency on purpose
```

`pip-audit` checks against the Python Packaging Advisory Database and OSV. `--skip-editable` skips your own project, which isn't on PyPI. Dependabot or Renovate keeps the lock file current between audits ([this repository's dependabot.yml](../../.github/dependabot.yml) covers every `uv.lock`).

## On every commit: pre-commit

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.17.1            # the same ruff version as CI, so results match
    hooks:
      - id: ruff-check
        args: [--fix]
      - id: ruff-format
```

```sh
uv add --dev pre-commit
uv run pre-commit install           # once per clone: installs the git hook
uv run pre-commit run --all-files   # run every hook on everything
```

A hook that fixes files fails the commit and leaves the fixes in your working tree: review them, `git add`, and commit again. Hooks are skippable (`git commit --no-verify`), so CI must run the same checks; the hooks just give faster feedback. Keep slow checks (mypy on a large project, the test suite) in CI rather than in the hook, or people will skip it. (`ruff-check` is the hook's current name; older ruff-pre-commit versions call it `ruff`.)

## In CI

GitLab CI, with reports that show up in the merge request:

```yaml
# .gitlab-ci.yml
python-checks:
  image: ghcr.io/astral-sh/uv:0.13-python3.13-trixie-slim
  variables:
    UV_FROZEN: "1"                 # use uv.lock exactly
  script:
    - uv run ruff format --check .
    - uv run ruff check --output-format=gitlab --output-file=code-quality.json .
    - uv run mypy
    - uv run pytest --junitxml=junit.xml --cov --cov-report=xml:coverage.xml --cov-report=term
    - uv run --with pip-audit pip-audit --skip-editable
  coverage: '/TOTAL.*\s(\d+(?:\.\d+)?)%/'   # the percentage shown on the merge request
  artifacts:
    when: always                   # upload reports even when a check fails, which is when you need them
    reports:
      codequality: code-quality.json
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
```

GitHub Actions:

```yaml
jobs:
  python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full commit SHA> # pin actions by SHA
      - uses: astral-sh/setup-uv@<full commit SHA>
      - run: uv sync --frozen
      - run: uv run ruff format --check . && uv run ruff check --output-format=github .
      - run: uv run mypy
      - run: uv run pytest --cov --cov-report=term-missing
```

`--output-format=github` turns ruff's findings into annotations on the pull request's changed lines; `--output-format=gitlab` produces GitLab's Code Quality report. This repository's [lint.yml](../../.github/workflows/lint.yml) runs ruff on every Python project.

## Common findings and fixes

| Finding | Means | Fix |
|---|---|---|
| `I001` import block is unsorted | Imports out of order | `ruff check --fix` |
| `F401` imported but unused | Dead import | Remove it (or re-export with `__all__`) |
| `B006` mutable default argument | `def f(items=[])` shares one list across calls | `def f(items=None)`, then `items = items or []` |
| `S603`/`S607` subprocess call | Running a program, possibly with untrusted input | Pass a list (never `shell=True`), use a full path, validate input; suppress with a reason if safe |
| `S310` URL open with unchecked scheme | `urlopen` would also open `file://` URLs | Check the scheme first, then suppress with the reason |
| mypy: `Item "None" of "X \| None" has no attribute` | A value that can be `None` is used as if it can't | Check for `None` first, or fix the type |
| mypy: `Missing type parameters for generic type "dict"` | Strict mode wants `dict[str, int]` | Add the types |
| pytest: `ModuleNotFoundError` in tests | The project isn't installed, or isn't on the path | `uv sync` (src layout), or `pythonpath = ["src"]` in the pytest config |
| pytest: no tests ran | File or function names don't match | Files `test_*.py` or `*_test.py`, functions `test_*` |
| Coverage below `fail_under` | New code without tests | Add tests for the behavior, not just to raise the number |

## Next

Back to the [Python overview](README.md), or on to [Unit testing in Python](../testing/python/README.md).
