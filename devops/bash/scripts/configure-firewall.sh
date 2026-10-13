#!/usr/bin/env bash
#
# configure-firewall.sh: default-deny inbound firewall that allows SSH plus
# the ports you list. Uses firewalld on RHEL and ufw on Ubuntu, the tools
# each distribution ships and documents.
#
# Usage: configure-firewall.sh [-n] [--allow PORT/PROTO]... [--ssh-port PORT]
#
#   --allow PORT/PROTO  also allow this port, for example 443/tcp (repeatable)
#   --ssh-port PORT     SSH listens on PORT instead of 22
#   -n, --dry-run       show the commands, change nothing
#   -h, --help          this help
#
# SSH is always allowed first, so enabling the firewall can't cut off the
# session running this script.

set -Eeuo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

ALLOW=()
SSH_PORT=22

while (($# > 0)); do
  case "$1" in
    --allow)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      ALLOW+=("$2")
      shift
      ;;
    --ssh-port)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      SSH_PORT="$2"
      shift
      ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" 2 ;;
  esac
  shift
done

# Validate every rule before touching anything: PORT or START-END, then /tcp or /udp.
for rule in "${ALLOW[@]}" "${SSH_PORT}/tcp"; do
  [[ "$rule" =~ ^([0-9]{1,5})(-([0-9]{1,5}))?/(tcp|udp)$ ]] || die "Invalid rule '$rule' (expected PORT/tcp, PORT/udp, or START-END/tcp)" 2
  ((BASH_REMATCH[1] <= 65535)) || die "Port out of range in '$rule'" 2
done

require_root
detect_os

case "$OS_FAMILY" in
  rhel)
    pkg_installed firewalld || pkg_install firewalld
    if has_systemd; then
      run systemctl enable --now firewalld
    else
      log_warn "No systemd; firewalld can't run here. Showing the rules only."
      DRY_RUN=1
    fi
    # --permanent writes the saved config; --reload applies it. firewalld's
    # default zone (public) already rejects unlisted inbound traffic.
    if [[ "$SSH_PORT" == 22 ]]; then
      run firewall-cmd --permanent --add-service=ssh
    else
      run firewall-cmd --permanent --add-port="${SSH_PORT}/tcp"
    fi
    for rule in "${ALLOW[@]}"; do
      run firewall-cmd --permanent --add-port="$rule"
    done
    run firewall-cmd --reload
    if [[ "$DRY_RUN" != 1 ]]; then run firewall-cmd --list-all; fi
    ;;
  debian)
    pkg_installed ufw || pkg_install ufw
    run ufw default deny incoming
    run ufw default allow outgoing
    run ufw allow "${SSH_PORT}/tcp" comment ssh
    for rule in "${ALLOW[@]}"; do
      # ufw writes ranges as START:END.
      run ufw allow "${rule/-/:}"
    done
    if has_systemd; then
      run ufw --force enable
      run ufw status verbose
    else
      log_warn "No systemd; rules are saved but ufw isn't enabled here."
    fi
    ;;
esac
log_info "Firewall configured: ssh (${SSH_PORT}/tcp)${ALLOW[*]:+, ${ALLOW[*]}}"
