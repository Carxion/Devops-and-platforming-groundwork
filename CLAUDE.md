# CLAUDE.md

Guidance for AI assistants working in this repository.

## What this is

DevOps and Platforming Groundwork: public, CC BY 4.0 material organized by audience. `tech-lead/` holds the onboarding checklist for tech leads joining cloud / CI/CD / IaC / DevSecOps programs; `devops/`, `software/`, and `manager/` hold tested reference material and guides. The root `README.md` is an index of all of it.

## Layout

- `README.md`: the repository index: what's in each folder, and reading paths by role. Update it when a folder or guide is added.
- `tech-lead/README.md`: the onboarding checklist. **Single source of truth** for every checklist item.
- `tech-lead/checklists/`: generated from `tech-lead/README.md` by `scripts/build_checklists.py`. Never edit by hand; regenerate.
- `tech-lead/templates/`: copy-ready templates. The ones in Appendix A must stay in sync with it; the rest support the 30/60/90 deliverables and are listed in `tech-lead/templates/README.md`.
- `tech-lead/assessing-an-inherited-system.md`: the method behind checklist sections 2 and 9. Keep its step numbers and template links in step with the checklist.
- `manager/`: guides (`00-first-90-days.md` is a checklist in the same item format as the tech lead checklist, but not generated into views) and `templates/`.
- `scrum-master/`, `product-owner/`: the same shape as `manager/` (a first-90-days checklist, numbered guides, `templates/`). Frameworks cite their primary source and version: the Scrum Guide (November 2020), the Kanban Guide (May 2025). Keep the "who does what" split in `scrum-master/README.md` consistent with the other role folders.
- `solutions-architect/`: the same shape (a first-90-days checklist, numbered guides, `templates/`). It covers discovery, stakeholders, proposals, and presenting; design quality stays in `architect/`, which it links to rather than repeats.
- `CHANGELOG.md`: add a line under **Unreleased** for every content change.
- `architect/`: considerations guides (numbered) and `templates/`. Each guide links principles to the tested code in `devops/`; keep those links pointing at real files.
- `software/testing/`: unit testing principles, and `python/` and `go/` guides, each with an `example/` project on the same pricing domain. Keep the two examples' behavior and tests parallel, and every technique the guides describe used in the example.
- `software/python/`, `software/go/`: 101 guides, `boilerplate/` projects (a CLI and the Items API in each), and `examples/` (the same five operational tools in each language; keep their flags, JSON output, and exit codes matching). The API implementations must pass the `software/api-testing` contract tests (run locally; see `CONTRIBUTING.md`).
- `devops/`, `software/`, `manager/`, `scrum-master/`, `product-owner/`, `solutions-architect/`: each has a README listing its contents. Material moves between them only when its audience changes.
- `devops/terraform/`: reference stacks, `aws/*` and `azure/*`, each a self-contained root module. See `devops/terraform/README.md`.
- `devops/kubernetes/`: Kustomize bases, overlays, and components for sample apps. See `devops/kubernetes/README.md`.
- `devops/aws/`, `devops/azure/`: CLI operations guides (`guides/`) plus CloudFormation (`devops/aws/cloudformation/`) and Bicep (`devops/azure/bicep/`) templates.
- `software/api-testing/`: OpenAPI contract (`openapi/items-api.yaml`), reference server, Postman, k6, and Locust tests. The spec defines the serverless stacks' behavior: change the spec, both handlers, and the local server together.
- `devops/observability/`: Prometheus guide and SLO rules (`prometheus/`), Grafana 101 and dashboards (`grafana/`), the Compose lab (`local-stack/`), and AWS and Azure guides with templates. `scripts/check_observability_lab.py` checks the running lab.
- `devops/bash/`: Bash 101 guides and `scripts/` (sourcing `lib/common.sh`). Tests: Bats (`tests/*.bats`) and `tests/integration.sh` in Ubuntu, Rocky, and AlmaLinux containers.
- `devops/gitlab/`: GitLab 101 and CI/CD guides, `examples/` (a component project and three pipelines), and `lab/` (Compose and `lab.sh`). `scripts/check_gitlab_examples.py` runs the examples in the lab and lints every yaml block in the guides whose first line is `# .gitlab-ci.yml`; fragments start with anything else. The AWS and Azure `gitlab-oidc` stacks in `devops/terraform/` are its cloud side.
- `devops/helm/`: Helm guides, `examples/` (charts, environment values, `publish-charts.sh`), and `lab/` (tools Dockerfile, kind config, `lab.sh`, `check.sh`). The charts are the `devops/kubernetes` apps as Helm: keep images, digests, security settings, and policies the same in both.
- `devops/ansible/`: guides and a project at the folder root (`site.yml`, `roles/`, `inventory/`, `molecule/default/`). Tests: `molecule test`.
- `software/git/`: Git 101 guides, `templates/`, `scripts/`, and `tests/recipes.sh`, which runs every recipe in the guides. Run it on Ubuntu 22.04 (Git 2.34), 24.04, and Rocky 9.
- `software/containers/`: how containers work, then `docker/` (guides, `examples/` with Dockerfiles and a Compose file, `scripts/`) and `podman/`. Tests: builds, Trivy, the Compose smoke test, and `docker-audit.sh --strict`. Verify Docker commands against a real daemon and Podman commands in a `quay.io/podman/stable` container before writing them.
- `ROADMAP.md`: coverage and planned areas; move an area to "Covered today" only when it meets the definition of done there.
- `scripts/check_cli_commands.py`: checks every `aws`/`az` command, flag, and `--query` in Markdown against the real CLIs (run locally).
- `.github/workflows/lint.yml`: the only CI workflow, static checks only: markdownlint, cspell, lychee, checklist freshness, ShellCheck, shfmt, yamllint and ansible-lint, ruff, gofmt and golangci-lint, `terraform fmt` and tflint, Hadolint. Every test suite runs locally instead (`CONTRIBUTING.md#running-the-tests-locally`): run the ones for an area before changing it, and keep that table current when adding an area. Don't add heavy jobs (builds, containers, test suites) to CI without asking.

## Rules

- **No program-specific information**, ever: no customer names, system names, internal URLs, or details from a restricted environment, even as "examples". Examples stay generic or come from public sources.
- **Primary sources only** for factual claims (NIST, CISA, DORA, OWASP, SLSA, vendor docs). Verify the current version of a standard before citing it; don't rely on memory for revision numbers or draft status. New citations go in the References table with a `[KEY]`.
- **Item format:** `- [ ] **W1|30|60|90** Imperative sentence.` Ask for observations, not solutions. Stay vendor-neutral, naming tools only as examples. See CONTRIBUTING.md.
- Match the existing voice: direct, plain, short sentences, no hype, practitioner judgment framed as a default rather than a rule.
- GitHub Actions are pinned to full commit SHAs with the version in a trailing comment. Keep it that way, since the guide itself recommends it.

## After editing tech-lead/README.md

```sh
python scripts/build_checklists.py
npx markdownlint-cli2 "**/*.md"
npx cspell@10.3.6 "**/*.md"   # the version CI pins in docs.yml
```

Add new correctly spelled terms to `cspell.json`.

## Terraform stacks

- Check provider schemas before writing arguments. azurerm 5.x renamed and removed several 4.x arguments, so validate rather than relying on memory.
- Keep each stack's file layout (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars.example`, `backend.hcl.example`, `tests/plan.tftest.hcl`). Every variable needs a description.
- Secure defaults. A checkov finding is fixed, or skipped inline inside the resource block with a specific, true reason: `#checkov:skip=<ID>:<reason>`. Never skip on a guess about why checkov flagged something; read the check first.
- Add a test run to `tests/plan.tftest.hcl` for any new conditional behavior.
- Never commit real tfvars, backend.hcl, or state. They're git-ignored.
- Lock files need checksums for every platform, not just the one that ran `init`: anyone validating on Linux with `-lockfile=readonly` (as a pipeline should) is rejected by a lock file that only has Windows or macOS hashes. After adding or upgrading a provider, run in each stack: `terraform providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64 -platform=windows_amd64`.

```sh
cd devops/terraform/<cloud>/<stack>
terraform init -backend=false && terraform validate && terraform test
cd ../.. && tflint --init && tflint --recursive --config "$(pwd)/.tflint.hcl" && checkov -d . --framework terraform
```

## Kubernetes manifests

- Plain YAML plus Kustomize only. Every workload keeps the hardened defaults: non-root UID 10001, read-only root filesystem, drop ALL capabilities, RuntimeDefault seccomp, no service account token, image pinned by digest, requests set, memory limit set.
- Kustomize `labels` do not fill NetworkPolicy selectors. Always write an explicit `podSelector.matchLabels`; an empty selector applies the policy to every pod in the namespace.
- Checkov exceptions are `checkov.io/skipN: CKV_K8S_xx=reason` annotations on the resource.
- Verify by rendering, not by reading the base:

```sh
kubectl kustomize devops/kubernetes/apps/<app>/overlays/<overlay> | kubeconform -strict -kubernetes-version 1.34.0 -
```

## CLI commands in docs

- Never write an `aws` or `az` command, flag, or `--query` from memory without running `scripts/check_cli_commands.py`. CLIs rename and remove commands (for example `az costmanagement query` and `az postgres flexible-server ad-admin` both changed), and the check is the only thing that catches it.
- Built-in Azure role and policy IDs must be verified against Microsoft's published definitions (the built-in roles page and github.com/Azure/azure-policy), not recalled.
- Incident runbooks contain, preserve evidence, and never delete. Keep that order.

## Bash scripts

- Every script: `set -Eeuo pipefail` (or a commented reason not to), `--help` from the header comment, input validated before changes, every change through `run` so `--dry-run` is honest, `bash` (not `sh`).
- Under `set -e`, never end a function, block, or loop body with `[[ test ]] && cmd`: a false test makes the block fail. Use `if`.
- Lint with ShellCheck and shfmt (`-i 2 -ci`), and test: Bats for anything that runs without root, `tests/integration.sh` in containers for the rest. Add a case to `tests/regex.bats` whenever `devops/bash/03-regex.md` gains a pattern.
- Check RHEL and Ubuntu claims in containers before writing them (`docker run --rm rockylinux/rockylinux:9 ...`, `ubuntu:24.04`).

## Python and Go boilerplate and examples

- Python: `uv` with a committed `uv.lock`, `src/` layout, ruff (lint and format), mypy strict, pytest. Run checks in a `python:3.14-slim` container with `uv sync --frozen`.
- Go: standard library first, `gofmt`, `go vet`, golangci-lint v2 (`.golangci.yml` per project), `go test -race`, govulncheck. Local Go may be older than `go.mod` needs; test in `golang:1.27-alpine` (add `gcc musl-dev` for `-race`).
- Example tests must not need network access or cloud credentials: local servers, generated certificates, moto or a fake client. Exit codes: 0 fine, 1 finding, 2 usage or configuration error.
- A change to either API implementation must keep Schemathesis (`--checks all`) and Newman passing against the built image.
- Code blocks in the language guides and `software/testing/` must parse: Python blocks with `ast.parse`, Go blocks with `go/format.Source` (keep declarations and statements in separate blocks).

## Ansible

- Fully qualified module names (`ansible.builtin.copy`). Role variables start with the role name. Pin collections in `requirements.yml` and tools in `requirements.txt`.
- Every role must pass `molecule test`, including the idempotence step: a second run reports `changed=0`. `command`/`shell` tasks need `changed_when`.
- Service tasks are gated on `<role>_manage_services`; the Molecule inventory sets them false because containers don't run systemd.
- Run locally in a container with the Docker socket mounted, and set `ANSIBLE_CONFIG` when the folder is world-writable (Windows mounts), or Ansible ignores `ansible.cfg`.

## Git guides

- Every command recipe in `software/git/*.md` needs a matching test in `tests/recipes.sh`. Use the `fails` helper for commands that must fail (a bare `! cmd` doesn't fail a test under `set -e`), and `grep -q <<<"$(cmd)"` rather than `cmd | grep -q` (SIGPIPE under pipefail).
- Commands must work on Git 2.34 (Ubuntu 22.04); say so where a feature needs a newer version.

## GitLab pipelines

- Run a pipeline in the lab before writing it into an example, and keep `check_gitlab_examples.py` asserting what each example should do (job statuses, parsed reports, pushed images). A pipeline that only passed the linter isn't tested.
- Complete pipelines in the guides start with `# .gitlab-ci.yml` and must pass the `lint` scenario; partial ones start with another comment.
- Pin job images to versions (digests for anything that builds or deploys) and components to exact versions. Check each image tag exists before using it; the linter doesn't.
- Say when a feature needs Premium or Ultimate. Check the tier on the feature's GitLab docs page, not from memory.

## Helm charts

- Run `devops/helm/lab/lab.sh check` (after `lab.sh up` for the cluster part) before changing a chart: lint with every environment's values, kubeconform, checkov, helm-unittest, ct lint, and the install, upgrade, and rollback steps. Bump the chart's `version` for every change.
- Every namespaced resource sets `namespace: {{ .Release.Namespace }}`; selector labels are name and instance only; images are pinned by digest; test pods meet Pod Security restricted and get their own NetworkPolicy.
- Add a helm-unittest case for any new value that changes what renders, and one for any input that must fail.
- Commit `Chart.lock`; never commit `charts/*/charts/` (generated).
- Check Helm flags against `helm <command> --help` from the lab image: Helm 4 renamed and changed several (`--atomic`, `--force`, `--wait`).

## Dockerfiles

- Base images pinned by tag and digest, non-root numeric `USER`, exec-form `ENTRYPOINT`, SIGTERM handled. Hadolint clean, and no fixable HIGH or CRITICAL Trivy findings.

## API tests and observability

- Run the API tests against the local server before changing the spec or either handler: `python software/api-testing/local-server/items_server.py`, then Newman, Schemathesis (`--checks all`), and k6 as in `software/api-testing/README.md`.
- Prometheus rule changes need a matching `promtool test rules` case in `devops/observability/prometheus/tests/`. Promtool compares annotations exactly, so update expected annotations with the rule.
- Dashboards refer to data sources by the fixed uids in `local-stack/grafana/provisioning/datasources/datasources.yaml`. Check every new panel query against the running lab, not by reading it.
- Keep image versions in `local-stack/compose.yaml` and the env block of `observability.yml` in step.

## CloudFormation and Bicep

- CloudFormation: partition-aware ARNs (`arn:${AWS::Partition}`), `DeletionPolicy: Retain` on data and keys, checkov skips in `Metadata.checkov.skip` with reasons. Validate with `cfn-lint` and checkov.
- Bicep: deterministic `guid()` names for role assignments, `principalType` always set, `// checkov:skip=ID:reason` inside the resource. Validate with `bicep build`, `bicep lint`, and checkov.
- Only add a skip or suppression after confirming the check actually fires on that resource.
