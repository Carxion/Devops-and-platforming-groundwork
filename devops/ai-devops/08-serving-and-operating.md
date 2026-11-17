# Serving and operating

[← AI DevOps](README.md)

Getting a model to answer requests in production, releasing new versions safely, and keeping it healthy afterwards. Most of this is ordinary service operation: the [Kubernetes](../kubernetes/README.md), [Helm](../helm/README.md), and [observability](../observability/README.md) material applies. This guide covers what's different.

## Serving a registered model

The registry alias is the deployment pointer, so a serving process loads `models:/<name>@champion` at start-up. MLflow can serve any registered model behind a standard REST API; checked in the lab against the example's champion:

```sh
export MLFLOW_TRACKING_URI=http://localhost:5500
uv run mlflow models serve -m "models:/wine-classifier@champion" --env-manager local --port 8080
```

```sh
curl -s http://127.0.0.1:8080/invocations -H 'Content-Type: application/json' -d '{
  "dataframe_split": {
    "columns": ["alcohol", "malic_acid", "ash", "alcalinity_of_ash", "magnesium", "total_phenols",
                "flavanoids", "nonflavanoid_phenols", "proanthocyanins", "color_intensity", "hue",
                "od280_od315_of_diluted_wines", "proline"],
    "data": [[13.2, 1.78, 2.14, 11.2, 100, 2.65, 2.76, 0.26, 1.28, 4.38, 1.05, 3.4, 1050]]}}'
# {"predictions": [0]}
```

`--env-manager local` uses the current environment; without it MLflow builds one from the model's recorded requirements, which is slower but proves they're complete. For production, `mlflow models build-docker` builds an image for a model version. Build it in the pipeline, scan and push it like any image ([the container-image component](../gitlab/examples/components/README.md)), and deploy the image. Then "which model is in production" has two answers that must agree: the image tag and the alias. Pick one as the source of truth: either serve by alias (a restart picks up a promotion) or bake the version into the image (a promotion is a deploy).

## Choosing a serving stack

| Need | Options |
|---|---|
| Classical models (scikit-learn, XGBoost) behind REST | MLflow serving, BentoML, a small FastAPI service like the [Items API](../../software/python/boilerplate/items-api/README.md) |
| Many models on Kubernetes, with autoscaling and canaries | [KServe](https://kserve.github.io/website/) (an `InferenceService` custom resource), Seldon Core |
| High-throughput GPU inference, several frameworks | NVIDIA Triton Inference Server |
| Self-hosted LLMs | [vLLM](https://docs.vllm.ai/) (an OpenAI-compatible server: `vllm serve <model>`), Hugging Face TGI, SGLang |
| LLMs on a laptop or in a lab | Ollama, llama.cpp (the [lab](lab/README.md) uses Ollama; not a production server) |
| Hosted LLMs | The provider's API, behind your [gateway](05-llm-gateway-litellm.md) |

Self-hosted LLMs served with an OpenAI-compatible API (vLLM, TGI, Ollama) sit behind the gateway like any provider: add a deployment to the gateway's config, and applications don't change.

## GPUs on Kubernetes

- The [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html) installs the drivers, container toolkit, and device plugin, which "registers each GPU as a Kubernetes extended resource named `nvidia.com/gpu`". Pods ask for whole GPUs in `resources.limits`:

```yaml
# A container fragment: one GPU.
resources:
  limits:
    nvidia.com/gpu: 1
```

- **Dedicated GPU node pools**, tainted so only GPU workloads land there, and scaled to zero when idle. Model images are large (often 10 GB or more) and weights larger: pre-pull images, cache weights on a volume, and expect slow cold starts.
- **Sharing GPUs:** time-slicing or MIG (on supported GPUs) lets several small models share one. Measure: a GPU running one small model at 5% utilization is the most expensive line on the bill.
- **Autoscale on the right signal.** CPU is meaningless for GPU inference; scale on queue depth, requests in flight, or GPU utilization (KEDA, or KServe's own autoscaler).
- The [hardened workload defaults](../kubernetes/README.md) still apply; GPU workloads need no privileges beyond the device plugin's.

## Releasing a new model

A new model version is riskier than a new code version: it can be "correct" and still behave differently on real traffic. Release it progressively:

| Strategy | How | Tells you |
|---|---|---|
| **Shadow** | Send a copy of production requests to the new model; discard its answers; compare | How it behaves on real inputs, with no user impact |
| **Canary** | Send a small share of traffic to it; watch error, latency, and business metrics; widen or roll back | Whether it holds up for real users |
| **A/B test** | Split traffic to compare outcomes over time | Whether it's actually better, statistically |
| **Rollback** | Move the alias (or the prompt label, or the gateway mapping) back | |

KServe supports canary traffic splitting on an `InferenceService`; Argo Rollouts and service meshes do it for any service. For LLM applications, the gateway can split traffic between deployments of an alias, and a prompt label can point a share of users at a new version.

## Monitoring models in production

Beyond service health (the [golden signals](../observability/README.md)), watch whether the model is still right:

- **Input drift:** has the distribution of inputs moved away from the training data? Compare production features with the training set ([Evidently](https://docs.evidentlyai.com/) computes drift reports and test suites; run them on a schedule over logged inputs).
- **Prediction drift:** has the distribution of outputs moved? A classifier that suddenly predicts one class far more often is a signal even before labels arrive.
- **Performance, when labels arrive:** the real accuracy, once ground truth is known (often days later). This is the number the gate's floors protect.
- **For LLM applications:** scores, feedback, cost, and fallbacks ([LLM observability](06-llm-observability-langfuse.md#what-to-watch)).

Alert on drift the way you alert on an SLO: a sustained change, not a single spike. The response is usually retraining ([continuous training](04-cicd-for-ml.md#continuous-training)), so wire the alert to the pipeline.

## Cost

| Lever | Effect |
|---|---|
| Right-size the model | The lab's finding cuts both ways: a smaller model is cheaper *only* if it passes the evaluation |
| Batch offline work | Scoring overnight in batches costs a fraction of real-time serving |
| Quantize | 8-bit or 4-bit weights fit a model on a smaller GPU, usually with a small quality loss; evaluate it |
| Cache | Identical requests (common in classification and FAQ-style apps) can be answered from a cache at the gateway |
| Budgets per key | Spend can't run away ([virtual keys](05-llm-gateway-litellm.md#virtual-keys-and-budgets)) |
| Scale to zero | GPU nodes that aren't serving shouldn't exist |

## Next

[Security and governance](09-security-and-governance.md).
