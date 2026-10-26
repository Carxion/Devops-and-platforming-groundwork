"""A command-line entry point: arguments in, output and exit code out."""

from __future__ import annotations

from pathlib import Path

import pytest

from pricing import main

from .conftest import FakeRates


@pytest.fixture
def cart(tmp_path: Path) -> Path:
    path = tmp_path / "cart.csv"
    path.write_text("sku,unit_price_cents,quantity\napple,1000,1\n", encoding="utf-8")
    return path


def test_prints_the_total(cart: Path, rates: FakeRates, capsys: pytest.CaptureFixture[str]) -> None:
    # capsys captures what the code prints, so the test can check it.
    assert main([str(cart), "CA"], rates=rates) == 0
    assert capsys.readouterr().out == "10.73\n"


def test_wrong_arguments_print_usage(capsys: pytest.CaptureFixture[str]) -> None:
    assert main(["only-one-argument"]) == 2
    assert "usage: pricing" in capsys.readouterr().err


def test_errors_exit_1_with_a_message(
    tmp_path: Path, rates: FakeRates, capsys: pytest.CaptureFixture[str]
) -> None:
    assert main([str(tmp_path / "missing.csv"), "CA"], rates=rates) == 1
    assert capsys.readouterr().err.startswith("pricing: ")


def test_tax_url_comes_from_the_environment(
    cart: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    # monkeypatch changes the environment (or an attribute) for this test only,
    # and undoes it afterwards.
    monkeypatch.setenv("TAX_URL", "not-a-url")
    assert main([str(cart), "CA"]) == 1
    assert "http or https" in capsys.readouterr().err
