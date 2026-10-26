"""Unit tests for the HTTP layer, with FastAPI's in-process TestClient (no server, no network).

The contract tests in software/api-testing run against a real server in CI.
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from items_api.main import MAX_BODY_BYTES, create_app
from items_api.store import MemoryStore


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(create_app(MemoryStore())) as c:
        yield c


def test_put_then_get_returns_item_with_id(client: TestClient) -> None:
    put = client.put("/items/order-1", json={"status": "pending", "quantity": 3})
    assert put.status_code == 200
    assert put.json() == {"id": "order-1"}

    got = client.get("/items/order-1")
    assert got.status_code == 200
    assert got.json() == {"status": "pending", "quantity": 3, "id": "order-1"}


def test_put_replaces_rather_than_merges(client: TestClient) -> None:
    client.put("/items/a", json={"status": "pending", "quantity": 3})
    client.put("/items/a", json={"status": "shipped"})
    assert client.get("/items/a").json() == {"status": "shipped", "id": "a"}


def test_id_in_body_is_ignored(client: TestClient) -> None:
    client.put("/items/a", json={"id": "other", "x": 1})
    assert client.get("/items/a").json() == {"x": 1, "id": "a"}


def test_missing_item_is_404_with_error_body(client: TestClient) -> None:
    response = client.get("/items/nope")
    assert response.status_code == 404
    assert response.json() == {"error": "not found"}


def test_delete_is_idempotent(client: TestClient) -> None:
    client.put("/items/a", json={})
    assert client.delete("/items/a").status_code == 204
    assert client.delete("/items/a").status_code == 204
    assert client.get("/items/a").status_code == 404


@pytest.mark.parametrize("body", ["[1, 2]", '"text"', "42", "not json", ""])
def test_put_rejects_anything_but_a_json_object(client: TestClient, body: str) -> None:
    response = client.put("/items/a", content=body, headers={"Content-Type": "application/json"})
    assert response.status_code == 400
    assert "error" in response.json()


@pytest.mark.parametrize("item_id", ["has space", "a" * 129, "semi;colon"])
def test_invalid_ids_are_400(client: TestClient, item_id: str) -> None:
    assert client.get(f"/items/{item_id}").status_code == 400
    assert client.put(f"/items/{item_id}", json={}).status_code == 400
    assert client.delete(f"/items/{item_id}").status_code == 400


def test_oversized_body_is_413(client: TestClient) -> None:
    big = '{"x": "' + "a" * MAX_BODY_BYTES + '"}'
    response = client.put("/items/a", content=big, headers={"Content-Type": "application/json"})
    assert response.status_code == 413


def test_unsupported_method_is_405(client: TestClient) -> None:
    response = client.post("/items/a", json={})
    assert response.status_code == 405
    assert response.json() == {"error": "method not allowed"}
    assert response.headers["allow"] == "DELETE, GET, PUT"


def test_healthz(client: TestClient) -> None:
    assert client.get("/healthz").json() == {"status": "ok"}
