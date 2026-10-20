#!/usr/bin/env bash
#
# docker-audit.sh: flag risky settings on the running containers of a host:
# running as root, privileged, host networking, the Docker socket mounted,
# writable root filesystem, added capabilities, no memory limit, no restart
# policy, no health check, ports published on every interface.
#
# Usage: docker-audit.sh [--all] [--strict]
#
#   --all       include stopped containers
#   --strict    exit 1 if any container has a HIGH finding (for CI or cron)
#   -h, --help  this help
#
# Read-only: it only runs "docker ps" and "docker inspect". Each check is
# explained in software/containers/docker/08-hardening.md.

set -Euo pipefail

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

ALL=()
STRICT=0
while (($# > 0)); do
  case "$1" in
    --all) ALL=(--all) ;;
    --strict) STRICT=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

command -v docker >/dev/null || {
  echo "docker not found" >&2
  exit 1
}

mapfile -t IDS < <(docker ps -q "${ALL[@]}")
if ((${#IDS[@]} == 0)); then
  echo "No containers to audit."
  exit 0
fi

# One docker inspect call for every container, printing one line per container
# with "|" between fields. Go template notes:
#   {{.Name}}                     always starts with "/", trimmed below
#   {{or .Config.User "root"}}    an empty User means the image default, usually root
#   {{if .HostConfig.CapAdd}}...  capabilities added; guarded, because len of an empty list errors
#   {{with index .State "Health"}}  index returns nothing for a missing key, where .State.Health errors
#   {{range .Mounts}}...{{end}}   loops over mounts; flags the Docker socket by where it appears inside
#   {{range $p, $b := .NetworkSettings.Ports}}  each published port and its bindings
# shellcheck disable=SC2016 # Go template, not shell: $p and $b are template variables
FORMAT='{{.Name}}|{{.Config.Image}}|{{or .Config.User "root"}}|{{.HostConfig.Privileged}}|{{.HostConfig.NetworkMode}}|{{.HostConfig.ReadonlyRootfs}}|{{if .HostConfig.CapAdd}}{{len .HostConfig.CapAdd}}{{else}}0{{end}}|{{.HostConfig.Memory}}|{{.HostConfig.RestartPolicy.Name}}|{{with index .State "Health"}}{{.Status}}{{else}}none{{end}}|{{range .Mounts}}{{if or (eq .Destination "/var/run/docker.sock") (eq .Destination "/run/docker.sock")}}sock{{end}}{{end}}|{{range $p, $b := .NetworkSettings.Ports}}{{range $b}}{{if or (eq .HostIp "0.0.0.0") (eq .HostIp "::") (eq .HostIp "")}}{{$p}} {{end}}{{end}}{{end}}'

# Inspect first, separately, so a template or daemon error fails the audit
# loudly instead of silently dropping containers from the report.
if ! REPORT="$(docker inspect --format "$FORMAT" "${IDS[@]}")"; then
  echo "docker inspect failed; audit incomplete" >&2
  exit 1
fi

HIGH_TOTAL=0
printf '%-28s %-6s %s\n' CONTAINER RISK FINDINGS
while IFS='|' read -r name image user privileged netmode readonly capadd memory restart health sock public_ports; do
  findings=()
  high=0
  # The user field may be "0", "root", or "0:0" for root; numeric UIDs other than 0 are fine.
  if [[ "$user" =~ ^(root|0)(:.*)?$ ]]; then findings+=("runs as root"); fi
  if [[ "$privileged" == true ]]; then
    findings+=("PRIVILEGED")
    high=1
  fi
  if [[ "$sock" == *sock* ]]; then
    findings+=("DOCKER SOCKET MOUNTED")
    high=1
  fi
  if [[ "$netmode" == host ]]; then
    findings+=("host network")
    high=1
  fi
  if ((capadd > 0)); then findings+=("${capadd} capabilities added"); fi
  if [[ "$readonly" != true ]]; then findings+=("writable root fs"); fi
  if [[ "$memory" == 0 ]]; then findings+=("no memory limit"); fi
  if [[ "$restart" == "" || "$restart" == no ]]; then findings+=("no restart policy"); fi
  case "$health" in
    none) findings+=("no health check") ;;
    unhealthy) findings+=("UNHEALTHY") ;;
  esac
  if [[ -n "${public_ports// /}" ]]; then
    # IPv4 and IPv6 bindings list the same port twice; show each once.
    ports="$(tr ' ' '\n' <<<"$public_ports" | sed '/^$/d' | sort -u | paste -sd' ')"
    findings+=("published on all interfaces: ${ports}")
  fi

  risk=ok
  ((${#findings[@]} > 0)) && risk=low
  if ((high)); then
    risk=HIGH
    HIGH_TOTAL=$((HIGH_TOTAL + 1))
  fi
  # Join the findings with commas.
  joined="$(
    IFS=,
    printf '%s' "${findings[*]}"
  )"
  printf '%-28s %-6s %s\n' "${name#/}" "$risk" "${joined//,/, }"
  printf '%-28s        image: %s\n' "" "$image"
done <<<"$REPORT"

echo
echo "${#IDS[@]} container(s), ${HIGH_TOTAL} with HIGH findings."
if ((STRICT && HIGH_TOTAL > 0)); then exit 1; fi
exit 0
