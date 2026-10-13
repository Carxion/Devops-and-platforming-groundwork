#!/usr/bin/env bash
#
# bootstrap-server.sh: bring a fresh RHEL-family or Ubuntu server to a known
# baseline: updates, base tools, time sync, an admin user with SSH keys, SSH
# hardening, a firewall, and automatic security updates. Each step is one of
# the other scripts in this folder, so they can also be run on their own.
#
# Usage: bootstrap-server.sh [-n] [-y] [options]
#
#   --hostname NAME         set the hostname
#   --timezone ZONE         set the time zone (default: UTC)
#   --admin-user USER       create USER as an administrator...
#   --ssh-key-file FILE     ...with these authorized keys (required with --admin-user)
#   --allow PORT/PROTO      open another inbound port, e.g. 443/tcp (repeatable)
#   --skip STEP             skip a step: packages, time, user, ssh, firewall, updates (repeatable)
#   --docker                also install Docker Engine (Podman with --podman on RHEL)
#   --podman                with --docker on RHEL, install Podman instead
#   -y, --yes               don't ask for confirmation
#   -n, --dry-run           print every change, make none
#   -h, --help              this help
#
# Run it from a console or an SSH session you keep open until a new login
# works. It's idempotent: running it again converges on the same state.
#
# Example:
#   sudo ./bootstrap-server.sh --hostname web-01 --admin-user deploy \
#        --ssh-key-file ~/deploy.pub --allow 443/tcp

set -Eeuo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }
trap 'log_error "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

HOSTNAME_NEW=""
TIMEZONE="UTC"
ADMIN_USER=""
KEY_FILE=""
ALLOW=()
SKIP=()
DOCKER=0
PODMAN=0

while (($# > 0)); do
  case "$1" in
    --hostname | --timezone | --admin-user | --ssh-key-file | --allow | --skip)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      case "$1" in
        --hostname) HOSTNAME_NEW="$2" ;;
        --timezone) TIMEZONE="$2" ;;
        --admin-user) ADMIN_USER="$2" ;;
        --ssh-key-file) KEY_FILE="$2" ;;
        --allow) ALLOW+=("$2") ;;
        --skip) SKIP+=("$2") ;;
      esac
      shift
      ;;
    --docker) DOCKER=1 ;;
    --podman) PODMAN=1 ;;
    -y | --yes) export ASSUME_YES=1 ;;
    -n | --dry-run) export DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1 (see --help)" 2 ;;
  esac
  shift
done

if [[ -n "$ADMIN_USER" && -z "$KEY_FILE" ]]; then die "--admin-user needs --ssh-key-file" 2; fi
if [[ -n "$HOSTNAME_NEW" ]]; then
  # RFC 1123 hostname: labels of letters, digits, and hyphens, not starting or ending with a hyphen.
  [[ "$HOSTNAME_NEW" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]] ||
    die "Invalid hostname: $HOSTNAME_NEW" 2
fi

skipped() {
  local s
  for s in "${SKIP[@]}"; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

step() { log_info "=== $* ==="; }

require_root
detect_os
log_info "Bootstrapping ${OS_ID} ${OS_VERSION} (${OS_FAMILY} family)$([[ "$DRY_RUN" == 1 ]] && echo ' [dry run]')"
if [[ "$DRY_RUN" != 1 ]]; then
  confirm "Apply the baseline to $(hostname)?" || die "Cancelled" 1
fi

# Base packages. Names differ by family where noted.
COMMON_PACKAGES=(sudo curl ca-certificates jq git tar unzip rsync lsof bash-completion chrony tmux)
case "$OS_FAMILY" in
  rhel) FAMILY_PACKAGES=(vim-enhanced bind-utils policycoreutils-python-utils dnf-utils) ;;
  debian) FAMILY_PACKAGES=(vim dnsutils apt-transport-https needrestart) ;;
esac

if ! skipped packages; then
  step "Packages"
  pkg_update
  case "$PKG" in
    apt) run env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q ;;
    dnf) run dnf upgrade -y -q ;;
  esac
  PACKAGES=("${COMMON_PACKAGES[@]}" "${FAMILY_PACKAGES[@]}")
  # RHEL 9 minimal installs and containers ship curl-minimal, which provides
  # the curl command but conflicts with the full curl package. Keep it.
  if [[ "$OS_FAMILY" == rhel ]] && pkg_installed curl-minimal; then
    mapfile -t PACKAGES < <(printf '%s\n' "${PACKAGES[@]}" | grep -vx curl)
  fi
  pkg_install "${PACKAGES[@]}"
fi

if ! skipped time; then
  step "Hostname and time"
  if has_systemd; then
    if [[ -n "$HOSTNAME_NEW" ]]; then run hostnamectl set-hostname "$HOSTNAME_NEW"; fi
    run timedatectl set-timezone "$TIMEZONE"
    # The chrony unit is chronyd on RHEL and chrony on Ubuntu.
    if [[ "$OS_FAMILY" == rhel ]]; then run systemctl enable --now chronyd; else run systemctl enable --now chrony; fi
  else
    log_warn "No systemd (container?); skipping hostname, time zone, and chrony"
  fi
fi

if [[ -n "$ADMIN_USER" ]] && ! skipped user; then
  step "Admin user"
  bash "${SCRIPT_DIR}/create-admin-user.sh" "$ADMIN_USER" --ssh-key-file "$KEY_FILE"
fi

if ! skipped ssh; then
  step "SSH"
  if command -v sshd >/dev/null 2>&1 || [[ -x /usr/sbin/sshd ]]; then
    bash "${SCRIPT_DIR}/harden-ssh.sh"
  else
    log_warn "openssh-server isn't installed; skipping SSH hardening"
  fi
fi

if ! skipped firewall; then
  step "Firewall"
  FIREWALL_ARGS=()
  for rule in "${ALLOW[@]}"; do FIREWALL_ARGS+=(--allow "$rule"); done
  bash "${SCRIPT_DIR}/configure-firewall.sh" "${FIREWALL_ARGS[@]}"
fi

if ! skipped updates; then
  step "Automatic security updates"
  bash "${SCRIPT_DIR}/enable-auto-updates.sh"
fi

if ((DOCKER)); then
  step "Containers"
  if ((PODMAN)); then bash "${SCRIPT_DIR}/install-docker.sh" --podman; else bash "${SCRIPT_DIR}/install-docker.sh"; fi
fi

step "Summary"
log_info "Baseline applied. Next: log in again in a NEW session as ${ADMIN_USER:-your admin user} before closing this one."
case "$OS_FAMILY" in
  rhel) log_info "Reboot needed? needs-restarting -r" ;;
  debian) [[ -f /var/run/reboot-required ]] && log_warn "A reboot is required (/var/run/reboot-required)" || true ;;
esac
