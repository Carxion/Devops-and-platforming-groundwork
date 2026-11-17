#!/usr/bin/env python3
"""Check the AI DevOps lab end to end.

Start the lab first (Ollama, LiteLLM, Langfuse, MLflow, and the tools image):
  devops/ai-devops/lab/lab.sh up

Then:
  python scripts/check_ai_devops_lab.py              # everything
  python scripts/check_ai_devops_lab.py gateway      # some scenarios

Scenarios, in the order they run:
  gateway    LiteLLM answers on an alias; a failing deployment falls back; a
             virtual key is refused a model it isn't allowed and stops at its budget
  tracing    the gateway's requests arrive in Langfuse as generations (OpenTelemetry)
  llm-app    examples/llm-app: lint, types, and offline tests; the prompt is published
             as "staging"; the evaluation gate passes on "chat" and fails on the
             smaller "chat-small"; "production" moves to the new version; the app's
             own traces arrive in Langfuse
  promptfoo  examples/promptfoo passes on "chat" and exits 100 on "chat-small"
  training   examples/training: lint, types, and tests; dvc repro against the MLflow
             server; the gate passes; the model is registered and promoted to
             champion; a worse candidate fails the gate; the champion loads by alias
  modelscan  a clean pickle passes and a pickle that runs a command is CRITICAL

Standard library only, plus docker on the PATH.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import UTC, datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXAMPLES = ROOT / "devops" / "ai-devops" / "examples"
NETWORK = "ai-devops-lab_default"
IMAGE = "ai-devops-lab-tools"
PROMPTFOO_IMAGE = (
    "ghcr.io/promptfoo/promptfoo:0.125.1"
    "@sha256:3ddd7be2b8b043a5c48f0df048b074396de8e60282b0a3b392c299c430b74134"
)
LITELLM = "http://127.0.0.1:4000"
LANGFUSE = "http://127.0.0.1:3300"
MLFLOW = "http://127.0.0.1:5500"
MASTER_KEY = "sk-lab-master-key"
LANGFUSE_AUTH = "Basic " + base64.b64encode(b"pk-lf-lab:sk-lf-lab").decode()
STARTED = datetime.now(UTC) - timedelta(minutes=1)
failures: list[str] = []


def ok(msg: str) -> None:
    print(f"  ok    {msg}")


def fail(msg: str) -> None:
    print(f"  FAIL  {msg}")
    failures.append(msg)


def check(condition: bool, msg: str, detail: str = "") -> None:
    if condition:
        ok(msg)
    else:
        fail(f"{msg}{': ' + detail if detail else ''}")


def http(
    method: str, url: str, data: dict | None = None, auth: str | None = None
) -> tuple[int, dict, dict]:
    """(status, JSON body, headers); never raises on an HTTP error status."""
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if auth:
        req.add_header("Authorization", auth)
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else {}, dict(r.headers)
    except urllib.error.HTTPError as err:
        raw = err.read()
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = {"raw": raw.decode(errors="replace")}
        return err.code, parsed, dict(err.headers)


def chat(key: str, model: str, text: str = "Say hello in three words.") -> tuple[int, dict, dict]:
    payload = {"model": model, "messages": [{"role": "user", "content": text}], "max_tokens": 20}
    return http("POST", f"{LITELLM}/v1/chat/completions", payload, f"Bearer {key}")


def new_key(**settings: object) -> str:
    status, body, _ = http("POST", f"{LITELLM}/key/generate", dict(settings), f"Bearer {MASTER_KEY}")
    if status != 200:
        raise SystemExit(f"could not create a LiteLLM key: {status} {body}")
    return str(body["key"])


def observations(name: str) -> list[dict]:
    """Langfuse v4 observations with this name since the check started."""
    query = urllib.parse.urlencode(
        {
            "fromStartTime": STARTED.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "toStartTime": (datetime.now(UTC) + timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "name": name,
            "fields": "core,basic,model,usage",
            "limit": "100",
        }
    )
    status, body, _ = http("GET", f"{LANGFUSE}/api/public/v2/observations?{query}", auth=LANGFUSE_AUTH)
    return list(body.get("data", [])) if status == 200 else []


def wait_observations(name: str, timeout: int = 90) -> list[dict]:
    deadline = time.time() + timeout
    while time.time() < deadline:
        found = observations(name)
        if found:
            return found
        time.sleep(5)
    return []


def host_path(path: Path) -> str:
    """A path Docker can mount (the Windows form under Git Bash)."""
    return str(path)


def tools(project: str, script: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    """Run a bash script in the tools container, in a writable copy of an example project."""
    args = ["docker", "run", "--rm", "--network", NETWORK, "-v", "ai-devops-lab-uv-cache:/tmp/uv-cache"]
    args += ["-v", f"{host_path(EXAMPLES / project)}:/src:ro"]
    for k, v in (env or {}).items():
        args += ["-e", f"{k}={v}"]
    copy = (
        "set -euo pipefail; mkdir -p /home/lab/work && cd /home/lab/work && "
        "tar -C /src --exclude=.venv --exclude=data --exclude=models --exclude=mlflow.db -cf - . | tar -xf - && "
        "uv sync -q --frozen && export PATH=$PWD/.venv/bin:$PATH && "
    )
    args += [IMAGE, "-c", copy + script]
    return subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False, env=_docker_env())


def _docker_env() -> dict[str, str]:
    env = dict(os.environ)
    env["MSYS_NO_PATHCONV"] = "1"  # Git Bash: don't rewrite /src and friends
    return env


def tail(proc: subprocess.CompletedProcess[str], lines: int = 15) -> str:
    out = (proc.stdout + proc.stderr).strip().splitlines()
    return "\n        ".join([""] + out[-lines:])


def scenario_gateway() -> None:
    status, _, _ = http("GET", f"{LITELLM}/health/liveliness")
    check(status == 200, "LiteLLM is live")

    status, body, _ = chat(MASTER_KEY, "chat")
    content = body.get("choices", [{}])[0].get("message", {}).get("content", "") if status == 200 else ""
    check(status == 200 and bool(content.strip()), "the 'chat' alias answers", f"{status} {body}")

    status, body, headers = chat(MASTER_KEY, "chat-primary")
    lowered = {k.lower(): v for k, v in headers.items()}
    check(
        status == 200
        and lowered.get("x-litellm-attempted-fallbacks") == "1"
        and lowered.get("x-litellm-model-group") == "chat",
        "a failing deployment falls back to 'chat'",
        f"{status} fallbacks={lowered.get('x-litellm-attempted-fallbacks')}",
    )

    key = new_key(models=["chat-metered"], max_budget=0.01, key_alias=f"check-{int(time.time())}")
    status, body, _ = chat(key, "chat")
    check(status in (401, 403), "a virtual key is refused a model it isn't allowed", f"{status}")

    statuses = []
    for _ in range(6):
        status, body, _ = chat(key, "chat-metered", "Write a haiku about pipelines.")
        statuses.append(status)
        if status != 200:
            break
    budget_hit = status != 200 and "budget" in json.dumps(body).lower()
    check(
        statuses[0] == 200 and budget_hit,
        "a virtual key stops at its budget",
        f"statuses {statuses}, last {body}",
    )


def scenario_tracing() -> None:
    found = wait_observations("litellm_request")
    generations = [o for o in found if o.get("type") == "GENERATION"]
    check(bool(generations), "gateway requests arrive in Langfuse as generations")
    with_usage = [o for o in generations if (o.get("usageDetails") or {}).get("total")]
    check(bool(with_usage), "the generations carry token usage")


def llm_env(key: str) -> dict[str, str]:
    return {
        "LLM_BASE_URL": "http://litellm:4000",
        "LLM_API_KEY": key,
        "LANGFUSE_BASE_URL": "http://langfuse-web:3000",
        "LANGFUSE_PUBLIC_KEY": "pk-lf-lab",
        "LANGFUSE_SECRET_KEY": "sk-lf-lab",
    }


def scenario_llm_app() -> None:
    env = llm_env(new_key(models=["chat", "chat-small"], key_alias=f"triage-{int(time.time())}"))
    proc = tools("llm-app", "ruff check -q && ruff format --check -q && mypy && pytest -q -p no:warnings")
    check(proc.returncode == 0, "llm-app: ruff, mypy, and offline tests pass", tail(proc))

    proc = tools("llm-app", "python -m ticket_triage.prompts publish --label staging", env)
    published = proc.stdout.strip().split()
    check(proc.returncode == 0, "the prompt is published as 'staging'", tail(proc))
    version = published[2] if len(published) > 2 else "?"

    proc = tools("llm-app", "python -m ticket_triage.experiment --label staging", env)
    check(proc.returncode == 0, "the evaluation gate passes on 'chat'", tail(proc))

    proc = tools("llm-app", "python -m ticket_triage.experiment --label staging", {**env, "LLM_MODEL": "chat-small"})
    check(proc.returncode == 1, "the evaluation gate fails on 'chat-small'", f"exit {proc.returncode}{tail(proc)}")

    proc = tools("llm-app", "python -m ticket_triage.prompts promote --from staging --to production", env)
    check(proc.returncode == 0, "'production' moves to the evaluated version", tail(proc))
    status, body, _ = http("GET", f"{LANGFUSE}/api/public/v2/prompts/ticket-triage?label=production", auth=LANGFUSE_AUTH)
    check(status == 200 and str(body.get("version")) == version, f"Langfuse serves version {version} as production", f"{status} {body.get('version')}")

    proc = tools("llm-app", "python -m ticket_triage.app 'I was charged twice this month.'", {**env, "PROMPT_LABEL": "production"})
    check(proc.returncode == 0 and proc.stdout.startswith("billing\t"), "the app routes a billing ticket", tail(proc))
    check(bool(wait_observations("triage")), "the app's own traces arrive in Langfuse")


def promptfoo(key: str, *extra: str) -> subprocess.CompletedProcess[str]:
    args = ["docker", "run", "--rm", "--network", NETWORK]
    args += ["-e", "OPENAI_BASE_URL=http://litellm:4000", "-e", f"OPENAI_API_KEY={key}"]
    args += ["-e", "PROMPTFOO_DISABLE_TELEMETRY=1", "-e", "PROMPTFOO_DISABLE_UPDATE=1"]
    args += ["-v", f"{host_path(EXAMPLES)}:/examples:ro", "-w", "/examples/promptfoo"]
    args += ["--entrypoint", "promptfoo", PROMPTFOO_IMAGE]
    args += ["eval", "-c", "promptfooconfig.yaml", "--no-cache", "--no-table", "--no-write", *extra]
    return subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False, env=_docker_env())


def scenario_promptfoo() -> None:
    key = new_key(models=["chat", "chat-small"], key_alias=f"promptfoo-{int(time.time())}")
    proc = promptfoo(key)
    check(proc.returncode == 0, "promptfoo passes on 'chat'", tail(proc))
    proc = promptfoo(key, "-r", "openai:chat:chat-small")
    check(proc.returncode == 100, "promptfoo exits 100 on 'chat-small'", f"exit {proc.returncode}{tail(proc)}")


def scenario_training() -> None:
    proc = tools("training", "ruff check -q && ruff format --check -q && mypy && pytest -q -p no:warnings")
    check(proc.returncode == 0, "training: ruff, mypy, and tests pass", tail(proc))

    model = f"wine-classifier-check-{int(time.time())}"
    env = {"MLFLOW_TRACKING_URI": "http://mlflow:5000", "MODEL_NAME": model, "CI_COMMIT_SHA": "lab-check"}
    script = """
git init -q . && git add -A && git commit -qm init
dvc repro -q
echo "status: $(dvc status -q && echo clean)"
rc=0; wine-model gate || rc=$?; echo "gate=$rc"
wine-model register && wine-model promote
# A deliberately weak candidate: far too much regularization.
dvc exp run -q -S train.C=0.001 >/dev/null
cat metrics.json
rc=0; wine-model gate || rc=$?; echo "weak-gate=$rc"
python - <<'EOF'
import mlflow, os, pandas as pd
mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
m = mlflow.pyfunc.load_model(f"models:/{os.environ['MODEL_NAME']}@champion")
x = pd.read_csv("data/test.csv").drop(columns=["target"]).head(3)
print("predictions", list(m.predict(x)))
EOF
# Serve the champion over REST, as in the serving guide, and call it.
(mlflow models serve -m "models:/$MODEL_NAME@champion" --env-manager local \
  --host 127.0.0.1 --port 8080 >serve.log 2>&1 &)
python - <<'EOF'
import json, time, urllib.request
import pandas as pd
for _ in range(60):
    try:
        urllib.request.urlopen("http://127.0.0.1:8080/ping")
        break
    except OSError:
        time.sleep(2)
x = pd.read_csv("data/test.csv").drop(columns=["target"]).head(2)
body = json.dumps({"dataframe_split": x.to_dict(orient="split", index=False)}).encode()
req = urllib.request.Request("http://127.0.0.1:8080/invocations", body, {"Content-Type": "application/json"})
print("served", urllib.request.urlopen(req).read().decode())
EOF
"""
    proc = tools("training", script, env)
    out = proc.stdout
    check("gate=0" in out, "dvc repro runs every stage and the gate passes", tail(proc))
    check("status: clean" in out, "dvc status is clean after repro", tail(proc))
    check("weak-gate=1" in out, "a worse candidate fails the gate against the champion", tail(proc, 25))
    check("predictions [" in out, "the champion loads from the registry by alias", tail(proc))
    check('served {"predictions": [' in out, "mlflow models serve answers for the champion", tail(proc))

    status, body, _ = http("GET", f"{MLFLOW}/api/2.0/mlflow/registered-models/alias?name={model}&alias=champion")
    version = body.get("model_version", {})
    check(status == 200 and version.get("version") == "1", "MLflow has @champion on version 1", f"{status} {body}")
    run_id = version.get("run_id", "")
    status, body, _ = http("GET", f"{MLFLOW}/api/2.0/mlflow/runs/get?run_id={run_id}")
    tags = {t["key"]: t["value"] for t in body.get("run", {}).get("data", {}).get("tags", [])}
    check(tags.get("git_commit") == "lab-check", "the run records the commit that produced it", f"{tags.get('git_commit')}")


def scenario_modelscan() -> None:
    script = """
cat > make.py <<'EOF'
import os, pickle
class Payload:
    def __reduce__(self):
        return (os.system, ("echo pwned",))
pickle.dump({"weights": [1, 2, 3]}, open("clean.pkl", "wb"))
pickle.dump(Payload(), open("evil.pkl", "wb"))
EOF
python make.py
rc=0; modelscan -p clean.pkl >/dev/null || rc=$?; echo "clean=$rc"
rc=0; modelscan -p evil.pkl -r json -o evil.json >/dev/null || rc=$?; echo "evil=$rc"
python -c "import json; print('critical=' + str(json.load(open('evil.json'))['summary']['total_issues_by_severity']['CRITICAL']))"
"""
    proc = tools("training", script)
    check("clean=0" in proc.stdout, "modelscan passes a clean pickle", tail(proc))
    check("evil=1" in proc.stdout and "critical=1" in proc.stdout, "modelscan flags a pickle that runs a command as CRITICAL", tail(proc))


SCENARIOS = {
    "gateway": scenario_gateway,
    "tracing": scenario_tracing,
    "llm-app": scenario_llm_app,
    "promptfoo": scenario_promptfoo,
    "training": scenario_training,
    "modelscan": scenario_modelscan,
}


def main() -> int:
    # Tool output includes emoji (MLflow's run links); don't die on a Windows console.
    sys.stdout.reconfigure(errors="replace")  # type: ignore[union-attr]
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scenarios", nargs="*", help=f"any of: {', '.join(SCENARIOS)} (default: all)")
    args = parser.parse_args()
    unknown = sorted(set(args.scenarios) - set(SCENARIOS))
    if unknown:
        parser.error(f"unknown scenario(s): {', '.join(unknown)}")
    for name in args.scenarios or list(SCENARIOS):
        print(f"{name}:")
        SCENARIOS[name]()
    if failures:
        print(f"\n{len(failures)} check(s) failed")
        return 1
    print("\nall checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
