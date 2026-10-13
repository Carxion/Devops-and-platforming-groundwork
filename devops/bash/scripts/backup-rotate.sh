#!/usr/bin/env bash
#
# backup-rotate.sh: archive a directory to a timestamped .tar.gz, verify the
# archive, and keep only the newest N archives.
#
# Usage: backup-rotate.sh [-n] [--keep N] [--exclude PATTERN]... SOURCE_DIR DEST_DIR
#
#   --keep N           archives to keep for this source (default 7)
#   --exclude PATTERN  tar exclude pattern, e.g. '*.log' (repeatable)
#   -n, --dry-run      show what would be created and deleted
#   -h, --help         this help
#
# Archives are named <source-name>-YYYYmmddTHHMMSSZ.tar.gz, so they sort by
# time. Schedule with a systemd timer or cron (see devops/bash/04-scripting.md), and
# copy DEST_DIR off the host: a backup on the same disk isn't a backup.

set -Eeuo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

KEEP=7
EXCLUDES=()
POSITIONAL=()
while (($# > 0)); do
  case "$1" in
    --keep)
      [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || die "--keep needs a positive number" 2
      KEEP="$2"
      shift
      ;;
    --exclude)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      EXCLUDES+=("--exclude=$2")
      shift
      ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) die "Unknown option: $1" 2 ;;
    *) POSITIONAL+=("$1") ;;
  esac
  shift
done
((${#POSITIONAL[@]} == 2)) || die "Need SOURCE_DIR and DEST_DIR (see --help)" 2

SOURCE="$(realpath -- "${POSITIONAL[0]}")" || die "No such source: ${POSITIONAL[0]}"
DEST="${POSITIONAL[1]}"
[[ -d "$SOURCE" ]] || die "Not a directory: $SOURCE"
NAME="$(basename -- "$SOURCE")"

# Only one backup of this source at a time: flock holds a lock on file
# descriptor 9 until the script exits; -n fails at once if it's taken.
run mkdir -p -- "$DEST"
if [[ "$DRY_RUN" != 1 ]]; then
  exec 9>"${DEST}/.${NAME}.lock"
  flock -n 9 || die "Another backup of $NAME is running"
fi

ARCHIVE="${DEST}/${NAME}-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
log_info "Archiving $SOURCE to $ARCHIVE"
# -C changes to the parent first, so the archive holds "NAME/..." rather than
# the absolute path. Write to a .partial name and rename only after checking.
run tar -czf "${ARCHIVE}.partial" "${EXCLUDES[@]}" -C "$(dirname -- "$SOURCE")" -- "$NAME"
# tar -t reads the whole archive back; gzip or tar damage makes it fail.
run tar -tzf "${ARCHIVE}.partial" >/dev/null
run mv -- "${ARCHIVE}.partial" "$ARCHIVE"

if [[ "$DRY_RUN" != 1 ]]; then
  log_info "Archive is $(du -h -- "$ARCHIVE" | cut -f1)"
fi

# Rotation: list this source's archives newest first (the names sort by time),
# skip the newest KEEP, delete the rest. The pattern matches only our names.
mapfile -t OLD < <(
  find "$DEST" -maxdepth 1 -type f -name "${NAME}-*.tar.gz" -printf '%f\n' |
    grep -E "^${NAME//./\\.}-[0-9]{8}T[0-9]{6}Z\.tar\.gz$" |
    sort -r | tail -n +"$((KEEP + 1))"
)
for old in "${OLD[@]}"; do
  log_info "Removing old archive $old"
  run rm -f -- "${DEST}/${old}"
done
log_info "Kept the newest ${KEEP} archive(s) of ${NAME}"
