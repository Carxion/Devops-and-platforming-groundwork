"""tag-audit against moto's in-memory AWS: no account or credentials needed."""

from __future__ import annotations

import json
from collections.abc import Iterator

import boto3
import pytest
from moto import mock_aws

from ops_examples import tag_audit


@pytest.fixture
def aws(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    # Fake credentials, so nothing can reach a real account even by accident.
    for key, value in {
        "AWS_ACCESS_KEY_ID": "testing",
        "AWS_SECRET_ACCESS_KEY": "testing",
        "AWS_DEFAULT_REGION": "us-east-1",
    }.items():
        monkeypatch.setenv(key, value)
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    with mock_aws():
        s3 = boto3.client("s3", region_name="us-east-1")
        buckets = {
            "tagged": [
                {"Key": "Owner", "Value": "platform"},
                {"Key": "Environment", "Value": "dev"},
            ],
            "no-env": [{"Key": "Owner", "Value": "platform"}],
            "empty-owner": [{"Key": "Owner", "Value": " "}, {"Key": "Environment", "Value": "dev"}],
        }
        for name, tags in buckets.items():
            s3.create_bucket(Bucket=name)
            s3.put_bucket_tagging(Bucket=name, Tagging={"TagSet": tags})  # type: ignore[typeddict-item]
        yield


def test_audit(aws: None) -> None:
    client = boto3.client("resourcegroupstaggingapi", region_name="us-east-1")
    findings = tag_audit.audit(client, ["Owner", "Environment"], ["s3:bucket"])
    missing = {f.arn: f.missing for f in findings}
    assert missing == {
        "arn:aws:s3:::no-env": ["Environment"],
        "arn:aws:s3:::empty-owner": ["Owner"],
    }
    assert all(f.service == "s3" for f in findings)


def test_main_json_and_exit_code(aws: None, capsys: pytest.CaptureFixture[str]) -> None:
    assert tag_audit.main(["--require", "Owner", "--output", "json"]) == 1
    out = json.loads(capsys.readouterr().out)
    assert [f["arn"] for f in out] == ["arn:aws:s3:::empty-owner"]


def test_main_reports_aws_errors(aws: None, capsys: pytest.CaptureFixture[str]) -> None:
    assert tag_audit.main(["--require", "Owner", "--profile", "does-not-exist"]) == 2
    assert "does-not-exist" in capsys.readouterr().err


def test_main_passes_when_compliant(aws: None, capsys: pytest.CaptureFixture[str]) -> None:
    assert tag_audit.main(["--require", "Owner", "--type", "ec2:instance"]) == 0
    assert "0 resource(s)" in capsys.readouterr().err
