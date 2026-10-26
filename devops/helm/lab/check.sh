#!/usr/bin/env bash
# Every check on the example charts. Runs inside the tools container (lab.sh
# check), from the repository root. Static checks always run; the cluster
# checks run when the lab's kubeconfig points at a reachable cluster.
#
#   static:  helm lint --strict with each environment's values, chart-testing
#            lint, helm-unittest, and every rendering validated by kubeconform
#            (Kubernetes 1.34 schemas, strict). Renderings are kept in
#            devops/helm/lab/out/rendered for lab.sh to run checkov on.
#   cluster: the namespace baseline from devops/kubernetes (Pod Security
#            restricted, default-deny), then install with --wait, helm test,
#            upgrade, a failing upgrade that must roll itself back, manual
#            rollback, helm diff, the worker, and publishing to and installing
#            from an OCI registry.
#
# Usage: bash devops/helm/lab/check.sh   (REGISTRY=host:port for the OCI steps)
set -Eeuo pipefail

EXAMPLES=devops/helm/examples
OUT=devops/helm/lab/out
NAMESPACE=sample-apps
K8S_VERSION=1.34.0
REGISTRY="${REGISTRY:-helm-lab-registry:5000}"
failures=0

ok() { printf 'ok    %s\n' "$*"; }
fail() {
  printf 'FAIL  %s\n' "$*"
  failures=$((failures + 1))
}
section() { printf -- '--- %s\n' "$*"; }

# check "description" command...: run it, show its output only on failure.
check() {
  local description="$1" output
  shift
  if output="$("$@" 2>&1)"; then
    ok "$description"
  else
    fail "$description"
    printf '%s\n' "$output" | tail -25 | sed 's/^/      | /'
  fi
}

# Work on a copy, so dependency builds and packages don't land in the repository.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -r "$EXAMPLES/charts" "$WORK/charts"
rm -rf "$OUT" && mkdir -p "$OUT/rendered"

section "static"
for chart in web-app worker; do
  check "$chart: helm dependency build (from Chart.lock)" helm dependency build "$WORK/charts/$chart"
done
check "platform-lib: helm lint --strict" helm lint --strict "$WORK/charts/platform-lib"

for chart in web-app worker; do
  check "$chart: helm lint --strict (chart defaults)" helm lint --strict "$WORK/charts/$chart"
  helm template "$chart" "$WORK/charts/$chart" --namespace "$NAMESPACE" >"$OUT/rendered/$chart-defaults.yaml"
  for env in dev prod-eks prod-aks; do
    values="$EXAMPLES/environments/$env/$chart.yaml"
    check "$chart: helm lint --strict with $env values" helm lint --strict "$WORK/charts/$chart" -f "$values"
    if helm template "$chart" "$WORK/charts/$chart" --namespace "$NAMESPACE" -f "$values" >"$OUT/rendered/$chart-$env.yaml" 2>"$WORK/err"; then
      ok "$chart: renders with $env values"
    else
      fail "$chart: renders with $env values"
      sed 's/^/      | /' "$WORK/err"
    fi
  done
  check "$chart: helm unittest" helm unittest "$WORK/charts/$chart"
done

check "kubeconform: every rendering, strict, Kubernetes $K8S_VERSION" \
  kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" "$OUT"/rendered/*.yaml

# chart-testing's lint: Chart.yaml schema, yamllint on the chart's files, and
# helm lint, for charts given explicitly (no Git diff against a base branch).
check "chart-testing: ct lint" \
  ct lint --charts "$WORK/charts/web-app,$WORK/charts/worker" \
  --chart-dirs "$WORK/charts" --validate-maintainers=false --check-version-increment=false

# Expected failures are checks too: a chart that accepts bad input isn't safe.
expect_failure() {
  local description="$1" pattern="$2" output
  shift 2
  if output="$("$@" 2>&1)"; then
    fail "$description (it succeeded)"
  elif grep -q -- "$pattern" <<<"$output"; then
    ok "$description"
  else
    fail "$description (wrong error)"
    printf '%s\n' "$output" | tail -10 | sed 's/^/      | /'
  fi
}
expect_failure "rejects an image tag in place of a digest" "sha256" \
  helm template x "$WORK/charts/web-app" --set image.digest=latest
expect_failure "rejects an unknown value (typo protection)" "additional properties" \
  helm template x "$WORK/charts/web-app" --set replicas=3
expect_failure "rejects ingress without a class" "ingress.className is required" \
  helm template x "$WORK/charts/web-app" --set ingress.enabled=true

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  printf '\nNo cluster (run lab.sh up for the cluster checks).\n'
  if ((failures > 0)); then
    printf '%s failure(s)\n' "$failures"
    exit 1
  fi
  printf 'static checks passed\n'
  exit 0
fi

section "cluster"
check "namespace baseline: Pod Security restricted, default-deny, quota" \
  kubectl apply -k devops/kubernetes/platform/namespace
helm uninstall web-app worker web-app-oci -n "$NAMESPACE" --wait >/dev/null 2>&1 || true

dev() { printf '%s/environments/dev/%s.yaml' "$EXAMPLES" "$1"; }
revision() { helm history web-app -n "$NAMESPACE" -o json | jq -r '.[-1].revision'; }
status() { helm status web-app -n "$NAMESPACE" -o json | jq -r '.info.status'; }
message() { kubectl -n "$NAMESPACE" get configmap web-app -o jsonpath='{.data.PODINFO_UI_MESSAGE}'; }

check "web-app: install with --wait (resources ready, not just created)" \
  helm install web-app "$WORK/charts/web-app" -n "$NAMESPACE" -f "$(dev web-app)" --wait --timeout 3m
check "web-app: helm test (a pod in the namespace reaches /readyz)" \
  helm test web-app -n "$NAMESPACE" --timeout 2m

old_rs="$(kubectl -n "$NAMESPACE" get rs -l app.kubernetes.io/instance=web-app -o name | sort)"
check "web-app: upgrade with a config change" \
  helm upgrade web-app "$WORK/charts/web-app" -n "$NAMESPACE" -f "$(dev web-app)" \
  --set config.PODINFO_UI_MESSAGE="Hello from revision 2" --wait --timeout 3m
new_rs="$(kubectl -n "$NAMESPACE" get rs -l app.kubernetes.io/instance=web-app -o name | sort)"
if [[ "$(revision)" == 2 && "$(message)" == "Hello from revision 2" && "$new_rs" != "$old_rs" ]]; then
  ok "web-app: revision 2, new config, and the checksum rolled the pods (new ReplicaSet)"
else
  fail "web-app: after upgrade: revision $(revision), message '$(message)'"
fi

# A digest that doesn't exist: the new pods can never start. With
# --rollback-on-failure, Helm waits, gives up at the timeout, and rolls back.
bad_digest="sha256:$(printf 'no-such-image' | sha256sum | cut -d' ' -f1)"
if helm upgrade web-app "$WORK/charts/web-app" -n "$NAMESPACE" -f "$(dev web-app)" \
  --set image.digest="$bad_digest" --rollback-on-failure --timeout 60s >"$WORK/bad" 2>&1; then
  fail "web-app: an upgrade to a missing image succeeded"
else
  if [[ "$(status)" == deployed && "$(message)" == "Hello from revision 2" ]] &&
    helm history web-app -n "$NAMESPACE" -o json | jq -e '.[-1].description | test("Rollback")' >/dev/null; then
    ok "web-app: failed upgrade rolled itself back (revision $(revision) is a rollback, still serving revision 2's config)"
  else
    fail "web-app: after failed upgrade: status $(status), message '$(message)'"
    sed 's/^/      | /' "$WORK/bad" | tail -10
  fi
fi
check "web-app: still passes helm test after the rollback" helm test web-app -n "$NAMESPACE" --timeout 2m

check "web-app: helm rollback to revision 1" helm rollback web-app 1 -n "$NAMESPACE" --wait --timeout 3m
if [[ "$(message)" == "Hello from dev" ]]; then
  ok "web-app: revision $(revision) runs revision 1's config again"
else
  fail "web-app: after rollback, message '$(message)'"
fi

if helm diff upgrade web-app "$WORK/charts/web-app" -n "$NAMESPACE" -f "$(dev web-app)" \
  --set config.PODINFO_UI_MESSAGE=Changed --no-color 2>&1 | grep -q '+.*PODINFO_UI_MESSAGE: "Changed"'; then
  ok "helm diff: shows the pending change before an upgrade"
else
  fail "helm diff: didn't show the change"
fi

check "worker: install with --wait" \
  helm install worker "$WORK/charts/worker" -n "$NAMESPACE" -f "$(dev worker)" --wait --timeout 3m
check "worker: logs show it processing" \
  bash -c "kubectl -n $NAMESPACE logs deploy/worker --tail=5 | grep -q 'processed batch'"

section "OCI registry"
# A path unique to this run, so "already published" is tested from a clean start.
repo="oci://$REGISTRY/charts-$(date +%s)"
export HELM_PLAIN_HTTP=true
if out="$(bash "$EXAMPLES/publish-charts.sh" "$WORK/charts" "$repo" 2>&1)" &&
  [[ "$(grep -c '^published ' <<<"$out")" == 3 ]]; then
  ok "publish-charts.sh: published all three charts to $repo"
else
  fail "publish-charts.sh: first run"
  printf '%s\n' "$out" | sed 's/^/      | /'
fi
digest="$(sed -n 's/^published web-app [^ ]* //p' <<<"$out")"
if again="$(bash "$EXAMPLES/publish-charts.sh" "$WORK/charts" "$repo" 2>&1)" &&
  [[ "$(grep -c '^skipped .*(already published)' <<<"$again")" == 3 ]]; then
  ok "publish-charts.sh: a second run pushes nothing (versions are never overwritten)"
else
  fail "publish-charts.sh: second run"
  printf '%s\n' "$again" | sed 's/^/      | /'
fi
check "web-app: helm show chart from the registry" \
  helm show chart "$repo/web-app" --version 0.1.0 --plain-http
check "web-app: install from the registry, by digest ($digest)" \
  helm install web-app-oci "$repo/web-app@$digest" -n "$NAMESPACE" \
  -f "$(dev web-app)" --plain-http --wait --timeout 3m

section "clean up"
check "uninstall every release" helm uninstall web-app worker web-app-oci -n "$NAMESPACE" --wait

if ((failures > 0)); then
  printf '\n%s failure(s)\n' "$failures"
  exit 1
fi
printf '\nall checks passed\n'
