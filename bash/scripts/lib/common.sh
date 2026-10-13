#!/usr/bin/env bash
# Shared helpers for the scripts in bash/scripts. Source it, don't run it:
#
#   SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"
#
# Provides logging, error handling, a dry-run aware command runner, OS
# detection for RHEL-family and Debian-family systems, and package helpers.
# Works on Bash 4.4 and later (RHEL 8+, Ubuntu 20.04+).

# Guard against being sourced twice.
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

# --- Logging -----------------------------------------------------------------
# Logs go to stderr so stdout stays clean for data a caller might pipe.
# Colors only when stderr is a terminal and NO_COLOR isn't set (no-color.org).

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  _C_RED=$'\e[31m' _C_YELLOW=$'\e[33m' _C_BLUE=$'\e[34m' _C_DIM=$'\e[2m' _C_RESET=$'\e[0m'
else
  _C_RED='' _C_YELLOW='' _C_BLUE='' _C_DIM='' _C_RESET=''
fi

_log() {
  local level="$1" color="$2"
  shift 2
  printf '%s%s %-5s%s %s\n' "$color" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$_C_RESET" "$*" >&2
}
log_info() { _log INFO "$_C_BLUE" "$@"; }
log_warn() { _log WARN "$_C_YELLOW" "$@"; }
log_error() { _log ERROR "$_C_RED" "$@"; }
log_debug() {
  [[ "${DEBUG:-0}" == 1 ]] && _log DEBUG "$_C_DIM" "$@"
  return 0
}

# die MESSAGE [EXIT_CODE]: log an error and exit (default exit code 1).
die() {
  log_error "$1"
  exit "${2:-1}"
}

# --- Command runner ----------------------------------------------------------
# run CMD [ARGS...]: run a command, or only print it when DRY_RUN=1.
# Use it for every command that changes the system, so --dry-run is honest.

DRY_RUN="${DRY_RUN:-0}"

run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    # %q quotes each argument the way Bash would need it typed.
    printf '%s[dry-run]%s' "$_C_YELLOW" "$_C_RESET" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  log_debug "+ $*"
  "$@"
}

# --- Checks ------------------------------------------------------------------

# require_root: exit unless running as root (dry runs are allowed as anyone).
require_root() {
  [[ "$DRY_RUN" == 1 ]] && return 0
  [[ "${EUID}" -eq 0 ]] || die "Run as root (for example with sudo), or add --dry-run to preview."
}

# require_cmd CMD...: exit if any command is missing.
require_cmd() {
  local cmd missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  ((${#missing[@]} == 0)) || die "Missing required commands: ${missing[*]}"
}

# has_systemd: true when systemd is running as PID 1 (false in most containers).
has_systemd() {
  [[ -d /run/systemd/system ]]
}

# --- OS detection ------------------------------------------------------------
# detect_os sets:
#   OS_ID       e.g. ubuntu, rhel, rocky, almalinux, centos, fedora, debian
#   OS_VERSION  e.g. 24.04, 9.4
#   OS_FAMILY   debian or rhel
#   PKG         apt or dnf
# from /etc/os-release, the standard file on every current distribution.

detect_os() {
  local os_release="${OS_RELEASE_FILE:-/etc/os-release}"
  [[ -r "$os_release" ]] || die "Can't read $os_release; unsupported system."

  # Read the file in a subshell so its variables don't leak into ours.
  local id version_id id_like
  # shellcheck source=/dev/null
  id="$(. "$os_release" && printf '%s' "${ID:-}")"
  # shellcheck source=/dev/null
  version_id="$(. "$os_release" && printf '%s' "${VERSION_ID:-}")"
  # shellcheck source=/dev/null
  id_like="$(. "$os_release" && printf '%s' "${ID_LIKE:-}")"

  OS_ID="$id"
  OS_VERSION="$version_id"
  case " $id $id_like " in
    *" debian "* | *" ubuntu "*)
      OS_FAMILY=debian
      PKG=apt
      ;;
    *" rhel "* | *" fedora "* | *" centos "*)
      OS_FAMILY=rhel
      PKG=dnf
      ;;
    *) die "Unsupported distribution: ${id:-unknown} (supported: RHEL family and Debian family)" ;;
  esac
  export OS_ID OS_VERSION OS_FAMILY PKG
  log_debug "Detected ${OS_ID} ${OS_VERSION} (${OS_FAMILY} family, ${PKG})"
}

# --- Packages ----------------------------------------------------------------

# pkg_update: refresh package metadata.
pkg_update() {
  case "$PKG" in
    apt) run env DEBIAN_FRONTEND=noninteractive apt-get update -q ;;
    dnf) run dnf makecache -q ;;
  esac
}

# pkg_install PACKAGE...: install packages non-interactively; already-installed is fine.
pkg_install() {
  (($# > 0)) || return 0
  case "$PKG" in
    apt) run env DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends "$@" ;;
    dnf) run dnf install -y -q "$@" ;;
  esac
}

# pkg_installed PACKAGE: true when the package is installed.
pkg_installed() {
  case "$PKG" in
    apt) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed' ;;
    dnf) rpm -q "$1" >/dev/null 2>&1 ;;
  esac
}

# --- Files -------------------------------------------------------------------

# backup_file PATH: copy a file to PATH.bak.TIMESTAMP before changing it.
backup_file() {
  local file="$1"
  [[ -e "$file" ]] || return 0
  run cp -a -- "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
}

# write_file PATH MODE: write stdin to PATH atomically (temp file, then rename),
# so a crash never leaves a half-written config. In a dry run, print it instead.
write_file() {
  local dest="$1" mode="${2:-0644}" tmp
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '%s[dry-run]%s would write %s (mode %s):\n' "$_C_YELLOW" "$_C_RESET" "$dest" "$mode" >&2
    sed 's/^/    /' >&2
    return 0
  fi
  tmp="$(mktemp "${dest}.XXXXXX")"
  cat >"$tmp"
  chmod "$mode" "$tmp"
  mv -f -- "$tmp" "$dest"
}

# confirm PROMPT: ask yes/no; true on yes. Returns yes without asking when ASSUME_YES=1.
confirm() {
  [[ "${ASSUME_YES:-0}" == 1 ]] && return 0
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}
