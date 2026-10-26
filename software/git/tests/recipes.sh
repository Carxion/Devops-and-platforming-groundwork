#!/usr/bin/env bash
# Each test is a function that runs the guide's commands in a fresh temporary
# directory, under set -e, and fails at the first command or check that fails.
# shellcheck disable=SC2016  # single-quoted Git format strings and patterns are literal on purpose
#
# Runs every command recipe in software/git/*.md against real repositories.
#
#   bash software/git/tests/recipes.sh                 # on any machine with Git and Bash
#   docker run --rm -v "$PWD/software/git:/work:ro" ubuntu:22.04 \
#     bash -c 'apt-get update -qq && apt-get install -y -qq git openssh-client >/dev/null && bash /work/tests/recipes.sh'
#
# Set REQUIRE_FILTER_REPO=1 to fail (not skip) when git filter-repo isn't installed.
# It never touches your own repositories or Git settings: HOME points at a temporary directory.

set -Euo pipefail # no -e here: run every test and report all failures

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$HERE/../scripts" && pwd)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

export HOME="$ROOT/home" GIT_CONFIG_NOSYSTEM=1 GIT_EDITOR=true GIT_PAGER=cat GIT_TERMINAL_PROMPT=0
mkdir -p "$HOME"
git config --global user.name "Test User"
git config --global user.email "test@example.com"
git config --global init.defaultBranch main
git config --global advice.detachedHead false
git config --global protocol.file.allow always # local file:// remotes, for the clone tests

PASSED=0
FAILED=0
SKIPPED=0

# ---- helpers ----------------------------------------------------------------

# commit FILE CONTENT MESSAGE: write the file and commit it.
commit() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1"
  git add "$1"
  git commit -q -m "$3"
}
# new_repo NAME: create a repository with one commit and cd into it.
new_repo() {
  git init -q "$1"
  cd "$1" || return 1
  commit README.md "# Test" "Initial commit"
}
# Match output with grep -q <<<"$(cmd)", not cmd | grep -q: grep -q exits at the
# first match, and under pipefail the writer's SIGPIPE would fail the test.
# expect_eq ACTUAL EXPECTED: fail with a readable message if they differ.
expect_eq() {
  if [[ "$1" != "$2" ]]; then
    printf 'expected: %q\n     got: %q\n' "$2" "$1" >&2
    return 1
  fi
}
# fails CMD...: the command must fail. (A bare "! cmd" never fails a test under set -e.)
fails() {
  if "$@"; then
    echo "expected to fail: $*" >&2
    return 1
  fi
}
skip() {
  echo "SKIP: $*" >&2
  return 99
}

run() {
  local name="$1" dir
  dir="$(mktemp -d "$ROOT/t.XXXXXX")"
  (
    set -e
    cd "$dir"
    "$name"
  ) >"$dir.log" 2>&1
  local rc=$?
  if ((rc == 0)); then
    printf 'PASS  %s\n' "$name"
    PASSED=$((PASSED + 1))
  elif ((rc == 99)); then
    printf 'SKIP  %s (%s)\n' "$name" "$(tail -1 "$dir.log")"
    SKIPPED=$((SKIPPED + 1))
  else
    printf 'FAIL  %s\n' "$name"
    sed 's/^/      /' "$dir.log" | tail -25
    FAILED=$((FAILED + 1))
  fi
}

# ---- 01: basics ---------------------------------------------------------------

test_restore_and_amend() {
  new_repo r
  commit app.txt "v1" "Add app"
  echo "oops" >>app.txt
  git restore app.txt
  expect_eq "$(cat app.txt)" "v1"
  echo "v2" >app.txt
  git add app.txt
  git restore --staged app.txt
  expect_eq "$(git diff --staged --name-only)" ""
  expect_eq "$(git diff --name-only)" "app.txt"
  git add app.txt
  git commit -q --amend --no-edit
  expect_eq "$(git rev-list --count HEAD)" "2"
  expect_eq "$(git show HEAD:app.txt)" "v2"
  git reset -q --soft HEAD~1
  expect_eq "$(git diff --staged --name-only)" "app.txt"
}

test_gitignore() {
  new_repo r
  commit .env "SECRET=1" "Oops, committed .env"
  printf '.env\n*.tfvars\n!example.tfvars\n' >.gitignore
  git rm -q --cached .env
  git add .gitignore
  git commit -q -m "Stop tracking .env"
  [[ -f .env ]] # still on disk
  expect_eq "$(git ls-files .env)" ""
  git check-ignore -v .env | grep -q '^.gitignore:1:.env'
  touch prod.tfvars example.tfvars
  git check-ignore -q prod.tfvars
  fails git check-ignore -q example.tfvars
}

test_gitattributes_line_endings() {
  new_repo r
  printf '* text=auto eol=lf\n' >.gitattributes
  printf 'echo hi\r\n' >script.sh
  git add .gitattributes script.sh
  git commit -q -m "Add script"
  # Stored with LF in the repository, whatever the working file had.
  stored="$(git cat-file -p HEAD:script.sh | od -c)"
  grep -q '\\n' <<<"$stored"
  fails grep -q '\\r' <<<"$stored"
}

test_ssh_signed_commit() {
  command -v ssh-keygen >/dev/null || skip "ssh-keygen not installed"
  new_repo r
  ssh-keygen -q -t ed25519 -N '' -C test@example.com -f "$HOME/id_ed25519"
  git config gpg.format ssh
  git config user.signingkey "$HOME/id_ed25519.pub"
  git config commit.gpgsign true
  commit signed.txt "signed" "A signed commit"
  printf 'test@example.com namespaces="git" %s\n' "$(cat "$HOME/id_ed25519.pub")" >"$HOME/allowed_signers"
  git -c gpg.ssh.allowedSignersFile="$HOME/allowed_signers" verify-commit HEAD
}

# ---- 02: branching and collaboration ---------------------------------------------

# A main branch and a fix branch that change the same line differently.
setup_conflict() {
  new_repo r
  commit config.txt "timeout_seconds = 5" "Add config"
  git switch -q -c fix
  commit config.txt "timeout_seconds = 10" "Raise timeout to 10"
  git switch -q main
  commit config.txt "timeout_seconds = 15" "Raise timeout to 15"
  git switch -q fix
}

test_conflict_markers_and_ours_theirs() {
  setup_conflict
  fails git -c merge.conflictStyle=diff3 rebase main
  grep -q '^<<<<<<< ' config.txt
  grep -q '^||||||| ' config.txt                                                              # the base section...
  expect_eq "$(sed -n '/^|||||||/,/^=======/p' config.txt | sed -n 2p)" "timeout_seconds = 5" # ...shows the original line
  git status --porcelain | grep -q '^UU config.txt'
  # During a rebase, "ours" is the branch being rebased onto (main) and "theirs" is your commit.
  git checkout --ours config.txt
  expect_eq "$(cat config.txt)" "timeout_seconds = 15"
  git checkout --theirs config.txt
  expect_eq "$(cat config.txt)" "timeout_seconds = 10"
  git add config.txt
  git rebase --continue
  expect_eq "$(git log --format=%s -2 | paste -sd,)" "Raise timeout to 10,Raise timeout to 15"
}

test_rebase_abort() {
  setup_conflict
  before="$(git rev-parse HEAD)"
  fails git rebase main
  git rebase --abort
  expect_eq "$(git rev-parse HEAD)" "$before"
  expect_eq "$(cat config.txt)" "timeout_seconds = 10"
}

test_rerere_reuses_resolution() {
  setup_conflict
  git config rerere.enabled true
  fails git rebase main
  echo "timeout_seconds = 20" >config.txt
  git add config.txt
  git rebase --continue
  git reset -q --hard ORIG_HEAD                        # back to before the rebase
  fails git rebase main                                # the same conflict again...
  expect_eq "$(cat config.txt)" "timeout_seconds = 20" # ...resolved from the recording
}

test_force_with_lease_refuses() {
  git init -q --bare origin.git
  git clone -q origin.git a
  git clone -q origin.git b 2>/dev/null
  (cd a && commit f.txt 1 "One" && git push -q -u origin main)
  (cd b && git pull -q)
  (cd a && commit f.txt 2 "Two" && git push -q) # a teammate pushes...
  cd b
  git commit -q --allow-empty -m "Mine"
  fails git push -q --force-with-lease 2>/dev/null # ...so b's lease fails
  git fetch -q
  expect_eq "$(git log --format=%s -1 origin/main)" "Two" # their work survived
}

test_tags() {
  new_repo r
  for v in 1.9.0 1.10.0; do
    git commit -q --allow-empty -m "Release $v"
    git tag -a "v$v" -m "Release $v"
  done
  git commit -q --allow-empty -m "After"
  git commit -q --allow-empty -m "After again"
  git describe --tags | grep -Eq '^v1\.10\.0-2-g[0-9a-f]+$'
  expect_eq "$(git tag --list 'v1.*' --sort=-v:refname | paste -sd,)" "v1.10.0,v1.9.0"
  expect_eq "$(git cat-file -t v1.10.0)" "tag" # annotated: a tag object, not just a name
  expect_eq "$(git log --format=%s v1.9.0..v1.10.0)" "Release 1.10.0"
}

test_merge_methods() {
  new_repo r
  git switch -q -c feat
  commit a.txt a "Add a"
  commit b.txt b "Add b"
  git switch -q main
  git merge -q --squash feat
  git commit -q -m "Add a and b (squashed)"
  expect_eq "$(git rev-list --count HEAD)" "2" # one commit for the whole branch
  git reset -q --hard HEAD~1
  git merge -q --no-ff -m "Merge feat" feat
  expect_eq "$(git rev-list --count HEAD)" "4" # both commits plus the merge commit
  expect_eq "$(git rev-list --parents -1 HEAD | wc -w)" "3"
}

# ---- 03: complex commands -----------------------------------------------------

test_bisect_run() {
  new_repo r
  for i in $(seq 2 20); do
    if ((i >= 13)); then echo "timeout_seconds = 0" >config.txt; else echo "timeout_seconds = 15" >config.txt; fi
    echo "$i" >counter.txt
    git add . && git commit -q -m "Commit $i"
  done
  # The test script lives outside the repository, so it exists at every commit.
  printf '#!/bin/sh\n! grep -q "timeout_seconds = 0" config.txt\n' >../check.sh
  chmod +x ../check.sh
  git bisect start HEAD "$(git rev-list --max-parents=0 HEAD)" >/dev/null
  out="$(git bisect run ../check.sh)"
  git bisect reset -q 2>/dev/null || git bisect reset >/dev/null
  bad="$(awk '/is the first bad commit/ { print $1; exit }' <<<"$out")"
  expect_eq "$(git log --format=%s -1 "$bad")" "Commit 13"
}

test_fixup_autosquash() {
  new_repo r
  git switch -q -c feat
  commit a.txt "a" "Add a"
  commit b.txt "b" "Add b"
  echo "a fixed" >a.txt
  git commit -q -a --fixup="$(git rev-parse HEAD~1)"
  expect_eq "$(git log --format=%s -1)" "fixup! Add a"
  GIT_SEQUENCE_EDITOR=: git rebase -q -i --autosquash main
  expect_eq "$(git log --format=%s main.. | paste -sd,)" "Add b,Add a"
  expect_eq "$(git show HEAD~1:a.txt)" "a fixed"
}

test_pickaxe() {
  new_repo r
  commit config/app.toml "timeout_seconds = 5" "Add config"
  commit other.txt "x" "Unrelated"
  commit config/app.toml "timeout_seconds = 15" "Raise timeout"
  expect_eq "$(git log -S 'timeout_seconds = 5' --format=%s -- config/ | paste -sd,)" "Raise timeout,Add config"
  expect_eq "$(git log -G 'timeout_seconds = [0-9]+' --format=%s -- config/app.toml | paste -sd,)" "Raise timeout,Add config"
}

test_blame_ignores_whitespace_and_listed_commits() {
  new_repo r
  printf 'def f():\n  return 1\n' >app.py
  git add app.py
  GIT_AUTHOR_NAME=Alice git commit -q -m "Add f"
  printf 'def f():\n    return 1\n' >app.py # reindent only
  GIT_AUTHOR_NAME=Bob git commit -q -am "Reformat"
  git blame -L 2,2 --porcelain app.py | grep -q '^author Bob$'
  git blame -w -L 2,2 --porcelain app.py | grep -q '^author Alice$'
  git rev-parse HEAD >.git-blame-ignore-revs
  git -c blame.ignoreRevsFile=.git-blame-ignore-revs blame -L 2,2 --porcelain app.py | grep -q '^author Alice$'
  expect_eq "$(git log -L 2,2:app.py --format=%s --no-patch | grep -v '^$' | paste -sd,)" "Reformat,Add f"
}

test_cherry_pick_x() {
  new_repo r
  git branch release/1.4
  commit fix1.txt 1 "Fix one"
  commit fix2.txt 2 "Fix two"
  fix="$(git rev-parse HEAD~1)"
  git switch -q release/1.4
  git cherry-pick -x "$fix" >/dev/null
  git log -1 --format=%B | grep -q "(cherry picked from commit $fix)"
  git reset -q --hard HEAD~1
  git cherry-pick -x main~2..main >/dev/null
  expect_eq "$(git log --format=%s main~2.. | paste -sd,)" "Fix two,Fix one"
}

test_revert_merge() {
  new_repo r
  git switch -q -c feat
  commit feature.txt "new" "Add feature"
  git switch -q main
  git merge -q --no-ff -m "Merge feat" feat
  git revert -m 1 --no-edit HEAD >/dev/null
  [[ ! -e feature.txt ]]
  git revert --no-edit HEAD >/dev/null # revert the revert to bring it back
  [[ -e feature.txt ]]
}

test_worktree() {
  new_repo r
  echo "work in progress" >>README.md # uncommitted work stays put
  git worktree add -q ../hotfix -b hotfix/cert-expiry main
  (cd ../hotfix && commit cert.txt "30" "Renew threshold")
  expect_eq "$(git worktree list | wc -l | tr -d ' ')" "2"
  git worktree remove ../hotfix
  expect_eq "$(git log --format=%s -1 hotfix/cert-expiry)" "Renew threshold"
  grep -q "work in progress" README.md
}

test_stash_named_with_path() {
  new_repo r
  commit src/app.txt "v1" "Add app"
  commit docs/notes.txt "v1" "Add notes"
  echo "v2" >src/app.txt
  echo "new" >src/new.txt
  echo "v2" >docs/notes.txt
  git stash push -q -u -m "half-done retry logic" -- src/
  git stash list | grep -q "half-done retry logic"
  [[ ! -e src/new.txt ]] # untracked file stashed too (-u)
  expect_eq "$(cat src/app.txt)" "v1"
  expect_eq "$(cat docs/notes.txt)" "v2" # outside the path: untouched
  git stash pop -q 'stash@{0}'
  expect_eq "$(cat src/app.txt)" "v2"
  [[ -e src/new.txt ]]
}

test_find_large_blobs() {
  new_repo r
  head -c 3000000 /dev/urandom >dump.sql
  git add dump.sql && git commit -q -m "Add dump"
  git rm -q dump.sql && git commit -q -m "Remove dump"
  out="$(git rev-list --objects --all |
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
    awk '$1 == "blob"' | sort -k3,3 -n -r | head -10 |
    awk '{ printf "%10.1f MB  %s  %s\n", $3 / 1048576, substr($2, 1, 10), $4 }')"
  head -1 <<<"$out" | grep -Eq '^ +2\.9 MB  [0-9a-f]{10}  dump.sql$'
  bash "$SCRIPTS/find-large-blobs.sh" -n 1 | grep -Eq '^ +2\.9 MB  [0-9a-f]{10}  dump.sql$'
  expect_eq "$(bash "$SCRIPTS/find-large-blobs.sh" --min-mb 5)" ""
}

test_log_format_and_author_counts() {
  new_repo r
  GIT_AUTHOR_NAME=Alice git commit -q --allow-empty -m "One"
  GIT_AUTHOR_NAME=Alice git commit -q --allow-empty -m "Two"
  GIT_AUTHOR_NAME=Bob git commit -q --allow-empty -m "Three"
  grep -q 'Three' <<<"$(git log --graph --format='%C(auto)%h %C(blue)%ad%C(auto)%d %s %C(dim)(%an)' --date=short --all -30)"
  expect_eq "$(git log --since='2 weeks ago' --no-merges --format='%an' | sort | uniq -c | sort -rn | head -1 | awk '{ print $1, $2 }')" "2 Alice"
}

# A remote with main, a branch merged by commit ID, a squash-merged branch
# whose remote branch was deleted, and an active branch. Leaves you in the clone.
setup_branches() {
  git init -q --bare origin.git
  git clone -q origin.git c 2>/dev/null
  cd c
  commit README.md "# Test" "Initial commit"
  git push -q -u origin main
  for b in merged squashed active; do
    git switch -q -c "$b" main
    commit "$b.txt" "$b" "Work on $b"
    git push -q -u origin "$b"
  done
  git switch -q main
  git merge -q --ff-only merged
  git merge -q --squash squashed && git commit -q -m "Squashed"
  git push -q origin main
  git push -q origin --delete squashed merged
}

test_branch_cleanup_commands() {
  setup_branches
  git fetch -q --prune
  git branch --merged origin/main | grep -vE '^\*|^\+|^\s*(main|master)$' | xargs -r git branch -d
  git branch -vv | awk '/: gone]/ { print $1 }' | xargs -r git branch -D
  expect_eq "$(git branch --format='%(refname:short)' | paste -sd,)" "active,main"
}

test_prune_branches_script() {
  setup_branches
  out="$(bash "$SCRIPTS/prune-branches.sh")"
  grep -q '^  merged$' <<<"$out"
  grep -q '^  squashed$' <<<"$out"
  fails grep -q 'active' <<<"$out"
  expect_eq "$(git branch --format='%(refname:short)' | wc -l | tr -d ' ')" "4" # listing deletes nothing
  git worktree add -q ../wt merged                                              # checked out elsewhere: protected
  bash "$SCRIPTS/prune-branches.sh" --delete >/dev/null
  expect_eq "$(git branch --format='%(refname:short)' | paste -sd,)" "active,main,merged"
  git worktree remove ../wt
  bash "$SCRIPTS/prune-branches.sh" --delete >/dev/null
  expect_eq "$(git branch --format='%(refname:short)' | paste -sd,)" "active,main"
  bash "$SCRIPTS/prune-branches.sh" --help | grep -q 'Usage'
}

test_partial_shallow_sparse_clones() {
  new_repo src
  commit services/billing/app.txt "billing" "Add billing"
  commit services/search/app.txt "search" "Add search"
  git tag v1.4.0
  commit services/search/app.txt "search v2" "Change search"
  git config uploadpack.allowFilter true # the server must allow partial clones (GitHub and GitLab do)
  cd ..
  git clone -q --filter=blob:none "file://$PWD/src" partial
  expect_eq "$(git -C partial config remote.origin.promisor)" "true"
  expect_eq "$(git -C partial rev-list --count HEAD)" "4" # full history
  git clone -q --depth 1 --branch v1.4.0 "file://$PWD/src" shallow 2>/dev/null
  expect_eq "$(git -C shallow rev-list --count HEAD)" "1"
  git clone -q "file://$PWD/src" sparse
  cd sparse
  git sparse-checkout set services/billing
  [[ -e services/billing/app.txt && ! -e services/search ]]
}

# ---- 04: recovery ---------------------------------------------------------------

test_move_commits_to_branch() {
  new_repo r
  commit a.txt a "Feature part 1"
  commit b.txt b "Feature part 2"
  git branch feat/export
  git reset -q --keep HEAD~2
  expect_eq "$(git log --format=%s -1)" "Initial commit"
  expect_eq "$(git rev-list --count main..feat/export)" "2"
  # --keep refuses to throw away uncommitted changes to files it would change.
  git switch -q feat/export
  echo "edited" >>b.txt
  fails git reset -q --keep HEAD~1 2>/dev/null
  grep -q edited b.txt
}

test_revert_range() {
  new_repo r
  commit f.txt "1" "One"
  for n in 2 3 4; do
    printf '%s\n' "$n" >>f.txt
    git commit -q -am "Add $n"
  done
  git revert --no-commit HEAD~3..HEAD
  git commit -q -m "Revert the last three commits"
  expect_eq "$(cat f.txt)" "1"
  expect_eq "$(git rev-list --count HEAD)" "6"
}

test_reflog_recovery() {
  new_repo r
  commit a.txt a "Keep me 1"
  commit b.txt b "Keep me 2"
  tip="$(git rev-parse HEAD)"
  git reset -q --hard HEAD~2
  grep -q 'reset: moving to HEAD~2' <<<"$(git reflog -1)"
  git branch rescued 'HEAD@{1}'
  expect_eq "$(git rev-parse rescued)" "$tip"
  git reset -q --hard 'HEAD@{1}' # or move the branch back to where HEAD was one move ago
  expect_eq "$(git rev-parse HEAD)" "$tip"
  # A deleted branch: git branch -D prints the commit it pointed to.
  git switch -q -c doomed
  commit c.txt c "Doomed work"
  git switch -q main
  was="$(git branch -D doomed | sed -E 's/.*\(was ([0-9a-f]+)\).*/\1/')"
  git branch doomed "$was"
  expect_eq "$(git log --format=%s -1 doomed)" "Doomed work"
}

test_fsck_finds_dropped_stash() {
  new_repo r
  echo "precious" >>README.md
  git stash push -q -m "precious work"
  dropped="$(git stash drop | sed -E 's/.*\(([0-9a-f]+)\).*/\1/')"
  found="$(git fsck --lost-found --no-reflogs 2>/dev/null | awk '/commit/ { print $3 }')"
  grep -q "^$(git rev-parse "$dropped")$" <<<"$found"
  git stash apply -q "$dropped" # a stash commit can be applied by ID
  grep -q precious README.md
}

test_orig_head_after_merge() {
  new_repo r
  git switch -q -c feat
  commit feat.txt x "Feature"
  git switch -q main
  before="$(git rev-parse HEAD)"
  git merge -q --no-ff -m "Wrong merge" feat
  git reset -q --hard ORIG_HEAD
  expect_eq "$(git rev-parse HEAD)" "$before"
}

test_recover_from_force_push() {
  git init -q --bare origin.git
  git clone -q origin.git a 2>/dev/null
  (cd a && commit f.txt 1 "One" && commit f.txt 2 "Two" && git push -q -u origin main)
  git clone -q origin.git b
  lost="$(git -C b rev-parse origin/main)"
  (cd a && git reset -q --hard HEAD~1 && git push -q --force origin main) # someone rewrites main
  cd b
  git fetch -q
  expect_eq "$(git log --format=%s -1 origin/main)" "One"
  git branch recovered 'origin/main@{1}'
  expect_eq "$(git rev-parse recovered)" "$lost"
}

test_detached_head() {
  new_repo r
  commit a.txt a "Second"
  git switch -q --detach HEAD~1
  commit d.txt d "Made while detached"
  git switch -q -c keep-this-work
  git switch -q main
  expect_eq "$(git log --format=%s -1 keep-this-work)" "Made while detached"
}

test_restore_deleted_file() {
  new_repo r
  commit docs/runbook.md "step 1" "Add runbook"
  git rm -q docs/runbook.md && git commit -q -m "Remove runbook"
  commit other.txt x "Later work"
  deleting="$(git log --format=%h --diff-filter=D -- docs/runbook.md)"
  expect_eq "$(git log --format=%s -1 "$deleting")" "Remove runbook"
  git restore --source="$deleting~1" docs/runbook.md
  expect_eq "$(cat docs/runbook.md)" "step 1"
}

test_filter_repo_removes_file_and_secret() {
  if ! git filter-repo --version >/dev/null 2>&1; then
    if [[ "${REQUIRE_FILTER_REPO:-0}" == 1 ]]; then
      echo "git filter-repo is required but not installed" >&2
      return 1
    fi
    skip "git filter-repo not installed"
  fi
  git init -q --bare origin.git
  git clone -q origin.git work 2>/dev/null
  (
    cd work
    commit README.md "# Test" "Initial commit"
    head -c 100000 /dev/urandom >dump.bin && mkdir -p db && mv dump.bin db/dump.sql
    git add db && git commit -q -m "Add dump"
    commit config.ini "key = AKIAEXAMPLEKEY123456" "Add config"
    git rm -q db/dump.sql && git commit -q -m "Remove dump"
    git tag v1
    git push -q origin main v1
  )
  git clone -q --mirror origin.git repo-cleanup.git
  (
    cd repo-cleanup.git
    git filter-repo --quiet --invert-paths --path db/dump.sql
    printf 'AKIAEXAMPLEKEY123456==>REMOVED\n' >../expressions.txt
    git filter-repo --quiet --replace-text ../expressions.txt
    git push -q --force --mirror ../origin.git
  )
  git clone -q origin.git fresh
  cd fresh
  expect_eq "$(git log --all --format=%h -- db/dump.sql)" ""
  expect_eq "$(git log --all -S AKIAEXAMPLEKEY123456 --format=%h)" ""
  expect_eq "$(cat config.ini)" "key = REMOVED"
  git rev-parse -q --verify v1 >/dev/null # tags were rewritten too, not lost
}

# ---- run ------------------------------------------------------------------------

os="$(uname -s)"
# shellcheck disable=SC1091 # os-release exists on the test machine, not the linting one
if [[ -r /etc/os-release ]]; then os="$(. /etc/os-release && echo "$PRETTY_NAME")"; fi
echo "== $(git --version) on $os"
for t in $(declare -F | awk '$3 ~ /^test_/ { print $3 }'); do run "$t"; done
echo
echo "${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
((FAILED == 0))
