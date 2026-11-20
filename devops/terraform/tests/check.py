#!/usr/bin/env python3
"""Check the Terraform guides and examples against moto, a local fake AWS.

Usage: python devops/terraform/tests/check.py [--keep] [GUIDE ...]

Starts moto and a Terraform container on a private Docker network, then:

  examples  fmt, validate, and the offline tests for examples/modules/s3-bucket
            and examples/uploads; the uploads apply tests against moto; a full
            apply of uploads, where an uploaded file has to arrive on the
            queue; a clean re-plan; destroy; and the committed lock file.
  guides    every NN-*.md in devops/terraform, block by block, in order:

    ```hcl whose first line is "# <workspace>/<file>"
        written to that file (later blocks overwrite earlier ones)
    ```hcl whose first line is any other comment
        a fragment: must parse and be formatted (terraform fmt -check)
    ```sh whose first line is "# in <workspace>"
        run in that workspace; it must exit 0
    other blocks
        not run

  An HTML comment right before a block adds a check:
    <!-- check: fails -->                    the commands must exit non-zero
    <!-- check: output "regex" -->           the output must match (repeatable)
    <!-- check: matches examples/x/y.tf -->  the block must equal that file
    <!-- check: moto-skip "reason" -->       not run: moto can't do it (say why,
                                             and test it another way)

Commands run with TF_INPUT=0 and -auto-approve on apply and destroy, so the
guides can show plain "terraform apply". Every workspace that configures the
aws provider gets a moto_override.tf (path-style S3), and S3 backends get
use_path_style; moto is reset between guides. Needs Docker and network access
for provider downloads. GUIDE limits the run (for example 04-state.md);
"examples" alone runs just the examples. --keep leaves the containers running.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
TF_DIR = HERE.parent
REPO = TF_DIR.parent.parent

TERRAFORM_IMAGE = "hashicorp/terraform:1.16.5"
MOTO_IMAGE = "motoserver/moto:5.2.5"
MOTO_ACCOUNT = "123456789012"
NETWORK = "tf-basics-check"
TF = "tf-basics-terraform"
MOTO = "tf-basics-moto"
CACHE_VOLUME = "tf-basics-plugin-cache"
WORK = "/work"

ENV = {
    "AWS_ENDPOINT_URL": "http://moto:5000",
    "AWS_ACCESS_KEY_ID": "test",
    "AWS_SECRET_ACCESS_KEY": "test",  # moto accepts any credentials
    "AWS_DEFAULT_REGION": "us-east-1",
    "TF_PLUGIN_CACHE_DIR": "/cache",
    "TF_IN_AUTOMATION": "1",
    "TF_INPUT": "0",
    "TF_CLI_ARGS_apply": "-auto-approve",
    "TF_CLI_ARGS_destroy": "-auto-approve",
    # The guides copy files from the repository with "$GUIDEBOOK/...".
    "GUIDEBOOK": "/repo",
}

TFLINT_IMAGE = "ghcr.io/terraform-linters/tflint:v0.64.0"
CHECKOV_IMAGE = "bridgecrew/checkov:3.4.5"

ANSI = re.compile(r"\x1b\[[0-9;]*m")
FENCE = re.compile(r"^```(\S*)\s*$")
CHECK = re.compile(r"^<!--\s*check:\s*(.*?)\s*-->$")
FILE_HEADER = re.compile(
    r"^#\s+([\w.-]+)/([\w./-]+\.(?:tf|tfvars|hcl|tftest\.hcl|json))\s*$"
)
RUN_HEADER = re.compile(r"^#\s+in\s+([\w./-]+)\s*$")
PROVIDER_ALIAS = re.compile(r'provider\s+"aws"\s*\{(?P<body>[^}]*)\}', re.DOTALL)

failures = 0


def ok(msg: str) -> None:
    print(f"ok    {msg}", flush=True)


def fail(msg: str, output: str = "") -> None:
    global failures
    failures += 1
    print(f"FAIL  {msg}", flush=True)
    lines = [
        ln
        for ln in output.strip().splitlines()
        if "Still creating" not in ln
        and "Still destroying" not in ln
        and "Still modifying" not in ln
    ]
    for line in lines[-25:]:
        print(f"      | {line}", flush=True)


def run(args: list[str], stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        input=stdin,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def sh(script: str, cwd: str = WORK, stdin: str | None = None) -> tuple[int, str]:
    """Run a shell script in the Terraform container; return (code, output)."""
    args = ["docker", "exec", "-i", "-w", cwd]
    for key, value in ENV.items():
        args += ["-e", f"{key}={value}"]
    args += [TF, "sh", "-c", script]
    result = run(args, stdin=stdin)
    return result.returncode, ANSI.sub("", result.stdout + result.stderr)


def write_file(path: str, content: str) -> None:
    code, out = sh(f'mkdir -p "$(dirname "{path}")" && cat > "{path}"', stdin=content)
    if code:
        raise RuntimeError(f"could not write {path}: {out}")


def check(description: str, script: str, cwd: str = WORK) -> str:
    code, out = sh(script, cwd)
    if code == 0:
        ok(description)
    else:
        fail(description, out)
    return out


# --- containers ------------------------------------------------------------


def start() -> None:
    stop()
    run(["docker", "network", "create", NETWORK])
    run(["docker", "volume", "create", CACHE_VOLUME])
    tf = run(
        [
            "docker",
            "run",
            "-d",
            "--rm",
            "--name",
            TF,
            "--network",
            NETWORK,
            "-v",
            f"{REPO}:/repo:ro",
            "-v",
            f"{CACHE_VOLUME}:/cache",
            "--tmpfs",
            f"{WORK}:exec,mode=1777",
            "--entrypoint",
            "sleep",
            TERRAFORM_IMAGE,
            "infinity",
        ]
    )
    if tf.returncode:
        sys.exit(f"could not start the Terraform container:\n{tf.stderr}")
    code, out = sh("apk add --no-cache -q aws-cli curl jq >/dev/null")
    if code:
        sys.exit(f"could not prepare the Terraform container:\n{out}")
    moto = run(
        [
            "docker",
            "run",
            "-d",
            "--rm",
            "--name",
            MOTO,
            "--network",
            NETWORK,
            "--network-alias",
            "moto",
            # S3 Control calls go to <account>.<endpoint host>.
            "--network-alias",
            f"{MOTO_ACCOUNT}.moto",
            MOTO_IMAGE,
        ]
    )
    if moto.returncode:
        sys.exit(f"could not start moto:\n{moto.stderr}")
    code, out = sh(
        "for i in $(seq 30); do curl -sf -o /dev/null http://moto:5000/moto-api/ && break; sleep 1; done; "
        "aws sts get-caller-identity --query Account --output text && terraform version | head -1"
    )
    if code:
        sys.exit(f"moto did not answer:\n{out}")
    print(" ".join(out.split()), flush=True)


def stop() -> None:
    run(["docker", "rm", "-f", TF, MOTO])
    run(["docker", "network", "rm", NETWORK])


def reset_moto() -> None:
    sh("curl -sf -X POST -o /dev/null http://moto:5000/moto-api/reset")


def add_moto_overrides(ws: str) -> None:
    """Point each aws provider block at path-style S3, which moto needs."""
    code, out = sh(f"cat {ws}/*.tf 2>/dev/null | grep -v '^ *#' || true")
    text = out if code == 0 else ""
    blocks = []
    for match in PROVIDER_ALIAS.finditer(text):
        alias = re.search(r'alias\s*=\s*"([^"]+)"', match.group("body"))
        line = f'  alias             = "{alias.group(1)}"\n' if alias else ""
        blocks.append(f'provider "aws" {{\n{line}  s3_use_path_style = true\n}}\n')
    if blocks:
        write_file(f"{ws}/moto_override.tf", "\n".join(blocks))
    else:
        sh(f"rm -f {ws}/moto_override.tf")


# --- examples --------------------------------------------------------------


def check_examples() -> None:
    print("--- examples", flush=True)
    reset_moto()
    ex = f"{WORK}/examples"
    sh(f"rm -rf {ex} && cp -r /repo/devops/terraform/examples {ex}")
    module, uploads = f"{ex}/modules/s3-bucket", f"{ex}/uploads"

    check("examples are formatted", f"terraform fmt -check -recursive -diff {ex}")
    check(
        "s3-bucket: validate and offline tests",
        "terraform init -no-color >/dev/null && terraform validate -no-color && terraform test -no-color",
        module,
    )
    check(
        "uploads: the committed lock file is complete (init -lockfile=readonly)",
        "terraform init -backend=false -lockfile=readonly -no-color",
        uploads,
    )
    check(
        "uploads: validate and offline tests",
        "terraform validate -no-color && terraform test -no-color -filter=tests/plan.tftest.hcl",
        uploads,
    )

    add_moto_overrides(uploads)
    check(
        "uploads: apply tests against moto",
        "terraform test -no-color -filter=tests/apply.tftest.hcl",
        uploads,
    )

    # A full apply with local state, then use what it built.
    write_file(
        f"{uploads}/backend_override.tf", 'terraform {\n  backend "local" {}\n}\n'
    )
    sh("cp terraform.tfvars.example terraform.tfvars", uploads)
    check(
        "uploads: init and apply with the example tfvars",
        "terraform init -reconfigure -no-color >/dev/null && terraform apply -no-color",
        uploads,
    )
    check_replan(uploads)
    check(
        "uploads: a file uploaded under incoming/ arrives on the queue",
        """
        set -e
        bucket=$(terraform output -raw bucket_name)
        queue=$(terraform output -raw queue_url)
        # moto denies every request under the TLS-only bucket policy, even
        # over TLS (it doesn't set aws:SecureTransport), so drop the policy.
        aws s3api delete-bucket-policy --bucket "$bucket"
        echo hello > /tmp/hello.txt
        aws s3 cp /tmp/hello.txt "s3://$bucket/incoming/hello.txt" >/dev/null
        aws sqs receive-message --queue-url "$queue" --wait-time-seconds 5 --max-number-of-messages 10 \
          --query 'Messages[].Body' --output text > /tmp/messages
        # S3 URL-encodes the key in the event: incoming%2Fhello.txt
        grep -q '"configurationId": "created-incoming"' /tmp/messages
        grep -q 'hello.txt' /tmp/messages
        """,
        uploads,
    )
    check(
        "uploads: a file outside the prefixes does not",
        """
        set -e
        bucket=$(terraform output -raw bucket_name)
        queue=$(terraform output -raw queue_url)
        aws s3 cp /tmp/hello.txt "s3://$bucket/other/hello.txt" >/dev/null
        out=$(aws sqs receive-message --queue-url "$queue" --wait-time-seconds 2 --query 'Messages[].Body' --output text)
        ! printf '%s' "$out" | grep -q 'other'
        """,
        uploads,
    )
    check(
        "uploads: destroy removes everything",
        'terraform destroy -no-color >/dev/null && test -z "$(terraform state list)"',
        uploads,
    )
    lint_examples()


def lint_examples() -> None:
    """tflint and checkov, the commands 08-testing-and-checks.md shows."""
    tf_dir = str(TF_DIR)
    result = run(
        [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{tf_dir}:/data",
            "-w",
            "/data",
            "--entrypoint",
            "sh",
            TFLINT_IMAGE,
            "-c",
            "tflint --init >/dev/null && tflint --recursive --config /data/.tflint.hcl --chdir examples",
        ]
    )
    if result.returncode == 0:
        ok("examples: tflint (terraform and AWS rulesets)")
    else:
        fail(
            "examples: tflint (terraform and AWS rulesets)",
            result.stdout + result.stderr,
        )
    result = run(
        [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{tf_dir}/examples:/src",
            CHECKOV_IMAGE,
            "-d",
            "/src",
            "--framework",
            "terraform",
            "--compact",
            "--quiet",
        ]
    )
    if result.returncode == 0:
        ok("examples: checkov")
    else:
        fail("examples: checkov", result.stdout + result.stderr)


# moto doesn't return the default tags the provider sets on a new bucket, and
# returns an SQS redrive policy with different JSON spacing than SQS does. Both
# show up as in-place updates on the next plan, and the policies built from
# those resources become "known after apply". Anything else fails the check.
MOTO_GAPS = {
    "aws_s3_bucket": {"tags_all"},
    "aws_sqs_queue": {"redrive_policy"},
    "aws_sqs_queue_policy": {"policy"},
    "aws_iam_role_policy": {"policy"},
    "aws_s3_bucket_policy": {"policy"},
}


def check_replan(ws: str) -> None:
    description = "uploads: a second plan only updates what moto doesn't round-trip (no create, delete, or replace)"
    code, out = sh(
        "terraform plan -no-color -out=replan.tfplan >/dev/null && terraform show -json replan.tfplan",
        ws,
    )
    if code:
        fail(description, out)
        return
    plan = json.loads(out[out.index("{") :])
    problems = []
    for change in plan.get("resource_changes", []):
        actions = change["change"]["actions"]
        if actions in (["no-op"], ["read"]):
            continue
        if actions != ["update"]:
            problems.append(f"{change['address']}: {actions}")
            continue
        before, after = change["change"]["before"], change["change"]["after"]
        unknown = change["change"].get("after_unknown", {})
        changed = {
            k
            for k in set(before) | set(after)
            if before.get(k) != after.get(k) or unknown.get(k) is True
        }
        allowed = MOTO_GAPS.get(change["type"], set())
        if not changed <= allowed:
            problems.append(f"{change['address']}: {sorted(changed - allowed)}")
        elif "redrive_policy" in changed and json.loads(
            before["redrive_policy"]
        ) != json.loads(after["redrive_policy"]):
            problems.append(
                f"{change['address']}: redrive_policy differs in content, not just spacing"
            )
    if problems:
        fail(description, "\n".join(problems))
    else:
        ok(description)


# --- guides ----------------------------------------------------------------


@dataclass
class Block:
    lang: str
    lines: list[str]
    line_no: int
    checks: list[str] = field(default_factory=list)


def parse_blocks(text: str) -> list[Block]:
    blocks: list[Block] = []
    lines = text.splitlines()
    pending: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        directive = CHECK.match(line.strip())
        if directive:
            pending.append(directive.group(1))
            i += 1
            continue
        fence = FENCE.match(line)
        if fence:
            start = i + 1
            body: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                body.append(lines[i])
                i += 1
            blocks.append(Block(fence.group(1), body, start, pending))
            pending = []
        elif line.strip():
            pending = []
        i += 1
    return blocks


def check_guide(path: Path) -> None:
    rel = path.relative_to(REPO).as_posix()
    print(f"--- {rel}", flush=True)
    # One root for every guide: later guides use what earlier ones leave
    # running (the state bucket from 04-state.md).
    root = f"{WORK}/guides"
    sh(f"mkdir -p {root}")
    counts = {"files": 0, "fragments": 0, "runs": 0}

    for block in parse_blocks(path.read_text(encoding="utf-8")):
        where = f"{rel}:{block.line_no}"
        if not block.lines:
            continue
        first, content = block.lines[0], "\n".join(block.lines) + "\n"

        for directive in block.checks:
            if directive.startswith("matches "):
                target = TF_DIR / directive.removeprefix("matches ").strip()
                body = "\n".join(block.lines[1:]) + "\n"
                if not target.is_file():
                    fail(f"{where}: no such file {target.relative_to(REPO).as_posix()}")
                elif body != target.read_text(encoding="utf-8"):
                    fail(f"{where}: differs from {target.relative_to(REPO).as_posix()}")
                else:
                    ok(f"{where}: matches {target.relative_to(TF_DIR).as_posix()}")

        if block.lang == "hcl":
            header = FILE_HEADER.match(first)
            if header:
                write_file(f"{root}/{header.group(1)}/{header.group(2)}", content)
                counts["files"] += 1
            elif first.lstrip().startswith("#"):
                code, out = sh(
                    "terraform fmt -check -no-color - >/dev/null", stdin=content
                )
                counts["fragments"] += 1
                if code:
                    _, diff = sh("terraform fmt -no-color - ", stdin=content)
                    fail(
                        f"{where}: fragment does not parse or is not formatted",
                        out or diff,
                    )
            else:
                fail(
                    f"{where}: hcl block must start with '# <workspace>/<file>' or a comment"
                )
        elif block.lang in {"sh", "bash", "shell"}:
            header = RUN_HEADER.match(first)
            if not header:
                continue
            skip = next((d for d in block.checks if d.startswith("moto-skip")), None)
            if skip:
                reason = skip.removeprefix("moto-skip").strip().strip('"')
                print(
                    f"skip  {where}: {summarize(block.lines[1:])} ({reason})",
                    flush=True,
                )
                continue
            ws = f"{root}/{header.group(1)}"
            sh(f"mkdir -p {ws}")
            add_moto_overrides(ws)
            env = ""
            _, backend = sh(f"grep -ls 'backend \"s3\"' {ws}/*.tf || true")
            if backend.strip():
                env = 'export TF_CLI_ARGS_init="-backend-config=use_path_style=true"; '
            script = env + "set -e\n" + "\n".join(block.lines[1:])
            code, out = sh(script, ws)
            counts["runs"] += 1
            expect_fail = "fails" in block.checks
            label = f"{where}: {summarize(block.lines[1:])}"
            if expect_fail and code == 0:
                fail(f"{label} (expected a failure)", out)
                continue
            if not expect_fail and code != 0:
                fail(label, out)
                continue
            missing = [
                pattern
                for d in block.checks
                if d.startswith("output ")
                for pattern in [output_pattern(d)]
                if not re.search(pattern, out, re.MULTILINE)
            ]
            if missing:
                fail(f"{label} (output missing {missing})", out)
            else:
                ok(label)

    print(
        f"      {counts['files']} files, {counts['fragments']} fragments, {counts['runs']} command blocks",
        flush=True,
    )


def output_pattern(directive: str) -> str:
    """The regex in: output "regex" (\" inside it is a literal quote)."""
    text = directive.removeprefix("output ").strip()
    if len(text) >= 2 and text[0] == text[-1] == '"':
        text = text[1:-1]
    return text.replace('\\"', '"')


def summarize(lines: list[str]) -> str:
    commands = [
        ln.strip() for ln in lines if ln.strip() and not ln.strip().startswith("#")
    ]
    text = "; ".join(commands)
    return text if len(text) <= 90 else text[:87] + "..."


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--keep"]
    if any(a in {"-h", "--help"} for a in args):
        print(__doc__)
        return 0
    guides = sorted(TF_DIR.glob("[0-9][0-9]-*.md"))
    selected = [g for g in guides if not args or g.name in args]
    if args and not selected and args != ["examples"]:
        print(f"no guide matches {args}", file=sys.stderr)
        return 2

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    start()
    try:
        if not args or "examples" in args:
            check_examples()
        reset_moto()
        for guide in selected:
            check_guide(guide)
    finally:
        if "--keep" not in sys.argv:
            stop()
    print("all checks passed" if failures == 0 else f"{failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
