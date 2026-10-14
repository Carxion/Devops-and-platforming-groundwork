# items-api (Python)

[← Python](../../README.md)

The [Items API](../../../api-testing/openapi/items-api.yaml) in FastAPI: boilerplate for an HTTP service with a contract, tests, and a production container image. The same API in Go is in [../../../go/boilerplate/items-api](../../../go/boilerplate/items-api/), and CI runs the shared [contract tests](../../../api-testing/README.md) against both.

```sh
uv sync
uv run uvicorn items_api.main:app --reload --port 8080   # development server, reloads on change
uv run pytest
uv run ruff check . && uv run ruff format --check . && uv run mypy

# Container
docker build -t items-api-python .
docker run --rm -p 127.0.0.1:8080:8080 items-api-python

# Contract tests from software/api-testing, against the running container
schemathesis run ../../../api-testing/openapi/items-api.yaml --url http://127.0.0.1:8080 --checks all
```

| File | Shows |
|---|---|
| [src/items_api/main.py](src/items_api/main.py) | An app factory (`create_app`) so tests inject their own store; exception handlers that map FastAPI's default error shapes onto the contract's; input validation; body size limits; a health endpoint |
| [src/items_api/store.py](src/items_api/store.py) | Storage behind a `Protocol`, so a database implementation can replace the in-memory one without touching the HTTP layer |
| [tests/test_api.py](tests/test_api.py) | In-process tests with FastAPI's `TestClient`, parametrized edge cases, and every error path the contract defines |
| [Dockerfile](Dockerfile) | Multi-stage build with `uv` from the lock file, dependencies cached before source, non-root runtime without pip, health check |
| [pyproject.toml](pyproject.toml) and `uv.lock` | Runtime and dev dependencies separated; the lock file pins every transitive version for reproducible builds |

**Why the error handlers?** FastAPI generates its own OpenAPI schema and error format (`{"detail": ...}` with status 422). The contract here says `{"error": ...}` with status 400. When a framework's defaults and your contract disagree, the contract wins, and the contract tests prove it.
