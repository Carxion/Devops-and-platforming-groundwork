#!/usr/bin/env bash
#
# wait-for-port.sh: wait until a TCP port accepts connections, for example
# before running tests against a service that's still starting.
#
# Usage: wait-for-port.sh [-t TIMEOUT] HOST:PORT [-- COMMAND...]
#
#   -t TIMEOUT  give up after this many seconds (default 60)
#   -h, --help  this help
#
# Runs COMMAND once the port is open, if given. Uses Bash's built-in
# /dev/tcp, so it needs no nc, curl, or telnet.

set -Euo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

TIMEOUT=60
TARGET=""
while (($# > 0)); do
  case "$1" in
    -t)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || die "-t needs a number of seconds" 2
      TIMEOUT="$2"
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
    *) TARGET="$1" ;;
  esac
  shift
done

# HOST:PORT, where HOST may be a name, an IPv4 address, or [IPv6].
[[ "$TARGET" =~ ^(\[[0-9A-Fa-f:]+\]|[A-Za-z0-9.-]+):([0-9]{1,5})$ ]] || die "Expected HOST:PORT, got '${TARGET}'" 2
HOST="${BASH_REMATCH[1]}"
HOST="${HOST#[}"
HOST="${HOST%]}"
PORT="${BASH_REMATCH[2]}"

# SECONDS is a Bash built-in: seconds since the shell started.
deadline=$((SECONDS + TIMEOUT))
until (exec 3<>"/dev/tcp/${HOST}/${PORT}") 2>/dev/null; do
  if ((SECONDS >= deadline)); then
    log_error "Timed out after ${TIMEOUT}s waiting for ${HOST}:${PORT}"
    exit 1
  fi
  sleep 1
done
log_info "${HOST}:${PORT} is accepting connections"

(($# > 0)) && exec "$@"
exit 0
