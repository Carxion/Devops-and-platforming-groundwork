# Security and governance

[← AI DevOps](README.md)

AI systems have the usual attack surface (credentials, dependencies, the network) plus their own: inputs that steer the model, models that can carry code, outputs that get trusted too much, and data that leaks through prompts and traces. And they increasingly come with obligations to show how they were built and tested. This guide maps both to controls the earlier guides implement.

## The risks

The [OWASP Top 10 for LLM Applications 2026](https://genai.owasp.org/resource/owasp-genai-llm-top-10-2026/) is the common reference. Its entries, with where this folder addresses each:

| ID | Risk | Controls here |
|---|---|---|
| LLM01:2026 | Prompt Injection | Treat all model input as untrusted; constrain output and validate it (the example parses to a fixed set of labels); an injection case in the [promptfoo tests](examples/promptfoo/promptfooconfig.yaml); red teaming |
| LLM02:2026 | Sensitive Information Disclosure | Don't put secrets or other users' data in prompts; mask personal data before tracing; per-application keys at the gateway |
| LLM03:2026 | Excessive Agency | Give tools and agents the least privilege; require a person to approve consequential actions; log every tool call in traces |
| LLM04:2026 | Supply Chain | Safe model formats, scanning, signing, pinned images and dependencies ([models and supply chain](03-models-registry-and-supply-chain.md)) |
| LLM05:2026 | Data and Model Poisoning | Validate and version training data ([data and training](02-data-and-training.md)); know where datasets and base models come from |
| LLM06:2026 | Unbounded Consumption | Budgets and rate limits per virtual key; `max_tokens` on requests; timeouts ([gateway](05-llm-gateway-litellm.md)) |
| LLM07:2026 | Misinformation | Evaluation against known answers; grounding answers in retrieved sources; showing users that answers can be wrong |
| LLM08:2026 | Hidden Context Exposure | Assume system prompts and hidden context can be extracted; keep secrets and authorization logic out of them |
| LLM09:2026 | Vector and Embedding Weaknesses | Apply access control to retrieval (users retrieve only documents they may read); validate what's ingested |
| LLM10:2026 | Improper Output Handling | Never pass model output to a shell, SQL, or HTML without the same validation and encoding as user input |

[MITRE ATLAS](https://github.com/mitre-atlas/atlas-data) is "a public knowledge base of adversary TTPs targeting AI systems", modeled on ATT&CK. Use it for threat modeling alongside the [security architecture](../../architect/04-security-architecture.md) guide.

## Controls by layer

**Identity and secrets**

- Provider keys live only in the gateway. Applications, CI, and people get virtual keys: scoped to aliases, with budgets, revocable one at a time.
- The gateway's master key, Langfuse's `ENCRYPTION_KEY` and `SALT`, and MLflow's database credentials are root credentials. Keep them in a secrets manager.
- CI reaches cloud storage (DVC remotes, artifact stores) with OIDC, not stored keys ([cloud access](../gitlab/06-variables-secrets-and-cloud-access.md)).

**Network**

- Only the gateway reaches model providers. Applications reach only the gateway.
- Langfuse, MLflow, and the gateway's admin UI are internal services behind SSO, never public. (The lab binds everything to `127.0.0.1` for the same reason.)

**Data**

- Prompts, completions, and traces contain whatever users typed. Classify them like the most sensitive data users might enter, set retention in Langfuse, and limit who can read projects.
- Check what your provider does with requests (training use, retention, region) and put it in the contract ([vendors and contracts](../../manager/08-budget-vendors-and-contracts.md)).
- Training data needs provenance and the right to use it. Record its source with its version (`dvc.lock` names the files; record where they came from).

**Models**

- Load only safe formats from anywhere you don't control; scan the rest; verify signatures before deploying ([supply chain](03-models-registry-and-supply-chain.md)).
- Only the pipeline registers models and only a reviewed promotion releases them, so every production model has a run, a commit, and a person behind it.

**Application**

- Validate model output before acting on it, exactly like user input.
- For agents and tool use: allowlist tools, scope their credentials to the minimum, and require confirmation for actions that change things.
- Red team before launch and on a schedule ([red teaming](07-evaluating-llm-apps.md#red-teaming)).

## Governance

Governance means you can answer, for any model in production: what is it for, what data trained it, how was it tested, who approved it, and how is it monitored? The pipelines in this folder produce that evidence as a side effect:

| Question | Where the answer is |
|---|---|
| Which model and prompt are in production? | MLflow `@champion`; Langfuse `production` label |
| What produced it? | The MLflow run: parameters, metrics, `git_commit`, `pipeline_url`; `dvc.lock` for data |
| How was it tested? | The pipeline's `train` (gate) or `evaluate` and `promptfoo` jobs, and the Langfuse experiment |
| Who released it, and when? | The `promote` job in the `production` environment's deployment history |
| How is it monitored? | Traces, scores, and drift reports ([serving and operating](08-serving-and-operating.md#monitoring-models-in-production)) |
| What is it for, and what are its limits? | The model card ([models](03-models-registry-and-supply-chain.md#model-cards)) |

Frameworks that ask for this, as of November 2026:

- **NIST AI Risk Management Framework** (AI RMF 1.0, NIST AI 100-1, January 2023): voluntary; its functions are Govern, Map, Measure, and Manage. NIST says it is being revised. The **Generative AI Profile** (NIST AI 600-1, July 2024) applies it to generative AI ([NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework)).
- **EU AI Act** (Regulation (EU) 2024/1689): obligations by risk level. Per the European Commission, prohibitions applied from 2 February 2025, obligations for general-purpose AI models from 2 August 2025, and most of the Act from 2 August 2026, with high-risk obligations for Annex III systems extended to 2 December 2027 and for Annex I products to 2 August 2028 by the AI Omnibus, which entered into force on 27 July 2026 ([Commission: AI Act](https://digital-strategy.ec.europa.eu/en/policies/regulatory-framework-ai)). Whether and how it applies to you is a question for your legal team; the evidence above is what they'll ask for.
- **ISO/IEC 42001** (AI management systems) is the certifiable standard some customers ask for. It expects the same records.

## Next

Back to the [AI DevOps index](README.md), or run the [lab](lab/README.md).
