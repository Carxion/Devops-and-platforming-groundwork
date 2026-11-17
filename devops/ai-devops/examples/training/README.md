# wine-model: a training pipeline

[← AI DevOps](../../README.md)

A deliberately small model (scikit-learn's wine dataset, three classes) with every part a production training pipeline needs. The model is trivial so the pipeline is the point. Walkthroughs: [Data and training](../../02-data-and-training.md), [Models and supply chain](../../03-models-registry-and-supply-chain.md), [CI/CD for ML](../../04-cicd-for-ml.md).

| File | Part |
|---|---|
| [dvc.yaml](dvc.yaml), `dvc.lock` | The pipeline as DVC stages, and the hashes of every input and output |
| [params.yaml](params.yaml) | Every parameter: split, model, and the gate's thresholds |
| [src/wine_model/data.py](src/wine_model/data.py) | Prepare the data, and validate it with a pandera schema |
| [src/wine_model/train.py](src/wine_model/train.py) | Train, save with skops, log the run and model to MLflow with the commit |
| [src/wine_model/evaluate.py](src/wine_model/evaluate.py) | Metrics on held-out data, safe loading, and the release gate |
| [src/wine_model/registry.py](src/wine_model/registry.py) | Register a model and move the `@challenger` and `@champion` aliases |
| [tests/](tests/test_pipeline.py) | 16 tests: validation, reproducibility, the gate, the CLI end to end with a registry, refusing untrusted model files |
| [../gitlab/training/.gitlab-ci.yml](../gitlab/training/.gitlab-ci.yml) | Its pipeline |

## Run it

Offline, MLflow writes to `mlflow.db` in the project:

```sh
uv sync --frozen
uv run pytest
uv run dvc repro                 # prepare, validate, train, evaluate
uv run wine-model gate           # exit 1 if the candidate shouldn't ship
uv run wine-model register       # @challenger
uv run wine-model promote        # @champion
```

Against the lab's MLflow server, set `MLFLOW_TRACKING_URI=http://localhost:5500` first.

Commands exit 0 when fine, 1 on a finding (invalid data, a failed gate), and 2 on a usage or configuration error. `MODEL_NAME` and `MLFLOW_EXPERIMENT_NAME` override the defaults (`wine-classifier`).
