#!/usr/bin/env bash
#
# docker-cleanup.sh: reclaim disk space from Docker safely. Shows what it
# would remove first; removes only with --apply.
#
# Usage: docker-cleanup.sh [--apply] [--until DURATION] [--all-images] [--volumes]
#
#   --apply           actually remove (default: show what would be removed)
#   --until DURATION  only things older than this, e.g. 72h or 168h (default 168h, a week)
#   --all-images      remove every image no container uses, not just dangling
#                     (untagged) ones. They'll be pulled again when needed.
#   --volumes         also remove unused anonymous volumes. Volumes hold data:
#                     there's no undo. Named volumes are never touched.
#   -h, --help        this help
#
# Never removes running containers, images they use, or named volumes.

set -Eeuo pipefail

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

APPLY=0
UNTIL=168h
ALL_IMAGES=0
VOLUMES=0
while (($# > 0)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --until)
      [[ "${2:-}" =~ ^[0-9]+[smh]$ ]] || {
        echo "--until needs a duration like 72h, 30m, or 3600s" >&2
        exit 2
      }
      UNTIL="$2"
      shift
      ;;
    --all-images) ALL_IMAGES=1 ;;
    --volumes) VOLUMES=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

command -v docker >/dev/null || {
  echo "docker not found" >&2
  exit 1
}
section() { printf '\n== %s ==\n' "$*"; }

section "Disk use before"
docker system df

if ((! APPLY)); then
  section "Would remove (preview; run with --apply)"
  echo "Stopped containers (all ages; prune applies the ${UNTIL} filter):"
  docker ps -a --filter status=exited --filter status=created --filter status=dead \
    --format '  {{.Names}}  {{.Image}}  {{.Status}}'
  echo "Dangling images:"
  docker images --filter dangling=true --format '  {{.ID}}  {{.Size}}  created {{.CreatedSince}}'
  if ((ALL_IMAGES)); then
    echo "All images not used by any container:"
    # Images used by any container, running or stopped, as image IDs.
    used="$(docker ps -a --format '{{.Image}}' | xargs -r docker image inspect --format '{{.Id}}' 2>/dev/null | sort -u)"
    docker images --no-trunc --format '{{.ID}} {{.Repository}}:{{.Tag}} {{.Size}}' |
      while read -r id ref size; do
        grep -qx "$id" <<<"$used" || printf '  %s  %s\n' "$ref" "$size"
      done
  fi
  echo "Build cache older than ${UNTIL}: see the RECLAIMABLE column for Build Cache above."
  if ((VOLUMES)); then
    echo "Unused anonymous volumes:"
    docker volume ls --filter dangling=true --format '  {{.Name}}'
  fi
  exit 0
fi

section "Removing"
# "until" filters by creation time. Running containers, and images they use,
# are never pruned.
docker container prune --force --filter "until=${UNTIL}"
if ((ALL_IMAGES)); then
  docker image prune --all --force --filter "until=${UNTIL}"
else
  docker image prune --force --filter "until=${UNTIL}"
fi
docker builder prune --force --filter "until=${UNTIL}"
docker network prune --force --filter "until=${UNTIL}"
if ((VOLUMES)); then
  # Without --all, volume prune removes only anonymous volumes (Docker 23 and later).
  docker volume prune --force
fi

section "Disk use after"
docker system df
