# Python 101

[← Software](../README.md)

Python is the most common language for operations tooling after the shell: automation scripts, cloud SDK work, data wrangling, CLIs, and small web services. It's readable, has a huge standard library, and every cloud has an official SDK for it. This folder takes you from the language basics to a tested, typed, containerized project.

> **Status.** CI lints the boilerplate projects and the operational examples with ruff. They also pass strict mypy and pytest, and the items API container passes the shared [API contract](../api-testing/openapi/items-api.yaml) tests with Schemathesis and Newman; run those locally ([how](../../CONTRIBUTING.md#running-the-tests-locally)).

## Learning path

| # | Guide | You'll be able to |
|---|---|---|
| 1 | [Language essentials](01-language-essentials.md) | Read and write Python: types, collections, control flow, functions, errors, classes and dataclasses, comprehensions, type hints |
| 2 | [Python for operations](02-python-for-operations.md) | Work with files and paths, run commands, parse JSON and YAML, call HTTP APIs, use the AWS and Azure SDKs, write CLIs, log properly, and do things in parallel |
| 3 | [Projects and tooling](03-projects-and-tooling.md) | Set up a project with `uv` and `pyproject.toml`, lint and format with ruff, type-check with mypy, test with pytest, and package and containerize it |
| 4 | [Testing and linting](04-testing-and-linting.md) | Run every check and know what it catches: ruff (format and lint), mypy, pytest and coverage, the lock file, pip-audit, pre-commit, and CI with reports in GitLab and GitHub |

## Boilerplate

| Project | What it is |
|---|---|
| [boilerplate/healthcheck](boilerplate/healthcheck/README.md) | A command-line tool that checks HTTP endpoints in parallel, using only the standard library |
| [boilerplate/items-api](boilerplate/items-api/README.md) | The [Items API](../api-testing/README.md) in FastAPI, with tests, a lock file, and a multi-stage container image |

The same two projects exist in [Go](../go/README.md), so you can compare the languages on the same problems.

## Operational examples

[examples/](examples/README.md) has five working tools of the kind operations teams write all the time, each built the same way in Go:

| Tool | Job |
|---|---|
| certcheck | Warn before TLS certificates expire |
| logstats | Summarize web access logs and gate on a 5xx error budget |
| probe-exporter | Expose endpoint health as Prometheus metrics |
| alert-relay | Forward Alertmanager alerts to a chat webhook |
| tag-audit | Find AWS resources missing required tags |

For the wider picture of what teams build in each language, see [what operations teams build](../README.md#what-operations-teams-build).

For writing unit tests (fixtures, fakes, table-driven tests, and more), see [Unit testing in Python](../testing/python/README.md).

## Setup

Use a current Python (3.12 or later) and [uv](https://docs.astral.sh/uv/), a fast tool that manages Python versions, virtual environments, dependencies, and lock files in one.

```sh
# Install uv (or: pipx install uv, brew install uv, winget install astral-sh.uv)
curl -LsSf https://astral.sh/uv/install.sh | sh

uv python install 3.14         # a managed Python, separate from the system one
cd software/python/boilerplate/healthcheck
uv sync                        # creates .venv and installs everything from uv.lock
uv run healthcheck --help      # runs inside the project's environment
```

**Leave the system Python alone.** On RHEL and Ubuntu the operating system depends on it, and recent Ubuntu releases refuse `pip install` into it ("externally-managed-environment"). Use a virtual environment for every project (uv makes one automatically), and `uv tool install` or `pipx` for command-line tools.

Without uv, the standard library's tools work too:

```sh
python3 -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -e . --group dev    # the project plus its dev dependency group (pip 25.1 or later)
```

## When to choose Python

| Good fit | Consider something else |
|---|---|
| Automation and glue between systems | A ten-line sequence of commands: [Bash](../../devops/bash/README.md) |
| Cloud SDK work, reports, data processing | A single static binary to ship to many machines without a runtime: [Go](../go/README.md) |
| CLIs used by your team | Very high-throughput services where memory and startup time matter |
| Web APIs and internal services | Programs where many concurrent CPU-bound tasks dominate |
| Tests, including API and infrastructure tests | |
