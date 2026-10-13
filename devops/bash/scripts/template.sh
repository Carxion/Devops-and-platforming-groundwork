#!/usr/bin/env bash
#
# template.sh: starting point for a new script. Copy it, rename it, and replace
# the body of main(). Every convention in devops/bash/04-scripting.md is here.
#
# Usage: template.sh [-n] [-v] [-o OUTPUT] TARGET...
#
#   -n, --dry-run     show what would change, change nothing
#   -v, --verbose     debug logging
#   -o, --output DIR  where to write results (default: current directory)
#   -h, --help        this help
#
# Exit codes: 0 success, 1 failure, 2 bad usage.

# Strict mode: exit on errors (-e), on unset variables (-u), and when any
# command in a pipeline fails (-o pipefail). -E makes the ERR trap fire
# inside functions too.
set -Eeuo pipefail

# Split words only on newlines and tabs, so filenames with spaces survive
# unquoted expansions (quote anyway).
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  # Print the header comment: from line 3 to the first blank line, minus the leading "# ".
  sed -n '3,/^$/s/^# \{0,1\}//p' "$0"
}

# --- Cleanup -----------------------------------------------------------------
# Anything created here is removed on exit, whether the script succeeds,
# fails, or is interrupted.

WORK_DIR=""
cleanup() {
  local status=$?
  [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf -- "$WORK_DIR"
  exit "$status"
}
trap cleanup EXIT
trap 'log_error "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR
trap 'log_warn "Interrupted"; exit 130' INT TERM

# --- Arguments ---------------------------------------------------------------

OUTPUT_DIR="."
TARGETS=()

parse_args() {
  while (($# > 0)); do
    case "$1" in
      -n | --dry-run) DRY_RUN=1 ;;
      -v | --verbose) DEBUG=1 ;;
      -o | --output)
        [[ $# -ge 2 ]] || die "$1 needs a value" 2
        OUTPUT_DIR="$2"
        shift
        ;;
      --output=*) OUTPUT_DIR="${1#*=}" ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        TARGETS+=("$@")
        break
        ;;
      -*) die "Unknown option: $1 (see ${SCRIPT_NAME} --help)" 2 ;;
      *) TARGETS+=("$1") ;;
    esac
    shift
  done
  ((${#TARGETS[@]} > 0)) || die "At least one TARGET is required (see --help)" 2
}

# --- Main --------------------------------------------------------------------

main() {
  parse_args "$@"
  WORK_DIR="$(mktemp -d)"

  log_info "Processing ${#TARGETS[@]} target(s) into ${OUTPUT_DIR}"
  local target
  for target in "${TARGETS[@]}"; do
    log_debug "Working on ${target}"
    run mkdir -p -- "${OUTPUT_DIR}"
    printf '%s\n' "$target" >"${WORK_DIR}/last-target"
  done
  log_info "Done"
}

# Run main only when executed, not when sourced (so tests can source this
# file and call its functions directly).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
