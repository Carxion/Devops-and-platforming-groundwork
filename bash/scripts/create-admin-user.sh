#!/usr/bin/env bash
#
# create-admin-user.sh: create a named administrator account with SSH key
# login and sudo, on RHEL-family or Ubuntu/Debian systems. Safe to re-run.
#
# Usage: create-admin-user.sh [-n] USERNAME --ssh-key-file FILE [--nopasswd]
#
#   --ssh-key-file FILE  public key(s) to authorize (required)
#   --nopasswd           allow sudo without a password (automation accounts only)
#   -n, --dry-run        show what would change, change nothing
#   -h, --help           this help
#
# The admin group is "wheel" on RHEL and "sudo" on Ubuntu; both are granted
# sudo by the distribution's default /etc/sudoers.

set -Eeuo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

USERNAME=""
KEY_FILE=""
NOPASSWD=0

while (($# > 0)); do
  case "$1" in
    --ssh-key-file)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      KEY_FILE="$2"
      shift
      ;;
    --nopasswd) NOPASSWD=1 ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) die "Unknown option: $1" 2 ;;
    *) USERNAME="$1" ;;
  esac
  shift
done

# Linux username rules (useradd's default): start with a letter or underscore,
# then letters, digits, underscores, or hyphens; at most 32 characters.
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Invalid or missing USERNAME (lowercase letters, digits, _ and -)" 2
[[ -n "$KEY_FILE" ]] || die "--ssh-key-file is required: key-only login is the point" 2
[[ -r "$KEY_FILE" ]] || die "Can't read $KEY_FILE"
# Every non-comment line must look like an OpenSSH public key.
if grep -Ev '^(#|$)' "$KEY_FILE" | grep -Evq '^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com) [A-Za-z0-9+/=]+( .*)?$'; then
  die "$KEY_FILE contains a line that isn't an OpenSSH public key (is it the private key?)"
fi

require_root
detect_os

case "$OS_FAMILY" in
  rhel) ADMIN_GROUP=wheel ;;
  debian) ADMIN_GROUP=sudo ;;
esac

if id "$USERNAME" >/dev/null 2>&1; then
  log_info "User $USERNAME exists; making sure it's in $ADMIN_GROUP"
  run usermod -aG "$ADMIN_GROUP" "$USERNAME"
else
  log_info "Creating $USERNAME in group $ADMIN_GROUP"
  run useradd --create-home --shell /bin/bash --groups "$ADMIN_GROUP" "$USERNAME"
fi

# Home directory from the account database, not an assumption about /home.
HOME_DIR="$(getent passwd "$USERNAME" | cut -d: -f6 || true)"
[[ -n "$HOME_DIR" ]] || HOME_DIR="/home/${USERNAME}" # only reached in a dry run

log_info "Installing authorized keys in ${HOME_DIR}/.ssh"
run install -d -m 0700 -o "$USERNAME" -g "$USERNAME" "${HOME_DIR}/.ssh"
run install -m 0600 -o "$USERNAME" -g "$USERNAME" "$KEY_FILE" "${HOME_DIR}/.ssh/authorized_keys"

# Restore SELinux labels on RHEL, or sshd may refuse to read the keys.
if [[ "$OS_FAMILY" == rhel ]] && command -v restorecon >/dev/null 2>&1; then
  run restorecon -R "${HOME_DIR}/.ssh"
fi

if ((NOPASSWD)); then
  require_cmd visudo # from the sudo package, absent on some minimal images
  SUDOERS_FILE="/etc/sudoers.d/90-${USERNAME}"
  log_warn "Granting passwordless sudo to $USERNAME via $SUDOERS_FILE"
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$USERNAME" | write_file "${SUDOERS_FILE}.new" 0440
  # Validate before installing: a broken sudoers file can lock everyone out of sudo.
  run visudo -cf "${SUDOERS_FILE}.new" || {
    run rm -f "${SUDOERS_FILE}.new"
    die "sudoers validation failed; nothing installed"
  }
  run mv -f "${SUDOERS_FILE}.new" "$SUDOERS_FILE"
fi

log_info "Done. Test in a NEW terminal before closing this one: ssh ${USERNAME}@<host> then sudo -v"
