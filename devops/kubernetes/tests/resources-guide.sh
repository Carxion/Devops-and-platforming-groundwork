#!/usr/bin/env bash
# Check devops/kubernetes/RESOURCES.md against a real cluster: validate every
# YAML block, apply every block that starts with "apiVersion:" (CRDs first),
# and check what the page claims about the result.
#
# Usage: devops/kubernetes/tests/resources-guide.sh [--help]
#
# Needs the Helm lab's kind cluster (devops/helm/lab/lab.sh up). From the
# host, the script re-runs itself in the lab's tools image; inside it, it
# runs directly. Everything it creates is removed at the end.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
GUIDE=devops/kubernetes/RESOURCES.md
K8S_VERSION=1.34.0

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "$0"
  exit 0
fi

# From the host: run inside the tools image, on the kind network.
if ! command -v kubeconform >/dev/null 2>&1; then
  export MSYS_NO_PATHCONV=1
  host_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
  [[ -f "$REPO/devops/helm/lab/.kubeconfig" ]] || {
    echo "no lab cluster: run devops/helm/lab/lab.sh up first" >&2
    exit 2
  }
  exec docker run --rm --user 10001 --network kind -v "$(host_path "$REPO"):/work:ro" -w /work \
    -e KUBECONFIG=/work/devops/helm/lab/.kubeconfig helm-lab-tools devops/kubernetes/tests/resources-guide.sh
fi

cd "$REPO"
failures=0
ok() { printf 'ok    %s\n' "$*"; }
fail() {
  printf 'FAIL  %s\n' "$*"
  failures=$((failures + 1))
}
check() {
  local description="$1" output
  shift
  if output="$("$@" 2>&1)"; then
    ok "$description"
  else
    fail "$description"
    printf '%s\n' "$output" | tail -15 | sed 's/^/      | /'
  fi
}
expect_error() {
  local description="$1" pattern="$2" output
  shift 2
  if output="$("$@" 2>&1)"; then
    fail "$description (it succeeded)"
  elif grep -q -- "$pattern" <<<"$output"; then
    ok "$description"
  else
    fail "$description (unexpected error)"
    printf '%s\n' "$output" | tail -8 | sed 's/^/      | /'
  fi
}

WORK="$(mktemp -d)"
cleanup() {
  kubectl delete namespace shop demo --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl delete priorityclass shop-critical --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete crd backups.example.com --ignore-not-found >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# Every ```yaml block: all of them to validate, the apiVersion-first ones to apply.
python3 - "$GUIDE" "$WORK" <<'EOF'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r"^```yaml\n(.*?)^```", text, re.S | re.M)
applied = [b for b in blocks if b.startswith("apiVersion:")]
crds = [b for b in applied if "kind: CustomResourceDefinition" in b]
rest = [b for b in applied if b not in crds]
open(f"{sys.argv[2]}/all.yaml", "w").write("---\n".join(blocks))
open(f"{sys.argv[2]}/crds.yaml", "w").write("---\n".join(crds))
open(f"{sys.argv[2]}/applied.yaml", "w").write("---\n".join(rest))
print(f"{len(blocks)} yaml blocks, {len(applied)} applied ({len(crds)} CRDs)")
EOF

echo "--- validate"
# Custom kinds (the Backup, Gateway API) have no published schema; kubeconform skips them.
check "kubeconform: every block, strict, Kubernetes $K8S_VERSION" \
  kubeconform -strict -summary -ignore-missing-schemas -kubernetes-version "$K8S_VERSION" "$WORK/all.yaml"

echo "--- apply"
cleanup_now() { kubectl delete namespace shop demo --ignore-not-found --wait >/dev/null 2>&1 || true; }
cleanup_now
check "CRDs first" kubectl apply --server-side -f "$WORK/crds.yaml"
check "CRD established" kubectl wait --for=condition=Established crd/backups.example.com --timeout=60s
check "apply every manifest (server-side)" kubectl apply --server-side -f "$WORK/applied.yaml"
check "applying again changes nothing it shouldn't" kubectl apply --server-side -f "$WORK/applied.yaml"

echo "--- what the page says happens"
check "Deployment becomes available" kubectl -n shop wait --for=condition=Available deployment/web --timeout=180s
check "StatefulSet rolls out" kubectl -n shop rollout status statefulset/queue --timeout=180s
check "DaemonSet rolls out" kubectl -n shop rollout status daemonset/node-agent --timeout=120s
check "Job completes" kubectl -n shop wait --for=condition=Complete job/migrate --timeout=120s
check "Job log says done" bash -c "kubectl -n shop logs job/migrate | grep -qx done"
check "bare Pod runs" kubectl -n shop wait --for=jsonpath='{.status.phase}'=Running pod/hello --timeout=90s
check "Pod log" bash -c "kubectl -n shop logs hello | grep -q 'hello from a pod'"
check "every StatefulSet claim is bound" bash -c \
  "[[ \$(kubectl -n shop get pvc -o jsonpath='{.items[*].status.phase}') == 'Bound Bound' ]]"
check "queue-0 wrote to its own volume" bash -c "kubectl -n shop exec queue-0 -- cat /data/log | grep -q 'I am queue-0'"
check "the Service has ready endpoints" bash -c \
  "kubectl -n shop get endpointslices -l kubernetes.io/service-name=web -o jsonpath='{.items[*].endpoints[*].addresses[*]}' | grep -q ."
check "the HPA owns replicas (at its minimum of 2)" bash -c \
  "sleep 5; [[ \$(kubectl -n shop get deployment web -o jsonpath='{.spec.replicas}') == 2 ]]"
check "CronJob can be run now" kubectl -n shop create job --from=cronjob/nightly-report report-now
check "that Job completes" kubectl -n shop wait --for=condition=Complete job/report-now --timeout=120s
check "custom resource exists" kubectl -n shop get backup orders-db
check "RBAC: reader can list pods" bash -c "[[ \$(kubectl auth can-i list pods -n shop --as=system:serviceaccount:shop:reader) == yes ]]"
check "RBAC: reader can't delete pods" bash -c "[[ \$(kubectl auth can-i delete pods -n shop --as=system:serviceaccount:shop:reader 2>/dev/null) == no ]]"
check "RBAC: reader can't read secrets" bash -c "[[ \$(kubectl auth can-i list secrets -n shop --as=system:serviceaccount:shop:reader 2>/dev/null) == no ]]"
check "the Secret is only base64-encoded" bash -c \
  "[[ \$(kubectl -n shop get secret web-db -o jsonpath='{.data.password}' | base64 -d) == change-me ]]"
expect_error "the quota refuses a LoadBalancer Service" "exceeded quota" \
  kubectl -n shop create service loadbalancer public --tcp=80:9898
expect_error "the CRD's schema rejects retentionDays: 0" "should be greater than or equal to 1" \
  bash -c "printf 'apiVersion: example.com/v1\nkind: Backup\nmetadata:\n  name: bad\n  namespace: shop\nspec:\n  schedule: daily\n  retentionDays: 0\n' | kubectl apply -f -"

echo "--- diff"
set +e
kubectl diff -f "$WORK/applied.yaml" >/dev/null 2>&1
unchanged=$?
sed 's/Hello from a ConfigMap/Hello, changed/' "$WORK/applied.yaml" | kubectl diff -f - >/dev/null 2>&1
changed=$?
set -e
if [[ $unchanged == 0 && $changed == 1 ]]; then
  ok "kubectl diff exits 0 with nothing to change and 1 with a change"
else
  fail "kubectl diff exit codes: $unchanged and $changed (expected 0 and 1)"
fi

echo "--- imperative creation under restricted"
kubectl create namespace demo >/dev/null
kubectl label namespace demo pod-security.kubernetes.io/enforce=restricted >/dev/null
check "kubectl create deployment is accepted" \
  kubectl -n demo create deployment web --image=ghcr.io/stefanprodan/podinfo:6.15.0 --replicas=2 --port=9898
check "but its pods are rejected by Pod Security" bash -c \
  "sleep 8; kubectl -n demo get events --field-selector reason=FailedCreate -o jsonpath='{.items[*].message}' | grep -q 'violates PodSecurity'"
check "so none are ready" bash -c "[[ -z \$(kubectl -n demo get deployment web -o jsonpath='{.status.readyReplicas}') ]]"
expect_error "kubectl run is refused outright" "violates PodSecurity" \
  kubectl -n demo run debug --image=busybox:1.38.0 --restart=Never -- sleep 60
check "--dry-run=client -o yaml generates a manifest without creating anything" bash -c \
  "kubectl create deployment gen --image=busybox:1.38.0 --dry-run=client -o yaml | grep -q 'kind: Deployment' && ! kubectl get deployment gen >/dev/null 2>&1"

if ((failures > 0)); then
  printf '\n%s failure(s)\n' "$failures"
  exit 1
fi
printf '\nall checks passed\n'
