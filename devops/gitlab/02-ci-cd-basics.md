# CI/CD basics

[← GitLab](README.md)

A GitLab pipeline is defined in `.gitlab-ci.yml` at the root of the repository. This guide covers how a pipeline gets created and run, the parts of that file, and the pieces almost every pipeline uses: variables, artifacts, caches, reports, and `needs`. The [YAML reference](https://docs.gitlab.com/ci/yaml/) lists every keyword.

## How a pipeline runs

```text
push, MR, tag,      GitLab reads .gitlab-ci.yml   runners poll GitLab, take         job log, status,
schedule, or API ─► at that commit, evaluates  ─► jobs whose tags they match,  ─►  artifacts, and reports
                    rules, creates a pipeline     run each in a fresh environment   go back to GitLab
                    of jobs grouped in stages
```

- **GitLab** decides which jobs exist, in what order. It never runs your code.
- **Runners** run the jobs. A runner polls for jobs, so it needs outbound HTTPS to GitLab and nothing inbound. Each job starts clean: a new container on the Docker executor, with a fresh clone of the repository ([Runners](05-runners.md)).
- **Stages** run in order; jobs in the same stage run in parallel. A failed job stops later stages unless it's allowed to fail. [`needs`](#needs-run-jobs-as-soon-as-their-inputs-are-ready) lets a job start as soon as the jobs it depends on finish, ignoring stage order.

## A first pipeline

```yaml
# .gitlab-ci.yml
stages: [test, build]

unit-tests:
  stage: test
  image: python:3.14-slim          # the container the job runs in
  script:
    - python -m unittest discover -s tests

package:
  stage: build
  image: alpine:3.24
  script:
    - mkdir -p dist
    - tar -czf dist/app.tar.gz src
  artifacts:                       # files kept after the job, for later jobs and for download
    paths: [dist/]
    expire_in: 1 week
```

Commit it and push: GitLab creates a pipeline with `unit-tests`, then `package`. Each `script` line runs in a shell (`sh` or `bash` in the image), and the job fails on the first command that exits non-zero.

## The parts of a job

| Keyword | Does |
|---|---|
| `script` | The commands. Required. |
| `before_script`, `after_script` | Commands before `script` (in the same shell), and after it in a **separate** shell that runs even when the job fails or is canceled. Use `after_script` for cleanup and diagnostics, never for a check that should fail the job. |
| `stage` | Which stage it belongs to (`test` if not set) |
| `image` | The container image, for the Docker and Kubernetes executors. Pin a version; pin a digest for anything that deploys. |
| `services` | Extra containers next to the job, such as a database: `services: [postgres:18]`, reachable by hostname |
| `variables` | Environment variables for the job |
| `tags` | Which runners can take it ([tags](05-runners.md#tags)) |
| `rules` | Whether the job is added to the pipeline, and how ([When jobs run](03-rules-and-pipeline-types.md)) |
| `needs` | Jobs it waits for, instead of the whole previous stage |
| `artifacts`, `cache` | Files kept for later jobs, and files kept to speed up later pipelines ([below](#artifacts-and-caches)) |
| `allow_failure` | The pipeline continues (with a warning) if this job fails |
| `retry` | Retry on failure, for example `retry: {max: 2, when: [runner_system_failure, stuck_or_timeout_failure]}`. Retry infrastructure failures, not test failures: a flaky test needs fixing. |
| `timeout` | A job-level limit, shorter than the project's |
| `interruptible` | The job can be canceled when a newer pipeline starts for the same branch ([auto-cancel](03-rules-and-pipeline-types.md#auto-cancel-redundant-pipelines)) |
| `environment` | The job deploys to an environment ([Environments](07-environments-and-deployments.md)) |

Settings shared by every job go under `default:` (for example `image`, `before_script`, `interruptible`, `retry`), and reusable fragments in hidden jobs whose names start with a dot ([Reusing pipeline code](04-reusing-pipeline-code.md)).

## Predefined variables

GitLab sets [many variables](https://docs.gitlab.com/ci/variables/predefined_variables/) in every job. The ones used most:

| Variable | Value |
|---|---|
| `CI_COMMIT_SHA`, `CI_COMMIT_SHORT_SHA` | The commit being built |
| `CI_COMMIT_BRANCH` | The branch, in branch pipelines only (not in merge request or tag pipelines) |
| `CI_COMMIT_TAG` | The tag, in tag pipelines only |
| `CI_COMMIT_REF_NAME`, `CI_COMMIT_REF_SLUG` | The branch or tag name, and a version safe for URLs and hostnames |
| `CI_DEFAULT_BRANCH` | The project's default branch, usually `main` |
| `CI_PIPELINE_SOURCE` | What created the pipeline: `push`, `merge_request_event`, `schedule`, `web`, `api`, `trigger`, `parent_pipeline`, ... |
| `CI_MERGE_REQUEST_IID`, `CI_MERGE_REQUEST_TARGET_BRANCH_NAME` | The MR, in merge request pipelines |
| `CI_OPEN_MERGE_REQUESTS` | MRs open for this branch, in branch pipelines (used to [avoid duplicates](03-rules-and-pipeline-types.md#merge-request-pipelines-without-duplicates)) |
| `CI_PROJECT_DIR` | Where the repository is checked out; artifact and cache paths are relative to it |
| `CI_PROJECT_PATH` | `group/subgroup/project` |
| `CI_REGISTRY`, `CI_REGISTRY_IMAGE` | The container registry, and this project's image repository in it |
| `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD` | Registry credentials for this job only |
| `CI_JOB_TOKEN` | The job's own token ([details](06-variables-secrets-and-cloud-access.md#the-job-token)) |
| `CI_SERVER_FQDN` | The GitLab host, used in component references |

## Artifacts and caches

They look alike and do different jobs:

| | Artifacts | Cache |
|---|---|---|
| **Purpose** | Pass a job's outputs to later jobs in the same pipeline, and keep them for people | Speed up jobs by reusing downloads (packages, modules) across pipelines |
| **Reliability** | Guaranteed: a job that needs them gets them, or fails | Best effort: a job must work with an empty cache |
| **Stored** | In GitLab, per job | Locally on the runner, or in object storage shared by runners |
| **Expiry** | `expire_in` (default 30 days; the latest successful pipeline's are kept) | Until evicted or the key changes |
| **Put in it** | Build outputs, test reports, plans | Package manager caches, downloaded tools |

Two habits:

- **Key caches on lock files,** so a dependency change starts a fresh cache: `cache: {key: {files: [uv.lock]}, paths: [.uv-cache/]}`. Package managers write to your home directory by default, which isn't cached; point them inside `$CI_PROJECT_DIR` (`UV_CACHE_DIR`, `GOPATH`, `npm_config_cache`).
- **Keep secrets out of artifacts.** Anyone who can see the pipeline can usually download them. `artifacts:access: developer` limits downloads to Developers and above, which is what the [Terraform example](examples/terraform/.gitlab-ci.yml) does for its saved plan.

### Reports

`artifacts:reports` files are parsed by GitLab and shown in the merge request and pipeline:

| Report | Shows | From |
|---|---|---|
| `junit` | Test results: failures in the MR, with their output | pytest `--junitxml`, gotestsum `--junitfile`, most test runners |
| `coverage_report` (Cobertura) | Covered and uncovered lines in the MR diff | coverage.py `--cov-report=xml`, gocover-cobertura |
| `coverage:` (job keyword, a regex) | The coverage percentage on the MR and pipeline | The test run's output |
| `codequality` | Linter findings on the changed lines | ruff `--output-format=gitlab`, golangci-lint `--output.code-climate.path` |
| `terraform` | Planned creates, updates, and deletes in the MR | A JSON summary of `terraform show -json` |
| `dotenv` | Variables for later jobs (`KEY=value` lines) | Anything; the [component](examples/components/README.md) exports `IMAGE_REF` this way |
| `sast`, `secret_detection`, `container_scanning`, ... | Security findings (MR widget and dashboards need Ultimate) | GitLab's scanners ([Pipeline security](08-pipeline-security.md#security-scanning)) |

Upload reports `when: always`: they matter most when the job fails. The [Python](examples/python-service/.gitlab-ci.yml) and [Go](examples/go-service/.gitlab-ci.yml) examples upload test, coverage, and code quality reports, and the lab check confirms GitLab parsed each one.

## needs: run jobs as soon as their inputs are ready

Without `needs`, a job waits for every job in all earlier stages. With it, the job starts when the jobs it lists finish, and only downloads their artifacts:

```yaml
# .gitlab-ci.yml
stages: [build, test, deploy]

build-api:
  stage: build
  script: [mkdir -p out, echo api > out/api]
  artifacts: {paths: [out/api]}

build-web:
  stage: build
  script: [mkdir -p out, echo web > out/web]
  artifacts: {paths: [out/web]}

test-api:
  stage: test
  needs: [build-api]               # starts when build-api is done, even if build-web is still running
  script: [cat out/api]

lint:
  stage: test
  needs: []                        # no dependencies: starts at once
  script: [echo lint]

deploy:
  stage: deploy
  needs: [test-api, build-web]
  script: [ls out]
```

A job can list up to 50 needs. `needs: []` is useful for linters and other jobs that don't depend on anything. GitLab draws the resulting graph on the pipeline page under "Job dependencies".

## Running and watching pipelines

- **Pipeline editor** (Build > Pipeline editor): edits `.gitlab-ci.yml` with live validation, shows the merged configuration after `include` and `extends`, and visualizes the stages.
- **CI Lint** (in the editor, or `glab ci lint --dry-run --ref main`): validates the file and simulates creating a pipeline on a ref, which also evaluates `rules` and resolves includes. It's how this repository checks the [examples](examples/README.md).
- **Run pipeline** (Build > Pipelines): start one by hand on a branch, with variables.
- **`glab ci status`** and **`glab ci trace`** from a terminal ([glab](01-basics.md#the-glab-cli)).

## Next

[When jobs run](03-rules-and-pipeline-types.md).
