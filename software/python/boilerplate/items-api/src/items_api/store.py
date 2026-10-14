"""Item storage. In memory here; swap in a database behind the same interface."""

from __future__ import annotations

import threading
from typing import Any, Protocol


class ItemStore(Protocol):
    """What the API needs from storage. A database-backed store implements the same methods."""

    def get(self, item_id: str) -> dict[str, Any] | None: ...
    def put(self, item_id: str, item: dict[str, Any]) -> None: ...
    def delete(self, item_id: str) -> None: ...


class MemoryStore:
    """A thread-safe dictionary. Data is lost on restart: for local use and tests only."""

    def __init__(self) -> None:
        self._items: dict[str, dict[str, Any]] = {}
        self._lock = threading.Lock()

    def get(self, item_id: str) -> dict[str, Any] | None:
        with self._lock:
            item = self._items.get(item_id)
            return dict(item) if item is not None else None

    def put(self, item_id: str, item: dict[str, Any]) -> None:
        with self._lock:
            self._items[item_id] = dict(item)

    def delete(self, item_id: str) -> None:
        with self._lock:
            self._items.pop(item_id, None)
