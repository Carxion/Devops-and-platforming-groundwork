#!/usr/bin/env bash
#
# retry.sh: run a command until it succeeds, with exponential backoff and jitter.
#
# Usage: retry.sh [-n ATTEMPTS] [-d DELAY] [-m MAX_DELAY] -- COMMAND [ARGS...]
#
#   -n ATTEMPTS   total attempts (default 5)
#   -d DELAY      seconds before the first retry (default 1); doubles each time
#   -m MAX_DELAY  cap on the wait between attempts (default 30)
#   -h, --help    this help
#
# Exits with the command's last exit code if every attempt fails.
# Example: retry.sh -n 10 -d 2 -- curl -fsS https://example.com/healthz

set -Euo pipefail # no -e: the command is expected to fail sometimes
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

ATTEMPTS=5
DELAY=1
MAX_DELAY=30
while (($# > 0)); do
  case "$1" in
    -n | -d | -m)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || die "$1 needs a whole number" 2
      case "$1" in
        -n) ATTEMPTS="$2" ;;
        -d) DELAY="$2" ;;
        -m) MAX_DELAY="$2" ;;
      esac
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *) die "Unknown option: $1 (put the command after --)" 2 ;;
  esac
  shift
done
(($# > 0)) || die "No command given (usage: retry.sh [options] -- COMMAND)" 2
((ATTEMPTS >= 1)) || die "-n must be at least 1" 2

attempt=1
while true; do
  "$@"
  status=$?
  ((status == 0)) && exit 0
  if ((attempt >= ATTEMPTS)); then
    log_error "Failed after ${attempt} attempt(s), last exit code ${status}: $*"
    exit "$status"
  fi
  # Jitter: wait between half and all of the delay, so many clients retrying
  # at once spread out instead of hitting the service together.
  wait_for=$((DELAY / 2 + RANDOM % (DELAY / 2 + 1)))
  ((wait_for < 1)) && wait_for=1
  log_warn "Attempt ${attempt}/${ATTEMPTS} failed (exit ${status}); retrying in ${wait_for}s"
  sleep "$wait_for"
  attempt=$((attempt + 1))
  DELAY=$((DELAY * 2 > MAX_DELAY ? MAX_DELAY : DELAY * 2))
done
