"""Dependencies: a fake, a mock, and a real local server for the real client."""

from __future__ import annotations

import json
import threading
from collections.abc import Iterator
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import Mock

import pytest

from pricing import Discount, HttpTaxRates, Item, PricingError, total

from .conftest import FakeRates

# --- With a fake: the usual choice -------------------------------------------------


def test_total_adds_tax_for_the_region(rates: FakeRates) -> None:
    items = [Item("apple", 1000)]
    assert total(items, "CA", rates) == 1073  # 1000 + 72.5 tax, rounded half up
    assert rates.calls == ["CA"]  # the fake also records how it was used


def test_tax_applies_after_the_discount(
    rates: FakeRates, codes: dict[str, Discount], clock: datetime
) -> None:
    items = [Item("apple", 1000)]
    result = total(items, "CA", rates, code="SAVE10", codes=codes, clock=lambda: clock)
    assert result == 965  # 900 + 65.25 tax


def test_empty_cart_is_refused_before_calling_the_service(rates: FakeRates) -> None:
    with pytest.raises(PricingError, match="cart is empty"):
        total([], "CA", rates)
    assert rates.calls == []


# --- With a mock: when the interaction itself is what you're testing ----------------


def test_tax_service_is_asked_once_with_the_region() -> None:
    rates = Mock()
    rates.rate.return_value = 0.0
    total([Item("apple", 500)], "OR", rates)
    rates.rate.assert_called_once_with("OR")


def test_tax_service_failure_propagates() -> None:
    rates = Mock()
    rates.rate.side_effect = TimeoutError("tax service timed out")  # make the call raise
    with pytest.raises(TimeoutError):
        total([Item("apple", 500)], "OR", rates)


# --- The real client, against a real local server -----------------------------------
# The fake proves total() works; these prove HttpTaxRates really speaks HTTP.
# A local server on port 0 (any free port) keeps the test offline and fast.


class RatesHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        responses = {"/rates/CA": {"rate": 0.0725}, "/rates/XX": {"rate": 7.25}}
        body = responses.get(self.path)
        self.send_response(200 if body else 404)
        self.end_headers()
        if body:
            self.wfile.write(json.dumps(body).encode())

    def log_message(self, format: str, *args: object) -> None:
        pass  # keep test output quiet


@pytest.fixture
def tax_server() -> Iterator[str]:
    # A fixture with `yield`: code before it is setup, code after it is teardown,
    # which runs even when the test fails.
    server = ThreadingHTTPServer(("127.0.0.1", 0), RatesHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()


def test_http_client_reads_the_rate(tax_server: str) -> None:
    assert HttpTaxRates(tax_server).rate("CA") == pytest.approx(0.0725)


def test_http_client_rejects_an_implausible_rate(tax_server: str) -> None:
    with pytest.raises(PricingError, match="implausible tax rate"):
        HttpTaxRates(tax_server).rate("XX")


def test_http_client_requires_an_http_url() -> None:
    with pytest.raises(PricingError, match="http or https"):
        HttpTaxRates("file:///etc/passwd")
