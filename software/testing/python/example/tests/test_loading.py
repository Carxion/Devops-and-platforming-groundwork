"""Files: tmp_path gives every test its own empty directory, deleted afterwards."""

from __future__ import annotations

from pathlib import Path

import pytest

from pricing import Item, PricingError, load_items


def write(path: Path, text: str) -> Path:
    path.write_text(text, encoding="utf-8")
    return path


def test_loads_every_row(tmp_path: Path) -> None:
    csv_file = write(
        tmp_path / "cart.csv", "sku,unit_price_cents,quantity\napple,50,3\npear,75,1\n"
    )
    assert load_items(csv_file) == [Item("apple", 50, 3), Item("pear", 75, 1)]


def test_bad_row_reports_file_and_line(tmp_path: Path) -> None:
    csv_file = write(
        tmp_path / "cart.csv", "sku,unit_price_cents,quantity\napple,50,3\npear,lots,1\n"
    )
    # The message is part of the behavior: a user has to be able to find the bad line.
    with pytest.raises(PricingError, match=r"cart\.csv line 3"):
        load_items(csv_file)


def test_missing_column_is_an_error(tmp_path: Path) -> None:
    csv_file = write(tmp_path / "cart.csv", "sku,quantity\napple,3\n")
    with pytest.raises(PricingError, match="line 2"):
        load_items(csv_file)


def test_missing_file_raises_os_error(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        load_items(tmp_path / "nope.csv")
