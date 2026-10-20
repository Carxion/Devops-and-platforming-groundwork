"""Time: inject a clock instead of reading the real one."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from pricing import Discount, PricingError, apply_discount


def test_valid_code_takes_percent_off(codes: dict[str, Discount], clock: datetime) -> None:
    # `codes` and `clock` are fixtures from conftest.py: pytest passes them in by name.
    assert apply_discount(1000, "SAVE10", codes, clock=lambda: clock) == 900


def test_codes_are_case_insensitive(codes: dict[str, Discount], clock: datetime) -> None:
    assert apply_discount(1000, "save10", codes, clock=lambda: clock) == 900


def test_discount_rounds_down_to_whole_cents(codes: dict[str, Discount], clock: datetime) -> None:
    assert apply_discount(999, "SAVE10", codes, clock=lambda: clock) == 899  # 899.1 -> 899


def test_expired_code_is_refused(codes: dict[str, Discount], clock: datetime) -> None:
    with pytest.raises(PricingError, match="expired on 2026-01-01"):
        apply_discount(1000, "OLD20", codes, clock=lambda: clock)


def test_code_expires_at_exactly_its_expiry_time(codes: dict[str, Discount]) -> None:
    # Boundaries are where bugs live: test the moment before and the moment of.
    expiry = codes["SAVE10"].expires
    assert apply_discount(1000, "SAVE10", codes, clock=lambda: expiry - timedelta(seconds=1)) == 900
    with pytest.raises(PricingError, match="expired"):
        apply_discount(1000, "SAVE10", codes, clock=lambda: expiry)


def test_unknown_code_is_refused(codes: dict[str, Discount], clock: datetime) -> None:
    with pytest.raises(PricingError, match="unknown discount code: NOPE"):
        apply_discount(1000, "NOPE", codes, clock=lambda: clock)


def test_fixtures_are_fresh_for_every_test(codes: dict[str, Discount]) -> None:
    # Changing a fixture's value here can't leak into another test: each test
    # gets a new dict. That's what keeps tests independent of each other.
    codes["FREE"] = Discount(100, datetime(2030, 1, 1, tzinfo=UTC))
    assert len(codes) == 3
