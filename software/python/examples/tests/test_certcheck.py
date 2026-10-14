"""certcheck against a local TLS server with a certificate generated for the test."""

from __future__ import annotations

import socket
import ssl
import threading
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

from ops_examples import certcheck


def make_cert(tmp: Path, days: int) -> tuple[Path, Path]:
    """A self-signed certificate for localhost, valid for `days` from now."""
    key = ec.generate_private_key(ec.SECP256R1())
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "localhost")])
    now = datetime.now(UTC)
    cert = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(days=1))
        .not_valid_after(now + timedelta(days=days))
        .add_extension(x509.SubjectAlternativeName([x509.DNSName("localhost")]), critical=False)
        .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
        .sign(key, hashes.SHA256())
    )
    cert_path, key_path = tmp / f"cert-{days}.pem", tmp / f"key-{days}.pem"
    cert_path.write_bytes(cert.public_bytes(serialization.Encoding.PEM))
    key_path.write_bytes(
        key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
    )
    return cert_path, key_path


def serve_tls(cert: Path, key: Path) -> Iterator[int]:
    """Accept TLS connections on a free port until the test ends; yield the port."""
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert, key)
    listener = socket.create_server(("127.0.0.1", 0))
    listener.settimeout(0.2)
    port = listener.getsockname()[1]
    stop = threading.Event()

    def loop() -> None:
        while not stop.is_set():
            try:
                conn, _ = listener.accept()
            except TimeoutError:
                continue
            try:
                with context.wrap_socket(conn, server_side=True):
                    pass
            except (ssl.SSLError, OSError):
                pass  # the client rejected our certificate: expected in some tests

    thread = threading.Thread(target=loop, daemon=True)
    thread.start()
    yield port
    stop.set()
    thread.join()
    listener.close()


@pytest.fixture
def valid_server(tmp_path: Path) -> Iterator[tuple[int, Path]]:
    cert, key = make_cert(tmp_path, days=90)
    for port in serve_tls(cert, key):
        yield port, cert


@pytest.fixture
def expiring_server(tmp_path: Path) -> Iterator[tuple[int, Path]]:
    cert, key = make_cert(tmp_path, days=5)
    for port in serve_tls(cert, key):
        yield port, cert


@pytest.mark.parametrize(
    ("target", "expected"),
    [
        ("example.com", ("example.com", 443)),
        ("example.com:8443", ("example.com", 8443)),
        ("[2001:db8::1]:8443", ("2001:db8::1", 8443)),
        ("[2001:db8::1]", ("2001:db8::1", 443)),
    ],
)
def test_parse_target(target: str, expected: tuple[str, int]) -> None:
    assert certcheck.parse_target(target) == expected


def test_valid_certificate(valid_server: tuple[int, Path]) -> None:
    port, cert = valid_server
    result = certcheck.check(f"localhost:{port}", ca_file=str(cert))
    assert result.ok, result.error
    assert result.days_left is not None and 88 <= result.days_left <= 90
    assert result.names == ["localhost"]
    assert result.issuer == "commonName=localhost"


def test_expiring_certificate_fails(expiring_server: tuple[int, Path]) -> None:
    port, cert = expiring_server
    result = certcheck.check(f"localhost:{port}", ca_file=str(cert), warn_days=21)
    assert not result.ok
    assert result.error is not None and "expires in" in result.error


def test_untrusted_certificate_fails(valid_server: tuple[int, Path]) -> None:
    port, _ = valid_server
    result = certcheck.check(f"localhost:{port}")  # system CAs don't trust our test cert
    assert not result.ok
    assert result.error is not None and result.error.startswith("verification failed")


def test_connection_refused() -> None:
    with socket.create_server(("127.0.0.1", 0)) as s:
        port = s.getsockname()[1]
    result = certcheck.check(f"127.0.0.1:{port}", timeout=1)
    assert not result.ok and result.error


def test_main_exit_codes(
    valid_server: tuple[int, Path], capsys: pytest.CaptureFixture[str]
) -> None:
    port, cert = valid_server
    assert certcheck.main([f"localhost:{port}", "--ca-file", str(cert)]) == 0
    assert "OK" in capsys.readouterr().out
    assert certcheck.main([f"localhost:{port}", "--ca-file", str(cert), "-w", "365"]) == 1
