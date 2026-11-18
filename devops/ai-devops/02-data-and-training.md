# Data and training

[← AI DevOps](README.md)

How to make training reproducible and safe to automate: version the data and the pipeline, validate data before it's used, track every run, and give training the hardware it needs. Every command here runs in the [training example](examples/training/README.md) and the [lab](lab/README.md).

## Reproducibility is the requirement

A pipeline can only retrain unattended if the same inputs give the same model. That needs four things pinned:

| Pin | How | In the example |
|---|---|---|
| **Code** | Git | The commit; MLflow tags each run with `git_commit` from `CI_COMMIT_SHA` |
| **Dependencies** | A lock file | `uv.lock`; MLflow also records the exported requirements with the model |
| **Data** | Content hashes | `dvc.lock` records the MD5 of every data file and model |
| **Parameters and randomness** | One parameters file; fixed seeds | `params.yaml`, `seed: 42` for the split and the model |

The example's tests check the last one directly: training twice gives identical metrics, and the split writes byte-identical files ([tests](examples/training/tests/test_pipeline.py)). GPU training is harder to make exactly reproducible (some CUDA operations are nondeterministic); aim for "within noise", and record enough to rerun.

## Versioning data and the pipeline with DVC

Git can't hold large data, and a model trained on "the data in the bucket" can't be reproduced once the bucket changes. [DVC](https://doc.dvc.org/) keeps data in storage you choose (S3, Azure Blob, GCS, a shared drive) and puts small pointer files and hashes in Git.

DVC also runs the pipeline. Stages, their inputs, and their outputs go in `dvc.yaml` ([the example's](examples/training/dvc.yaml)):

```yaml
# dvc.yaml (excerpt)
stages:
  train:
    cmd: python -m wine_model train
    deps:
      - src/wine_model/train.py
      - data/train.csv
    params:
      - train          # the train: section of params.yaml
    outs:
      - models/model.skops
```

`dvc repro` runs the stages whose inputs changed and records the hashes in `dvc.lock`. Commit `dvc.lock` with the code: that commit now names the exact data and model it produced.

```sh
uv run dvc repro            # run what's out of date
uv run dvc repro            # again: "Data and pipelines are up to date."
uv run dvc status           # what changed since dvc.lock
uv run dvc metrics show     # metrics.json, as a table
uv run dvc push             # upload data and models to the remote (configure one first)
```

Things that bit us building the example:

- **Run DVC through `uv run`.** Stage commands call `python`; without the project's virtual environment on `PATH`, they get the system Python and fail with "No module named wine_model".
- **DVC needs a Git repository** (`dvc init` without `--no-scm`). CI checkouts are one. DVC reads it with its own library, so the job image doesn't need the `git` binary.
- **A project in a subfolder of a repository** needs `dvc init --subdir`.
- **Experiments without commits:** `dvc exp run -S train.C=0.5` runs the pipeline with a changed parameter and keeps the result as an experiment you can compare (`dvc exp show`) and promote. The lab's check uses it to make a deliberately weak candidate.
- **YAML 1.1 numbers.** `dvc exp run -S train.C=0.00001` writes `1e-05` to `params.yaml`, and PyYAML reads that as a *string* (YAML 1.1 needs `1.0e-05`). The example's code casts parameters with `float()`; validate parameter types rather than trusting the file.

## Validating data before training

Data problems are the most common cause of a bad model, and they don't fail anything on their own: training happily fits garbage. Validate as the first stage, and fail the pipeline with a readable report. The example's [schema](examples/training/src/wine_model/data.py) checks:

- **Structure:** exactly the expected columns (`strict=True`), with the expected types. A new or renamed column fails here, not as a key error in training.
- **Values:** no nulls, no negative measurements, labels only from the known classes.
- **The dataset as a whole:** enough rows, and every class present. A filter upstream that drops a class trains a model that can never predict it.

```sh
uv run wine-model validate data/train.csv data/test.csv     # exit 0: valid
uv run wine-model validate bad.csv                          # exit 1, one line per problem:
# bad.csv: None: column_in_dataframe (value 'proline')
# bad.csv: alcohol: greater_than_or_equal_to(0) (value -1.0)
# bad.csv: invalid
```

Beyond the schema, production pipelines usually also check **drift** against the training data (has the distribution of a feature moved?) and **freshness** (is today's extract actually today's?). [Evidently](https://docs.evidentlyai.com/) and Great Expectations do both; keep them as stages so a failure stops the pipeline the same way.

## Tracking experiments with MLflow

Every training run should leave a record: parameters, metrics, the code version, and the model. [MLflow](https://mlflow.org/docs/latest/ml/) tracking does this with a server (or a local SQLite file for offline work). The example's [train.py](examples/training/src/wine_model/train.py):

```python
import mlflow

mlflow.set_tracking_uri("http://mlflow:5000")   # MLFLOW_TRACKING_URI in CI
mlflow.set_experiment("wine-classifier")
with mlflow.start_run() as active:
    mlflow.log_params({"model": "logistic_regression", "C": 1.0, "seed": 42})
    mlflow.set_tags({"git_commit": "abc123"})        # from CI_COMMIT_SHA
    info = mlflow.sklearn.log_model(model, name="model", serialization_format="skops")
```

In MLflow 3, a logged model is its own entity with an ID (`models:/m-...`), linked to the run: "Models are now first-class entities in MLflow 3" ([MLflow 3](https://mlflow.org/docs/latest/ml/mlflow-3/)). Register from `info.model_uri`; registering from `runs:/<run_id>/model` logs a warning that the run "has no artifacts at artifact path 'model'".

Running MLflow as a shared service, the lab's [compose.yaml](lab/compose.yaml) shows the shape: a database for runs and the registry (SQLite in the lab, PostgreSQL in production), an artifact store (a volume in the lab, S3 or Blob in production), and `--artifacts-destination` so clients upload through the server instead of needing storage credentials. MLflow 3 also checks the `Host` header: list every address clients use in `--allowed-hosts`, or requests are rejected.

## Hardware for training

Small models (like the example) train on a CPU runner in seconds. Large ones need GPUs, and the CI design follows:

- **GPU runners as a separate pool**, selected with a tag (`tags: [gpu]` in the job). In GitLab, a runner with the Docker executor passes GPUs through with `gpus = "all"` in its `config.toml`; on Kubernetes, the runner's job pods request `nvidia.com/gpu`, which the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html) makes schedulable by installing the drivers and device plugin.
- **Long jobs don't belong in the merge request loop.** Train a small configuration (a sample of the data, a few steps) on merge requests to prove the code works, and the full run on the default branch or a schedule.
- **Checkpoint**, so a preempted or timed-out job resumes instead of restarting. Spot or preemptible GPUs are much cheaper and fine for checkpointed training.
- **Cache the big inputs** (datasets, base model weights) near the runners, not in CI cache archives, which are slow at multi-gigabyte sizes. A DVC remote in the same region, or a mounted volume, works.
- **Put a budget on it.** Make GPU hours visible per team; the manager's [budget guide](../../manager/08-budget-vendors-and-contracts.md) applies.

For training that needs many GPUs or many hours, CI usually *starts* the run on a training platform (Kubeflow, Ray, SageMaker, Azure ML, Vertex AI) and waits for its result, rather than running it inside a CI job.

## Next

[Models, registry, and supply chain](03-models-registry-and-supply-chain.md).
