# When jobs run

[← GitLab](README.md)

Most pipeline surprises are about *when*: a pipeline that runs twice for one push, a job that never appears, a deploy that runs from a feature branch. This guide covers what creates pipelines, how `workflow:rules` and `rules` decide what's in them, and the other ways pipelines start: manual jobs, schedules, child pipelines, and pipelines in other projects.

## Pipeline sources

`CI_PIPELINE_SOURCE` says what created the pipeline. The ones that matter most:

| Source | Created by | `CI_COMMIT_BRANCH` set? |
|---|---|---|
| `push` | A push to a branch or a new tag | Yes for branches; for tags, `CI_COMMIT_TAG` is set instead |
| `merge_request_event` | A push to an MR's source branch, or creating the MR, when jobs are configured for MR pipelines | No: use `CI_MERGE_REQUEST_*` variables |
| `schedule` | A pipeline schedule | Yes |
| `web` | "Run pipeline" in the UI | Yes |
| `api`, `trigger` | The pipelines API, or a trigger token | Yes |
| `parent_pipeline` | A parent pipeline's `trigger:include` (a child pipeline) | Yes |
| `pipeline` | Another project's pipeline (multi-project) | Yes |

## Merge request pipelines without duplicates

A project can run **branch pipelines** (on every push to a branch) and **merge request pipelines** (on pushes to a branch with an open MR). If jobs match both, one push creates two pipelines. Every example in this folder starts with the same `workflow:rules`, which GitLab documents for this:

```yaml
# .gitlab-ci.yml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"   # MR pipelines: yes
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS    # a branch pipeline when an MR is open: no
      when: never
    - if: $CI_COMMIT_BRANCH                               # other branch pipelines: yes
    - if: $CI_COMMIT_TAG                                  # tag pipelines: yes

test:
  script: [echo "runs in exactly one pipeline per push"]
```

`workflow:rules` decides whether a pipeline is created at all, evaluated top to bottom; the first match wins, and no match means no pipeline. The lab check pushes a second commit to a branch with an open MR and confirms that only the MR pipeline appears.

Why MR pipelines: they show results in the MR, they can use `CI_MERGE_REQUEST_*` variables, and `rules:changes` compares with the target branch, not just the last commit. In Premium, **merged results pipelines** go further and test the result of merging into the target branch, and **merge trains** queue merges so each is tested on top of the ones ahead of it. Both help on busy default branches where "it passed on my branch" isn't enough.

Pipelines for MRs from **forks** run in the fork, with the fork's runners and variables, and none of yours. A member of the parent project can choose to run one in the parent project, which then has the parent's variables: review the fork's changes, especially to `.gitlab-ci.yml`, before doing that.

## rules

`rules` on a job works the same way as `workflow:rules`: a list of conditions, first match wins, and the match decides whether the job is added and how.

```yaml
# .gitlab-ci.yml
stages: [test, deploy]

unit-tests:
  stage: test
  script: [echo test]              # no rules: in every pipeline

docs-check:
  stage: test
  script: [echo checking docs]
  rules:
    - changes: [docs/**/*, "*.md"] # only when docs change (see the caveat below)

deploy-staging:
  stage: deploy
  script: [echo deploy staging]
  environment: staging
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-production:
  stage: deploy
  script: [echo deploy production]
  environment: production
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
      when: manual                 # added, but waits for a person
    - when: never                  # explicit: nowhere else
```

| Clause | Matches when |
|---|---|
| `if` | The expression is true. Compare with `==`, `!=`, `=~` and `!~` (regular expressions), combine with `&&`, `\|\|`, and parentheses. A variable alone is true if it's set and non-empty. |
| `changes` | Any listed path (globs allowed) changed |
| `exists` | Any listed path exists in the repository |
| (none) | Always: a catch-all as the last rule |

| `when` | The job is |
|---|---|
| `on_success` (default) | Added, and runs if earlier stages succeeded |
| `manual` | Added, and waits for someone to start it |
| `delayed` | Added, and starts after `start_in` |
| `always` | Added, and runs even if earlier stages failed |
| `never` | Not added |

Each rule can also set `allow_failure`, `variables`, `needs`, and `interruptible` for the job when it matches, which is how the examples let a dependency audit fail softly in MRs and hard on `main`.

Older pipelines use `only` and `except`. They still work but can't be combined with `rules` in the same job, and `rules` replaces everything they do. Convert them when you touch them.

### The rules:changes caveat

`changes` compares with the target branch in MR pipelines, and with the previous commit in branch pipelines. **For a new branch's first pipeline, and in pipelines with no push (tags, schedules, manual runs), it's always true.** So a `changes`-only job runs on every new branch and every tag. To compare with a fixed ref instead:

```yaml
docs-check:
  script: [echo checking docs]
  rules:
    - changes:
        paths: [docs/**/*]
        compare_to: refs/heads/main
```

Use `changes` to save time, never to skip a check that protects production: a job skipped by `changes` hasn't proven anything.

## Manual jobs and blocked pipelines

A `when: manual` job waits for someone with permission to start it. Inside `rules`, a manual job defaults to `allow_failure: false`, so the pipeline shows **blocked** until it runs and later stages wait for it. That's what you want for a production deploy gate. Outside `rules`, `when: manual` defaults to `allow_failure: true`: the pipeline is considered passed and later stages run without it.

Who can start a manual job: anyone with permission to merge into the pipeline's branch. On an unprotected branch that's any Developer; on a protected branch, only the roles allowed to merge into it. For a stronger gate, use [protected environments](07-environments-and-deployments.md#deployment-gates) (Premium).

## Schedules

Build > Pipeline schedules runs a pipeline on a cron schedule, on a branch, with optional variables. Use them for nightly builds, dependency audits, drift detection (`terraform plan` on `main`), and cleanups. Select scheduled-only jobs with `if: $CI_PIPELINE_SOURCE == "schedule"`, and keep them out of other pipelines with the reverse.

A schedule runs as the user who owns it (whoever created it, or last took ownership), with that user's permissions. If the owner's access changes, so does the schedule's: give important schedules an owner who'll keep access, such as a service account, and take ownership when people move on.

## Parent-child and multi-project pipelines

A **child pipeline** is a separate pipeline in the same project, started by a `trigger` job. Use them for monorepos (one child per component, each only when its files change) and for generated pipelines.

```yaml
# Fragment: a monorepo parent. services/api/.gitlab-ci.yml and
# services/web/.gitlab-ci.yml are ordinary pipelines for each service.
api:
  trigger:
    include: services/api/.gitlab-ci.yml
    strategy: mirror               # the trigger job mirrors the child's status (all statuses, not just success)
  rules:
    - changes: [services/api/**/*]

web:
  trigger:
    include: services/web/.gitlab-ci.yml
    strategy: mirror
  rules:
    - changes: [services/web/**/*]
```

- `strategy: mirror` (GitLab 18.2 and later) or `depend` makes the parent wait for and reflect the child's result. Without it, the trigger job succeeds as soon as the child is created, and a failed child doesn't fail the parent.
- A **dynamic child pipeline** includes a YAML file generated by an earlier job (`trigger:include: {artifact: generated.yml, job: generate}`), for pipelines that depend on the repository's contents.
- A **multi-project pipeline** triggers a pipeline in another project: `trigger: {project: group/deployer, branch: main, strategy: mirror}`. The user who triggers it needs permission to run pipelines there.

## Auto-cancel redundant pipelines

When a new commit lands on a branch, the older pipeline is usually redundant. `workflow:auto_cancel:on_new_commit` controls what's canceled:

| Value | Cancels |
|---|---|
| `conservative` (default) | The older pipeline, only if none of its `interruptible: false` jobs have started |
| `interruptible` | Only the older pipeline's `interruptible: true` jobs |
| `none` | Nothing |

The examples set `interruptible: true` as a default and `on_new_commit: interruptible`, so checks and builds cancel, but anything not marked interruptible (a push, a deploy) finishes. Never mark a deploy job interruptible: canceling it halfway leaves the environment half deployed.

## Matrix jobs

`parallel:matrix` creates one job per combination of values, up to 200:

```yaml
# .gitlab-ci.yml
test:
  image: python:$PYTHON_VERSION-slim
  parallel:
    matrix:
      - PYTHON_VERSION: ["3.12", "3.13", "3.14"]
  script:
    - python --version
    - python -m unittest discover -s tests
```

Each job is named with its values (`test: [3.13]`), and `needs` can refer to one combination: `needs: [{job: test, parallel: {matrix: [{PYTHON_VERSION: "3.14"}]}}]`.

## Next

[Reusing pipeline code](04-reusing-pipeline-code.md).
