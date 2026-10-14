#!/usr/bin/env bash
#
# find-large-blobs.sh: list the largest files anywhere in a repository's
# history, including files deleted long ago that every clone still downloads.
#
# Usage: find-large-blobs.sh [-n COUNT] [--min-mb MB]
#
#   -n COUNT     how many to show (default 10)
#   --min-mb MB  only files at least this big (default 0)
#   -h, --help   this help
#
# Read-only. To remove a file from history, see 04-recovery.md.

set -Eeuo pipefail

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }
die() {
  printf 'find-large-blobs: %s\n' "$1" >&2
  exit "${2:-1}"
}

COUNT=10
MIN_MB=0
while (($# > 0)); do
  case "$1" in
    -n | --min-mb)
      [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "$1 needs a whole number" 2
      if [[ "$1" == -n ]]; then COUNT="$2"; else MIN_MB="$2"; fi
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown option: $1 (see --help)" 2 ;;
  esac
  shift
done

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a Git repository" 2

# Every object reachable from any ref, with the path for file contents; then
# each object's type, ID, size, and path; keep blobs over the minimum; largest first.
git rev-list --objects --all |
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
  awk -v min="$((MIN_MB * 1048576))" '$1 == "blob" && $3 >= min' |
  sort -k3,3 -n -r |
  # awk rather than head: head exits early, and under pipefail sort's SIGPIPE would fail the script.
  awk -v count="$COUNT" 'NR <= count {
    size = $3; id = substr($2, 1, 10)
    sub(/^[^ ]+ [^ ]+ [^ ]+ /, "")   # what remains is the path, spaces and all
    printf "%10.1f MB  %s  %s\n", size / 1048576, id, $0
  }'
