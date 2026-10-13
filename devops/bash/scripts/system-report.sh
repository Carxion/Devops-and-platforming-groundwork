#!/usr/bin/env bash
#
# system-report.sh: a read-only health snapshot of a Linux host, for a ticket,
# a handover, or the first five minutes of an incident. Works on RHEL-family
# and Ubuntu systems; sections that need root say so instead of failing.
#
# Usage: system-report.sh [--disk-threshold PERCENT] > report.txt
#
#   --disk-threshold PERCENT  flag filesystems at or above this use (default 85)
#   -h, --help                this help
#
# Changes nothing. Safe to run on production.

set -Euo pipefail # no -e: one failing check shouldn't stop the report
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

DISK_THRESHOLD=85
while (($# > 0)); do
  case "$1" in
    --disk-threshold)
      DISK_THRESHOLD="${2:?--disk-threshold needs a value}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" 2 ;;
  esac
  shift
done

section() { printf '\n== %s ==\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

detect_os

section "Host"
printf 'Hostname:  %s\n' "$(hostname -f 2>/dev/null || hostname)"
# shellcheck source=/dev/null
printf 'OS:        %s\n' "$(. /etc/os-release && echo "$PRETTY_NAME")"
printf 'Kernel:    %s\n' "$(uname -r)"
printf 'Uptime:    %s\n' "$(uptime -p 2>/dev/null || uptime)"
printf 'Time:      %s\n' "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
# /proc/loadavg: 1, 5, and 15 minute load averages, then running/total tasks.
read -r l1 l5 l15 _ </proc/loadavg
printf 'Load:      %s %s %s (on %s CPUs)\n' "$l1" "$l5" "$l15" "$(nproc)"

section "Memory"
free -h

section "Filesystems at or above ${DISK_THRESHOLD}% use"
# df -P gives one line per filesystem in a fixed format; awk strips the % sign
# from column 5 and prints rows at or over the threshold. -x skips pseudo filesystems.
df -P -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null |
  awk -v t="$DISK_THRESHOLD" 'NR == 1 { print; next } { use = $5; sub(/%/, "", use); if (use + 0 >= t) { print; n++ } } END { if (!n) print "(none)" }'

section "Inodes at or above ${DISK_THRESHOLD}% use"
df -P -i -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null |
  awk -v t="$DISK_THRESHOLD" 'NR > 1 { use = $5; sub(/%/, "", use); if (use ~ /^[0-9]+$/ && use + 0 >= t) { print; n++ } } END { if (!n) print "(none)" }'

section "Top 5 processes by CPU"
ps -eo pid,user,%cpu,%mem,etime,comm --sort=-%cpu | head -6

section "Top 5 processes by memory"
ps -eo pid,user,%cpu,%mem,rss,comm --sort=-%mem | head -6

section "Failed systemd units"
if has_systemd; then
  systemctl --failed --no-legend --plain || true
  [[ -z "$(systemctl --failed --no-legend --plain)" ]] && echo "(none)"
else
  echo "(systemd isn't running)"
fi

section "Listening sockets"
if have ss; then
  # -t TCP, -u UDP, -l listening, -n numeric, -p process (process names need root).
  ss -tulnp 2>/dev/null || ss -tuln
else
  echo "(ss not installed: package iproute2 on Ubuntu, iproute on RHEL)"
fi

section "Errors in the journal, last hour"
if have journalctl; then
  # -p err: priority error and worse; -q no hints; --no-pager for files.
  journalctl -p err -q --no-pager --since "-1h" 2>/dev/null | tail -20
  [[ "${EUID}" -ne 0 ]] && echo "(run as root to include system logs)"
else
  echo "(no journald)"
fi

section "Mandatory access control"
if have getenforce; then
  printf 'SELinux: %s\n' "$(getenforce)"
elif have aa-status; then
  aa-status --enabled 2>/dev/null && echo "AppArmor: enabled" || echo "AppArmor: disabled or not readable"
else
  echo "(neither SELinux nor AppArmor tools found)"
fi

section "Pending updates"
case "$PKG" in
  apt)
    # apt-get -s (simulate) lists what an upgrade would install; count the Inst lines.
    total="$(apt-get -s -q upgrade 2>/dev/null | grep -c '^Inst ' || true)"
    security="$(apt-get -s -q upgrade 2>/dev/null | grep '^Inst ' | grep -ci 'security' || true)"
    printf '%s packages (%s from security pockets)\n' "$total" "$security"
    [[ -f /var/run/reboot-required ]] && echo "Reboot required: yes"
    ;;
  dnf)
    # check-update exits 100 when updates exist, so ignore its status.
    total="$(dnf -q check-update 2>/dev/null | grep -cE '^[[:alnum:]_.+-]+\.[[:alnum:]_]+[[:space:]]' || true)"
    security="$(dnf -q updateinfo list --security 2>/dev/null | wc -l || true)"
    printf '%s packages (%s security advisories)\n' "$total" "$security"
    if have needs-restarting; then needs-restarting -r >/dev/null 2>&1 || echo "Reboot required: yes"; fi
    ;;
esac

section "Recent logins"
last -n 5 -w 2>/dev/null | head -5 || echo "(last not available)"
