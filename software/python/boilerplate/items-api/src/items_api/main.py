"""HTTP layer for the Items API.

The contract is software/api-testing/openapi/items-api.yaml, not the schema
FastAPI generates: errors are {"error": "..."}, invalid input is 400 (not
FastAPI's default 422), and bodies over 256 KiB are 413. The api-testing
suite (Schemathesis and Newman) checks this implementation against it in CI.

Run:  uvicorn items_api.main:app --host 0.0.0.0 --port 8080
"""

from __future__ import annotations

import json
import logging
import re
from typing import Any

from fastapi import FastAPI, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from starlette.exceptions import HTTPException as StarletteHTTPException

from items_api.store import ItemStore, MemoryStore

VALID_ID = re.compile(r"[A-Za-z0-9._-]{1,128}")
MAX_BODY_BYTES = 256 * 1024

log = logging.getLogger("items_api")


def error(status: int, message: str, headers: dict[str, str] | None = None) -> JSONResponse:
    return JSONResponse({"error": message}, status_code=status, headers=headers)


def allowed_methods(app: FastAPI, request: Request) -> list[str]:
    """Every method any route accepts for this request's path, for the Allow header."""
    methods: set[str] = set()
    for route in app.router.routes:
        if isinstance(route, APIRoute) and route.path_regex.fullmatch(request.url.path):
            methods |= (route.methods or set()) - {"HEAD"}
    return sorted(methods)


def create_app(store: ItemStore | None = None) -> FastAPI:
    """Build the app. Tests pass their own store; production uses the default."""
    items: ItemStore = store if store is not None else MemoryStore()
    app = FastAPI(title="Items API", version="1.0.0")

    # Map FastAPI's and Starlette's default error shapes onto the contract's.
    @app.exception_handler(StarletteHTTPException)
    async def http_error(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        message = "not found" if exc.status_code == 404 else str(exc.detail).lower()
        headers = getattr(exc, "headers", None)
        if exc.status_code == 405:
            # Each decorator registers its own route, so Starlette's 405 lists only
            # the first matching route's method. Allow must list them all.
            headers = {"Allow": ", ".join(allowed_methods(app, request))}
        return error(exc.status_code, message, headers=headers)

    @app.exception_handler(RequestValidationError)
    async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        return error(400, "invalid request")

    @app.get("/healthz", include_in_schema=False)
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/items/{item_id}")
    def get_item(item_id: str) -> Response:
        if not VALID_ID.fullmatch(item_id):
            return error(400, "invalid id")
        item = items.get(item_id)
        if item is None:
            return error(404, "not found")
        return JSONResponse({**item, "id": item_id})

    @app.put("/items/{item_id}")
    async def put_item(item_id: str, request: Request) -> Response:
        if not VALID_ID.fullmatch(item_id):
            return error(400, "invalid id")
        body = await request.body()
        if len(body) > MAX_BODY_BYTES:
            return error(413, "body too large")
        try:
            data: Any = json.loads(body)  # an empty body is invalid JSON, so it's rejected
        except ValueError:
            return error(400, "body must be JSON")
        if not isinstance(data, dict):
            return error(400, "body must be a JSON object")
        items.put(item_id, {k: v for k, v in data.items() if k != "id"})
        log.info("stored item %s", item_id)
        return JSONResponse({"id": item_id})

    @app.delete("/items/{item_id}", status_code=204)
    def delete_item(item_id: str) -> Response:
        if not VALID_ID.fullmatch(item_id):
            return error(400, "invalid id")
        items.delete(item_id)
        return Response(status_code=204)

    return app


app = create_app()
