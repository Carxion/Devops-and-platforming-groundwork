# 3. Complex commands, broken down

[← Git 101](README.md)

The commands that solve real problems but look intimidating, each taken apart piece by piece. Every one of them is run by the [tests](tests/recipes.sh) on Ubuntu and Rocky Linux.

## Find the commit that broke something: `git bisect run`

```sh
git bisect start HEAD v1.4.0
git bisect run ./scripts/test-login.sh
git bisect reset
```

| Part | Meaning |
|---|---|
| `bisect start HEAD v1.4.0` | Search between a bad commit (`HEAD`, broken now) and a good one (`v1.4.0`, worked then) |
| `bisect run ./scripts/test-login.sh` | Check out the commit halfway between, run the script, and mark it good (exit 0) or bad (exit 1 to 127, except 125), repeating until one commit is left |
| exit code 125 | "Can't test this one" (it doesn't build, say): skip it |
| `bisect reset` | Go back to where you started |

A binary search: 1,000 commits take about 10 tests. Without a script, mark each commit yourself with `git bisect good` or `git bisect bad`. The test script must exist outside the commits being tested (or be committed before the good commit), or it disappears as bisect moves back in time. Copy it to `/tmp` first if needed.

## Clean up your branch before review: interactive rebase with fixups

```sh
git commit --fixup=a1b2c3d
git rebase -i --autosquash main
```

| Part | Meaning |
|---|---|
| `commit --fixup=a1b2c3d` | Make a commit titled `fixup! <title of a1b2c3d>`, meaning "this belongs in a1b2c3d" |
| `rebase -i main` | Rewrite every commit on this branch since `main`, opening a to-do list in the editor |
| `--autosquash` | Pre-arrange the list so each `fixup!` commit sits after its target, marked `fixup` (melt in, drop its message) |

In the to-do list, each line is an action and a commit. Change the action word to `reword` (edit the message), `edit` (stop to change the commit), `squash` (combine, keeping both messages), `fixup` (combine, keeping the first message), or `drop`. Reorder lines to reorder commits. Save and close to run it.

Set `git config --global rebase.autoSquash true` to make `--autosquash` the default. To run the whole thing without an editor (in a script, for example), `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash main` accepts the list as Git arranged it.

## Find when a line or a value appeared: the pickaxe

```sh
git log -S 'timeout_seconds = 5' --oneline -- config/
git log -G 'timeout_seconds = [0-9]+' -p -- config/app.toml
```

| Part | Meaning |
|---|---|
| `-S 'text'` | Commits where the number of occurrences of `text` changed: it was added or removed |
| `-G 'regex'` | Commits whose diff has an added or removed line matching the regular expression, including lines merely changed |
| `-p` | Show each matching commit's diff |
| `-- config/` | Only look at changes under this path. The `--` separates paths from branch names |

`-S` is the fastest way to answer "when did this function or setting get deleted?". It searches all history, including content that no longer exists in any file.

## Who changed this line, really: `git blame` without the noise

```sh
git blame -w -C -C -L 40,60 src/handler.py
git log -L 40,60:src/handler.py
```

| Part | Meaning |
|---|---|
| `-w` | Ignore whitespace changes, so a reformat doesn't take the blame |
| `-C -C` | Follow lines moved or copied from other files in the same commit, or (twice) any commit that created the file |
| `-L 40,60` | Only lines 40 to 60 |
| `log -L 40,60:file` | Every commit that changed those lines, with the diff of just those lines, newest first |

Big reformatting commits (a linter run across the codebase, say) can be hidden from blame permanently: list their IDs in a `.git-blame-ignore-revs` file and run `git config blame.ignoreRevsFile .git-blame-ignore-revs`. GitHub and GitLab read the same file.

## Copy a fix to a release branch: `cherry-pick -x`

```sh
git switch release/1.4
git cherry-pick -x 9f8e7d6
git cherry-pick -x main~3..main
```

| Part | Meaning |
|---|---|
| `cherry-pick 9f8e7d6` | Apply that commit's changes here, as a new commit |
| `-x` | Add "(cherry picked from commit 9f8e7d6...)" to the message, so you can trace the copy to its original |
| `main~3..main` | A range: the last three commits on `main` (`A..B` means "in B but not in A") |

Fix on `main` first, then cherry-pick to release branches: never the other way round, or the fix gets lost at the next release.

## Undo a merged pull request: `revert -m 1`

```sh
git revert -m 1 4c5d6e7
```

| Part | Meaning |
|---|---|
| `revert 4c5d6e7` | Make a new commit that undoes that commit's changes. History is only added to, so it's safe on shared branches |
| `-m 1` | That commit is a merge, with two parents. Keep parent 1 (the main line) and undo everything parent 2 (the branch) brought in |

To bring the work back later, revert the revert (`git revert <revert commit>`). Merging the branch again won't work: Git sees those commits as already merged. A squash-merged pull request is an ordinary commit, so reverting it needs no `-m`.

## Work on two branches at once: `git worktree`

```sh
git worktree add ../hotfix -b hotfix/cert-expiry origin/main
cd ../hotfix && git commit -am "Renew the certificate check threshold" && git push -u origin HEAD
cd - && git worktree remove ../hotfix
```

| Part | Meaning |
|---|---|
| `worktree add ../hotfix` | Check out a second working directory, sharing the same repository (no second clone) |
| `-b hotfix/cert-expiry origin/main` | ...on a new branch, starting from the latest `main` |
| `push -u origin HEAD` | Push the current branch under the same name and track it |
| `worktree remove` | Delete the extra directory (refuses if it has uncommitted changes) |

Your half-finished work stays untouched in the original directory: no stash, no switching back and forth. `git worktree list` shows them all.

## Set work aside: `git stash` with a name

```sh
git stash push -u -m "half-done retry logic" -- src/
git stash list
git stash pop stash@{0}
```

| Part | Meaning |
|---|---|
| `push -u` | Save uncommitted changes and clean the working tree. `-u` includes untracked (new) files, which plain stash leaves behind |
| `-m "..."` | A name, so `git stash list` is readable a week later |
| `-- src/` | Only stash changes under this path |
| `pop stash@{0}` | Reapply that stash and drop it. `apply` reapplies and keeps it |

Stashes are easy to forget. For anything longer than a quick switch, a work-in-progress commit on a branch (or a worktree) is safer.

## Find the biggest files in history

```sh
git rev-list --objects --all |
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
  awk '$1 == "blob"' | sort -k3,3 -n -r | head -10 |
  awk '{ printf "%10.1f MB  %s  %s\n", $3 / 1048576, substr($2, 1, 10), $4 }'
```

| Part | Meaning |
|---|---|
| `rev-list --objects --all` | Every object reachable from any branch or tag: commits, trees, and file contents (blobs), with the path for blobs |
| `cat-file --batch-check='...'` | For each object, print its type, ID, size in bytes, and the rest of the input line (the path) |
| `awk '$1 == "blob"'` | Keep file contents only |
| `sort -k3,3 -n -r` | Sort by the third field (size), numerically, largest first |
| last `awk` | Print the size in MB, a short ID, and the path |

This finds the 300 MB database dump someone committed in 2022 and deleted a week later, which every clone still downloads. Removing it takes a history rewrite: see [a large file or secret is in history](04-recovery.md#a-large-file-or-secret-is-in-history). [find-large-blobs.sh](scripts/find-large-blobs.sh) wraps this pipeline.

## Read history as a graph, your way: `git log --format`

```sh
git log --graph --format='%C(auto)%h %C(blue)%ad%C(auto)%d %s %C(dim)(%an)' --date=short --all -30
git log --since='2 weeks ago' --no-merges --format='%an' | sort | uniq -c | sort -rn
```

| Part | Meaning |
|---|---|
| `--graph --all` | Draw the branch structure, for every branch and tag |
| `%h %ad %d %s %an` | Short hash, author date, branch and tag names, subject, author name |
| `%C(auto)`, `%C(blue)`, `%C(dim)` | Colors (auto colors the hash and names the usual way) |
| `--since='2 weeks ago' --no-merges` | Only recent commits, skipping merge commits |
| `sort \| uniq -c \| sort -rn` | Count commits per author, most first |

Save a format you like as an alias: `git config --global alias.lg "log --graph --format='%C(auto)%h %C(blue)%ad%C(auto)%d %s %C(dim)(%an)' --date=short"`, then `git lg --all`.

## Clean up branches that are done

```sh
git fetch --prune
git branch --merged origin/main | grep -vE '^\*|^\+|^\s*(main|master)$' | xargs -r git branch -d
git branch -vv | awk '/: gone]/ { print $1 }' | xargs -r git branch -D
```

| Part | Meaning |
|---|---|
| `fetch --prune` | Update remote branches, and forget the ones deleted on the server |
| `branch --merged origin/main` | Local branches whose commits are all in `main` |
| `grep -vE '^\*\|^\+\|...'` | Leave out the current branch (`*`), branches checked out in other worktrees (`+`), and `main` itself |
| `xargs -r git branch -d` | Delete them. `-d` refuses to delete unmerged work; `-r` does nothing if the list is empty |
| `branch -vv` and `: gone]` | Branches whose upstream was deleted (usually: the pull request was squash-merged, so `--merged` can't tell) |
| `branch -D` | Force delete, because a squash-merged branch's commits aren't in `main` under their own IDs |

Check the second list before deleting: a gone upstream usually means merged, but not always. [prune-branches.sh](scripts/prune-branches.sh) shows both lists and only deletes when asked.

## Clone big repositories quickly

```sh
git clone --filter=blob:none https://github.com/owner/big-repo.git
git clone --depth 1 --branch v1.4.0 https://github.com/owner/big-repo.git
git sparse-checkout set services/billing libs/common
```

| Part | Meaning |
|---|---|
| `--filter=blob:none` | Partial clone: all commits and trees, but file contents are downloaded only when needed. Full history still works |
| `--depth 1 --branch v1.4.0` | Shallow clone: only that one commit. Fastest, for CI builds; `git log` and `blame` can't see history |
| `sparse-checkout set dir...` | Only these directories appear in the working tree (for monorepos) |

For CI, a shallow clone is usually right. For developers, a partial clone keeps full history without the download.

## Next

[Recovery: undo almost anything](04-recovery.md).
