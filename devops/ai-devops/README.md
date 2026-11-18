# AI DevOps

[← DevOps](../README.md)

DevOps for systems with a model inside: training models in a pipeline (MLOps), and running applications on top of large language models (LLMOps). It covers the components of AI training and how to put each one into CI/CD, plus the tools a platform team runs around models: an LLM gateway ([LiteLLM](https://docs.litellm.ai/)), tracing and prompt management ([Langfuse](https://langfuse.com/docs)), experiment tracking and a model registry ([MLflow](https://mlflow.org/docs/latest/ml/)), data and pipeline versioning ([DVC](https://doc.dvc.org/)), evaluation ([promptfoo](https://www.promptfoo.dev/docs/intro/)), and model scanning (modelscan). Everything was run in the [lab](lab/README.md), and both pipelines ran end to end in the [GitLab lab](../gitlab/lab/README.md).

| Guide | Covers |
|---|---|
| [What AI DevOps is](01-what-ai-devops-is.md) | MLOps and LLMOps, the components of AI training, CI/CD/CT and the MLOps levels, the tools by job, and who does what |
| [Data and training](02-data-and-training.md) | Reproducibility, versioning data and pipelines with DVC, validating data, tracking experiments with MLflow, and hardware for training |
| [Models, registry, and supply chain](03-models-registry-and-supply-chain.md) | The model registry and aliases, safe model formats, scanning, provenance and signing, OCI packaging, ML-BOMs, and model cards |
| [CI/CD for ML](04-cicd-for-ml.md) | The training pipeline job by job, designing the release gate, continuous training, and where data and models live in CI |
| [LLM gateway with LiteLLM](05-llm-gateway-litellm.md) | Why a gateway, aliases, virtual keys and budgets, fallbacks, and running it in production |
| [LLM observability with Langfuse](06-llm-observability-langfuse.md) | Traces and generations, tracing from the gateway and the app, prompts as code with labels, the v4 read API, running Langfuse, and what to watch |
| [Evaluating LLM applications](07-evaluating-llm-apps.md) | Kinds of evaluation, datasets, a Langfuse experiment as the gate, promptfoo, the evaluation pipeline, red teaming, and RAG |
| [Serving and operating](08-serving-and-operating.md) | Serving registered models, choosing a serving stack, GPUs on Kubernetes, progressive model releases, drift monitoring, and cost |
| [Security and governance](09-security-and-governance.md) | The OWASP Top 10 for LLM Applications 2026, controls by layer, and the evidence governance frameworks ask for |

## Examples and lab

| Path | What it is |
|---|---|
| [examples/training](examples/training/README.md) | A training pipeline: DVC stages (prepare, validate, train, evaluate), a pandera data schema, MLflow tracking and registry, skops model files, and a release gate; 16 tests |
| [examples/llm-app](examples/llm-app/README.md) | A ticket-triage app calling a model through the gateway, traced with Langfuse, with prompts published and promoted by label and an evaluation gate run as a Langfuse experiment |
| [examples/promptfoo](examples/promptfoo/promptfooconfig.yaml) | Assertion tests for the same prompt, through the same gateway alias, including a prompt injection case |
| [examples/litellm](examples/litellm/config.yaml) | The gateway's configuration: aliases, a fallback, a priced alias for budgets, and tracing to Langfuse |
| [examples/gitlab](examples/gitlab/) | The two pipelines: [training](examples/gitlab/training/.gitlab-ci.yml) (test, train and gate, register, promote) and [llm-app](examples/gitlab/llm-app/.gitlab-ci.yml) (test, publish the prompt, evaluate, promote) |
| [lab/](lab/README.md) | Ollama, LiteLLM, Langfuse, and MLflow in Docker Compose, with [a check](../../scripts/check_ai_devops_lab.py) that exercises all of it |

## A suggested path

1. [What AI DevOps is](01-what-ai-devops-is.md), then start the [lab](lab/README.md) and run its check.
2. **Training models:** [Data and training](02-data-and-training.md), [Models and supply chain](03-models-registry-and-supply-chain.md), and [CI/CD for ML](04-cicd-for-ml.md), with the [training example](examples/training/README.md) open.
3. **LLM applications:** the [gateway](05-llm-gateway-litellm.md), [observability](06-llm-observability-langfuse.md), and [evaluation](07-evaluating-llm-apps.md), with the [LLM app](examples/llm-app/README.md) open.
4. Before production: [Serving and operating](08-serving-and-operating.md) and [Security and governance](09-security-and-governance.md).

It assumes the [GitLab CI/CD](../gitlab/README.md) guides, [Python](../../software/python/README.md), and [containers](../../software/containers/README.md).

## Checks

| Check | Runs |
|---|---|
| Both example projects: ruff, mypy (strict), and pytest, offline | `lab.sh check`, and by hand in each project (`uv sync --frozen && uv run pytest`) |
| The gateway: an alias answers, a failing deployment falls back, a virtual key is refused a model and stopped by its budget | [`lab.sh check`](lab/README.md) |
| Tracing: gateway and application traces arrive in Langfuse | The same |
| The LLM app: prompt published, gate passes on `chat` and fails on `chat-small`, `production` promoted, app answers | The same |
| promptfoo: passes on `chat`, exits 100 on `chat-small` | The same |
| Training: `dvc repro` against MLflow, gate passes, register and promote, a worse candidate fails the gate, the champion loads and serves by alias | The same |
| modelscan: a clean pickle passes, a malicious one is CRITICAL | The same |
| Both pipelines, every job, in GitLab, including the manual promotions and the merge request pipelines | `python scripts/check_gitlab_examples.py ai`, with both labs up |
| Markdown lint, spelling, links; ruff on both example projects; ShellCheck and shfmt on `lab.sh`; Hadolint on the tools image | CI ([lint.yml](../../.github/workflows/lint.yml)) |

> **Status.** Checked November 2026 with LiteLLM 1.108.9 (LTS image), Langfuse 4.80 (Python SDK 5.2), MLflow 3.18, DVC 3.67, scikit-learn 1.9, skops 0.16, pandera 0.36, promptfoo 0.125.1, modelscan 0.8.8, Ollama 0.40.16 with Qwen2.5 0.5B and 1.5B Instruct, and GitLab CE 19.5. Sources: each tool's documentation, linked where used; [Google Cloud's MLOps guidance](https://docs.cloud.google.com/architecture/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning); the [OWASP Top 10 for LLM Applications 2026](https://genai.owasp.org/resource/owasp-genai-llm-top-10-2026/); the [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework); and the [European Commission's AI Act page](https://digital-strategy.ec.europa.eu/en/policies/regulatory-framework-ai). These tools release often: recheck versions and rerun the checks before relying on a detail.
