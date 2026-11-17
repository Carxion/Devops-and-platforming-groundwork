# AI DevOps lab

[← AI DevOps](../README.md)

Everything the AI DevOps guides use, on one machine, in Docker Compose: a local model server, an LLM gateway in front of it, tracing and prompt management, and experiment tracking with a model registry. A check script exercises all of it and the examples.

| Service | Address | What it is |
|---|---|---|
| LiteLLM | <http://localhost:4000> (UI at `/ui`, master key `sk-lab-master-key`) | The [gateway](../05-llm-gateway-litellm.md), configured by [examples/litellm/config.yaml](../examples/litellm/config.yaml) |
| Langfuse | <http://localhost:3300> (`admin@example.com` / `lab-password`) | [Tracing, prompts, experiments](../06-llm-observability-langfuse.md); project keys `pk-lf-lab` / `sk-lf-lab` |
| MLflow | <http://localhost:5500> | [Tracking and registry](../02-data-and-training.md#tracking-experiments-with-mlflow) |
| Ollama | <http://localhost:11435> | Serves `qwen2.5:1.5b-instruct` (the `chat` alias) and `qwen2.5:0.5b-instruct` (`chat-small`) on the CPU |

Behind them: PostgreSQL (databases for Langfuse and LiteLLM), ClickHouse, Redis, and MinIO for Langfuse.

## Use

```sh
devops/ai-devops/lab/lab.sh up       # build the tools image, start everything, pull the models
devops/ai-devops/lab/lab.sh check    # run every check
devops/ai-devops/lab/lab.sh down     # stop and delete the data
```

Needs Docker with about 8 GB of free memory and 6 GB of disk. The first `up` downloads about 5 GB of images and 1.4 GB of models; after that it starts in about a minute. Ollama is on host port 11435, not its usual 11434, so it doesn't collide with an Ollama already running on your machine.

## What the check does

[`scripts/check_ai_devops_lab.py`](../../../scripts/check_ai_devops_lab.py) (standard library only; run it directly to pick scenarios, for example `python scripts/check_ai_devops_lab.py gateway tracing`):

| Scenario | Checks |
|---|---|
| `gateway` | LiteLLM is live; `chat` answers; `chat-primary` (always down) falls back to `chat`; a virtual key gets 403 for a model it isn't allowed and stops at its budget |
| `tracing` | Gateway requests arrive in Langfuse as generations with token usage |
| `llm-app` | ruff, mypy, and offline tests; the prompt is published as `staging`; the gate passes on `chat` and fails on `chat-small`; `production` moves to the new version; the app answers and its traces arrive |
| `promptfoo` | Passes on `chat`; exits 100 on `chat-small` |
| `training` | ruff, mypy, and tests; `dvc repro` against MLflow; the gate passes; register and promote; a weaker candidate (`dvc exp run -S train.C=0.001`) fails the gate; the champion loads by alias and `mlflow models serve` answers; the run carries the commit |
| `modelscan` | A clean pickle passes; a pickle that runs a command is CRITICAL |

The checks that run the examples use the tools image ([Dockerfile](Dockerfile)): uv with Python 3.14, git (DVC needs a repository), and modelscan in its own Python 3.12 environment. Downloads are cached in the `ai-devops-lab-uv-cache` volume.

## With the GitLab lab

`python scripts/check_gitlab_examples.py ai` runs the [example pipelines](../examples/gitlab/) in the [GitLab lab](../../gitlab/lab/README.md). It connects this lab's MLflow, LiteLLM, and Langfuse containers to the GitLab lab's network, so jobs reach them as `http://mlflow:5000`, `http://litellm:4000`, and `http://langfuse-web:3000`. Both labs together need about 14 GB of free memory.

## Lab only

Every key and password here is a fixed value in [compose.yaml](compose.yaml), every port is bound to `127.0.0.1`, and Langfuse telemetry is off. None of it is a production configuration: the guides say what production needs for each service.
