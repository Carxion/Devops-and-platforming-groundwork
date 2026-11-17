# Models, registry, and supply chain

[← AI DevOps](README.md)

A trained model is a build artifact. Treat it like a container image: store it in a registry, version it immutably, release it by moving a reference, know where it came from, and never load one you can't trust.

## The model registry

A registry holds versions of a named model and says which one each environment should use. With MLflow's registry ([docs](https://mlflow.org/docs/latest/ml/model-registry/)):

- **Versions are immutable.** Registering the same name again creates version 2, 3, and so on. Each links to the run that produced it, so its parameters, metrics, and commit are one click away.
- **Aliases are the release mechanism.** An alias is "a mutable, named reference" to one version. Serving loads `models:/wine-classifier@champion`; promoting is moving `@champion` to a new version, and rolling back is moving it back. Nothing is copied or rebuilt.
- **Stages are gone.** The older Staging/Production stages "are deprecated and will be removed in a future major release" ([workflow docs](https://mlflow.org/docs/latest/ml/model-registry/workflow/)). Use aliases.

The example uses two aliases, a common convention:

| Alias | Set by | Means |
|---|---|---|
| `@challenger` | The pipeline, on the default branch, after the gate passes | The newest model that may ship |
| `@champion` | A person, by playing the pipeline's manual `promote` job | What production serves |

```sh
uv run wine-model register --alias challenger             # register the run's model, point @challenger at it
uv run wine-model promote --from challenger --to champion # release
```

The gate compares every candidate with the metrics of the run behind `@champion` ([evaluate.py](examples/training/src/wine_model/evaluate.py)), so "better than what's in production" is checked by the pipeline, not remembered by a person. The lab's check shows both outcomes: a candidate trained with `C=0.001` scores 0.82 against a champion's 1.0, and the gate fails it with three reasons.

## Model formats: never load a pickle you didn't make

Python's `pickle` (and formats built on it: older PyTorch `.pt` and `.bin` files, joblib) runs code while loading. A model file from the internet can contain a payload that runs the moment you load it. This is the model supply chain's biggest risk, and it's in the [OWASP Top 10 for LLM Applications 2026](https://genai.owasp.org/resource/owasp-genai-llm-top-10-2026/) as LLM04:2026 Supply Chain.

| Format | Runs code on load | Use for |
|---|---|---|
| **safetensors** | No: tensors only | Neural network weights (Hugging Face's default). "A new simple format for storing tensors safely (as opposed to pickle)" ([docs](https://huggingface.co/docs/safetensors/index)) |
| **skops** | No: loads only types it knows are safe, and lists the rest for you to trust explicitly | scikit-learn models (the example uses it) |
| **ONNX** | No: a computation graph | Portable inference across runtimes and languages |
| **GGUF** | No | Quantized LLMs for llama.cpp and Ollama |
| pickle, joblib, PyTorch `.pt` without `weights_only` | **Yes** | Only files you produced, in your own pipeline |

The example saves with skops and, when loading, trusts only the types it expects ([evaluate.py](examples/training/src/wine_model/evaluate.py)):

```python
import skops.io as sio

TRUSTED_TYPES = ["sklearn.tree._tree.Tree"]   # what a random forest needs; nothing else

untrusted = sio.get_untrusted_types(file=path)
unexpected = [t for t in untrusted if t not in TRUSTED_TYPES]
if unexpected:
    raise ValueError(f"model file contains untrusted types: {unexpected}")
model = sio.load(path, trusted=untrusted)
```

MLflow applies the same rule: logging with `serialization_format="skops"` needs `skops_trusted_types` for those types too, or loading the model from the registry fails with "The saved sklearn model references untrusted types". The lab's check hit this with a random forest.

## Scanning models you didn't train

Before a pipeline loads a third-party model (a base model to fine-tune, a downloaded classifier), scan it. [modelscan](https://github.com/protectai/modelscan) reads pickle, PyTorch, Keras, and TensorFlow files without loading them, looking for operations that run code:

```sh
modelscan -p evil.pkl
# --- CRITICAL ---
# Unsafe operator found:
#   - Severity: CRITICAL
#   - Description: Use of unsafe operator 'system' from module 'posix'
echo $?    # 1: issues found
```

Its exit codes make it a pipeline gate: 0 no issues, 1 issues found, and 3 when nothing in the path was a format it scans. Checked in the lab with modelscan 0.8.8, which supports Python 3.10 to 3.12 only (the lab gives it its own Python 3.12 environment), and doesn't read skops files: pointed at the example's model it exits 3, after a numpy 2 incompatibility error in its numpy scanner. Scan what it supports, and use a format that can't run code for the rest.

```yaml
# A job fragment: scan a downloaded base model before anything loads it.
scan-base-model:
  image: python:3.12-slim
  script:
    - pip install modelscan==0.8.8
    - modelscan -p models/base/
```

## Provenance, signing, and packaging

The same supply chain controls as for images ([pipeline security](../gitlab/08-pipeline-security.md)) apply to models:

- **Provenance:** record what produced a model: commit, pipeline, data hash, parameters. MLflow's run (with the `git_commit`, `pipeline_url`, and `job_id` tags the example sets) plus `dvc.lock` is that record. The lab's GitLab check asserts the champion's run carries the commit that trained it.
- **Signing:** [Sigstore's `model_signing`](https://github.com/sigstore/model-transparency) (an OpenSSF project) signs a model directory and verifies it before loading, with the same keyless signing as `cosign` for images. Sign in the pipeline that produced the model; verify in the one that deploys it.
- **Packaging as OCI artifacts:** registries that hold images can hold models. ModelKit ([KitOps](https://kitops.org/)) packages a model, its dataset, code, and config as one OCI artifact, so the access control, retention, and scanning you already run for images cover models too.
- **A bill of materials:** CycloneDX added machine learning BOMs in version 1.5 ([history](https://cyclonedx.org/about/history/); the current version is 1.7). An ML-BOM lists the model, its datasets, and their provenance, the way an SBOM lists packages.

## Model cards

Every registered model should say what it's for and where it fails: intended use, training data, evaluation results by segment, known limitations, owner. MLflow's registered model and version descriptions hold this; keep a `MODEL_CARD.md` in the repository and paste it in the pipeline, so the card is reviewed with the code that changes it.

## Next

[CI/CD for ML](04-cicd-for-ml.md).
