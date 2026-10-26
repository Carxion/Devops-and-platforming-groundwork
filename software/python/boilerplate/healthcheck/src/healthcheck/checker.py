"""The checking logic, kept separate from the command line so it's easy to test."""

from __future__ import annotations

import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class Result:
    """The outcome of checking one URL."""

    url: str
    ok: bool
    status: int | None
    elapsed_ms: int
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def check_url(url: str, *, timeout: float = 5.0, expect_status: int = 200) -> Result:
    """GET one URL and report whether it returned the expected status in time.

    Never raises for network problems: they become a failed Result, so one bad
    endpoint can't stop the others from being checked.
    """
    if not url.startswith(("http://", "https://")):
        # urllib would also open file:// and other schemes; refuse them.
        return Result(url, ok=False, status=None, elapsed_ms=0, error="only http and https URLs")

    request = urllib.request.Request(url, headers={"User-Agent": "healthcheck/0.1"})  # noqa: S310
    start = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310 (scheme checked above)
            status = int(response.status)
    except urllib.error.HTTPError as err:
        # A 4xx or 5xx is still an answer; whether it's OK depends on expect_status.
        status = err.code
    except (urllib.error.URLError, TimeoutError, OSError) as err:
        reason = getattr(err, "reason", err)
        return Result(url, ok=False, status=None, elapsed_ms=_ms_since(start), error=str(reason))
    return Result(url, ok=status == expect_status, status=status, elapsed_ms=_ms_since(start))


def check_all(
    urls: list[str], *, timeout: float = 5.0, expect_status: int = 200, concurrency: int = 8
) -> list[Result]:
    """Check every URL with up to `concurrency` requests in flight; results keep the input order."""
    if not urls:
        return []
    workers = max(1, min(concurrency, len(urls)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        return list(
            pool.map(lambda u: check_url(u, timeout=timeout, expect_status=expect_status), urls)
        )


def _ms_since(start: float) -> int:
    return round((time.monotonic() - start) * 1000)
