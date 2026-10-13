"""Minimal item store behind API Gateway HTTP API (payload format 2.0)."""

import json
import os
import re
from decimal import Decimal

import boto3

# Matches the ItemId parameter in api-testing/openapi/items-api.yaml.
VALID_ID = re.compile(r"[A-Za-z0-9._-]{1,128}")
MAX_BODY = 256 * 1024  # bytes; well under the DynamoDB (400 KB) and Cosmos DB (2 MB) item limits

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def _json_default(value):
    # DynamoDB returns numbers as Decimal, which json can't serialize.
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    raise TypeError(f"{type(value).__name__} is not JSON serializable")


def _response(status, body=None):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body, default=_json_default) if body is not None else "",
    }


def handler(event, _context):
    method = event["requestContext"]["http"]["method"]
    item_id = event["pathParameters"]["id"]
    if not VALID_ID.fullmatch(item_id):
        return _response(400, {"error": "invalid id"})

    if method == "GET":
        item = table.get_item(Key={"pk": item_id}).get("Item")
        if not item:
            return _response(404, {"error": "not found"})
        # Same shape as the Azure stack: the key comes back as "id" (api-testing/openapi/items-api.yaml).
        item.pop("pk")
        return _response(200, {**item, "id": item_id})

    if method == "PUT":
        body = event.get("body") or ""
        if len(body.encode()) > MAX_BODY:
            return _response(413, {"error": "body too large"})
        try:
            data = json.loads(body, parse_float=Decimal)  # an empty body is invalid JSON, so it's rejected
        except json.JSONDecodeError:
            return _response(400, {"error": "body must be JSON"})
        if not isinstance(data, dict):
            return _response(400, {"error": "body must be a JSON object"})
        table.put_item(Item={**data, "pk": item_id})
        return _response(200, {"id": item_id})

    if method == "DELETE":
        table.delete_item(Key={"pk": item_id})
        return _response(204)

    return _response(405, {"error": "method not allowed"})
