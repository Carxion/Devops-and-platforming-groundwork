# Contributing

Corrections and additions are welcome. The most useful contributions fix something that's wrong or out of date: a standard that has been revised, a link that moved, or advice that no longer holds.

## Before you open anything

**Do not contribute program-specific information.** Examples must be generic or drawn from public sources. Don't submit anything from a customer, employer, or restricted environment, even de-identified. If you're unsure, leave it out.

**Source factual claims to a primary source**: the standard, specification, or official documentation, not a blog post summarizing it. Practitioner judgment is fine without a citation, but it should read as a default rather than a rule.

## Ways to contribute

- **Report a correction:** open a [correction issue](../../issues/new?template=correction.yml) with the section, what's wrong, and the primary source.
- **Suggest an item:** open a [new item issue](../../issues/new?template=new-item.yml). Say which section it belongs in and what goes wrong on a program that skips it.
- **Open a pull request** for small, clear fixes. For anything that changes a section's structure, open an issue first.

## Writing checklist items

Items follow a consistent shape so they can be parsed into the [phase view and CSV](tech-lead/checklists/):

```markdown
- [ ] **30** Imperative sentence describing one thing to check or do. Optional second sentence on why it matters.
```

- **One timing tag per item:** `W1`, `30`, `60`, or `90`. Items in section 9 take their phase from the `### By day N` heading instead.
- **Start with a verb.** "Confirm…", "Inventory…", "Check whether…".
- **Ask for observations, not solutions.** "Find out how applies happen" rather than "Move applies to a pipeline". The tech lead's job in the first 90 days is to learn before changing things.
- **Stay vendor-neutral.** Name a specific tool only as an example ("for example Argo CD or Flux"), and use generic terms where they're clear.
- **Cite standards by key**, like `[SLSA]`, and add or update the matching row in [References](tech-lead/README.md#references). Note the version current at the time of review.
- **Sub-bullets** (two-space indent) are allowed for lists inside an item. They become the `Details` column in the CSV.

## Making a change

1. Edit `tech-lead/README.md`. It is the single source of truth. Don't edit files in `tech-lead/checklists/` by hand.
2. Regenerate the derived checklists:

   ```sh
   python scripts/build_checklists.py
   ```

3. Run the docs checks CI runs:

   ```sh
   npx markdownlint-cli2 "**/*.md"
   npx cspell@10.3.6 "**/*.md"   # the version CI pins in lint.yml
   python scripts/build_checklists.py --check
   ```

   If cspell flags a correctly spelled term (an acronym, a product, a surname), add it to `words` in [cspell.json](cspell.json).
4. Add a line to [CHANGELOG.md](CHANGELOG.md) under **Unreleased**.
5. If you checked the references, update the **Last reviewed** date at the top of `tech-lead/README.md`.

Note that item IDs in the generated files (`3.2-04`) are positional, so adding an item renumbers the ones after it in that subsection. Anyone tracking progress in the CSV should match on item text when they update.

## Terraform changes

The stacks in [devops/terraform/](devops/terraform/) are reference code. Changes should keep them generic, secure by default, and passing every check. See [devops/terraform/README.md](devops/terraform/README.md#checks-and-tested-versions) for the commands.

- Every variable has a description. Defaults should be safe for production; cheaper non-prod settings go in `terraform.tfvars.example` with a comment.
- Fix checkov findings where you can. Otherwise skip them inline, inside the resource block, with the reason: `#checkov:skip=CKV_AWS_123:Why this doesn't apply here.`
- Add or update a run in the stack's `tests/plan.tftest.hcl` for any conditional behavior you add.
- If you bump a provider, run `terraform init -upgrade` in each affected stack and commit the updated `.terraform.lock.hcl`.

## CLI commands and cloud templates

Commands in the `devops/aws/`, `devops/azure/`, `devops/kubernetes/`, and `devops/terraform/` guides were checked against the real CLIs. If you add or change an `aws` or `az` command, run the check:

```sh
python -m venv .venv && .venv/bin/pip install awscli azure-cli
.venv/bin/python scripts/check_cli_commands.py
```

It confirms commands and flags exist and that `--query` expressions parse. It can't confirm a command does what the text says, so run it against a sandbox account when you can.

CloudFormation templates must pass `cfn-lint` and checkov; Bicep templates must pass `bicep build`, `bicep lint`, and checkov (commands below).

## Running the tests locally

CI ([lint.yml](.github/workflows/lint.yml)) runs only fast static checks: formatting, linters, spelling, and links. The tests below don't run in CI, so run the ones for the area you change before opening a pull request, and say in it which you ran. Most need only Docker. Run them from the repository root unless noted.

| Area | Run | Details |
|---|---|---|
| Terraform | `terraform init -backend=false && terraform validate && terraform test` in each stack; `checkov -d devops/terraform --framework terraform` | [Checks and tested versions](devops/terraform/README.md#checks-and-tested-versions) |
| Kubernetes | Render every overlay, then `kubeconform -strict` and `checkov --framework kubernetes` | [Checks and tested versions](devops/kubernetes/README.md#checks-and-tested-versions) |
| AWS and Azure commands | `python scripts/check_cli_commands.py` (needs `awscli` and `azure-cli` installed) | [Above](#cli-commands-and-cloud-templates) |
| CloudFormation | `cfn-lint "devops/aws/cloudformation/**/*.yaml" "devops/observability/aws/cloudformation/**/*.yaml"`, then `checkov -d <folder> --framework cloudformation` | [CloudFormation](devops/aws/cloudformation/README.md) |
| Bicep | `bicep lint <file>` and `bicep build <file> --stdout > /dev/null` for each template, then `checkov -d <folder> --framework bicep` | [Bicep](devops/azure/bicep/README.md) |
| API testing | Start the reference server, then Spectral, Newman, Schemathesis, k6, and Locust | [Quick start](software/api-testing/README.md#quick-start-local) |
| Observability | `promtool test rules` in `devops/observability/prometheus/tests`; start the lab with `docker compose -f devops/observability/local-stack/compose.yaml --profile traffic up -d`, then `python3 scripts/check_observability_lab.py` | [The lab](devops/observability/local-stack/README.md) |
| Bash | Bats as a normal user, then `tests/integration.sh` in Ubuntu and Rocky containers | [Running the tests](devops/bash/README.md#running-the-tests) |
| Docker | `docker compose -f software/containers/docker/examples/compose.yaml up --build --exit-code-from smoke-test`, then Trivy on the images | [Docker](software/containers/docker/README.md) |
| Python | In each project: `uv sync --frozen && uv run mypy && uv run pytest` | [Projects and tooling](software/python/03-projects-and-tooling.md) |
| Go | In each module: `go vet ./... && go test -race ./... && go run golang.org/x/vuln/cmd/govulncheck@latest ./...` | [Projects and tooling](software/go/03-projects-and-tooling.md) |
| Unit testing examples | In `software/testing/python/example`: `uv sync && uv run pytest --cov`; in `software/testing/go/example`: `go test -race -cover ./...` | [Unit testing](software/testing/README.md) |
| API implementations | Build each items-api image, run it on port 8080, then Schemathesis (`--checks all`) and Newman against it | [Python](software/python/boilerplate/items-api/README.md), [Go](software/go/boilerplate/items-api/README.md) |
| Ansible | In `devops/ansible`: `molecule test` (needs Docker; 10 to 15 minutes) | [Running the checks](devops/ansible/README.md#running-the-checks) |
| GitLab CI/CD | `devops/gitlab/lab/lab.sh up`, then `python scripts/check_gitlab_examples.py` (needs Docker with about 6 GB free; 15 to 20 minutes) | [The lab](devops/gitlab/lab/README.md) |
| Git | `bash software/git/tests/recipes.sh`, ideally on Ubuntu 22.04 for the oldest supported Git | [Running the tests](software/git/README.md#running-the-tests) |

## License

By contributing, you agree your contribution is licensed under [CC BY 4.0](LICENSE), the same license as the rest of the content.
