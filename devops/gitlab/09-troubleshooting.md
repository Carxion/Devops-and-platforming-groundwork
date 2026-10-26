# Troubleshooting

[← GitLab](README.md)

Symptom by symptom. Several of these came up while the examples in this folder were being tested, and the fix is in the example.

**First, for any pipeline problem:** open the pipeline editor's **Validate** tab, or run `glab ci lint --dry-run --ref <branch>`. A simulated pipeline on the right ref shows which jobs GitLab would create, which settles most "why didn't it run" questions without pushing anything.

## The pipeline doesn't start

| Cause | Check | Fix |
|---|---|---|
| `workflow:rules` matched nothing, or matched `when: never` | The simulated pipeline says "filtered out by workflow rules" | Add a rule for this kind of pipeline (tags are a common omission) |
| Every job's `rules` excluded it | Simulation shows no jobs | A pipeline with no jobs isn't created; check each job's first matching rule |
| A YAML or include error | The pipelines list shows a failed pipeline with a yaml error, or the editor reports one | Fix it; the pipeline editor's full configuration view shows what the includes resolved to |
| CI/CD is turned off, or the file is elsewhere | Settings > General > Visibility (CI/CD on), Settings > CI/CD > General pipelines (configuration file path) | Turn it on, or point at the right file |
| The push had `-o ci.skip`, or `[skip ci]` in the commit message | The commit message | Push again without it |

## Two pipelines for one push

A branch pipeline and a merge request pipeline, because jobs match both. Use the [duplicate-avoiding `workflow:rules`](03-rules-and-pipeline-types.md#merge-request-pipelines-without-duplicates). Jobs that use `rules` without `workflow:rules` are the usual cause: `if: $CI_PIPELINE_SOURCE == "merge_request_event"` on some jobs and plain rules on others.

## A job stays pending

No online runner matches the job. In order of likelihood:

- **Tags:** the job's `tags` must all be on one runner, and an untagged job needs a runner set to run untagged jobs. Compare the job's tags (in the job's sidebar) with the runners' tags (Settings > CI/CD > Runners).
- **Protected runner, unprotected branch:** protected runners only take jobs from protected branches and tags.
- **No runner online:** check the runner list for a green dot, and the runner host's logs (`journalctl -u gitlab-runner`, or the container's logs).
- **Every runner busy:** `concurrent` and each runner's `limit` cap jobs at once; jobs queue behind them.
- **Hosted runners on GitLab.com:** the namespace has used its compute minutes.

## A variable is empty

| Cause | Fix |
|---|---|
| The variable is **protected** and the branch or tag isn't | Protect the branch (if it should deploy), or don't protect the variable (if it isn't sensitive) |
| An **environment scope** that doesn't match the job's `environment:name` | Match the scope (`production`, `review/*`), or the job's environment |
| The variable is defined at the group, and the project is in another group | Define it where the project inherits it |
| `$VAR` used where variables aren't expanded (some keywords, or in `include` paths) | Check the YAML reference's "supported variables" for that keyword |
| Expand variable reference is off, and the value refers to `$OTHER` | Expected for secrets; build the combined value in the script instead |
| A `TF_VAR_` or other environment variable from the UI overrides a value the job set | UI variables take precedence over `.gitlab-ci.yml`; rename one of them |

## A job ran when it shouldn't, or didn't when it should

- **`rules:changes` was true on a new branch or a tag.** It always is, for a branch's first pipeline and for pipelines without a push. Use `compare_to`, or don't rely on `changes` for anything important ([the caveat](03-rules-and-pipeline-types.md#the-ruleschanges-caveat)).
- **The first rule matched.** Rules stop at the first match: put specific rules before general ones, and end with an explicit `when: never` where that's the intent.
- **A manual job didn't block the pipeline:** `when: manual` outside `rules` defaults to `allow_failure: true`. Inside `rules`, it blocks.
- **A security scanner didn't run in the MR:** the stable templates need `AST_ENABLE_MR_PIPELINES: "true"` to run in merge request pipelines.

## Artifacts and caches

| Symptom | Cause | Fix |
|---|---|---|
| A later job can't find a file | It wasn't in `artifacts:paths`, or `needs` doesn't list the job that made it, or it expired | List the path and the job; check `expire_in` |
| `No files to upload` | The path didn't exist when the job ended, often because it's relative to the wrong directory | Paths are relative to `$CI_PROJECT_DIR`, even if the script changed directory |
| The cache never helps | Packages are written outside the project directory, or the key changes every run | Point the package manager's cache into `$CI_PROJECT_DIR`; key on lock files |
| `Failed to extract cache` on the first run | There's no cache yet | Expected; the job continues |
| Different runners have different caches | Each host has a local cache | A shared cache in object storage ([config.toml](05-runners.md#configtoml)) |

## Building images

| Error | Cause | Fix |
|---|---|---|
| `Error during unshare(CLONE_NEWUSER): Operation not permitted` (Buildah, Podman) | Docker's default seccomp profile blocks the user namespace a `RUN` step needs | Run builds on a runner with `security_opt = ["seccomp=unconfined"]`, selected by tag ([Building container images](05-runners.md#building-container-images)) |
| `short-name resolution enforced but cannot prompt without a TTY` | An unqualified image name (`FROM python:3.14`) and no alias for it in the build container's `registries.conf.d` | Use fully qualified names (`docker.io/library/python:3.14`), or keep the image's short-name aliases if you mount your own registry configuration |
| `Cannot connect to the Docker daemon` | No Docker daemon in the job: Docker-in-Docker isn't configured, or the runner isn't privileged | Prefer Buildah; for Docker-in-Docker, a privileged runner and the `docker:dind` service |
| Trivy: `unable to open ... as a Docker image` or `... as an OCI Image` | `--input` was given an OCI archive tarball | Give it a Docker archive or an OCI layout directory (the component uses a directory) |
| The scan fails on a vulnerability with a fix | The image (often a pinned base image) has a fixable HIGH or CRITICAL vulnerability | Update the base image digest and rebuild; don't raise the threshold to get past it |

## Cloud authentication fails

With [ID tokens](06-variables-secrets-and-cloud-access.md#id-tokens-oidc), the error is almost always a mismatch between the token's claims and the trust policy. To see the claims, decode the token's payload in a job (it isn't secret after it expires, but don't leave this in a pipeline):

```sh
payload=$(echo "$GITLAB_OIDC_TOKEN" | cut -d. -f2 | tr '_-' '/+')
while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done   # restore base64 padding
echo "$payload" | base64 -d; echo
```

| Error | Cause | Fix |
|---|---|---|
| AWS `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The `sub` or `aud` doesn't match the role's trust policy: wrong branch, renamed project, MR pipeline on an unexpected branch | Compare the token's `sub` with the `gitlab-oidc` stack's `trusted_subjects` output |
| AWS `No OpenIDConnect provider found` | The OIDC provider's URL isn't exactly the token's `iss` | Create the provider for the issuer the token carries |
| `InvalidIdentityToken: Issuer must start with https://` | A self-managed instance on `http` | Serve GitLab on `https`, or set `ci_id_tokens_issuer_url` |
| `InvalidIdentityToken: ... could not be validated` | AWS can't fetch the issuer's keys: the instance isn't reachable from the internet | Publish the OpenID configuration and keys at a public URL and set `ci_id_tokens_issuer_url` to it |
| Azure `AADSTS70021: No matching federated identity record found` | No federated credential with this exact `sub`, issuer, and audience | Check the branch: an MR pipeline's `sub` names its source branch, which only `plan_any_branch` matches |
| The credentials work, but a tool reaches the wrong endpoint | Endpoint overrides apply per service in AWS SDKs | When pointing tools at an emulator (as the lab does with moto), set the STS endpoint (`AWS_ENDPOINT_URL_STS`) as well as the global one, or role assumption goes to the real AWS |

## Terraform in pipelines

- **`terraform test` fails in CI but passes locally:** CI/CD variables named `TF_VAR_<name>` reach every job and override the values the test files set. Pass environment inputs to `plan` as a `-var-file` from a file variable instead, as the [Terraform example](examples/terraform/.gitlab-ci.yml) does.
- **`Saved plan is stale`:** the state changed after `plan` (another apply). Run the pipeline again for a fresh plan.
- **State lock errors:** another plan or apply holds the lock. `resource_group` per environment prevents overlap; `-lock-timeout=5m` waits instead of failing at once. Only force-unlock when you're sure the holder is gone.
- **`-lockfile=readonly` fails:** the lock file lacks checksums for the runner's platform. Lock for every platform ([CLAUDE.md](../../CLAUDE.md#terraform-stacks) has the command).

## Next

Back to the [GitLab guides](README.md), or the [examples](examples/README.md).
