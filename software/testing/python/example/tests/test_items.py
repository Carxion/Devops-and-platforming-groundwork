"""Plain asserts, exceptions, and parametrize."""

from __future__ import annotations

import pytest

from pricing import Item, PricingError, subtotal


def test_line_total_is_price_times_quantity() -> None:
    # Arrange, act, assert: set up the input, call the code, check the result.
    item = Item("apple", unit_price_cents=50, quantity=3)

    result = item.total_cents

    assert result == 150


def test_subtotal_adds_every_line() -> None:
    items = [Item("apple", 50, 3), Item("pear", 75)]
    assert subtotal(items) == 225


def test_subtotal_of_nothing_is_zero() -> None:
    assert subtotal([]) == 0


# One test function, run once per row. Each row shows up as its own test,
# named by `ids`, so a failure says exactly which case broke.
@pytest.mark.parametrize(
    ("sku", "price", "quantity", "message"),
    [
        ("", 100, 1, "sku must not be empty"),
        ("apple", -1, 1, "price must not be negative"),
        ("apple", 100, 0, "quantity must be at least 1"),
    ],
    ids=["empty sku", "negative price", "zero quantity"],
)
def test_invalid_items_are_rejected(sku: str, price: int, quantity: int, message: str) -> None:
    # pytest.raises fails the test if the block doesn't raise; `match` checks the message.
    with pytest.raises(PricingError, match=message):
        Item(sku, price, quantity)


def test_items_are_immutable() -> None:
    item = Item("apple", 50)
    with pytest.raises(AttributeError):
        item.quantity = 5  # type: ignore[misc]


def test_floating_point_needs_approx() -> None:
    # Not about pricing (which uses whole cents precisely to avoid this), but the
    # classic trap: compare floats with pytest.approx, never ==.
    result = 0.1 + 0.2
    assert result != 0.3
    assert result == pytest.approx(0.3)
