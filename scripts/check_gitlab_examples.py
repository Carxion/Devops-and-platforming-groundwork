#!/usr/bin/env python3
"""Check the GitLab examples against a real GitLab: lint them, then run them.

Start the lab first (GitLab CE, a Docker-executor runner, and moto as a fake AWS):
  devops/gitlab/lab/lab.sh up

Then:
  python scripts/check_gitlab_examples.py               # everything
  python scripts/check_gitlab_examples.py lint python   # some scenarios

Scenarios, in the order they run:
  components  push examples/components as platform/ci-components; the main pipeline
              builds, scans, and pushes its test image; tag 1.0.0 creates a release
  python      the Items API (Python) with examples/python-service: every job passes on
              main, and a merge request gets one merge request pipeline, not a branch one
  go          the Items API (Go) with examples/go-service: every job passes on main
  terraform   devops/terraform/aws/network-vpc with examples/terraform against moto:
              a merge request plans; main plans, then the manual apply is played and passes
  lint        every .gitlab-ci.yml under devops/gitlab/examples, and every yaml block in
              devops/gitlab/*.md and devops/helm/*.md whose first line is "# .gitlab-ci.yml", through GitLab's
              CI Lint API with a simulated pipeline (dry run)

lint runs last because the snippets include the component release made by
components. Standard library only, plus git and docker on the PATH.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GITLAB = ROOT / "devops" / "gitlab"
EXAMPLES = GITLAB / "examples"
ENV_FILE = GITLAB / "lab" / ".env.lab"
URL = os.environ.get("GITLAB_URL", "http://127.0.0.1:8929")
IGNORE = shutil.ignore_patterns(
    ".terraform", ".mypy_cache", ".pytest_cache", ".ruff_cache", "__pycache__", ".venv", "*.tfstate*"
)
FINISHED = {"success", "failed", "canceled", "skipped", "manual"}
failures: list[str] = []


def token() -> str:
    if os.environ.get("GITLAB_TOKEN"):
        return os.environ["GITLAB_TOKEN"]
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("GITLAB_LAB_TOKEN="):
            return line.split("=", 1)[1]
    raise SystemExit(f"no token: set GITLAB_TOKEN or run devops/gitlab/lab/lab.sh up ({ENV_FILE})")


TOKEN = ""


def api(method: str, path: str, data: dict | None = None, ok404: bool = False):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(f"{URL}/api/v4{path}", data=body, method=method)
    req.add_header("PRIVATE-TOKEN", TOKEN)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as err:
        if ok404 and err.code == 404:
            return None
        raise SystemExit(f"{method} {path}: {err.code} {err.read().decode()[:500]}") from err


def enc(path: str) -> str:
    return urllib.parse.quote(path, safe="")


def ok(msg: str) -> None:
    print(f"ok    {msg}", flush=True)


def fail(msg: str) -> None:
    print(f"FAIL  {msg}", flush=True)
    failures.append(msg)


# --- Projects and Git ---------------------------------------------------------


def ensure_group(path: str) -> int:
    group = api("GET", f"/groups/{enc(path)}", ok404=True)
    if group is None:
        group = api("POST", "/groups", {"name": path, "path": path, "visibility": "private"})
    return group["id"]


def ensure_project(path: str) -> dict:
    """Return the project, creating it (empty) if needed."""
    project = api("GET", f"/projects/{enc(path)}", ok404=True)
    if project is None:
        namespace, name = path.rsplit("/", 1)
        project = api(
            "POST",
            "/projects",
            {"name": name, "path": name, "namespace_id": ensure_group(namespace), "visibility": "private"},
        )
    return project


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-c", "core.autocrlf=false", "-c", "user.name=lab", "-c", "user.email=lab@example.com", *args],
        cwd=repo,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit(f"git {args[0]} failed: {result.stderr.replace(TOKEN, '***').strip()}")
    return result.stdout.strip()


def remote(path: str) -> str:
    host = URL.split("://", 1)[1]
    return f"http://root:{TOKEN}@{host}/{path}.git"


def push_tree(path: str, sources: list[tuple[Path, str]], branch: str = "main", message: str = "update") -> str:
    """Replace the branch's contents with sources ([(file or dir, destination)]); return the new SHA."""
    work = Path(tempfile.mkdtemp(prefix="gl-check-"))
    try:
        git(work, "init", "-q", "-b", branch)
        # Commit on top of what's there: the default branch is protected, so no force pushes.
        if (
            subprocess.run(
                ["git", "fetch", "-q", remote(path), branch], cwd=work, capture_output=True, check=False
            ).returncode
            == 0
        ):
            git(work, "reset", "-q", "FETCH_HEAD")
            git(work, "rm", "-rq", "--cached", ".")
        for src, dest in sources:
            target = work / dest
            if src.is_dir():
                shutil.copytree(src, target, ignore=IGNORE, dirs_exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, target)
        git(work, "add", "-A")
        # --allow-empty: every run makes a new commit, so a new pipeline always runs.
        git(work, "commit", "-q", "--allow-empty", "-m", message)
        git(work, "push", "-q", remote(path), f"HEAD:refs/heads/{branch}")
        return git(work, "rev-parse", "HEAD")
    finally:
        shutil.rmtree(work, ignore_errors=True)


def commit_file(path: str, branch: str, start: str, file: str, content: str) -> str:
    """Create or update one file on a branch through the API; return the new SHA."""
    data = {
        "branch": branch,
        "commit_message": f"edit {file}",
        "actions": [{"action": "create", "file_path": file, "content": content}],
    }
    if api("GET", f"/projects/{enc(path)}/repository/branches/{enc(branch)}", ok404=True) is None:
        data["start_branch"] = start
    return api("POST", f"/projects/{enc(path)}/repository/commits", data)["id"]


def set_variable(path: str, key: str, value: str, **extra) -> None:
    project = enc(path)
    body = {"key": key, "value": value, "masked": False, **extra}
    if api("GET", f"/projects/{project}/variables/{key}", ok404=True) is None:
        api("POST", f"/projects/{project}/variables", body)
    else:
        api("PUT", f"/projects/{project}/variables/{key}", body)


def protect_branch(path: str, branch: str) -> None:
    project = enc(path)
    if api("GET", f"/projects/{project}/protected_branches/{enc(branch)}", ok404=True) is None:
        api("POST", f"/projects/{project}/protected_branches", {"name": branch})


# --- Pipelines ----------------------------------------------------------------


def pipelines_for(path: str, sha: str) -> list[dict]:
    return api("GET", f"/projects/{enc(path)}/pipelines?sha={sha}&per_page=20") or []


def wait_pipeline(path: str, sha: str, source: str | None = None, ref: str | None = None, timeout: int = 1800) -> dict:
    """Wait for the newest pipeline for a commit (optionally by source or ref) to finish."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        found = [
            p
            for p in pipelines_for(path, sha)
            if (source is None or p["source"] == source) and (ref is None or p["ref"] == ref)
        ]
        if found:
            pipeline = api("GET", f"/projects/{enc(path)}/pipelines/{found[0]['id']}")
            if pipeline["status"] in FINISHED:
                return pipeline
        time.sleep(10)
    raise SystemExit(f"{path}: pipeline for {sha[:8]} ({source or ref or 'any'}) didn't finish in {timeout}s")


def jobs(path: str, pipeline_id: int) -> dict[str, dict]:
    listed = api("GET", f"/projects/{enc(path)}/pipelines/{pipeline_id}/jobs?per_page=100&include_retried=false")
    return {j["name"]: j for j in listed}


def trace_tail(path: str, job_id: int, lines: int = 40) -> str:
    req = urllib.request.Request(f"{URL}/api/v4/projects/{enc(path)}/jobs/{job_id}/trace")
    req.add_header("PRIVATE-TOKEN", TOKEN)
    with urllib.request.urlopen(req, timeout=60) as r:
        text = r.read().decode(errors="replace")
    text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]|section_(start|end):\d+:\S+\r?", "", text)
    return "\n".join("      | " + line for line in text.splitlines()[-lines:])


def expect_jobs(path: str, pipeline: dict, expected: dict[str, str], label: str) -> dict[str, dict]:
    """Check each named job's status; print the log tail of any that doesn't match."""
    found = jobs(path, pipeline["id"])
    for name, status in expected.items():
        job = found.get(name)
        if job is None:
            fail(f"{label}: job {name} missing (have: {', '.join(sorted(found))})")
        elif job["status"] != status:
            fail(f"{label}: job {name} is {job['status']}, expected {status}")
            print(trace_tail(path, job["id"]), flush=True)
        else:
            ok(f"{label}: {name} {status}")
    extra = sorted(set(found) - set(expected))
    if extra:
        fail(f"{label}: unexpected jobs {extra}")
    return found


def play(path: str, job: dict) -> None:
    api("POST", f"/projects/{enc(path)}/jobs/{job['id']}/play")


def wait_job(path: str, job_id: int, timeout: int = 1200) -> dict:
    deadline = time.time() + timeout
    while time.time() < deadline:
        job = api("GET", f"/projects/{enc(path)}/jobs/{job_id}")
        if job["status"] in FINISHED - {"manual"}:
            return job
        time.sleep(10)
    raise SystemExit(f"{path}: job {job_id} didn't finish in {timeout}s")


def open_merge_request(path: str, branch: str) -> int:
    project = enc(path)
    for mr in api("GET", f"/projects/{project}/merge_requests?state=opened&source_branch={enc(branch)}"):
        return mr["iid"]
    return api(
        "POST",
        f"/projects/{project}/merge_requests",
        {"source_branch": branch, "target_branch": "main", "title": f"Check {branch}", "remove_source_branch": True},
    )["iid"]


def check_merge_request_flow(path: str, expected: dict[str, str], label: str) -> None:
    """A second push to a branch with an open merge request makes one MR pipeline and no branch pipeline."""
    branch = f"check-{int(time.time())}"
    commit_file(path, branch, "main", "CHANGE.md", "first change\n")
    open_merge_request(path, branch)
    sha = commit_file(path, branch, "main", f"CHANGE-{int(time.time())}.md", "second change\n")
    pipeline = wait_pipeline(path, sha, source="merge_request_event")
    time.sleep(15)  # give a (wrong) branch pipeline time to appear
    sources = sorted(p["source"] for p in pipelines_for(path, sha))
    if sources == ["merge_request_event"]:
        ok(f"{label}: one merge request pipeline for the push, no duplicate branch pipeline")
    else:
        fail(f"{label}: pipelines for the push have sources {sources}")
    expect_jobs(path, pipeline, expected, f"{label} (merge request)")


# --- Scenarios ----------------------------------------------------------------

COMPONENTS = "platform/ci-components"


def scenario_components() -> None:
    path = COMPONENTS
    ensure_project(path)
    project = enc(path)
    # Rerunnable: remove the previous release and tag before re-creating them.
    if api("GET", f"/projects/{project}/releases/1.0.0", ok404=True):
        api("DELETE", f"/projects/{project}/releases/1.0.0")
    if api("GET", f"/projects/{project}/repository/tags/1.0.0", ok404=True):
        api("DELETE", f"/projects/{project}/repository/tags/1.0.0")
    sha = push_tree(path, [(EXAMPLES / "components", ".")])
    pipeline = wait_pipeline(path, sha, source="push")
    expect_jobs(
        path,
        pipeline,
        {"test-image-build": "success", "test-image-scan": "success", "test-image-push": "success"},
        "components main",
    )
    api("POST", f"/projects/{project}/repository/tags", {"tag_name": "1.0.0", "ref": sha})
    tag_pipeline = wait_pipeline(path, sha, ref="1.0.0")
    expect_jobs(
        path,
        tag_pipeline,
        {
            "test-image-build": "success",
            "test-image-scan": "success",
            "test-image-push": "success",
            "create-release": "success",
        },
        "components tag 1.0.0",
    )
    if api("GET", f"/projects/{project}/releases/1.0.0", ok404=True):
        ok("components: release 1.0.0 exists")
    else:
        fail("components: release 1.0.0 wasn't created")


def check_reports(path: str, pipeline: dict, label: str) -> None:
    """Jobs passing isn't enough: GitLab must have parsed the reports, and the image must be in the registry."""
    project = enc(path)
    tests = api("GET", f"/projects/{project}/pipelines/{pipeline['id']}/test_report_summary")["total"]
    if tests["count"] > 0 and tests["failed"] == 0:
        ok(f"{label}: test report parsed ({tests['count']} tests)")
    else:
        fail(f"{label}: test report {tests}")
    coverage = api("GET", f"/projects/{project}/pipelines/{pipeline['id']}")["coverage"]
    if coverage:
        ok(f"{label}: coverage parsed ({coverage}%)")
    else:
        fail(f"{label}: no coverage on the pipeline")
    types = {a["file_type"] for j in jobs(path, pipeline["id"]).values() for a in j["artifacts"]}
    missing = {"junit", "codequality", "dotenv"} - types
    if missing:
        fail(f"{label}: missing report artifacts {sorted(missing)}")
    else:
        ok(f"{label}: junit, code quality, and dotenv reports uploaded")
    tag = pipeline["sha"][:8]
    repos = api("GET", f"/projects/{project}/registry/repositories?tags=true")
    if any(t["name"] == tag for r in repos for t in r.get("tags", [])):
        ok(f"{label}: image {tag} in the registry")
    else:
        fail(f"{label}: image {tag} not in the registry")


def scenario_service(language: str, source: Path, example: str, checks: list[str]) -> None:
    path = f"apps/items-api-{language}"
    ensure_project(path)
    sha = push_tree(path, [(source, "."), (EXAMPLES / example / ".gitlab-ci.yml", ".gitlab-ci.yml")])
    pipeline = wait_pipeline(path, sha, source="push")
    image_jobs = {"items-api-build": "success", "items-api-scan": "success"}
    expect_jobs(
        path,
        pipeline,
        {**{j: "success" for j in checks}, **image_jobs, "items-api-push": "success"},
        f"{language} main",
    )
    check_reports(path, pipeline, language)
    if language == "python":
        check_merge_request_flow(path, {**{j: "success" for j in checks}, **image_jobs}, language)


def scenario_python() -> None:
    scenario_service(
        "python",
        ROOT / "software" / "python" / "boilerplate" / "items-api",
        "python-service",
        ["lint", "typecheck", "test", "audit"],
    )


def scenario_go() -> None:
    scenario_service(
        "go",
        ROOT / "software" / "go" / "boilerplate" / "items-api",
        "go-service",
        ["vet", "lint", "test", "vulncheck"],
    )


def moto_bucket(name: str) -> None:
    """Create the state bucket in the lab's moto, from inside its own container."""
    script = (
        "import boto3; s3 = boto3.client('s3', endpoint_url='http://localhost:5000', region_name='us-east-1',"
        " aws_access_key_id='lab', aws_secret_access_key='lab');"
        f" names = [b['Name'] for b in s3.list_buckets()['Buckets']];"
        f" '{name}' in names or s3.create_bucket(Bucket='{name}')"
    )
    result = subprocess.run(
        ["docker", "exec", "gitlab-lab-moto-1", "python", "-c", script], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        raise SystemExit(f"couldn't create the state bucket in moto: {result.stderr.strip()[-500:]}")


def scenario_terraform() -> None:
    path = "infra/network-vpc"
    ensure_project(path)
    moto_bucket("lab-tfstate")
    backend = """\
bucket         = "lab-tfstate"
key            = "network-vpc/terraform.tfstate"
region         = "us-east-1"
use_lockfile   = true
use_path_style = true  # moto; real S3 uses virtual-hosted style
"""
    inputs = """\
project            = "lab"
environment        = "lab"
region             = "us-east-1"
owner              = "platform-team"
availability_zones = ["us-east-1a", "us-east-1b"]
single_nat_gateway = true
"""
    settings = {
        # moto answers every AWS API, including AssumeRoleWithWebIdentity (it
        # doesn't validate the token). The web identity credential provider
        # ignores the global endpoint, so STS needs its own: without it, the
        # token goes to the real STS, which rejects it.
        "AWS_ENDPOINT_URL": "http://moto:5000",
        "AWS_ENDPOINT_URL_STS": "http://moto:5000",
        "AWS_REGION": "us-east-1",
        "AWS_PLAN_ROLE_ARN": "arn:aws:iam::123456789012:role/lab-gitlab-plan",
    }
    for key, value in settings.items():
        set_variable(path, key, value)
    for stale in [
        "TF_VAR_project",
        "TF_VAR_environment",
        "TF_VAR_region",
        "TF_VAR_owner",
        "TF_VAR_availability_zones",
        "TF_VAR_single_nat_gateway",
    ]:
        api("DELETE", f"/projects/{enc(path)}/variables/{stale}", ok404=True)
    set_variable(path, "TF_BACKEND_CONFIG", backend, variable_type="file")
    set_variable(path, "TF_VARS_FILE", inputs, variable_type="file")
    # Protected: only pipelines on protected branches (main) can read it.
    set_variable(path, "AWS_APPLY_ROLE_ARN", "arn:aws:iam::123456789012:role/lab-gitlab-apply", protected=True)

    stack = ROOT / "devops" / "terraform" / "aws" / "network-vpc"
    sha = push_tree(path, [(stack, "."), (EXAMPLES / "terraform" / ".gitlab-ci.yml", ".gitlab-ci.yml")])
    protect_branch(path, "main")
    pipeline = wait_pipeline(path, sha, source="push")
    checks = {"fmt": "success", "validate": "success", "test": "success", "kics-iac-sast": "success"}
    found = expect_jobs(path, pipeline, {**checks, "plan": "success", "apply": "manual"}, "terraform main")
    if pipeline["status"] != "manual":
        fail(f"terraform main: pipeline is {pipeline['status']}, expected manual (waiting for apply)")
    if "apply" in found and found["apply"]["status"] == "manual":
        play(path, found["apply"])
        job = wait_job(path, found["apply"]["id"])
        if job["status"] == "success":
            ok("terraform main: apply played and succeeded")
        else:
            fail(f"terraform main: apply is {job['status']}")
            print(trace_tail(path, job["id"]), flush=True)
    check_merge_request_flow(path, {**checks, "plan": "success"}, "terraform")


def gitlab_ci_blocks() -> list[tuple[str, str]]:
    """Every example pipeline, and every complete pipeline in the guides."""
    found = [
        (str(p.relative_to(ROOT)), p.read_text(encoding="utf-8")) for p in sorted(EXAMPLES.rglob(".gitlab-ci.yml"))
    ]
    for md in sorted(GITLAB.glob("*.md")) + sorted((ROOT / "devops" / "helm").glob("*.md")):
        for n, block in enumerate(
            re.findall(r"^```yaml\n(.*?)^```", md.read_text(encoding="utf-8"), re.DOTALL | re.MULTILINE), 1
        ):
            if block.startswith("# .gitlab-ci.yml"):
                found.append((f"{md.relative_to(ROOT)} block {n}", block))
    return found


def scenario_lint() -> None:
    path = "apps/lint-sandbox"
    ensure_project(path)
    project = enc(path)
    if api("GET", f"/projects/{project}/repository/branches/main", ok404=True) is None:
        push_tree(path, [(GITLAB / "lab" / "compose.yaml", "README.md")], message="sandbox")
    for name, content in gitlab_ci_blocks():
        # The component project's pipeline includes components from its own path,
        # so it lints there; everything else lints in the sandbox.
        target = enc(COMPONENTS) if "$CI_PROJECT_PATH/" in content else project
        result = api("POST", f"/projects/{target}/ci/lint", {"content": content, "dry_run": True, "ref": "main"})
        # A dry run simulates a push to main; rules that only match merge requests
        # or tags can leave no jobs, which is fine for linting.
        expected_empty = ["filtered out by workflow rules", "No stages / jobs"]
        if "merge_request_event" in content:
            # A pipeline of merge request jobs only is empty on a simulated push to main.
            expected_empty.append("resulting pipeline would have been empty")
        errors = [e for e in result["errors"] if not any(text in e for text in expected_empty)]
        if result["valid"] or (not errors and result["errors"]):
            ok(f"lint: {name}" + (f" (warnings: {result['warnings']})" if result["warnings"] else ""))
        else:
            fail(f"lint: {name}: {errors or result['errors']}")


SCENARIOS = {
    "components": scenario_components,
    "python": scenario_python,
    "go": scenario_go,
    "terraform": scenario_terraform,
    "lint": scenario_lint,
}


def main() -> int:
    global TOKEN
    # Job logs contain any characters; don't let a Windows console code page crash the report.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("scenarios", nargs="*", help=f"any of: {', '.join(SCENARIOS)} (default: all, in order)")
    args = parser.parse_args()
    unknown = sorted(set(args.scenarios) - set(SCENARIOS))
    if unknown:
        parser.error(f"unknown scenario(s): {', '.join(unknown)}")
    TOKEN = token()
    version = api("GET", "/version")
    print(f"GitLab {version['version']} at {URL}", flush=True)
    for name in args.scenarios or list(SCENARIOS):
        print(f"--- {name}", flush=True)
        SCENARIOS[name]()
    if failures:
        print(f"\n{len(failures)} failure(s)", flush=True)
        return 1
    print("\nall checks passed", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
