"""Price a shopping cart: line items, expiring discount codes, and tax.

Written to be tested: everything that varies from run to run (the current
time, the tax service, files) comes in as an argument, so tests can supply
their own.
"""

from __future__ import annotations

import csv
import json
import os
import sys
import urllib.request
from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Protocol


class PricingError(ValueError):
    """Raised for invalid input: bad items, unknown or expired codes."""


@dataclass(frozen=True)
class Item:
    sku: str
    unit_price_cents: int
    quantity: int = 1

    def __post_init__(self) -> None:
        if not self.sku:
            raise PricingError("sku must not be empty")
        if self.unit_price_cents < 0:
            raise PricingError(f"{self.sku}: price must not be negative")
        if self.quantity < 1:
            raise PricingError(f"{self.sku}: quantity must be at least 1")

    @property
    def total_cents(self) -> int:
        return self.unit_price_cents * self.quantity


def subtotal(items: Iterable[Item]) -> int:
    """Sum of every line, in cents."""
    return sum(item.total_cents for item in items)


@dataclass(frozen=True)
class Discount:
    percent: int
    expires: datetime


# A clock is any function that returns the current time. Tests pass a fixed one.
Clock = Callable[[], datetime]


def system_clock() -> datetime:
    return datetime.now(UTC)


def apply_discount(
    amount_cents: int, code: str, codes: dict[str, Discount], clock: Clock = system_clock
) -> int:
    """Return the amount after the discount, rounded down to whole cents."""
    discount = codes.get(code.upper())
    if discount is None:
        raise PricingError(f"unknown discount code: {code}")
    if clock() >= discount.expires:
        raise PricingError(f"discount code {code} expired on {discount.expires:%Y-%m-%d}")
    return amount_cents * (100 - discount.percent) // 100


class TaxRates(Protocol):
    """Anything that can return a tax rate for a region: the real client or a fake."""

    def rate(self, region: str) -> float: ...


class HttpTaxRates:
    """Fetch tax rates from an HTTP service: GET {base_url}/rates/{region} -> {"rate": 0.08}."""

    def __init__(self, base_url: str, timeout: float = 5.0) -> None:
        if not base_url.startswith(("http://", "https://")):
            raise PricingError("base_url must be an http or https URL")
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def rate(self, region: str) -> float:
        url = f"{self.base_url}/rates/{region}"
        with urllib.request.urlopen(url, timeout=self.timeout) as response:  # noqa: S310 (scheme checked in __init__)
            body = json.load(response)
        rate = float(body["rate"])
        if not 0 <= rate < 1:
            raise PricingError(f"implausible tax rate for {region}: {rate}")
        return rate


def total(
    items: Sequence[Item],
    region: str,
    rates: TaxRates,
    code: str | None = None,
    codes: dict[str, Discount] | None = None,
    clock: Clock = system_clock,
) -> int:
    """Subtotal, minus any discount, plus tax, in cents (tax rounded half up)."""
    if not items:
        raise PricingError("cart is empty")
    amount = subtotal(items)
    if code:
        amount = apply_discount(amount, code, codes or {}, clock)
    tax = int(amount * rates.rate(region) + 0.5)
    return amount + tax


def load_items(path: Path) -> list[Item]:
    """Read items from a CSV file with the columns sku, unit_price_cents, quantity."""
    items = []
    with path.open(newline="", encoding="utf-8") as f:
        for line_number, row in enumerate(csv.DictReader(f), start=2):
            try:
                items.append(Item(row["sku"], int(row["unit_price_cents"]), int(row["quantity"])))
            except (KeyError, ValueError, TypeError) as err:
                raise PricingError(f"{path.name} line {line_number}: {err}") from err
    return items


def main(argv: Sequence[str] | None = None, rates: TaxRates | None = None) -> int:
    """pricing ITEMS.csv REGION: print the cart total. Tax rates come from $TAX_URL."""
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) != 2:
        print("usage: pricing ITEMS.csv REGION", file=sys.stderr)
        return 2
    try:
        rates = rates or HttpTaxRates(os.environ.get("TAX_URL", ""))
        cents = total(load_items(Path(args[0])), args[1], rates)
    except (PricingError, OSError) as err:
        print(f"pricing: {err}", file=sys.stderr)
        return 1
    print(f"{cents / 100:.2f}")
    return 0
