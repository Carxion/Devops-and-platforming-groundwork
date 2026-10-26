# Git 101

[← Software](../README.md)

Every other area in this repository assumes Git: infrastructure code, pipelines, and reviews all run through it. This folder goes from first setup to the commands that get you out of trouble, with complex commands taken apart piece by piece, and the review practices and repository settings that keep a shared codebase healthy.

> **Status.** Every command recipe in these guides passes [tests/recipes.sh](tests/recipes.sh), run against real repositories on Ubuntu 22.04 (Git 2.34, the oldest Git these guides support), Ubuntu 24.04, and Rocky Linux 9. That includes bisect, autosquash, reflog recovery, force-push recovery, and removing a file and a secret from history with git filter-repo. CI runs ShellCheck and shfmt on the scripts; run the recipe tests locally (below).

## Learning path

| # | Guide | You'll be able to |
|---|---|---|
| 1 | [Basics](01-basics.md) | Install and configure Git, authenticate and sign commits with SSH keys, understand the working tree, index, and commits, and do everyday work: status, diff, add, commit, push, pull, ignore files |
| 2 | [Branching and collaboration](02-branching-and-collaboration.md) | Choose a branching model, merge, rebase, or squash, keep a branch up to date safely, resolve conflicts, tag releases, and write useful commit messages |
| 3 | [Complex commands, broken down](03-complex-commands.md) | Bisect to find a breaking commit, clean up a branch with fixups, search history, blame past reformatting, cherry-pick and revert merges, use worktrees and stashes, find large files, and clone big repositories fast |
| 4 | [Recovery](04-recovery.md) | Undo almost anything: amend, move commits, revert pushed work, get lost commits back from the reflog, recover from a force push, and clean a secret or a large file out of history |
| 5 | [Code review and repository settings](05-code-review.md) | Write reviewable pull requests, review for what matters, protect the default branch, set up CODEOWNERS, and use hooks |

New to Git? Read 1 and 2 with a terminal open. Already comfortable? Keep 3 and 4 open as references; 4 is the one to find before you need it.

To practice safely, use a throwaway repository:

```sh
mkdir /tmp/practice && cd /tmp/practice && git init
docker run --rm -it ubuntu:24.04 bash -c 'apt-get update && apt-get install -y git && bash'   # or in a container
```

## Templates

| File | What it is |
|---|---|
| [gitconfig](templates/gitconfig) | A recommended `~/.gitconfig`, every setting explained: signing, rebase on pull, conflict style, rerere, aliases |
| [gitattributes](templates/gitattributes) | A `.gitattributes` that fixes line endings for everyone and marks binary and generated files |
| [CODEOWNERS](templates/CODEOWNERS) | Required reviewers by path, for GitHub and GitLab |
| [pull_request_template.md](templates/pull_request_template.md) | A pull request (merge request) template that asks for why, testing, risk, and rollback |
| [review-checklist.md](templates/review-checklist.md) | What reviewers check, in order of importance, and comment labels |

## Scripts

| Script | What it does |
|---|---|
| [prune-branches.sh](scripts/prune-branches.sh) | Lists local branches that are merged, or whose remote branch was deleted (squash-merged pull requests), and deletes them with `--delete`. Never touches the current branch, branches in other worktrees, or `main` |
| [find-large-blobs.sh](scripts/find-large-blobs.sh) | Lists the largest files anywhere in history, including deleted ones every clone still downloads |

## Running the tests

```sh
# On any machine with Git and Bash (it uses a temporary HOME, so your settings and repositories are untouched)
bash software/git/tests/recipes.sh

# On the oldest supported Git, as CI does
docker run --rm -v "$PWD/software/git:/work:ro" ubuntu:22.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq git openssh-client git-filter-repo >/dev/null && bash /work/tests/recipes.sh'
```

CI lints the scripts ([lint.yml](../../.github/workflows/lint.yml)); the recipe tests run locally.

## Related

- The [glossary](../../GLOSSARY.md#source-control-and-collaboration) defines branching, merge, rebase, pull request, and trunk-based development.
- The [tech lead checklist](../../tech-lead/README.md) asks about branch protection, review practices, and repository hygiene in its source control and CI sections.
- [GitLab CI/CD](../../devops/gitlab/README.md) builds on this: merge requests, protected branches, and pipelines. Jenkins is [on the roadmap](../../ROADMAP.md).
