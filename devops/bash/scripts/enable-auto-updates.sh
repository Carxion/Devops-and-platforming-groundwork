#!/usr/bin/env bash
#
# enable-auto-updates.sh: install security updates automatically, with the
# tool each distribution provides: unattended-upgrades on Ubuntu, and
# dnf-automatic on RHEL.
#
# Usage: enable-auto-updates.sh [-n] [--all]
#
#   --all          apply all updates, not only security updates
#   -n, --dry-run  show the changes, change nothing
#   -h, --help     this help
#
# Neither tool reboots by default. Kernel and glibc updates need a reboot to
# take effect; schedule one, and check with: needs-restarting -r (RHEL) or
# test -f /var/run/reboot-required (Ubuntu).

set -Eeuo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

ALL=0
while (($# > 0)); do
  case "$1" in
    --all) ALL=1 ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" 2 ;;
  esac
  shift
done

require_root
detect_os

case "$OS_FAMILY" in
  debian)
    pkg_install unattended-upgrades
    # The two settings the "dpkg-reconfigure unattended-upgrades" prompt writes.
    write_file /etc/apt/apt.conf.d/20auto-upgrades 0644 <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
    if ((ALL)); then
      # By default only the -security pocket is allowed; add -updates as well.
      write_file /etc/apt/apt.conf.d/52unattended-upgrades-all 0644 <<'EOF'
Unattended-Upgrade::Allowed-Origins:: "${distro_id}:${distro_codename}-updates";
EOF
    fi
    # Check the configuration parses and see what would be installed.
    if [[ "$DRY_RUN" != 1 ]]; then run unattended-upgrade --dry-run --debug 2>&1 | tail -5 || true; fi
    ;;
  rhel)
    pkg_install dnf-automatic
    CONF=/etc/dnf/automatic.conf
    UPGRADE_TYPE=security
    ((ALL)) && UPGRADE_TYPE=default
    backup_file "$CONF"
    # Edit the two keys in place. The regex anchors on the key at the start of
    # a line, with optional spaces around "=", and replaces the whole line.
    run sed -i -E \
      -e "s/^[[:space:]]*upgrade_type[[:space:]]*=.*/upgrade_type = ${UPGRADE_TYPE}/" \
      -e 's/^[[:space:]]*apply_updates[[:space:]]*=.*/apply_updates = yes/' \
      "$CONF"
    if [[ "$DRY_RUN" != 1 ]]; then grep -E '^(upgrade_type|apply_updates)' "$CONF" >&2; fi
    if has_systemd; then
      run systemctl enable --now dnf-automatic.timer
      run systemctl list-timers dnf-automatic.timer
    else
      log_warn "No systemd; the timer can't be enabled here."
    fi
    ;;
esac
log_info "Automatic $( ((ALL)) && echo "all" || echo "security") updates enabled"
