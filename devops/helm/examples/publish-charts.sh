#!/usr/bin/env bash
# Publish every chart in a directory to an OCI registry, skipping any chart
# whose version is already there: a published version is never overwritten,
# so the same version always means the same chart.
#
# Usage: publish-charts.sh [--dry-run] <charts-dir> <oci://registry/path>
#
#   --dry-run   Show what would be published, and push nothing.
#
# Log in to the registry first (helm registry login <host>). Set
# HELM_PLAIN_HTTP=true for a registry without TLS, such as a local lab one.
# Prints one line per chart: "published <name> <version> <digest>" or
# "skipped <name> <version> (already published)".
set -Eeuo pipefail

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "$0"; }
die() {
  printf 'publish-charts: %s\n' "$*" >&2
  exit 2
}

dry_run=false
if [[ "${1:-}" == --dry-run ]]; then
  dry_run=true
  shift
fi
if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  usage
  exit 0
fi
[[ $# -eq 2 ]] || {
  usage >&2
  exit 2
}
charts_dir="$1"
registry="${2%/}"
[[ -d "$charts_dir" ]] || die "no such directory: $charts_dir"
[[ "$registry" == oci://* ]] || die "registry must be an oci:// reference: $registry"

plain_http=()
if [[ "${HELM_PLAIN_HTTP:-false}" == true ]]; then plain_http=(--plain-http); fi

packages="$(mktemp -d)"
trap 'rm -rf "$packages"' EXIT

# A field from Chart.yaml's top level.
chart_field() { sed -n "s/^$2: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p" "$1/Chart.yaml" | head -1; }

for chart in "$charts_dir"/*/; do
  chart="${chart%/}"
  [[ -f "$chart/Chart.yaml" ]] || continue
  name="$(chart_field "$chart" name)"
  version="$(chart_field "$chart" version)"
  [[ -n "$name" && -n "$version" ]] || die "$chart/Chart.yaml has no name or version"

  if helm show chart "$registry/$name" --version "$version" "${plain_http[@]}" >/dev/null 2>&1; then
    printf 'skipped %s %s (already published)\n' "$name" "$version"
    continue
  fi
  if $dry_run; then
    printf 'would publish %s %s\n' "$name" "$version"
    continue
  fi
  if grep -q '^dependencies:' "$chart/Chart.yaml"; then
    helm dependency build "$chart" >/dev/null
  fi
  helm package "$chart" --destination "$packages" >/dev/null
  digest="$(helm push "$packages/$name-$version.tgz" "$registry" "${plain_http[@]}" 2>&1 | sed -n 's/^Digest: //p')"
  [[ -n "$digest" ]] || die "pushing $name $version returned no digest"
  printf 'published %s %s %s\n' "$name" "$version" "$digest"
done
