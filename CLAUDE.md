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
- `CHANGELOG.md`: add a line under **Unreleased** for every content change.
- `architect/`: considerations guides (numbered) and `templates/`. Each guide links principles to the tested code in `devops/`; keep those links pointing at real files.
- `devops/`, `software/`, `manager/`: each has a README listing its contents. Material moves between them only when its audience changes.
- `devops/terraform/`: reference stacks, `aws/*` and `azure/*`, each a self-contained root module. See `devops/terraform/README.md`.
- `devops/kubernetes/`: Kustomize bases, overlays, and components for sample apps. See `devops/kubernetes/README.md`.
- `.github/workflows/kubernetes.yml`: renders every overlay, then kubeconform (strict) and checkov on the rendered output.
- `devops/aws/`, `devops/azure/`: CLI operations guides (`guides/`) plus CloudFormation (`devops/aws/cloudformation/`) and Bicep (`devops/azure/bicep/`) templates.
- `software/api-testing/`: OpenAPI contract (`openapi/items-api.yaml`), reference server, Postman, k6, and Locust tests. The spec defines the serverless stacks' behavior: change the spec, both handlers, and the local server together. `.github/workflows/api-testing.yml` runs everything against the local server.
- `devops/observability/`: Prometheus guide and SLO rules (`prometheus/`), Grafana 101 and dashboards (`grafana/`), the Compose lab (`local-stack/`), and AWS and Azure guides with templates. `.github/workflows/observability.yml` runs promtool, amtool, and collector validation, then starts the lab and runs `scripts/check_observability_lab.py`.
- `devops/bash/`: Bash 101 guides and `scripts/` (sourcing `lib/common.sh`). `.github/workflows/bash.yml` runs ShellCheck, shfmt, Bats (`tests/*.bats`), and `tests/integration.sh` in Ubuntu, Rocky, and AlmaLinux containers.
- `devops/docker/`: Docker 101 guides, `examples/` (Dockerfiles and a Compose file), and `scripts/`. `.github/workflows/docker.yml` runs Hadolint, builds, Trivy, the Compose smoke test, and `docker-audit.sh --strict`.
- `ROADMAP.md`: coverage and planned areas; move an area to "Covered today" only when it meets the definition of done there.
- `scripts/check_cli_commands.py`: checks every `aws`/`az` command, flag, and `--query` in Markdown against the real CLIs (run by `.github/workflows/cli-commands.yml`).
- `.github/workflows/cloud-templates.yml`: cfn-lint and checkov for CloudFormation; bicep build, lint, and checkov for Bicep.
- `.github/workflows/docs.yml`: markdownlint, cspell, lychee link check, generated-file freshness.
- `.github/workflows/terraform.yml`: fmt, validate, `terraform test` (mock providers, no credentials), tflint, checkov.

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
- Lock files need checksums for every platform, not just the one that ran `init`: CI runs Linux with a plugin cache and `-lockfile=readonly`, which rejects a lock file that only has Windows or macOS hashes. After adding or upgrading a provider, run in each stack: `terraform providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64 -platform=windows_amd64`.

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
