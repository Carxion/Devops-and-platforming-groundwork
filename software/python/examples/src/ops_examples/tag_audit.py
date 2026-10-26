"""tag-audit: list AWS resources missing required tags.

    tag-audit --require Owner --require Environment
    tag-audit --require Owner --type ec2:instance --type s3:bucket --output csv > untagged.csv
    tag-audit --profile prod --region eu-west-1 --require CostCenter

Uses the Resource Groups Tagging API, which lists taggable resources across
services in one paginated call. Exits 1 if any resource is missing a tag, so
it can gate a pipeline or feed a weekly report. Credentials come from the
usual chain (environment, SSO profile, instance or pod role); none are
stored here.

Limitation: the Tagging API returns resources that have, or have had, tags.
A resource created without ever being tagged may not appear; AWS Config's
required-tags rule covers that case. The Azure equivalent is a Resource
Graph query (devops/azure/guides/cost.md#untagged-resources).
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections.abc import Iterator, Sequence
from dataclasses import asdict, dataclass
from typing import TYPE_CHECKING

import boto3
from botocore.exceptions import BotoCoreError, ClientError

if TYPE_CHECKING:
    from mypy_boto3_resourcegroupstaggingapi import ResourceGroupsTaggingAPIClient


@dataclass(frozen=True)
class Finding:
    arn: str
    service: str
    missing: list[str]


def resources(
    client: ResourceGroupsTaggingAPIClient, types: list[str]
) -> Iterator[tuple[str, dict[str, str]]]:
    """Yield (arn, tags) for every resource, following pagination."""
    paginator = client.get_paginator("get_resources")
    pages = paginator.paginate(ResourceTypeFilters=types) if types else paginator.paginate()
    for page in pages:
        for mapping in page["ResourceTagMappingList"]:
            tags = {t["Key"]: t.get("Value", "") for t in mapping.get("Tags", [])}
            yield mapping["ResourceARN"], tags


def audit(
    client: ResourceGroupsTaggingAPIClient, required: list[str], types: list[str]
) -> list[Finding]:
    findings = []
    for arn, tags in resources(client, types):
        # An empty value counts as missing: "Owner=" is no owner.
        missing = [key for key in required if not tags.get(key, "").strip()]
        if missing:
            service = arn.split(":")[2]  # arn:partition:service:region:account:resource
            findings.append(Finding(arn, service, missing))
    return findings


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="tag-audit", description=__doc__.splitlines()[0])
    parser.add_argument(
        "--require",
        action="append",
        required=True,
        metavar="KEY",
        help="a tag every resource must have (repeatable)",
    )
    parser.add_argument(
        "--type",
        action="append",
        default=[],
        metavar="SERVICE:TYPE",
        help="only these resource types, e.g. ec2:instance (repeatable)",
    )
    parser.add_argument("--profile")
    parser.add_argument("--region")
    parser.add_argument("-o", "--output", choices=["text", "json", "csv"], default="text")
    args = parser.parse_args(argv)

    try:
        session = boto3.Session(profile_name=args.profile, region_name=args.region)
        client = session.client("resourcegroupstaggingapi")
        findings = audit(client, args.require, args.type)
    except (BotoCoreError, ClientError) as err:
        # No credentials, an unknown profile, access denied: a configuration problem.
        print(f"tag-audit: {err}", file=sys.stderr)
        return 2

    if args.output == "json":
        print(json.dumps([asdict(f) for f in findings], indent=2))
    elif args.output == "csv":
        writer = csv.writer(sys.stdout)
        writer.writerow(["arn", "service", "missing"])
        for f in findings:
            writer.writerow([f.arn, f.service, ";".join(f.missing)])
    else:
        for f in findings:
            print(f"{f.service:<16} {f.arn}  missing: {', '.join(f.missing)}")
        print(f"{len(findings)} resource(s) missing required tags", file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
