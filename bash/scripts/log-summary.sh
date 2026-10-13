#!/usr/bin/env bash
#
# log-summary.sh: summarize SSH authentication logs or web access logs with
# grep, sed, and awk. Every regex is explained in bash/03-regex.md.
#
# Usage: log-summary.sh ssh [FILE...]      failed and accepted SSH logins
#        log-summary.sh access [FILE...]   nginx or Apache combined-format access log
#
#   --top N     rows per table (default 10)
#   -h, --help  this help
#
# With no FILE: ssh mode reads the system log (/var/log/secure on RHEL,
# /var/log/auth.log on Ubuntu, or journalctl when neither exists); access
# mode reads stdin. Gzipped rotated logs (*.gz) are read too.

set -Eeuo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

TOP=10
MODE=""
FILES=()
while (($# > 0)); do
  case "$1" in
    --top)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || die "--top needs a number" 2
      TOP="$2"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    ssh | access)
      if [[ -z "$MODE" ]]; then MODE="$1"; else FILES+=("$1"); fi
      ;;
    *) FILES+=("$1") ;;
  esac
  shift
done
[[ -n "$MODE" ]] || die "Choose a mode: ssh or access (see --help)" 2

# read_logs: concatenate FILES (decompressing .gz), or fall back per mode.
read_logs() {
  local f
  if ((${#FILES[@]} > 0)); then
    for f in "${FILES[@]}"; do
      [[ -r "$f" ]] || die "Can't read $f"
      case "$f" in
        *.gz) gzip -dc -- "$f" ;;
        *) cat -- "$f" ;;
      esac
    done
  elif [[ "$MODE" == ssh ]]; then
    if [[ -r /var/log/secure ]]; then
      cat /var/log/secure
    elif [[ -r /var/log/auth.log ]]; then
      cat /var/log/auth.log
    elif command -v journalctl >/dev/null 2>&1; then
      # The SSH unit is sshd on RHEL and ssh on Ubuntu; ask for both.
      journalctl -q --no-pager -u sshd -u ssh -o short
    else
      die "No SSH log found; pass a FILE"
    fi
  else
    cat
  fi
}

# top_counts TITLE: count identical input lines, most frequent first.
top_counts() {
  printf '\n%s\n' "$1"
  sort | uniq -c | sort -rn | head -n "$TOP" | awk '{ count = $1; $1 = ""; printf "  %7d %s\n", count, substr($0, 2) }'
}

ssh_summary() {
  local tmp
  tmp="$(mktemp)"
  # Keep only sshd lines once, then analyze the copy several ways.
  read_logs | grep -E 'sshd(-session)?\[[0-9]+\]:' >"$tmp" || true

  local failed accepted invalid
  failed="$(grep -cE 'Failed (password|publickey) for' "$tmp" || true)"
  accepted="$(grep -cE 'Accepted (password|publickey|keyboard-interactive/pam) for' "$tmp" || true)"
  invalid="$(grep -cE 'Invalid user ' "$tmp" || true)"
  printf 'SSH: %s failed, %s accepted, %s attempts for users that do not exist\n' "$failed" "$accepted" "$invalid"

  # "Failed password for invalid user admin from 203.0.113.9 port 50122 ssh2"
  # "Failed password for root from 198.51.100.4 port 40112 ssh2"
  # -o prints only the match; the IPv4 pattern is four groups of 1 to 3 digits.
  grep -E 'Failed (password|publickey) for' "$tmp" |
    grep -oE 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' | sed 's/^from //' |
    top_counts "Top source IPs of failed logins"

  # sed -E with a capture group: keep only the user name after "for", skipping "invalid user".
  grep -E 'Failed (password|publickey) for' "$tmp" |
    sed -E 's/.*Failed (password|publickey) for (invalid user )?([^ ]+) from .*/\3/' |
    top_counts "Top user names tried"

  grep -E 'Accepted [a-z/-]+ for' "$tmp" |
    sed -E 's/.*Accepted ([a-z/-]+) for ([^ ]+) from ([^ ]+) port.*/\2 from \3 (\1)/' |
    top_counts "Successful logins"

  rm -f -- "$tmp"
}

access_summary() {
  # Combined log format:
  # 203.0.113.9 - - [10/Oct/2026:13:55:36 +0000] "GET /items/1 HTTP/1.1" 200 512 "-" "curl/8.5.0"
  # awk -F'"' splits on double quotes: $2 is the request, $3 holds status and size.
  local tmp
  tmp="$(mktemp)"
  read_logs >"$tmp"

  awk -F'"' '
    {
      split($3, a, " ")           # a[1] = status, a[2] = bytes
      status = a[1]
      total++
      if (status ~ /^5[0-9][0-9]$/) errors++
      bytes += (a[2] ~ /^[0-9]+$/) ? a[2] : 0
    }
    END {
      if (!total) { print "No requests"; exit }
      printf "Requests: %d, 5xx: %d (%.2f%%), data sent: %.1f MB\n", total, errors, 100 * errors / total, bytes / 1048576
    }' "$tmp"

  awk -F'"' '{ split($3, a, " "); print a[1] }' "$tmp" | top_counts "Status codes"
  awk '{ print $1 }' "$tmp" | top_counts "Top client IPs"

  # Request paths with query strings removed, and numeric IDs collapsed to {id},
  # so /items/17 and /items/42 count as one route.
  awk -F'"' '{ split($2, r, " "); print r[1] " " r[2] }' "$tmp" |
    sed -E 's/\?.*$//; s#/[0-9]+(/|$)#/{id}\1#g' |
    top_counts "Top routes"

  awk -F'"' '{ split($3, a, " "); if (a[1] ~ /^5/) { split($2, r, " "); print a[1] " " r[1] " " r[2] } }' "$tmp" |
    top_counts "Top 5xx requests"

  rm -f -- "$tmp"
}

case "$MODE" in
  ssh) ssh_summary ;;
  access) access_summary ;;
esac
