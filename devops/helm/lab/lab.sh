#!/usr/bin/env bash
# Start, check, use, or remove the Helm lab: a kind cluster and a local OCI
# registry, driven from a tools container (see Dockerfile) so nothing needs
# installing on your machine except Docker.
#
# Usage: lab.sh up | check | shell | down | --help
#
#   up      Build the tools image, start the registry, create the kind cluster,
#           and write its kubeconfig to .kubeconfig next to this script
#           (git-ignored). Safe to rerun.
#   check   Run every check in check.sh: lint, render, schema and policy checks,
#           unit tests, then install, test, upgrade, roll back, and publish the
#           example charts on the cluster. Static checks run even without `up`.
#   shell   A shell in the tools container, with helm and kubectl pointed at
#           the cluster and the repository mounted at /work.
#   down    Delete the cluster, the registry, and the kubeconfig.
#
# Needs Docker with about 2 GB of free memory.
set -Eeuo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$LAB_DIR/../../.." && pwd)"
IMAGE=helm-lab-tools
CLUSTER=helm-lab
REGISTRY=helm-lab-registry
REGISTRY_IMAGE="registry:3.1.2"
NETWORK=kind # the network kind creates; the registry and tools join it too
CHECKOV_IMAGE="bridgecrew/checkov:3.3.30"
METRICS_SERVER_VERSION=3.14.0
# Git Bash on Windows rewrites paths like /var/run/docker.sock; stop it.
export MSYS_NO_PATHCONV=1

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "$0"; }
log() { printf '%s\n' "lab: $*" >&2; }
die() {
  log "error: $*"
  exit 1
}

# A path Docker can mount: on Git Bash for Windows, the Windows form.
host_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

# tools [--root] [docker run options...] -- command...
# Runs a command in the tools container with the repository at /work and the
# lab's kubeconfig, on the kind network. --root is only for kind, which talks
# to the Docker daemon through the mounted socket.
tools() {
  local user=(--user 10001) opts=()
  if [[ "${1:-}" == --root ]]; then
    user=(--user 0 -v /var/run/docker.sock:/var/run/docker.sock)
    shift
  fi
  while [[ $# -gt 0 && "$1" != -- ]]; do
    opts+=("$1")
    shift
  done
  shift
  local network=()
  if docker network inspect "$NETWORK" >/dev/null 2>&1; then network=(--network "$NETWORK"); fi
  docker run --rm "${user[@]}" "${network[@]}" "${opts[@]}" \
    -v "$(host_path "$REPO_DIR"):/work" -w /work \
    -e KUBECONFIG=/work/devops/helm/lab/.kubeconfig \
    "$IMAGE" -c "$*"
}

build_image() {
  log "building the tools image"
  docker build -q -t "$IMAGE" "$(host_path "$LAB_DIR")" >/dev/null
}

cmd_up() {
  command -v docker >/dev/null || die "docker is required"
  build_image
  if ! tools --root -- "kind get clusters" | grep -qx "$CLUSTER"; then
    log "creating the kind cluster (about a minute)"
    tools --root -- "kind create cluster --config devops/helm/lab/kind-config.yaml --wait 120s"
  else
    log "cluster $CLUSTER already exists"
  fi
  # The kubeconfig with the cluster's address on the kind network, for the tools container.
  tools --root -- "kind get kubeconfig --internal --name $CLUSTER > devops/helm/lab/.kubeconfig && chmod 644 devops/helm/lab/.kubeconfig"
  if ! docker inspect "$REGISTRY" >/dev/null 2>&1; then
    log "starting the OCI registry"
    docker run -d --name "$REGISTRY" --network "$NETWORK" --restart unless-stopped "$REGISTRY_IMAGE" >/dev/null
  fi
  # metrics-server, so HorizontalPodAutoscalers have CPU metrics. kind's kubelets
  # use self-signed certificates, hence --kubelet-insecure-tls: lab only.
  log "installing metrics-server"
  tools -- "helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null &&
    helm upgrade --install metrics-server metrics-server/metrics-server --version $METRICS_SERVER_VERSION \
      -n kube-system --set 'args={--kubelet-insecure-tls}' --wait --timeout 3m >/dev/null"
  tools -- "kubectl get nodes"
  log "ready: lab.sh check, or lab.sh shell"
}

cmd_check() {
  docker image inspect "$IMAGE" >/dev/null 2>&1 || build_image
  local status=0
  tools -e "REGISTRY=$REGISTRY:5000" -- "bash devops/helm/lab/check.sh" || status=$?
  if [[ -d "$LAB_DIR/out/rendered" ]]; then
    log "checkov on the rendered manifests"
    docker run --rm -v "$(host_path "$LAB_DIR/out/rendered"):/rendered:ro" "$CHECKOV_IMAGE" \
      -d /rendered --framework kubernetes --compact --quiet || status=1
  fi
  if [[ $status -ne 0 ]]; then die "checks failed"; fi
  log "all checks passed"
}

cmd_shell() {
  docker image inspect "$IMAGE" >/dev/null 2>&1 || build_image
  docker run --rm -it --user 10001 --network "$NETWORK" \
    -v "$(host_path "$REPO_DIR"):/work" -w /work \
    -e KUBECONFIG=/work/devops/helm/lab/.kubeconfig "$IMAGE"
}

cmd_down() {
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    tools --root -- "kind delete cluster --name $CLUSTER" || true
  fi
  docker rm -f "$REGISTRY" >/dev/null 2>&1 || true
  rm -f "$LAB_DIR/.kubeconfig"
  log "removed (the tools image stays; docker rmi $IMAGE to remove it)"
}

case "${1:-}" in
  up) cmd_up ;;
  check) cmd_check ;;
  shell) cmd_shell ;;
  down) cmd_down ;;
  -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
