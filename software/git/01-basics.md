# 1. Git basics

[← Git 101](README.md)

Everything you need for everyday work: setting Git up, the model that makes the commands make sense, and the dozen commands you'll use every day.

## Install and set up

```sh
# Ubuntu (22.04 ships Git 2.34, 24.04 ships 2.43)
sudo apt-get update && sudo apt-get install -y git

# RHEL, Rocky Linux, AlmaLinux 9
sudo dnf install -y git

# macOS: xcode-select --install, or brew install git
# Windows: winget install Git.Git (includes Git Bash)

git --version
```

Every guide here works with Git 2.34 and later. Where a command needs something newer, it says so.

Tell Git who you are. Every commit records this name and email, and they're public once you push:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main        # new repositories start on main
git config --global pull.rebase true               # git pull rebases your local commits instead of making merge commits
git config --global fetch.prune true               # forget remote branches that were deleted
git config --global rerere.enabled true            # remember how you resolved a conflict, and reuse it
git config --global core.editor "vim"              # or "code --wait", "nano"

git config --global --list --show-origin           # see every setting and the file it came from
```

`--global` writes to `~/.gitconfig` and applies to every repository. Without it, the setting goes in the current repository's `.git/config` and overrides the global one there. A [recommended ~/.gitconfig](templates/gitconfig) is in the templates folder, with every line explained.

### Line endings

Windows ends lines with CRLF; Linux and macOS with LF. Mixed endings make every line show as changed. Let the repository decide, not each person's settings, with a [.gitattributes](templates/gitattributes) file at the root:

```text
* text=auto eol=lf
*.ps1 text eol=crlf
*.png binary
```

`text=auto` lets Git detect text files, and `eol=lf` stores and checks them out with LF everywhere. Shell scripts with CRLF fail on Linux with `/bin/bash^M: bad interpreter`, which is the most common symptom.

### Authenticate with SSH keys

```sh
ssh-keygen -t ed25519 -C "you@example.com"     # accept the default path, set a passphrase
cat ~/.ssh/id_ed25519.pub                       # paste this into GitHub or GitLab: Settings → SSH keys
ssh -T git@github.com                           # or git@gitlab.com; prints a greeting with your username
git clone git@github.com:owner/repo.git
```

HTTPS with a credential manager or a personal access token also works. Use a token with the narrowest scope and an expiry date, never your password.

### Sign your commits

The name and email on a commit are whatever the author configured, so anyone can commit as anyone. A signature proves who made it. Git 2.34 and later can sign with the SSH key you already have:

```sh
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```

Add the same public key to GitHub or GitLab again, this time as a signing key, and commits show as verified. A branch protection rule can then require signed commits.

## The model: three places your work lives

| Place | What it is | Commands that move work into it |
|---|---|---|
| Working tree | The files on disk you edit | `git switch`, `git restore` |
| Index (staging area) | The next commit, being assembled | `git add`, `git restore --staged` |
| Repository (`.git`) | Every commit, forever, linked by parent | `git commit` |

A **commit** is a snapshot of every file, plus a message, an author, a time, and a pointer to its parent commit. Its ID (the SHA) is a hash of all of that, so changing anything about a commit, even its message, makes a new commit with a new ID.

A **branch** is just a movable name for one commit. Committing on a branch moves the name forward to the new commit. **HEAD** is the branch (or commit) you have checked out now.

That's why most "scary" Git operations are recoverable: they make new commits and move names around, and the old commits stay in the repository for weeks. See [Recovery](04-recovery.md).

## Everyday commands

### See where you are

```sh
git status                    # branch, staged changes, unstaged changes, untracked files
git status -sb                # the short version: one line per file
git log --oneline --graph --decorate -20    # the last 20 commits as a graph, with branch names
git diff                      # unstaged changes: working tree vs index
git diff --staged             # staged changes: index vs last commit (what will be committed)
git diff main...HEAD          # everything on this branch since it left main
```

### Make a commit

```sh
git switch -c fix/login-timeout     # create a branch and switch to it
# ...edit files...
git add -p                          # stage changes hunk by hunk: y, n, s (split), e (edit), q
git add path/to/new-file
git commit                          # opens the editor for the message
git commit -m "Fix login timeout on slow networks"
```

`git add -p` is the habit that matters most: you see every change before it goes in, which catches debug prints, stray files, and secrets.

A good commit message has a short summary line (50 characters or so, imperative mood: "Fix", not "Fixed"), a blank line, then why the change was needed:

```text
Fix login timeout on slow networks

The client gave up after 5 seconds, but the identity provider's p99 is
7 seconds during peak hours. Raise the timeout to 15 seconds and retry
once on timeout.

Refs: OPS-412
```

### Undo things before they're shared

```sh
git restore file.txt               # discard unstaged changes to a file (they're gone)
git restore --staged file.txt      # unstage, keeping the changes in the working tree
git commit --amend                 # change the last commit's message or add staged changes to it
git reset --soft HEAD~1            # undo the last commit, keeping its changes staged
```

Only amend or reset commits you haven't pushed. Once someone else has a commit, change history only by adding new commits (`git revert`). The [recovery guide](04-recovery.md) covers every case.

### Work with a remote

```sh
git remote -v                      # where "origin" points
git fetch                          # download new commits and branches; changes none of your files
git pull                           # fetch, then rebase your local commits on top (with pull.rebase true)
git push -u origin fix/login-timeout   # push a new branch and track it
git push                           # push again later
git switch main && git pull        # update main
```

`git fetch` is always safe. Use it, then look (`git log --oneline HEAD..origin/main`) before you pull, when you're not sure what's coming.

### Ignore files

`.gitignore` lists files Git should never track: build output, dependencies, local settings, and secrets.

```text
# Build output and dependencies
/dist/
node_modules/
.venv/
*.pyc

# Local settings and secrets
.env
*.tfvars
!example.tfvars          # but do track this one
.terraform/
```

```sh
git check-ignore -v .env           # which rule ignores this file, and where it's defined
git rm --cached .env               # stop tracking a file that's already committed (then add it to .gitignore)
```

Ignoring a file that was already committed doesn't remove it from history. If it was a secret, it's leaked: see [a secret was committed](04-recovery.md#a-secret-was-committed).

## Next

[Branching and collaboration](02-branching-and-collaboration.md): branches, merging and rebasing, resolving conflicts, and tags.
