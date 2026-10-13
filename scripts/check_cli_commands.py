#!/usr/bin/env python3
"""Check every `aws` and `az` command in the repository's Markdown code blocks.

Docs that tell people to run commands rot as CLIs change: operations get
renamed, flags disappear, extensions drop commands. This script extracts each
command from ```sh blocks and checks it against the installed CLIs:

  aws  service, operation, waiter, and every flag, against the AWS CLI command
       tables (AWS CLI v1 package with current botocore models). Commands that
       only exist in AWS CLI v2 (logs tail, s3 high-level commands, sso login)
       are checked against `aws <cmd> help` from a v2 binary.
  az   command path and every flag, against `az <cmd> -h`.
  --query  every JMESPath expression compiles.

It checks syntax, not behavior: a valid command can still do the wrong thing.

Usage:
  pip install awscli azure-cli    # versions pinned in .github/workflows/docs.yml
  az extension add --name resource-graph  (and the others listed in AZ_EXTENSIONS)
  python scripts/check_cli_commands.py [--only aws|az|query]

Environment:
  AWS_V2_BIN   path to an AWS CLI v2 executable (default: `aws` on PATH)
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AZ_EXTENSIONS = ["resource-graph", "log-analytics", "application-insights", "bastion", "serial-console", "load", "amg", "scheduled-query"]

AWS_GLOBAL_FLAGS = {
    "profile", "region", "output", "query", "no-cli-pager", "cli-binary-format", "max-items",
    "starting-token", "page-size", "no-paginate", "debug", "endpoint-url", "no-verify-ssl",
    "color", "cli-input-json", "cli-input-yaml", "generate-cli-skeleton", "cli-read-timeout",
    "cli-connect-timeout", "no-sign-request", "ca-bundle",
}
# Present only in AWS CLI v2, or built outside v1's static argument tables.
AWS_V2_HELP = {
    ("logs", "tail"), ("sso", "login"), ("configure", "sso"),
    ("s3", "ls"), ("s3", "cp"), ("s3", "sync"), ("s3", "mv"), ("s3", "rm"), ("s3", "presign"),
}
SKIP_DIRS = {".venv", "venv", "node_modules", ".terraform", ".git"}
QUERY = re.compile(r"""--query\s+("(?:[^"\\]|\\.)*"|'[^']*')""")

# Captured before importing awscli, which modifies the process environment.
CLEAN_ENV = {**os.environ, "AWS_PAGER": "", "AZURE_CORE_COLLECT_TELEMETRY": "false"}


def code_blocks():
    for path in sorted(ROOT.rglob("*.md")):
        if SKIP_DIRS.intersection(path.parts):
            continue
        text = path.read_text(encoding="utf-8")
        for block in re.findall(r"```(?:sh|bash|shell)?\n(.*?)```", text, re.S):
            yield path.relative_to(ROOT).as_posix(), re.sub(r"\\\n\s*", " ", block)


def commands(prefix: str):
    """Yield (file, tokens) for each `<prefix> ...` command, including inside $(...) and pipes."""
    for rel, block in code_blocks():
        for line in block.splitlines():
            line = line.split(" #")[0]
            for part in re.split(r"\$\(|\||;|&&|\)|\bdo\b|\bthen\b", line):
                part = part.strip()
                if not part.startswith(prefix + " "):
                    continue
                cleaned = part.replace("<", "").replace(">", "")  # placeholders such as <rg>
                try:
                    yield rel, shlex.split(cleaned)
                except ValueError:
                    yield rel, cleaned.split()


def check_aws() -> list[str]:
    from awscli.clidriver import create_clidriver

    table = create_clidriver()._get_command_table()
    v2 = os.environ.get("AWS_V2_BIN") or shutil.which("aws")
    v2_help: dict[tuple[str, str], str] = {}
    problems, count = [], 0

    for rel, toks in commands("aws"):
        if len(toks) < 3:
            continue
        svc, op = toks[1], toks[2]
        flags = [t[2:].split("=")[0] for t in toks[3:] if t.startswith("--")]
        flags = [f for f in flags if f not in AWS_GLOBAL_FLAGS]
        count += 1

        if (svc, op) in AWS_V2_HELP:
            if not v2:
                problems.append(f"{rel}: aws {svc} {op}: no AWS CLI v2 binary to check against (set AWS_V2_BIN)")
                continue
            if (svc, op) not in v2_help:
                out = subprocess.run([v2, svc, op, "help"], capture_output=True, env=CLEAN_ENV).stdout
                v2_help[(svc, op)] = out.decode("utf-8", "replace")
            problems += [f"{rel}: aws {svc} {op}: unknown flag --{f}" for f in flags if f"--{f}" not in v2_help[(svc, op)]]
            continue

        if svc not in table:
            problems.append(f"{rel}: aws: unknown service '{svc}'")
            continue
        service = table[svc]
        # Most services expose _get_command_table(); customized ones such as
        # `aws configure` expose subcommand_table instead.
        ops = service._get_command_table() if hasattr(service, "_get_command_table") else service.subcommand_table
        if op not in ops:
            problems.append(f"{rel}: aws {svc}: unknown operation '{op}'")
            continue
        cmd = ops[op]
        if op == "wait":
            waiter = toks[3] if len(toks) > 3 else ""
            if waiter not in cmd.subcommand_table:
                problems.append(f"{rel}: aws {svc} wait: unknown waiter '{waiter}'")
                continue
            cmd = cmd.subcommand_table[waiter]
        problems += [f"{rel}: aws {svc} {op}: unknown flag --{f}" for f in flags if f not in cmd.arg_table]

    print(f"aws: checked {count} commands")
    return problems


def check_az() -> list[str]:
    found: dict[str, set[tuple[str, str]]] = {}
    for rel, toks in commands("az"):
        words = []
        for t in toks[1:]:
            if not re.fullmatch(r"[a-z][a-z0-9-]*", t):
                break
            words.append(t)
        if words:
            flags = {t.split("=")[0] for t in toks[1 + len(words):] if re.match(r"^--?[a-zA-Z]", t)}
            found.setdefault(" ".join(words), set()).update((f, rel) for f in flags)

    def help_for(cmd: str):
        r = subprocess.run([sys.executable, "-m", "azure.cli", *cmd.split(), "-h"], capture_output=True, env=CLEAN_ENV)
        return cmd, r.returncode, (r.stdout + r.stderr).decode("utf-8", "replace")

    problems = []
    with cf.ThreadPoolExecutor(max_workers=8) as pool:
        for cmd, code, out in pool.map(help_for, sorted(found)):
            if code != 0 or "misspelled or not recognized" in out:
                files = sorted({rel for _, rel in found[cmd]}) or ["?"]
                problems.append(f"{files[0]}: az {cmd}: command not found")
                continue
            for flag, rel in sorted(found[cmd]):
                if not re.search(r"(?<![\w-])" + re.escape(flag) + r"(?![\w-])", out):
                    problems.append(f"{rel}: az {cmd}: unknown flag {flag}")

    print(f"az: checked {len(found)} distinct commands")
    return problems


def check_queries() -> list[str]:
    import jmespath

    problems, count = [], 0
    for rel, block in code_blocks():
        for line in block.splitlines():
            if "aws " not in line and "az " not in line:
                continue
            for m in QUERY.finditer(line):
                q = m.group(1)[1:-1].replace('\\"', '"').replace("\\`", "`")
                q = re.sub(r"\$\w+|\$\{\w+\}", "x", q)  # shell-interpolated values
                count += 1
                try:
                    jmespath.compile(q)
                except Exception as e:  # noqa: BLE001 - report any parse failure
                    problems.append(f"{rel}: invalid --query {q[:80]!r}: {e}")
    print(f"query: compiled {count} JMESPath expressions")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", choices=["aws", "az", "query"])
    args = parser.parse_args()

    checks = {"query": check_queries, "aws": check_aws, "az": check_az}
    problems = []
    for name, fn in checks.items():
        if args.only in (None, name):
            problems += fn()
    for p in sorted(set(problems)):
        print(f"  {p}")
    print("OK" if not problems else f"{len(set(problems))} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
