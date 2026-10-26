# Python for operations

[← Python 101](README.md)

The parts of Python that operations work uses every day: files, commands, structured data, HTTP, cloud SDKs, command-line interfaces, logging, and concurrency. Most of it is in the standard library. The [healthcheck boilerplate](boilerplate/healthcheck/) puts several of these together.

## Files and paths

```python
from pathlib import Path

config_dir = Path("/etc/app")
config = config_dir / "config.json"            # / joins paths
config.exists(), config.is_file(), config.suffix, config.stem, config.parent

text = config.read_text(encoding="utf-8")       # whole file
for line in config.open(encoding="utf-8"):      # line by line, for big files
    ...

Path("out").mkdir(parents=True, exist_ok=True)  # like mkdir -p
for log in Path("/var/log/app").glob("*.log"):  # rglob for recursive
    print(log, log.stat().st_size)
```

Write files atomically, so a crash never leaves half a file (the same idea as `write_file` in the [Bash library](../../devops/bash/scripts/lib/common.sh)):

```python
import os, tempfile

def write_atomic(path: Path, data: str) -> None:
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(data)
    os.replace(tmp, path)          # atomic rename on the same filesystem
```

## Running commands

```python
import subprocess

result = subprocess.run(
    ["systemctl", "is-active", "nginx"],   # a list: no shell, no quoting problems, no injection
    capture_output=True, text=True, timeout=10,
)
print(result.returncode, result.stdout.strip())

subprocess.run(["git", "pull"], check=True)   # check=True raises CalledProcessError on failure
```

**Never build commands as strings with `shell=True`** from any input you didn't write yourself: `subprocess.run(f"ping {host}", shell=True)` runs whatever a malicious `host` contains. Pass a list. If you need a pipeline, do the filtering in Python.

## JSON, YAML, CSV, and environment variables

```python
import csv, json, os

data = json.loads('{"name": "web-01", "tags": {"env": "prod"}}')
print(json.dumps(data, indent=2, sort_keys=True))

with open("hosts.csv", newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):                 # each row is a dict keyed by the header
        print(row["hostname"], row["ip"])

region = os.environ.get("AWS_REGION", "us-east-1")    # with a default
token = os.environ["API_TOKEN"]                        # KeyError if missing: fail early
```

YAML needs a library (`uv add pyyaml`). Always use `yaml.safe_load`, never `yaml.load`, which can construct arbitrary objects from untrusted input:

```python
import yaml
with open("values.yaml", encoding="utf-8") as f:
    values = yaml.safe_load(f)
```

## HTTP APIs

The standard library has `urllib.request` (the [healthcheck](boilerplate/healthcheck/src/healthcheck/checker.py) uses it, to stay dependency-free). For anything more, use `httpx` (or `requests`):

```python
import httpx

with httpx.Client(base_url="https://api.example.com", timeout=10.0,
                  headers={"Authorization": f"Bearer {token}"}) as client:
    response = client.get("/items/order-1001")
    response.raise_for_status()                # raise for 4xx and 5xx
    item = response.json()

    # Pagination: follow the cursor until there's no next page
    items, cursor = [], None
    while True:
        page = client.get("/items", params={"after": cursor} if cursor else None).json()
        items += page["items"]
        cursor = page.get("next")
        if not cursor:
            break
```

**Always set a timeout:** without one, a hung server hangs your script forever. Retry only idempotent requests, with backoff (the same pattern as [retry.sh](../../devops/bash/scripts/retry.sh)).

## Cloud SDKs

**AWS (boto3):** credentials come from the environment, the shared config (`aws configure sso`), or the instance or pod role. Never put keys in code.

```python
import boto3

session = boto3.Session(profile_name="sandbox", region_name="us-east-1")
ec2 = session.client("ec2")

# Paginators handle pagination for you
for page in ec2.get_paginator("describe_instances").paginate(
    Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
):
    for reservation in page["Reservations"]:
        for instance in reservation["Instances"]:
            tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
            print(instance["InstanceId"], tags.get("Owner", "UNTAGGED"))
```

**Azure:** `DefaultAzureCredential` tries managed identity, workload identity, environment variables, and your `az login` session in turn, so the same code works on a laptop and in the cloud with no secrets.

```python
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient

credential = DefaultAzureCredential()
client = ResourceManagementClient(credential, subscription_id)
for group in client.resource_groups.list():
    print(group.name, (group.tags or {}).get("Owner", "UNTAGGED"))
```

The [Azure Functions stack](../../devops/terraform/azure/functions-api/src/function_app.py) uses the same credential to reach Cosmos DB without keys; the [AWS Lambda handler](../../devops/terraform/aws/serverless-api/src/handler.py) uses boto3 with the function's role.

## Command-line interfaces

`argparse` is in the standard library and enough for most tools. See [healthcheck's cli.py](boilerplate/healthcheck/src/healthcheck/cli.py) for a complete example: positional arguments, typed options, choices, a `--version`, help text, and validation with `parser.error`.

Conventions worth following, the same as for [Bash scripts](../../devops/bash/04-scripting.md):

- **Results to stdout, logs and errors to stderr,** so output can be piped
- **Exit codes:** 0 success, 1 failure, 2 bad usage
- **`--help`** that explains every option, and a `--dry-run` for anything that changes things
- **Machine-readable output** (`--output json`) alongside human-readable text

Third-party libraries such as `click` and `typer` add subcommands and nicer help with less code, at the cost of a dependency.

## Logging

```python
import logging

log = logging.getLogger(__name__)          # one logger per module

def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    log.info("checking %d hosts", len(hosts))      # lazy formatting: arguments, not f-strings
    try:
        ...
    except OSError:
        log.exception("check failed")              # logs the stack trace too
```

For services, log JSON so log systems can parse fields (a library such as `python-json-logger` or `structlog`, or a custom `Formatter`), include a request or trace ID, and never log secrets ([observability](../../devops/observability/README.md#logs-that-help)).

## Doing things in parallel

| Work | Use | Why |
|---|---|---|
| Waiting on network or disk (HTTP calls, cloud APIs, SSH) | `concurrent.futures.ThreadPoolExecutor` | Threads release the interpreter lock while waiting, so I/O overlaps well |
| Heavy CPU (parsing huge files, compression) | `concurrent.futures.ProcessPoolExecutor` | Separate processes use several cores |
| Many thousands of concurrent connections | `asyncio` with async libraries (`httpx.AsyncClient`) | Lightweight, but every library in the path must be async |

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

with ThreadPoolExecutor(max_workers=8) as pool:
    futures = {pool.submit(check_url, url): url for url in urls}
    for future in as_completed(futures):       # handle results as they finish
        print(futures[future], future.result())
```

Bound the concurrency (as above): starting a thousand simultaneous requests overwhelms the target and your own machine.

## Dates and times

```python
from datetime import UTC, datetime, timedelta

now = datetime.now(UTC)                       # always timezone-aware, in UTC
now.isoformat()                               # '2026-10-13T08:00:01.123456+00:00'
yesterday = now - timedelta(days=1)
datetime.fromisoformat("2026-10-13T08:00:00+00:00")
```

Naive datetimes (without a time zone) cause bugs around daylight saving time and across servers. Use UTC everywhere internally; convert to local time only for display.
