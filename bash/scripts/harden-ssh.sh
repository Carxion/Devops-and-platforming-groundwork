#!/usr/bin/env bash
#
# harden-ssh.sh: apply a baseline SSH server configuration on RHEL 9+ or
# Ubuntu 22.04+, as a drop-in file that leaves the vendor's sshd_config alone.
# Validates with sshd -t and rolls back if the result doesn't validate.
#
# Usage: harden-ssh.sh [-n] [--allow-group GROUP] [--port PORT] [--force]
#
#   --allow-group GROUP  only members of GROUP may log in (for example wheel or sudo)
#   --port PORT          listen on PORT instead of 22 (RHEL also needs an SELinux port label)
#   --force              skip the check that someone has an authorized key
#   -n, --dry-run        show the file and commands, change nothing
#   -h, --help           this help
#
# Keep your current session open and test a new login before disconnecting.

set -Eeuo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

# sshd uses the FIRST value it reads for most settings, and both distributions
# include sshd_config.d/*.conf at the top of sshd_config in lexical order. A
# "10-" prefix sorts before RHEL's 50-redhat.conf and cloud-init's
# 50-cloud-init.conf, so these settings win.
DROPIN="${SSHD_DROPIN:-/etc/ssh/sshd_config.d/10-hardening.conf}"
ALLOW_GROUP=""
PORT=""
FORCE=0

while (($# > 0)); do
  case "$1" in
    --allow-group)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      ALLOW_GROUP="$2"
      shift
      ;;
    --port)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      PORT="$2"
      shift
      ;;
    --force) FORCE=1 ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" 2 ;;
  esac
  shift
done

if [[ -n "$PORT" ]]; then
  if ! [[ "$PORT" =~ ^[0-9]+$ ]] || ((PORT < 1 || PORT > 65535)); then die "Invalid --port: $PORT" 2; fi
fi

require_root
detect_os
command -v sshd >/dev/null 2>&1 || [[ -x /usr/sbin/sshd ]] || die "sshd isn't installed (package openssh-server)"
SSHD="$(command -v sshd || echo /usr/sbin/sshd)"

# Lockout protection: password login is about to be turned off, so someone
# must be able to log in with a key.
if ((! FORCE)); then
  found_key=0
  while IFS=: read -r _ _ uid _ _ home _; do
    if ((uid >= 1000 || uid == 0)) && [[ -s "${home}/.ssh/authorized_keys" ]]; then
      found_key=1
      break
    fi
  done </etc/passwd
  ((found_key)) || die "No user has ~/.ssh/authorized_keys. Add a key first (create-admin-user.sh), or use --force."
fi

log_info "Writing $DROPIN"
backup_file "$DROPIN"
{
  echo "# Managed by harden-ssh.sh. Edit the script's options, not this file."
  if [[ -n "$PORT" ]]; then echo "Port $PORT"; fi
  cat <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
LogLevel VERBOSE
EOF
  if [[ -n "$ALLOW_GROUP" ]]; then echo "AllowGroups $ALLOW_GROUP"; fi
} | write_file "$DROPIN" 0600

# sshd -t parses the full configuration, including drop-ins, without restarting.
if ! run "$SSHD" -t; then
  log_error "sshd -t rejected the configuration; removing $DROPIN"
  run rm -f -- "$DROPIN"
  die "Rolled back. Nothing was reloaded."
fi

if [[ -n "$PORT" && "$OS_FAMILY" == rhel ]] && command -v semanage >/dev/null 2>&1; then
  # SELinux only lets sshd bind to ports labeled ssh_port_t.
  run semanage port -a -t ssh_port_t -p tcp "$PORT" 2>/dev/null || run semanage port -m -t ssh_port_t -p tcp "$PORT"
fi

# The unit is sshd on RHEL and ssh on Ubuntu.
SERVICE=sshd
if [[ "$OS_FAMILY" == debian ]]; then SERVICE=ssh; fi
if has_systemd; then
  run systemctl reload "$SERVICE"
  log_info "Reloaded $SERVICE. Existing sessions stay open; test a NEW login now."
else
  log_warn "No systemd (container?); not reloading $SERVICE"
fi

# Show the effective values, as sshd will apply them.
if [[ "$DRY_RUN" != 1 ]]; then
  "$SSHD" -T 2>/dev/null | grep -Ei '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|maxauthtries|allowgroups) ' >&2 || true
fi
