<!-- markdownlint-disable-file MD041 -->
## What changed and why

<!-- One or two sentences. Link the issue if there is one. -->

## Checklist

- [ ] Contains no program-specific, customer, or employer information
- [ ] Factual claims link a primary source, added to References with a `[KEY]`
- [ ] New items follow the format in [CONTRIBUTING.md](../CONTRIBUTING.md#writing-checklist-items)
- [ ] Ran `python scripts/build_checklists.py` after editing `tech-lead/README.md`
- [ ] Added a line to `CHANGELOG.md` under **Unreleased**
- [ ] Updated `tech-lead/templates/` if Appendix A changed (or the reverse)
- [ ] Terraform changes pass `terraform test`, tflint, and checkov, with any checkov skip explained inline (or no Terraform changes)
