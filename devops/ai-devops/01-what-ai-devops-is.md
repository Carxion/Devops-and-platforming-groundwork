# What AI DevOps is

[← AI DevOps](README.md)

AI DevOps applies the DevOps practices from the rest of this repository (version control, pipelines, tests as gates, small reversible releases, observability) to systems with a model inside them. Two kinds of system need it, and they share most of the tooling:

| | You train the model (MLOps) | You call a model someone else trained (LLMOps) |
|---|---|---|
| **What changes** | Code, **data**, and the trained model | Code, **prompts**, and which model serves them |
| **What you release** | A model artifact, then the service that loads it | A prompt version and a gateway route |
| **What can silently get worse** | Accuracy, as the world drifts from the training data | Answer quality, when a prompt, model, or provider changes |
| **Where the cost is** | Training compute (often GPUs) | Tokens, per request |
| **This folder's example** | [examples/training](examples/training/README.md) | [examples/llm-app](examples/llm-app/README.md) |

The difference from ordinary DevOps is that **behavior depends on things that aren't code**. A service built from the same commit behaves the same; a model trained from the same commit on different data doesn't, and an LLM app with the same code and a new model version answers differently. So the pipeline has to version, test, and release those things too.

## The components of AI training

Training a model is a pipeline of stages, each with an output the next one consumes. Every stage below appears in the [training example](examples/training/README.md):

| Component | What it does | Fails how, if skipped | In the example |
|---|---|---|---|
| **Data ingestion** | Gets the raw data from where it lives | Training on a stale or partial extract | `prepare` stage |
| **Data validation** | Checks schema, ranges, nulls, class balance before training | A quietly worse model, three stages later | `validate` stage, a [pandera](https://pandera.readthedocs.io/) schema |
| **Data versioning** | Records exactly which data a model was trained on | "Which data was this?" has no answer, so nothing reproduces | DVC: `dvc.lock` hashes every input and output |
| **Feature engineering** | Turns raw data into model inputs; must run identically at training and serving time | Training/serving skew: the model sees different inputs in production | A scikit-learn `Pipeline` (scaler plus model) saved as one artifact |
| **Training** | Fits the model with given parameters and seeds | Unreproducible results | `train` stage, parameters in `params.yaml` |
| **Experiment tracking** | Records parameters, metrics, code version, and artifacts for every run | You can't compare runs or explain a model | MLflow runs, tagged with the Git commit |
| **Evaluation** | Measures the model on data it didn't train on | Shipping a model that only memorized | `evaluate` stage, held-out test set |
| **Release gate** | Compares the candidate with absolute floors and with the current production model | Regressions reach production | `wine-model gate` |
| **Model registry** | Versions models and marks which one is in production | Deployments copy files around by hand | MLflow registry, `@challenger` and `@champion` aliases |
| **Packaging** | Stores the model in a safe, loadable format with its signature and dependencies | Loading a model runs arbitrary code; it won't load elsewhere | skops format, input signature, exported requirements |
| **Serving** | Loads a registered version and answers requests | | [Serving and operating](08-serving-and-operating.md) |
| **Monitoring and retraining** | Watches inputs and outcomes in production; retrains when they drift | Accuracy decays unnoticed | A scheduled pipeline ([CI/CD for ML](04-cicd-for-ml.md#continuous-training)) |

Fine-tuning a large language model has the same components with bigger numbers: the dataset is instruction pairs instead of rows, training runs on GPUs for hours, and evaluation uses the methods in [Evaluating LLM applications](07-evaluating-llm-apps.md) rather than accuracy on a test split.

## CI, CD, and CT

Google's MLOps guidance describes three levels of automation and adds a third practice to CI and CD: **continuous training (CT)**, "concerned with automatically retraining and serving the models" ([Google Cloud, MLOps: continuous delivery and automation pipelines](https://docs.cloud.google.com/architecture/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning)):

| Level | What's automated | Typical sign |
|---|---|---|
| **0: Manual process** | Nothing. A data scientist trains in a notebook and hands over a file | "Which notebook made the production model?" |
| **1: ML pipeline automation** | The training pipeline runs end to end without a person, so it can retrain on new data (CT) | Retraining is a scheduled job, not a project |
| **2: CI/CD pipeline automation** | The pipeline itself is built, tested, and deployed by CI/CD | A change to training code goes through review and a pipeline like any service |

This folder's examples are level 2: the training pipeline is code in Git, tested in CI, run by CI, and its output goes through a gate and a registry before anything serves it.

## The tools, by job

Tools change faster here than anywhere else in the repository. Pick by the job; every one below has alternatives, and the examples use the first-named because they're open source and run locally.

| Job | Examples used here | Alternatives |
|---|---|---|
| Data and pipeline versioning | DVC | lakeFS, Delta Lake or Apache Iceberg time travel, Pachyderm |
| Data validation | pandera | Great Expectations, TensorFlow Data Validation, Soda |
| Experiment tracking and model registry | MLflow | Weights & Biases, Neptune, cloud registries (SageMaker, Azure ML, Vertex AI) |
| Pipeline orchestration | GitLab CI, DVC | Kubeflow Pipelines, Argo Workflows, Airflow, Dagster, Metaflow, ZenML |
| LLM gateway | LiteLLM | Portkey, Kong AI Gateway, Envoy AI Gateway, cloud gateways (Bedrock, Azure API Management) |
| LLM tracing, prompts, and experiments | Langfuse | Arize Phoenix, MLflow tracing, Helicone, LangSmith (proprietary) |
| LLM evaluation and red teaming | promptfoo, Langfuse experiments | DeepEval, Ragas (retrieval), garak (red teaming), OpenAI Evals |
| Model scanning and signing | modelscan, skops | Sigstore `model_signing`, ModelKit (KitOps) for OCI packaging |
| Model serving | MLflow, Ollama (lab only) | vLLM, KServe, NVIDIA Triton, BentoML, Ray Serve, Hugging Face TGI |
| Drift monitoring | | Evidently, NannyML, WhyLabs, the observability stack in [devops/observability](../observability/README.md) |

## Who does what

Most teams split the work along the same line as in software: data scientists and ML engineers own the model and its evaluation; the platform team owns the paved road it runs on. The [platform engineering](../../platform-engineering/README.md) guides apply directly: a golden path for "a new model service" is the same idea as one for "a new web service".

| Platform team provides | Model teams provide |
|---|---|
| The gateway, its keys and budgets, and provider contracts | Prompts, datasets, and evaluation thresholds |
| MLflow and Langfuse, run as services with backups and access control | Training code, `params.yaml`, and the gate's floors |
| GPU runners and quotas | Choosing the model and justifying its cost |
| Pipeline templates (like the [examples](examples/gitlab/)) | Owning the pipeline's results, including failures |

## Next

[Data and training](02-data-and-training.md).
