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

3. Run the same checks CI runs:

   ```sh
   npx markdownlint-cli2 "**/*.md"
   npx cspell "**/*.md"
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

Commands in the `devops/aws/`, `devops/azure/`, `devops/kubernetes/`, and `devops/terraform/` guides are checked in CI against the real CLIs ([cli-commands.yml](.github/workflows/cli-commands.yml)). If you add or change an `aws` or `az` command, run the same check locally:

```sh
python -m venv .venv && .venv/bin/pip install awscli azure-cli
.venv/bin/python scripts/check_cli_commands.py
```

It confirms commands and flags exist and that `--query` expressions parse. It can't confirm a command does what the text says, so run it against a sandbox account when you can.

CloudFormation templates must pass `cfn-lint` and checkov; Bicep templates must pass `bicep build`, `bicep lint`, and checkov ([cloud-templates.yml](.github/workflows/cloud-templates.yml)).

## License

By contributing, you agree your contribution is licensed under [CC BY 4.0](LICENSE), the same license as the rest of the content.
