# Language essentials

[← Python 101](README.md)

Enough Python to read and write real programs. Try each example in the interpreter (`uv run python`, or `python3`). The [official tutorial](https://docs.python.org/3/tutorial/) goes deeper on everything here.

## Values and types

```python
name = "web-01"                # str
port = 8080                    # int
load = 0.75                    # float
healthy = True                 # bool
owner = None                   # None: "no value"

print(type(port))              # <class 'int'>
print(f"{name}:{port}")        # f-string: web-01:8080
print(f"{load:.0%} busy")      # format spec: 75% busy
int("42"), str(42), float("1.5"), bool("")   # conversions; empty strings and zero are falsy
```

Variables don't have declared types; values do. Indentation (four spaces) defines blocks, so it isn't optional.

## Strings

```python
line = "  ERROR db timeout after 30s  "
line.strip()                   # remove surrounding whitespace
line.lower(), line.upper()
"ERROR" in line                # substring test: True
line.split()                   # ['ERROR', 'db', 'timeout', 'after', '30s']
",".join(["a", "b", "c"])      # 'a,b,c'
line.strip().startswith("ERROR")
"web-01.prod".removesuffix(".prod")   # 'web-01'
```

For patterns, the `re` module uses the same syntax as PCRE ([regular expressions](../../devops/bash/03-regex.md)):

```python
import re
m = re.search(r"after (\d+)s", line)
if m:
    seconds = int(m.group(1))  # 30
```

## Collections

```python
hosts = ["web-01", "web-02"]            # list: ordered, changeable
hosts.append("web-03")
hosts[0], hosts[-1], hosts[1:]          # first, last, slice
len(hosts)

point = (10, 20)                        # tuple: ordered, unchangeable
x, y = point                            # unpacking

tags = {"env": "prod", "team": "platform"}   # dict: key -> value
tags["owner"] = "alice"
tags.get("region", "unknown")           # default if the key is missing
for key, value in tags.items():
    print(key, value)

seen = {"web-01", "web-02"}             # set: unique, unordered
"web-01" in seen                        # fast membership test
```

## Control flow

```python
if load > 0.9:
    level = "critical"
elif load > 0.7:
    level = "warning"
else:
    level = "ok"

for i, host in enumerate(hosts):        # index and value
    print(i, host)

for host, port in zip(hosts, [80, 443, 8080]):   # walk two lists together
    print(host, port)

while retries < 3:
    retries += 1

match status:                           # structural pattern matching (3.10+)
    case 200 | 204:
        result = "ok"
    case 404:
        result = "missing"
    case code if code >= 500:
        result = "server error"
    case _:
        result = "other"
```

## Comprehensions

A concise way to build collections from other collections:

```python
ports = [80, 443, 8080, 9090]
high = [p for p in ports if p > 1024]               # [8080, 9090]
by_name = {h: len(h) for h in hosts}                # dict comprehension
unique_envs = {t["env"] for t in all_tags}          # set comprehension
total = sum(r["bytes"] for r in records)            # generator expression: no list built
```

Use them for simple transformations; switch to a `for` loop when the logic needs more than one line.

## Functions

```python
def check(url: str, timeout: float = 5.0, *, expect: int = 200) -> bool:
    """Return True if url answers with the expected status."""
    ...

check("https://example.com/")                   # defaults used
check("https://example.com/", 2.0, expect=204)  # arguments after * must be named
```

- **Type hints** (`url: str`, `-> bool`) aren't enforced at run time, but tools (mypy, editors) use them to catch mistakes. Use them on every function.
- **Never use a mutable default** like `def f(items=[])`: the same list is shared between calls. Use `None` and create it inside.
- `*args` and `**kwargs` collect extra positional and keyword arguments.

## Errors

```python
try:
    with open("/etc/app/config.json") as f:
        config = json.load(f)
except FileNotFoundError:
    config = {}                                  # handle what you expect
except json.JSONDecodeError as err:
    raise SystemExit(f"bad config: {err}") from err
else:
    print("loaded")                              # only if no exception
finally:
    print("always runs")
```

- **Catch specific exceptions,** never a bare `except:`, which also swallows Ctrl-C and real bugs.
- **Raise your own** with a clear message: `raise ValueError(f"port must be 1-65535, got {port}")`.
- `with` blocks (context managers) close files, connections, and locks even when an exception happens.

## Classes and dataclasses

For data, a **dataclass** writes the boilerplate for you:

```python
from dataclasses import dataclass, field

@dataclass(frozen=True)                 # frozen: immutable, hashable
class Endpoint:
    name: str
    url: str
    timeout: float = 5.0
    tags: list[str] = field(default_factory=list)   # mutable defaults need a factory

ep = Endpoint("api", "https://example.com/")
print(ep)                               # Endpoint(name='api', url='https://example.com/', timeout=5.0, tags=[])
```

Full classes, when you need behavior and state:

```python
class RateLimiter:
    def __init__(self, per_second: int) -> None:
        self.per_second = per_second
        self._tokens = per_second

    def allow(self) -> bool:
        if self._tokens > 0:
            self._tokens -= 1
            return True
        return False
```

Prefer functions and dataclasses; reach for classes when something genuinely holds state and behavior together.

## Modules and imports

```python
import json                             # a standard library module
from pathlib import Path                # one name from a module
from healthcheck.checker import check_url   # from your own package
```

A file is a module; a directory of modules (in a `src/` layout) is a package. Code that should run only when the file is executed, not imported, goes under:

```python
if __name__ == "__main__":
    main()
```

## Type hints in practice

```python
from collections.abc import Iterable

def total_bytes(records: Iterable[dict[str, int]]) -> int: ...
def find(name: str) -> Endpoint | None: ...      # may return None
Config = dict[str, str | int]                    # a type alias
```

Run `mypy --strict` (see [Projects and tooling](03-projects-and-tooling.md)): it catches `None` being used where a value is required, wrong argument types, and typos in attribute names, before the code runs.

## Idioms worth knowing

| Instead of | Write |
|---|---|
| `for i in range(len(items)): items[i]` | `for item in items:` (or `enumerate`) |
| `if len(items) == 0:` | `if not items:` |
| `if x == None:` | `if x is None:` |
| `open(...)` without closing | `with open(...) as f:` |
| String paths and `os.path.join` | `pathlib.Path`: `Path("/etc") / "app" / "config.json"` |
| `print` for diagnostics | `logging` ([Python for operations](02-python-for-operations.md#logging)) |
| `"%s:%d" % (h, p)` | f-strings: `f"{h}:{p}"` |
