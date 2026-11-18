# LLM observability with Langfuse

[← AI DevOps](README.md)

Metrics and logs tell you a service is up. For an LLM application you also need to see **what it was asked, what it answered, which prompt and model produced the answer, how long it took, and what it cost**, per request, and to score answers so quality becomes a number you can watch. [Langfuse](https://langfuse.com/docs) is an open source platform for that: tracing, prompt management, evaluation scores, datasets, and experiments.

Checked with Langfuse v4 (`langfuse/langfuse:4.80.0`, self-hosted in the [lab](lab/README.md)) and the Python SDK 5.2.

## What it records

| Concept | What it is | In the lab |
|---|---|---|
| **Trace** | One request through your application, end to end | One call to `triage()` |
| **Observation** | A step inside it: a span, a **generation** (a model call, with tokens and cost), a tool call, a retrieval | The `triage` span; the gateway's `litellm_request` generation |
| **Session, user** | Traces grouped by conversation or user | |
| **Score** | A judgment on a trace: from a user (thumbs up), an evaluator, or an LLM judge | `correct` = 1 or 0, from the experiment |
| **Prompt** | A versioned prompt, with labels such as `production` and `staging` | `ticket-triage`, published by the pipeline |
| **Dataset, experiment** | Inputs with expected outputs, and runs of your application over them | [Evaluating LLM applications](07-evaluating-llm-apps.md) |

Tracing in Langfuse v4 is OpenTelemetry: the SDKs and integrations send OTLP to `/api/public/otel`. The [OpenTelemetry GenAI semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai) define the attribute names, so any OpenTelemetry-instrumented framework can send traces, and your existing [observability stack](../observability/README.md) can receive the same spans.

## Two places to trace from

**At the gateway**, every call from every application, with no application changes. LiteLLM's `langfuse_otel` callback ([config](examples/litellm/config.yaml)) with three environment variables:

```yaml
# The litellm service in lab/compose.yaml (excerpt)
environment:
  LANGFUSE_PUBLIC_KEY: pk-lf-lab
  LANGFUSE_SECRET_KEY: sk-lf-lab
  LANGFUSE_OTEL_HOST: http://langfuse-web:3000
```

Each request arrives as a `litellm_request` generation with the model, token usage, and cost. Requests the gateway refused (an exceeded budget) arrive too, without usage.

**In the application**, for what the gateway can't see: which prompt version was used, the steps around the model call (retrieval, parsing, tools), and business context (user, session). The [example app](examples/llm-app/src/ticket_triage/app.py):

```python
import langfuse.openai  # noqa: F401  (importing it instruments the OpenAI client)
from langfuse import get_client, observe
from openai import OpenAI


@observe(name="triage")
def triage(ticket: str) -> str:
    prompt = get_client().get_prompt("ticket-triage", label="production", fallback=LOCAL_PROMPT)
    response = OpenAI(base_url=LLM_BASE_URL, api_key=LLM_API_KEY).chat.completions.create(
        model="chat",
        messages=[{"role": "user", "content": prompt.compile(ticket=ticket)}],
        temperature=0,
        langfuse_prompt=None if prompt.is_fallback else prompt,  # links the generation to the prompt version
    )
    return parse(response.choices[0].message.content or "")
```

`langfuse_prompt` is read by the Langfuse wrapper and not sent to the model; the OpenAI SDK's type hints don't know it, so the example passes it through a `**kwargs` dict to keep mypy strict passing.

Configuration is environment variables: `LANGFUSE_BASE_URL`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`. Call `get_client().flush()` before a short-lived process exits (a CLI, a CI job), or the last spans are lost.

Doing both is normal: the gateway's view is complete and uniform, the application's is rich. To join them, pass a trace or session ID from the application to the gateway in request metadata.

## Prompt management: prompts as code

A prompt is a release artifact: changing it changes behavior as much as changing code. The example keeps the prompt in Git and uses Langfuse labels as the release mechanism, the same pattern as MLflow aliases ([prompts.py](examples/llm-app/src/ticket_triage/prompts.py)):

1. The prompt file ([prompts/ticket-triage.txt](examples/llm-app/prompts/ticket-triage.txt)) is reviewed in a merge request like code.
2. The pipeline publishes it as a new Langfuse version with a label for that pipeline: `staging` on the default branch, `mr-<iid>` on a merge request. `create_prompt` with an existing name adds a version.
3. The pipeline evaluates **that version** through the gateway.
4. A person plays `promote`, which moves `production` to the exact version number the pipeline published (passed between jobs as a dotenv artifact, not looked up by label, so a newer pipeline's `staging` can't slip in).
5. The application fetches `production`. Rolling back is moving the label back, with no deploy.

```sh
python -m ticket_triage.prompts publish --label staging          # ticket-triage version 3 is staging
python -m ticket_triage.experiment --label staging               # the evaluation gate
python -m ticket_triage.prompts promote --version 3 --to production
```

`get_prompt` caches prompts in the process (`cache_ttl_seconds`) and takes a `fallback`, so the application keeps working when Langfuse is unreachable; `prompt.is_fallback` says which was used. The example's offline tests point Langfuse at a closed port and assert the fallback works.

Keep using Git as the source of truth even though Langfuse's UI can edit prompts: edits in a UI skip review and the evaluation gate. Use the UI for experimenting, then copy the result into a merge request.

## Reading traces back

Langfuse v4 changed the read API. The v3 endpoints (`GET /api/public/traces`, `/observations`, `/sessions`) return an error on a default v4 deployment saying they aren't available in "events_only mode", Langfuse v4's default. Use the v2 observations endpoint, filtering by time and name:

```sh
curl -s -G -u pk-lf-lab:sk-lf-lab http://localhost:3300/api/public/v2/observations \
  --data-urlencode "fromStartTime=2026-11-16T00:00:00Z" \
  --data-urlencode "toStartTime=2026-11-17T00:00:00Z" \
  --data-urlencode "name=litellm_request" \
  --data-urlencode "fields=core,basic,model,usage"
```

The lab's check uses this to confirm the gateway's and the application's traces arrive. Prompts are read with `GET /api/public/v2/prompts/<name>?label=production`.

## Running Langfuse

Self-hosted Langfuse is two application containers (web and worker) and four backing services: PostgreSQL, ClickHouse (for traces), Redis or Valkey (queue and cache), and S3-compatible storage (raw events and media) ([self-hosting](https://langfuse.com/self-hosting)). Langfuse recommends at least 2 CPUs and 4 GB of memory for each container in production, and two or more web instances for availability ([containers](https://langfuse.com/self-hosting/deployment/infrastructure/containers)).

- **Headless setup:** the `LANGFUSE_INIT_*` variables create an organization, project, API keys, and user at start-up ([compose.yaml](lab/compose.yaml)), so environments are reproducible without clicking.
- **Every `CHANGEME` in the upstream Compose file matters**: `SALT`, `ENCRYPTION_KEY` (64 hex characters, `openssl rand -hex 32`), `NEXTAUTH_SECRET`, and the database passwords. The lab uses fixed values; production takes them from a secrets manager.
- **Traces contain your users' data.** Prompts and completions hold whatever users typed. Decide retention, restrict access to the project, and mask personal data before it's sent (the SDK supports a masking function) where you need to. See [Security and governance](09-security-and-governance.md).
- **Sampling:** at high volume, trace a percentage of requests and every error, rather than everything.
- **Alternatives:** Arize Phoenix and MLflow tracing (both open source, OpenTelemetry-based), Helicone, and LangSmith (proprietary).

## What to watch

The numbers that tell you an LLM application is healthy, beyond the usual service metrics:

| Signal | Why |
|---|---|
| Cost per request and per day, by model and key | Cost is a production metric here; a prompt change can double it |
| Tokens in and out per request | Rising input tokens mean growing prompts or context; rising output, verbose answers |
| Latency, including time to first token | Users feel time to first token in streaming UIs |
| Fallback and error rates at the gateway | An outage you're surviving |
| Score trends (user feedback, evaluator scores) | Quality drifts without any error |
| Answers that fail parsing | The model ignoring the format: the example's `parse()` maps them to `other`; count them |

## Next

[Evaluating LLM applications](07-evaluating-llm-apps.md).
