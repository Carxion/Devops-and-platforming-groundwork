#!/usr/bin/env bash
# Check devops/kubernetes/CONCEPTS.md against a real cluster: on the kind
# node, the static pods, system services, and kube-proxy rules; through the
# API, apply the page's demo and check what the page says about the control
# plane, the reconcile loop, networking, and etcd.
#
# Usage: devops/kubernetes/tests/concepts-guide.sh [--help]
#
# Needs the Helm lab's kind cluster (devops/helm/lab/lab.sh up). From the
# host, the script runs the node checks with docker exec, then re-runs itself
# in the lab's tools image for the rest. Everything it creates is removed at
# the end.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
GUIDE=devops/kubernetes/CONCEPTS.md
NODE=helm-lab-control-plane
K8S_VERSION=1.34.0

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "$0"
  exit 0
fi

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
finish() {
  if ((failures > 0)); then
    printf '\n%s failure(s)\n' "$failures"
    exit 1
  fi
  printf '\nall checks passed\n'
  exit 0
}

# From the host: the node checks, then the rest inside the tools image.
if ! command -v kubeconform >/dev/null 2>&1; then
  export MSYS_NO_PATHCONV=1
  host_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
  [[ -f "$REPO/devops/helm/lab/.kubeconfig" ]] || {
    echo "no lab cluster: run devops/helm/lab/lab.sh up first" >&2
    exit 2
  }
  echo "--- on the node"
  check "static pod manifests for the four control plane components" bash -c \
    "[[ \$(docker exec $NODE ls /etc/kubernetes/manifests | tr '\n' ' ') == 'etcd.yaml kube-apiserver.yaml kube-controller-manager.yaml kube-scheduler.yaml ' ]]"
  check "the kubelet's staticPodPath is that directory" bash -c \
    "docker exec $NODE grep -qx 'staticPodPath: /etc/kubernetes/manifests' /var/lib/kubelet/config.yaml"
  check "kubelet and containerd are system services, not pods" \
    docker exec "$NODE" systemctl is-active kubelet containerd
  check "crictl lists the control plane containers" bash -c \
    "docker exec $NODE crictl ps | grep -q kube-apiserver"
  check "kube-proxy programmed iptables rules for the kubernetes Service" bash -c \
    "docker exec $NODE iptables-save -t nat | grep -q 'default/kubernetes:https cluster IP'"
  status=0
  docker run --rm --user 10001 --network kind -v "$(host_path "$REPO"):/work:ro" -w /work \
    -e KUBECONFIG=/work/devops/helm/lab/.kubeconfig helm-lab-tools devops/kubernetes/tests/concepts-guide.sh || status=$?
  ((status == 0)) || exit 1
  finish
fi

cd "$REPO"
WORK="$(mktemp -d)"
# shellcheck disable=SC2329 # called by the EXIT trap
cleanup() {
  kubectl delete namespace concepts --ignore-not-found --wait=false >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

python3 - "$GUIDE" "$WORK" <<'EOF'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = [b for b in re.findall(r"^```yaml\n(.*?)^```", text, re.S | re.M) if b.startswith("apiVersion:")]
open(f"{sys.argv[2]}/demo.yaml", "w").write("---\n".join(blocks))
print(f"{len(blocks)} yaml block(s) to apply")
EOF

pods() { kubectl -n concepts get pods -l app=hello -o jsonpath='{.items[*].metadata.name}'; }

echo "--- control plane"
for c in kube-apiserver etcd kube-scheduler kube-controller-manager; do
  check "$c runs as a static (mirror) pod" bash -c \
    "[[ \$(kubectl -n kube-system get pod $c-$NODE -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}') == file ]]"
done
check "kube-proxy runs as a DaemonSet" kubectl -n kube-system get daemonset kube-proxy
check "CoreDNS runs as a Deployment behind the kube-dns Service at 10.96.0.10" bash -c \
  "kubectl -n kube-system get deployment coredns >/dev/null && [[ \$(kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}') == 10.96.0.10 ]]"
check "the API server reports ready" bash -c "kubectl get --raw='/readyz?verbose' | grep -qx 'readyz check passed'"
for l in kube-scheduler kube-controller-manager; do
  check "$l holds a leader-election Lease" bash -c \
    "kubectl -n kube-system get lease $l -o jsonpath='{.spec.holderIdentity}' | grep -q ."
done
check "the kubelet renews a node Lease" kubectl -n kube-node-lease get lease "$NODE"
check "the node is Ready with no pressure conditions" bash -c \
  "[[ \$(kubectl get node $NODE -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}') == 'MemoryPressure=False DiskPressure=False PIDPressure=False Ready=True ' ]]"
check "the node's runtime is containerd" bash -c \
  "kubectl get node $NODE -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}' | grep -q '^containerd://'"
check "no cloud-controller-manager in kind" bash -c \
  "! kubectl -n kube-system get pods -o name | grep -q cloud-controller-manager"

echo "--- the demo"
kubectl delete namespace concepts --ignore-not-found --wait >/dev/null 2>&1 || true
check "kubeconform: the demo, strict, Kubernetes $K8S_VERSION" \
  kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" "$WORK/demo.yaml"
check "apply the demo" kubectl apply -f "$WORK/demo.yaml"
check "the Deployment rolls out" kubectl -n concepts rollout status deployment/hello --timeout=300s
check "owner chain: pod -> ReplicaSet -> Deployment" bash -c "
  p=\$(kubectl -n concepts get pods -l app=hello -o jsonpath='{.items[0].metadata.name}')
  rs=\$(kubectl -n concepts get pod \$p -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}')
  [[ \$rs == ReplicaSet/* ]] &&
  [[ \$(kubectl -n concepts get replicaset \${rs#ReplicaSet/} -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}') == Deployment/hello ]]"

echo "--- the reconcile loop"
check "scale to 3" kubectl -n concepts scale deployment hello --replicas=3
check "the third pod becomes ready" kubectl -n concepts rollout status deployment/hello --timeout=180s
for pair in deployment-controller:ScalingReplicaSet replicaset-controller:SuccessfulCreate \
  default-scheduler:Scheduled kubelet:Started; do
  check "event: ${pair%%:*} reports ${pair#*:}" bash -c \
    "kubectl -n concepts get events -o custom-columns=C:.source.component,R:.reason --no-headers | grep -Eq '^${pair%%:*} +${pair#*:}\$'"
done
before="$(pods)"
victim="${before%% *}"
check "delete a pod" kubectl -n concepts delete pod "$victim" --wait=false
check "a replacement with a new name appears" bash -c "
  for _ in \$(seq 30); do
    for n in \$(kubectl -n concepts get pods -l app=hello -o jsonpath='{.items[*].metadata.name}'); do
      [[ ' $before ' == *\" \$n \"* ]] || exit 0
    done
    sleep 1
  done
  exit 1"
check "and the Deployment is back at 3 ready" bash -c \
  "kubectl -n concepts rollout status deployment/hello --timeout=180s >/dev/null && [[ \$(kubectl -n concepts get deployment hello -o jsonpath='{.status.readyReplicas}') == 3 ]]"

echo "--- networking"
check "resolv.conf: kube-dns nameserver and the namespace search list" bash -c "
  r=\$(kubectl -n concepts exec deploy/hello -- cat /etc/resolv.conf)
  grep -qx 'nameserver 10.96.0.10' <<<\"\$r\" && grep -qx 'search concepts.svc.cluster.local svc.cluster.local cluster.local' <<<\"\$r\""
check "the Service name resolves to its ClusterIP" bash -c "
  ip=\$(kubectl -n concepts get svc hello -o jsonpath='{.spec.clusterIP}')
  kubectl -n concepts exec deploy/hello -- nslookup hello.concepts.svc.cluster.local | grep -q \"Address: \$ip\""
check "the EndpointSlice lists every ready pod's IP" bash -c "
  [[ \$(kubectl -n concepts get endpointslices -l kubernetes.io/service-name=hello -o jsonpath='{.items[*].endpoints[*].addresses[0]}' | tr ' ' '\n' | sort | tr '\n' ' ') == \
     \$(kubectl -n concepts get pods -l app=hello --field-selector=status.phase=Running -o jsonpath='{.items[*].status.podIP}' | tr ' ' '\n' | sort | tr '\n' ' ') ]]"
check "a request by Service name reaches a pod" bash -c \
  "kubectl -n concepts exec deploy/hello -- wget -qO- http://hello/version | grep -q '\"version\": \"6.15.0\"'"

echo "--- etcd"
check "etcd holds a key for every object the page lists" bash -c "
  k=\$(kubectl -n kube-system exec etcd-$NODE -- etcdctl --cacert /etc/kubernetes/pki/etcd/ca.crt \
    --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key \
    get /registry --prefix --keys-only | grep concepts)
  for p in namespaces/concepts deployments/concepts/hello replicasets/concepts/hello- pods/concepts/hello- \
    services/specs/concepts/hello services/endpoints/concepts/hello endpointslices/concepts/hello- \
    serviceaccounts/concepts/default configmaps/concepts/kube-root-ca.crt; do
    grep -q \"^/registry/\$p\" <<<\"\$k\" || { echo missing \$p; exit 1; }
  done"

echo "--- things to try"
check "a failing readiness probe stalls the rollout and keeps the old pods" bash -c "
  kubectl -n concepts patch deployment hello --type=json \
    -p='[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"/nope\"}]' >/dev/null
  ! kubectl -n concepts rollout status deployment/hello --timeout=40s >/dev/null 2>&1 &&
  [[ \$(kubectl -n concepts get deployment hello -o jsonpath='{.status.readyReplicas}') == 3 ]]"
check "rollout undo goes back to the previous ReplicaSet" bash -c "
  kubectl -n concepts rollout undo deployment/hello >/dev/null &&
  kubectl -n concepts rollout status deployment/hello --timeout=180s >/dev/null &&
  [[ \$(kubectl -n concepts get deployment hello -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}') == /readyz ]]"
check "a 100Gi memory request leaves a pod Pending: Insufficient memory" bash -c "
  kubectl -n concepts patch deployment hello --type=json \
    -p='[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/resources/requests/memory\",\"value\":\"100Gi\"},{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/resources/limits/memory\",\"value\":\"100Gi\"}]' >/dev/null
  sleep 8
  kubectl -n concepts get events --field-selector reason=FailedScheduling -o jsonpath='{.items[*].message}' | grep -q 'Insufficient memory'"
check "undo that too" bash -c \
  "kubectl -n concepts rollout undo deployment/hello >/dev/null && kubectl -n concepts rollout status deployment/hello --timeout=180s >/dev/null"
check "without runAsNonRoot, admission rejects the pods" bash -c "
  kubectl -n concepts patch deployment hello --type=json \
    -p='[{\"op\":\"remove\",\"path\":\"/spec/template/spec/securityContext/runAsNonRoot\"}]' >/dev/null
  sleep 8
  kubectl -n concepts get events --field-selector reason=FailedCreate -o jsonpath='{.items[*].message}' | grep -q 'runAsNonRoot != true'"
check "the API is plain REST" bash -c \
  "kubectl get --raw /api/v1/namespaces/concepts/pods | grep -q '\"kind\":\"PodList\"'"
check "-v=6 shows kubectl's HTTP requests" bash -c \
  "kubectl -n concepts get pods -v=6 2>&1 >/dev/null | grep -q 'verb=\"GET\" url=\"https://.*/api/v1/namespaces/concepts/pods'"

finish
