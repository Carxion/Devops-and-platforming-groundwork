# 4. Recovery: undo almost anything

[← Git 101](README.md)

Git rarely loses committed work. Commits that seem gone (after a reset, a bad rebase, a deleted branch) stay in the repository for at least two weeks by default, and the **reflog** remembers where every branch and `HEAD` pointed. What Git can't recover is work that was never committed or stashed, so commit early, even as "WIP".

Find your situation, then follow the recipe. Each one is run by the [tests](tests/recipes.sh).

| Situation | Jump to |
|---|---|
| The last commit has a typo or is missing a file | [Fix the last commit](#fix-the-last-commit) |
| I committed to the wrong branch | [Move commits to another branch](#move-commits-to-another-branch) |
| I need to undo a commit that's already pushed | [Undo a pushed commit](#undo-a-pushed-commit) |
| I reset, rebased, or deleted a branch and lost commits | [Get lost commits back with the reflog](#get-lost-commits-back-with-the-reflog) |
| A rebase or merge went wrong halfway | [Back out of a rebase or merge](#back-out-of-a-rebase-or-merge) |
| Someone force-pushed over my work | [Recover from a force push](#recover-from-a-force-push) |
| Git says "detached HEAD" | [Detached HEAD](#detached-head) |
| I deleted a file and want it back | [Restore a deleted file](#restore-a-deleted-file) |
| A secret was committed | [A secret was committed](#a-secret-was-committed) |
| History contains a huge file | [A large file or secret is in history](#a-large-file-or-secret-is-in-history) |

Before trying anything risky, take a free backup: `git branch backup/before-fix`. A branch costs nothing and keeps every commit reachable.

## Fix the last commit

Not pushed yet:

```sh
git add forgotten-file.txt
git commit --amend --no-edit           # add it to the last commit, same message
git commit --amend -m "Better message" # or change the message
```

Already pushed to your own branch (nobody else uses it): amend, then `git push --force-with-lease`. On a shared branch, make a new commit instead.

## Move commits to another branch

You made two commits on `main` that should be on a feature branch, and haven't pushed:

```sh
git branch feat/export          # a new branch pointing at your commits
git reset --keep HEAD~2         # move main back two commits; your files stay as they were in the new branch
git switch feat/export
```

`--keep` is the safe reset: like `--hard`, but it refuses if it would throw away uncommitted changes. They belong to an existing branch instead? `git switch other-branch && git cherry-pick main~2..main`, then reset `main` as above.

## Undo a pushed commit

```sh
git revert 9f8e7d6               # a new commit that undoes it; safe on shared branches
git revert -m 1 4c5d6e7          # undoing a merge commit (see the complex commands guide)
git revert --no-commit HEAD~3..HEAD && git commit -m "Revert the last three commits"
```

Never `reset` and force-push a shared branch to undo something: everyone who pulled has the commits already, and their next push brings them back.

## Get lost commits back with the reflog

```sh
git reflog                               # every position HEAD has had, newest first
git reflog show feat/export              # the same, for one branch
git branch rescued a1b2c3d               # put a branch on the commit you want back
git reset --hard HEAD@{2}                # or: move the current branch back to where HEAD was two moves ago
```

| Part | Meaning |
|---|---|
| `reflog` | A local log of where `HEAD` pointed after each commit, reset, rebase, checkout, and merge |
| `HEAD@{2}` | Where `HEAD` was two moves ago. `main@{yesterday}` and `HEAD@{1.hour.ago}` work too |
| `branch rescued a1b2c3d` | The safest recovery: a new name for the old commit, changing nothing else |

A deleted branch's last commit is in the reflog of `HEAD` (if you had it checked out) or in the message `git branch -D` printed (`Deleted branch x (was a1b2c3d)`). The reflog is local only: it's in your clone, not on the server, and entries expire after 90 days by default (30 for commits no branch points to any more).

Commits not in any reflog (from a stash you dropped, for example) can still be found while they exist:

```sh
git fsck --lost-found --no-reflogs | grep commit     # commits nothing points to
git show <id>                                        # inspect each one
```

## Back out of a rebase or merge

```sh
git rebase --abort               # in the middle of a rebase: back to exactly where you started
git merge --abort                # in the middle of a merge
git cherry-pick --abort
git reset --hard ORIG_HEAD       # after a rebase or merge finished, but it's wrong
```

`ORIG_HEAD` is where the branch was before the last rebase, merge, or reset. Use it straight away: the next such command overwrites it. Later, find the position in `git reflog` instead.

## Recover from a force push

Someone force-pushed `main` and your commits vanished from the server. Your clone still has them if you'd fetched before the force push:

```sh
git reflog show origin/main               # where origin/main pointed after each fetch
git branch recovered origin/main@{1}      # the position before the last fetch
git log --oneline recovered -10           # check it's the history you expect
```

Then push the recovered work back (after agreeing with whoever force-pushed). On GitHub and GitLab, turn on branch protection so `main` can't be force-pushed at all: see [code review](05-code-review.md#protect-the-default-branch).

## Detached HEAD

`HEAD` points at a commit instead of a branch, usually after `git checkout <commit>` or `git switch --detach`, or during a rebase. Looking around is fine. To keep commits made here:

```sh
git switch -c keep-this-work       # put a branch on them now
git switch main                    # or leave; Git prints the IDs of any commits left behind
```

## Restore a deleted file

```sh
git restore path/to/file                         # deleted but not committed
git log --oneline --diff-filter=D -- path/to/file    # find the commit that deleted it
git restore --source=<that commit>~1 path/to/file    # restore it from the commit before
```

## A secret was committed

**Rotate the secret first.** Once a secret is pushed to a shared remote, assume it's been copied: clones, forks, CI logs, and the Git host's caches all have it, and attackers run automated scanners that look for credentials pushed to public repositories. Removing it from history doesn't un-leak it. Revoke it, issue a new one, and check the provider's logs for use.

Then, if it was never pushed: `git reset --soft HEAD~1`, remove the secret, add the file to `.gitignore`, and commit again.

If it was pushed, removing it from history is the cleanup, after rotation. See the next section, and prevent the next one:

- Turn on the Git host's secret scanning and push protection (GitHub and GitLab both have them).
- Run a scanner such as [gitleaks](https://github.com/gitleaks/gitleaks) in a pre-commit hook and in CI.
- Keep secrets out of files Git can see: environment variables, a secrets manager, or files listed in `.gitignore`.

## A large file or secret is in history

Rewriting published history affects everyone with a clone. Agree it with the team, do it once, and have everyone re-clone afterwards.

The recommended tool is [git filter-repo](https://github.com/newren/git-filter-repo) (`pip install git-filter-repo`, or the `git-filter-repo` package on Ubuntu 22.04 and later and in EPEL). It's faster and safer than the older `git filter-branch`, which Git's own documentation now warns against.

```sh
git clone --mirror git@github.com:owner/repo.git repo-cleanup.git    # a fresh full copy, every branch and tag
cd repo-cleanup.git
git filter-repo --invert-paths --path db/dump.sql                    # remove a file from every commit
git filter-repo --replace-text ../expressions.txt                    # or replace secret strings everywhere
git push --force --mirror                                            # replace every branch and tag on the server
```

| Part | Meaning |
|---|---|
| `clone --mirror` | A bare copy of every branch, tag, and other ref. filter-repo insists on a fresh clone, so a mistake can't damage your working copy |
| `--invert-paths --path db/dump.sql` | Keep everything except this path, in every commit |
| `--replace-text expressions.txt` | Each line is a string to replace, like `AKIAEXAMPLEKEY123456==>REMOVED` (or `regex:...` for patterns) |
| `push --force --mirror` | Overwrite the server's branches and tags with the rewritten ones |

Afterwards, pull requests and forks on the Git host may still hold the old commits; GitHub and GitLab document how to ask them to purge cached views. Everyone must re-clone: an old clone pushed back reintroduces everything.

## Next

[Code review and repository settings](05-code-review.md).
