# ticket-triage: an LLM application

[← AI DevOps](../../README.md)

Routes a support ticket to a team (billing, outage, account, other) with a language model. Small on purpose: the parts around the model call are the point. Walkthroughs: [the gateway](../../05-llm-gateway-litellm.md), [observability](../../06-llm-observability-langfuse.md), [evaluation](../../07-evaluating-llm-apps.md).

| File | Part |
|---|---|
| [prompts/ticket-triage.txt](prompts/ticket-triage.txt) | The prompt: the source of truth, reviewed like code |
| [src/ticket_triage/app.py](src/ticket_triage/app.py) | Fetch the `production` prompt from Langfuse (falling back to the file), call the gateway, parse the answer; traced |
| [src/ticket_triage/prompts.py](src/ticket_triage/prompts.py) | Publish the prompt as a new version under a label; promote a label or an exact version |
| [src/ticket_triage/experiment.py](src/ticket_triage/experiment.py) | The evaluation gate: a Langfuse experiment over the dataset, exit 1 below a threshold |
| [evals/dataset.jsonl](evals/dataset.jsonl) | Twelve labelled tickets |
| [tests/](tests/test_app.py) | Offline tests: parsing, the fallback prompt, what's sent to the model, the accuracy calculation |
| [../promptfoo/promptfooconfig.yaml](../promptfoo/promptfooconfig.yaml) | Assertion tests for the same prompt |
| [../gitlab/llm-app/.gitlab-ci.yml](../gitlab/llm-app/.gitlab-ci.yml) | Its pipeline |

## Run it

With the [lab](../../lab/README.md) up, and a virtual key from the gateway:

```sh
export LLM_BASE_URL=http://localhost:4000 LLM_API_KEY=<virtual key>
export LANGFUSE_BASE_URL=http://localhost:3300 LANGFUSE_PUBLIC_KEY=pk-lf-lab LANGFUSE_SECRET_KEY=sk-lf-lab
uv sync --frozen
uv run python -m ticket_triage.prompts publish --label staging
uv run python -m ticket_triage.experiment --label staging          # the gate
uv run python -m ticket_triage.prompts promote --from staging --to production
uv run python -m ticket_triage.app "I was charged twice this month."
# billing	I was charged twice this month.
```

`LLM_MODEL` picks the gateway alias (default `chat`; try `chat-small` to watch the gate fail), and `PROMPT_LABEL` the prompt label the app uses (default `production`). The offline tests need neither the gateway nor Langfuse: `uv run pytest`.
