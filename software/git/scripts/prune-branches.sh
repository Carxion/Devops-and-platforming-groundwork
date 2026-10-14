#!/usr/bin/env bash
#
# prune-branches.sh: list local branches that are finished, and delete them
# when asked. "Finished" means merged into the base branch, or tracking a
# remote branch that was deleted (usually a squash-merged pull request).
#
# Usage: prune-branches.sh [--delete] [--base REF] [--no-fetch]
#
#   --base REF    what work is merged into (default: origin's default branch, else main)
#   --delete      delete the listed branches (merged: git branch -d; gone: git branch -D)
#   --no-fetch    don't run git fetch --prune first
#   -h, --help    this help
#
# Without --delete it only lists. It never touches the current branch, a
# branch checked out in another worktree, or main, master, or develop.

set -Eeuo pipefail

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }
die() {
  printf 'prune-branches: %s\n' "$1" >&2
  exit "${2:-1}"
}

DELETE=0
FETCH=1
BASE=""
while (($# > 0)); do
  case "$1" in
    --base)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      BASE="$2"
      shift
      ;;
    --delete) DELETE=1 ;;
    --no-fetch) FETCH=0 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown option: $1 (see --help)" 2 ;;
  esac
  shift
done

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a Git repository" 2

has_origin=0
if git remote | grep -qx origin; then has_origin=1; fi
if ((FETCH && has_origin)); then git fetch --prune --quiet origin; fi

if [[ -z "$BASE" ]]; then
  # origin/HEAD names the remote's default branch (set at clone time).
  BASE="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -z "$BASE" ]]; then
    if ((has_origin)) && git rev-parse --verify --quiet origin/main >/dev/null; then BASE=origin/main; else BASE=main; fi
  fi
fi
git rev-parse --verify --quiet "$BASE" >/dev/null || die "base '$BASE' doesn't exist (use --base)" 2

# One line per local branch: name, upstream state ("[gone]" if deleted on the
# remote), and the worktree it's checked out in (empty if none).
mapfile -t merged < <(
  git for-each-ref --merged="$BASE" --format='%(refname:short)|%(worktreepath)' refs/heads/ |
    awk -F'|' '$2 == "" && $1 !~ /^(main|master|develop)$/ { print $1 }'
)
mapfile -t gone < <(
  git for-each-ref --no-merged="$BASE" --format='%(refname:short)|%(upstream:track)|%(worktreepath)' refs/heads/ |
    awk -F'|' '$2 == "[gone]" && $3 == "" && $1 !~ /^(main|master|develop)$/ { print $1 }'
)

printf 'Merged into %s (safe to delete):\n' "$BASE"
if ((${#merged[@]})); then printf '  %s\n' "${merged[@]}"; else echo "  (none)"; fi
printf 'Upstream deleted, not merged by commit ID (check, then delete):\n'
if ((${#gone[@]})); then printf '  %s\n' "${gone[@]}"; else echo "  (none)"; fi

if ((! DELETE)); then
  if ((${#merged[@]} + ${#gone[@]})); then echo "Run again with --delete to delete them."; fi
  exit 0
fi
if ((${#merged[@]})); then git branch -d "${merged[@]}"; fi
# -D: a squash-merged branch's commits aren't in the base under their own IDs.
if ((${#gone[@]})); then git branch -D "${gone[@]}"; fi
