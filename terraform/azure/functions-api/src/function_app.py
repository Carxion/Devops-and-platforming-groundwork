"""Minimal item store: HTTP-triggered functions backed by Cosmos DB.

Authenticates to Cosmos DB with the function app's managed identity
(DefaultAzureCredential); there are no keys or connection strings.
"""

import json
import os
import re

import azure.functions as func
from azure.cosmos import CosmosClient, exceptions
from azure.identity import DefaultAzureCredential

# Authentication happens before requests reach this code: set
# entra_client_id in Terraform to turn on App Service Authentication with
# Entra ID. Without it, this API is open to anyone.
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Matches the ItemId parameter in api-testing/openapi/items-api.yaml.
VALID_ID = re.compile(r"[A-Za-z0-9._-]{1,128}")
MAX_BODY = 256 * 1024  # bytes; well under the DynamoDB (400 KB) and Cosmos DB (2 MB) item limits

_container = (
    CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=DefaultAzureCredential())
    .get_database_client(os.environ["COSMOS_DATABASE"])
    .get_container_client(os.environ["COSMOS_CONTAINER"])
)


def _json(status, body=None):
    return func.HttpResponse(
        json.dumps(body) if body is not None else "",
        status_code=status,
        mimetype="application/json",
    )


@app.route(route="items/{id}", methods=["GET"])
def get_item(req: func.HttpRequest) -> func.HttpResponse:
    item_id = req.route_params["id"]
    if not VALID_ID.fullmatch(item_id):
        return _json(400, {"error": "invalid id"})
    try:
        item = _container.read_item(item=item_id, partition_key=item_id)
    except exceptions.CosmosResourceNotFoundError:
        return _json(404, {"error": "not found"})
    return _json(200, {k: v for k, v in item.items() if not k.startswith("_")})


@app.route(route="items/{id}", methods=["PUT"])
def put_item(req: func.HttpRequest) -> func.HttpResponse:
    item_id = req.route_params["id"]
    if not VALID_ID.fullmatch(item_id):
        return _json(400, {"error": "invalid id"})
    if len(req.get_body()) > MAX_BODY:
        return _json(413, {"error": "body too large"})
    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "body must be JSON"})
    if not isinstance(data, dict):
        return _json(400, {"error": "body must be a JSON object"})
    _container.upsert_item({**data, "id": item_id})
    return _json(200, {"id": item_id})


@app.route(route="items/{id}", methods=["DELETE"])
def delete_item(req: func.HttpRequest) -> func.HttpResponse:
    item_id = req.route_params["id"]
    if not VALID_ID.fullmatch(item_id):
        return _json(400, {"error": "invalid id"})
    try:
        _container.delete_item(item=item_id, partition_key=item_id)
    except exceptions.CosmosResourceNotFoundError:
        pass
    return _json(204)
