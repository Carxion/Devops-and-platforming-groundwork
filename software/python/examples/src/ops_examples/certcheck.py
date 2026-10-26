"""certcheck: report TLS certificate expiry for a list of hosts.

    certcheck example.com example.org:8443 --warn-days 21
    certcheck --file hosts.txt --output json

Connects to each host, verifies the certificate chain and hostname the way a
client would, and reports the days until expiry. Exits 1 if any certificate
fails verification or expires within --warn-days, so it can run from cron or
CI and alert before an outage.
"""

from __future__ import annotations

import argparse
import json
import socket
import ssl
import sys
from collections.abc import Sequence
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import cast

# ssl's getpeercert() types every field loosely; these are the shapes it returns.
NameTuples = tuple[tuple[tuple[str, str], ...], ...]
SanTuples = tuple[tuple[str, str], ...]


@dataclass(frozen=True)
class Result:
    target: str
    ok: bool
    days_left: int | None = None
    expires: str | None = None
    issuer: str | None = None
    names: list[str] = field(default_factory=list)
    error: str | None = None


def parse_target(target: str) -> tuple[str, int]:
    """'host', 'host:port', or '[ipv6]:port' -> (host, port). Port defaults to 443."""
    if target.startswith("["):
        host, _, rest = target[1:].partition("]")
        return host, int(rest.lstrip(":") or 443)
    host, sep, port = target.rpartition(":")
    if sep and port.isdigit():
        return host, int(port)
    return target, 443


def _name(parts: NameTuples) -> str:
    """Turn ssl's nested name tuples into 'CN=..., O=...'."""
    return ", ".join(f"{k}={v}" for rdn in parts for k, v in rdn)


def check(
    target: str,
    *,
    warn_days: int = 21,
    timeout: float = 5.0,
    ca_file: str | None = None,
    now: datetime | None = None,
) -> Result:
    """Check one host. Never raises for network or certificate problems."""
    now = now or datetime.now(UTC)
    try:
        host, port = parse_target(target)
    except ValueError:
        return Result(target, ok=False, error="invalid target")

    # The default context verifies the chain against trusted CAs and checks
    # that the certificate matches the hostname: exactly what clients do.
    context = ssl.create_default_context(cafile=ca_file)
    try:
        with (
            socket.create_connection((host, port), timeout=timeout) as sock,
            context.wrap_socket(sock, server_hostname=host) as tls,
        ):
            cert = tls.getpeercert()
    except ssl.SSLCertVerificationError as err:
        # Expired, untrusted, or wrong hostname: report why.
        return Result(target, ok=False, error=f"verification failed: {err.verify_message}")
    except (OSError, ssl.SSLError) as err:
        return Result(target, ok=False, error=str(err))

    if not cert:
        return Result(target, ok=False, error="no certificate presented")
    expires = datetime.fromtimestamp(ssl.cert_time_to_seconds(str(cert["notAfter"])), UTC)
    days_left = (expires - now).days
    sans = cast(SanTuples, cert.get("subjectAltName", ()))
    names = [value for kind, value in sans if kind in ("DNS", "IP Address")]
    ok = days_left >= warn_days
    return Result(
        target,
        ok=ok,
        days_left=days_left,
        expires=expires.isoformat(),
        issuer=_name(cast(NameTuples, cert.get("issuer", ()))),
        names=names,
        error=None if ok else f"expires in {days_left} days (warning at {warn_days})",
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="certcheck", description=__doc__.splitlines()[0])
    parser.add_argument("targets", nargs="*", help="host, host:port, or [ipv6]:port")
    parser.add_argument("-f", "--file", type=Path, help="targets from a file, one per line")
    parser.add_argument(
        "-w", "--warn-days", type=int, default=21, help="fail within this many days"
    )
    parser.add_argument("-t", "--timeout", type=float, default=5.0)
    parser.add_argument("--ca-file", help="trust this CA bundle instead of the system's")
    parser.add_argument("-o", "--output", choices=["text", "json"], default="text")
    args = parser.parse_args(argv)

    targets = list(args.targets)
    if args.file:
        try:
            lines = args.file.read_text(encoding="utf-8").splitlines()
        except OSError as err:
            parser.error(str(err))
        targets += [t.strip() for t in lines if t.strip() and not t.startswith("#")]
    if not targets:
        parser.error("give at least one target, or --file")

    with ThreadPoolExecutor(max_workers=min(16, len(targets))) as pool:
        results = list(
            pool.map(
                lambda t: check(
                    t, warn_days=args.warn_days, timeout=args.timeout, ca_file=args.ca_file
                ),
                targets,
            )
        )

    if args.output == "json":
        print(json.dumps([asdict(r) for r in results], indent=2))
    else:
        for r in results:
            state = "OK  " if r.ok else "FAIL"
            detail = f"{r.days_left} days, until {r.expires}" if r.days_left is not None else ""
            print(f"{state}  {r.target}  {detail}  {r.error or ''}".rstrip())
    return 0 if all(r.ok for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
