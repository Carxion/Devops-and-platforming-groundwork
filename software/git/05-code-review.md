# 5. Code review and repository settings

[← Git 101](README.md)

Review is how a team shares knowledge, catches problems, and keeps the codebase consistent. Its biggest cost is waiting: a pull request that sits for two days slows delivery more than anything the review finds. This guide covers how to author and review well, and the repository settings that make good practice the default.

## For authors: make your pull request easy to review

- **Keep it small.** Aim for a few hundred changed lines at most. Large pull requests get skimmed and approved; small ones get read. Split refactoring from behavior changes, and mechanical changes (renames, formatting) from everything else.
- **Explain why, not just what.** The diff shows what changed. The description should say why, what you considered and rejected, how you tested it, and what reviewers should look at hardest. A [pull request template](templates/pull_request_template.md) prompts for this.
- **Review it yourself first.** Read your own diff in the Git host before asking anyone. You'll catch debug code, leftover TODOs, and unrelated changes.
- **Make CI pass before asking.** Reviewers shouldn't spend time on what a linter or test catches.
- **Tidy the commits** if your team merges with merge commits or rebases: [fixup and autosquash](03-complex-commands.md#clean-up-your-branch-before-review-interactive-rebase-with-fixups). With squash merging, the pull request description matters more than the individual commits.
- **Respond to every comment,** with a change or a reason, and resolve threads only when the reviewer is satisfied (or per your team's convention).

## For reviewers: what to look for

In rough order of importance:

1. **Is this the right change?** Does it solve the stated problem, and is it the simplest approach? Catching a wrong design here is worth more than any number of style comments.
2. **Correctness:** edge cases (empty, null, very large, concurrent), error handling, and what happens when a dependency is slow or down.
3. **Security:** input validation, authorization checks on every new endpoint, secrets in code or logs, injection (SQL, shell, template), and new dependencies (are they maintained, and do we need them?).
4. **Operability:** will we know when this breaks (logs, metrics, alerts)? Can it be rolled back? Does it need a migration, a feature flag, or a runbook update?
5. **Tests:** do they cover the change, and would they fail if the code were wrong?
6. **Readability:** names, structure, and comments that explain why. Would a new team member understand this in six months?
7. **Style:** only what the formatter and linter don't already enforce. If you keep making the same style comment, add a lint rule instead.

The [review checklist template](templates/review-checklist.md) has the full list to copy into a team's guidelines.

### How to comment

- **Label the weight of each comment,** so the author knows what must change. A common convention ([Conventional Comments](https://conventionalcomments.org/)): `issue:` must fix, `suggestion:` worth considering, `question:` asking to understand, `nit:` trivial and optional, `praise:` something done well.
- **Comment on the code, not the person,** and ask rather than assert when you're not sure: "What happens if `items` is empty here?" works better than "This is broken."
- **Suggest the fix** where you can, using the Git host's suggestion feature, so the author can apply it with one click.
- **Approve with comments** when the remaining points are small, rather than blocking for another round.

### Response time

Set a team norm and keep it: for example, a first response within one working day, and small pull requests reviewed the same day. Track it if it's a problem. Google's [engineering practices guide](https://google.github.io/eng-practices/review/reviewer/speed.html) recommends responding within one business day at most.

## Repository settings

These turn the practices above into defaults the Git host enforces. Configure them on every repository that deploys to production. The names below are GitHub's; GitLab has an equivalent for each.

### Protect the default branch

| Setting | Why |
|---|---|
| Require a pull request before merging | Nobody pushes straight to `main` |
| Require at least one approval (two for critical repositories) | A second person sees every change |
| Dismiss approvals when new commits are pushed | An approval applies to what was reviewed, not what was added afterwards |
| Require review from code owners | The people who know an area see changes to it ([CODEOWNERS](#codeowners)) |
| Require status checks to pass, and branches to be up to date | CI must pass on the code as it will be merged |
| Require signed commits | Proves who made each commit ([signing setup](01-basics.md#sign-your-commits)) |
| Require linear history | If you squash or rebase: keeps `main` easy to read, revert, and bisect |
| Block force pushes and deletion | Nobody can rewrite or delete `main`, by accident or otherwise |
| Apply the rules to administrators too | No quiet exceptions; an emergency bypass should be deliberate and logged |

On GitHub these are **rulesets** (or the older branch protection rules); on GitLab, **protected branches** plus **merge request approval rules**.

### CODEOWNERS

A `CODEOWNERS` file (in `.github/`, the root, or `docs/` on GitHub; the root, `.gitlab/`, or `docs/` on GitLab) maps paths to the people or teams who must review changes to them:

```text
# Later lines take precedence over earlier ones.
*                       @example-org/platform-team
/terraform/             @example-org/infrastructure
/.github/workflows/     @example-org/platform-team @example-org/security
/src/billing/           @example-org/billing
```

With "require review from code owners" on, a change to `/terraform/` can't merge without an approval from the infrastructure team. Protect the `CODEOWNERS` file itself by owning it. A fuller [example](templates/CODEOWNERS) is in the templates.

### Other settings worth turning on

- **Secret scanning and push protection:** block pushes that contain recognizable credentials.
- **Dependency alerts and automated update pull requests:** Dependabot on GitHub, dependency scanning on GitLab, or Renovate on either. This repository's [dependabot.yml](../../.github/dependabot.yml) is a working example.
- **Delete branches after merge:** keeps the branch list meaningful.
- **Merge method:** allow only the one your team uses (squash, rebase, or merge commit).
- **A pull request template:** `.github/pull_request_template.md` on GitHub, `.gitlab/merge_request_templates/Default.md` on GitLab.

## Git hooks

Hooks are scripts Git runs at certain moments (`pre-commit`, `commit-msg`, `pre-push`). They live in `.git/hooks`, which isn't committed, so use a shared framework instead:

```sh
pipx install pre-commit        # https://pre-commit.com/
pre-commit install             # installs the hook defined in the repository's .pre-commit-config.yaml
pre-commit run --all-files     # run every hook once, on everything
```

Good hooks are fast: formatters, linters on changed files, and a secret scanner. Run the same checks in CI, because hooks are optional and anyone can skip them with `--no-verify`.

## Next

Back to the [Git 101 overview](README.md), or on to the [tech lead checklist's](../../tech-lead/README.md) source control items.
