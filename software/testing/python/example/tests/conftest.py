"""Fixtures shared by every test file. pytest finds this file automatically."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from pricing import Discount

# One fixed moment for every test, so results never depend on when tests run.
NOW = datetime(2026, 10, 20, 12, 0, tzinfo=UTC)


class FakeRates:
    """A fake: a working, in-memory stand-in for the HTTP tax service.

    It also records which regions were asked for, so tests can check the call.
    """

    def __init__(self, rates: dict[str, float]) -> None:
        self.rates = rates
        self.calls: list[str] = []

    def rate(self, region: str) -> float:
        self.calls.append(region)
        return self.rates[region]


@pytest.fixture
def clock() -> datetime:
    """The fixed 'now'. Tests pass `lambda: clock` wherever a clock is needed."""
    return NOW


@pytest.fixture
def codes() -> dict[str, Discount]:
    """Discount codes: one valid, one expired. A fresh dict for every test."""
    return {
        "SAVE10": Discount(percent=10, expires=datetime(2026, 12, 31, tzinfo=UTC)),
        "OLD20": Discount(percent=20, expires=datetime(2026, 1, 1, tzinfo=UTC)),
    }


@pytest.fixture
def rates() -> FakeRates:
    return FakeRates({"CA": 0.0725, "OR": 0.0})
