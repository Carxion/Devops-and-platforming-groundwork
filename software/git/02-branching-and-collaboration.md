# 2. Branching and collaboration

[← Git 101](README.md)

How work moves from your branch into the shared history: choosing a branching model, merging and rebasing, resolving conflicts, and tagging releases.

## Branching models

| Model | How it works | Fits |
|---|---|---|
| **Trunk-based development** | Everyone merges small changes into `main` at least daily. Branches live hours or a day or two. Unfinished features hide behind feature flags. | Teams that deploy often. It's what the [DORA research](https://dora.dev/capabilities/trunk-based-development/) associates with higher delivery performance. |
| **GitHub flow** | Branch from `main`, open a pull request, review, merge, deploy. Like trunk-based development, but branches may live a little longer. | Most web services and internal tools. |
| **Release branches** | Trunk-based on `main`, plus a `release/1.4` branch cut for each release that only gets fixes, cherry-picked from `main`. | Software you ship in versions and must patch: libraries, appliances, on-premises products. |
| **GitFlow** | Long-lived `develop` and `main`, plus feature, release, and hotfix branches. | Rarely the right choice now. Its own author suggests simpler models for software that's continuously delivered. |

Whatever the model, long-lived branches are where pain comes from: the longer a branch lives, the bigger the merge and the later you find out it conflicts. Keep branches small and short.

Name branches so their purpose is obvious: `fix/login-timeout`, `feat/export-csv`, `chore/bump-terraform`. Some teams include the ticket: `ops-412-login-timeout`.

## Merging, rebasing, and squashing

Three ways to get a branch's commits into `main`, and what history looks like after each:

| Method | Command | Result |
|---|---|---|
| Merge commit | `git merge --no-ff feature` | All the branch's commits, plus a merge commit joining the two lines. History shows exactly what happened, including every "fix typo" commit. |
| Rebase and fast-forward | `git rebase main` on the branch, then `git merge --ff-only feature` | The branch's commits replayed on top of `main`, as if written there. Linear history. |
| Squash merge | `git merge --squash feature`, then `git commit` | One new commit with all the branch's changes. Linear and tidy, but the individual commits are gone. |

Most teams pick one in their Git host's settings and use it for every pull request. Squash merge is a popular choice because it keeps `main` to one commit per pull request, which is easy to read and easy to revert.

### Keeping your branch up to date

```sh
git fetch
git rebase origin/main          # replay your commits on top of the latest main
# resolve any conflicts (below), then:
git push --force-with-lease     # your branch's history changed, so a plain push is refused
```

**Never rebase a branch other people are working on.** Rebasing rewrites commits (new IDs), so anyone who has the old ones ends up with duplicates. Rebasing your own branch before review is fine.

`--force-with-lease` is the safe force push: it refuses if the remote branch has commits you haven't fetched, such as a teammate's push or a suggestion applied in the review tool. Plain `--force` would silently delete them.

Rebasing a stack of branches (one built on another)? Git 2.38 and later can move them all at once: `git rebase --update-refs main`.

## Resolving conflicts

A conflict happens when both sides changed the same lines. Git stops and marks the file:

```text
<<<<<<< HEAD
timeout_seconds = 15
||||||| base
timeout_seconds = 5
=======
timeout_seconds = 10
>>>>>>> fix/login-timeout
```

The section between `<<<<<<<` and `|||||||` is one side, between `|||||||` and `=======` is how the line looked before either change (the base), and below `=======` is the other side. The base section appears with `git config --global merge.conflictStyle diff3` (or `zdiff3` on Git 2.35 and later). Turn it on: knowing what the line used to be is what tells you how to combine the two changes.

```sh
git status                       # lists the conflicted files under "Unmerged paths"
# edit each file: keep the right lines, delete all the markers
git add path/to/file             # mark it resolved
git rebase --continue            # or: git merge --continue, git cherry-pick --continue

git rebase --abort               # give up and go back to how things were before
git checkout --ours path/to/file    # take one side's version of a whole file
git checkout --theirs path/to/file
```

During a rebase, "ours" is the branch you're rebasing onto (`main`) and "theirs" is your own commit being replayed, which is the opposite of what most people expect. When in doubt, open the file and look.

With `rerere.enabled true` (from [the setup](01-basics.md#install-and-set-up)), Git records each resolution and reapplies it automatically the next time the same conflict appears, which saves a lot of work when rebasing a long branch repeatedly.

## Tags and releases

A tag is a permanent name for a commit, used for releases.

```sh
git tag -a v1.4.0 -m "Release 1.4.0"        # annotated tag: has an author, date, message (and signature if tag.gpgsign)
git push origin v1.4.0                      # tags aren't pushed by default
git tag --list 'v1.*' --sort=-v:refname     # newest version first
git describe --tags                         # v1.4.0-3-g1a2b3c4: three commits after v1.4.0
git log --oneline v1.3.0..v1.4.0            # what changed between two releases
```

Use annotated tags (`-a`) for releases; lightweight tags (no `-a`) carry no author or date. Never move a release tag once it's pushed: build systems, package managers, and other people's checkouts trust that `v1.4.0` means one exact commit.

Version numbers usually follow [Semantic Versioning](https://semver.org/): MAJOR.MINOR.PATCH, where MAJOR changes break compatibility, MINOR adds features, and PATCH fixes bugs.

## Commit message conventions

Some teams use [Conventional Commits](https://www.conventionalcommits.org/) so tools can generate changelogs and version numbers from the history:

```text
feat(export): add CSV export of the audit log
fix(auth): retry once on identity provider timeout
chore(deps): bump terraform-provider-aws to 6.14
feat(api)!: remove the v1 items endpoint
```

The `!` marks a breaking change. It's worth adopting if you'll use the tooling (release-please, semantic-release); otherwise a clear summary line and a body that explains why matter more than the prefix.

## Next

[Complex commands, broken down](03-complex-commands.md).
