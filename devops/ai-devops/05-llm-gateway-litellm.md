# LLM gateway with LiteLLM

[← AI DevOps](README.md)

An LLM gateway is a proxy between your applications and every model provider. Applications send OpenAI-format requests to one endpoint with one kind of key; the gateway decides which provider and model serves them, enforces who may use what and how much, retries and falls back, and records every call. It's the platform team's control point for LLM usage, the way an API gateway or service mesh is for services.

[LiteLLM](https://docs.litellm.ai/) is an open source gateway (the proxy server; it's also a Python library). Everything below was run against `litellm/litellm:v1.108.9-lts` in the [lab](lab/README.md), with the configuration in [examples/litellm/config.yaml](examples/litellm/config.yaml).

## Why a gateway

| Without one | With one |
|---|---|
| Every application holds provider API keys | Providers' keys live in the gateway only; applications get virtual keys you can revoke |
| Switching provider or model is a code change in every application | It's a change to the gateway's config; applications keep asking for the same alias |
| No one knows the total spend until the invoice | Spend per key, team, and model, with budgets that stop requests |
| A provider outage takes the application down | The router retries and falls back to another deployment |
| Prompts and responses are logged inconsistently, or not at all | One place sends every call to tracing ([Langfuse](06-llm-observability-langfuse.md)) |

## Configuration: aliases, not models

Applications ask for an **alias** (`chat`); the config maps it to real deployments. Changing what serves `chat` is reviewed and deployed like any config change, and the [evaluation gate](07-evaluating-llm-apps.md) decides whether the new model is good enough:

```yaml
# Excerpt from examples/litellm/config.yaml
model_list:
  - model_name: chat                        # what applications ask for
    litellm_params:
      model: ollama_chat/qwen2.5:1.5b-instruct
      api_base: http://ollama:11434
  - model_name: chat-small                  # a cheaper model: the lab's eval gate rejects it
    litellm_params:
      model: ollama_chat/qwen2.5:0.5b-instruct
      api_base: http://ollama:11434
  # A hosted provider looks the same; the key comes from the environment:
  # - model_name: chat
  #   litellm_params:
  #     model: anthropic/claude-sonnet-5-5
  #     api_key: os.environ/ANTHROPIC_API_KEY

router_settings:
  fallbacks:
    - chat-primary: ["chat"]                # if chat-primary fails, try chat
  num_retries: 1
  timeout: 60

litellm_settings:
  callbacks: ["langfuse_otel"]              # every call to Langfuse, as OpenTelemetry
  redact_user_api_key_info: true

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL     # needed for virtual keys and spend
```

Two deployments with the same `model_name` are load-balanced, and a failure on one retries on the other. `os.environ/NAME` reads a secret at start-up, so the file itself holds none and can live in Git.

Calling it is any OpenAI client with a different base URL:

```sh
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LLM_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model": "chat", "messages": [{"role": "user", "content": "Say hello in three words."}]}'
```

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:4000", api_key=LLM_API_KEY)
client.chat.completions.create(model="chat", messages=[{"role": "user", "content": "Hi"}])
```

## Virtual keys and budgets

Virtual keys need the database ([docs](https://docs.litellm.ai/docs/proxy/virtual_keys)). Create one per application and environment, limited to the aliases it needs and with a budget, using the master key (which only the platform team and its automation hold):

```sh
curl -s http://localhost:4000/key/generate -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"models": ["chat"], "max_budget": 25, "key_alias": "ticket-triage-ci", "metadata": {"team": "support-tools"}}'
```

What the lab showed:

- **A model the key isn't allowed** returns HTTP 403.
- **Budgets stop requests once spend has passed them**, with HTTP 422 and `"type": "budget_exceeded"`. The check happens before each request, so the request that crosses the budget still succeeds; set budgets with that in mind.
- **Spend is written in batches.** Straight after a request, `/key/info` can still report `spend: 0.0` while enforcement already sees the new total. Don't build exact accounting on `/key/info` polling; use the spend logs and the tracing data.
- **Cost needs prices.** LiteLLM knows hosted providers' prices; for self-hosted models, set `input_cost_per_token` and `output_cost_per_token` in `model_info` (the lab's `chat-metered` alias has made-up prices so budgets have something to count).

Give **CI its own key**, with a small budget: evaluation runs call the model on every pipeline, and a loop in a test can spend a lot quickly. The [LLM app pipeline](examples/gitlab/llm-app/.gitlab-ci.yml) reads it from a masked CI/CD variable.

## Fallbacks and what the response tells you

Every response carries headers describing what the router did. From the lab, a request to `chat-primary` (a deployment that is always down) that fell back to `chat`:

```text
x-litellm-model-group: chat
x-litellm-attempted-fallbacks: 1
x-litellm-model-api-base: http://ollama:11434
x-litellm-response-cost-original: 0.0
x-litellm-key-spend: 0.0
x-litellm-attempted-retries: 0
x-litellm-version: 1.108.9
```

Fallbacks keep the application up, but a fallback model may be worse. Evaluate the fallback alias too, and alert when the fallback rate rises: it's an outage you're surviving, not one you can ignore.

## Running it in production

- **Pin an exact image.** LiteLLM releases very often. Its images include `-stable` and `-lts` builds alongside plain versions; pin one exact version (and the digest) and upgrade deliberately, rerunning your evaluations.
- **PostgreSQL** for keys and spend, backed up. Redis when you run more than one replica (shared rate limits, caching).
- **The master key is a root credential.** Store it in a secrets manager, and use it only from automation that creates keys.
- **Run it like any other critical service**: several replicas behind a load balancer, health checks on `/health/liveliness` and `/health/readiness`, and the latency it adds on your dashboards. Every application call now depends on it.
- **Egress**: the gateway is the only component that needs to reach model providers; applications need only reach the gateway.
- **Alternatives** do the same job: Portkey, Kong AI Gateway, Envoy AI Gateway, and the cloud providers' own (Amazon Bedrock, Azure API Management's AI gateway). Langfuse v4 also ships an AI gateway service. The design (aliases, virtual keys, budgets, fallbacks, one place for tracing) carries over.

## Next

[LLM observability with Langfuse](06-llm-observability-langfuse.md).
