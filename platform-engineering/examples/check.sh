#!/usr/bin/env bash
# Test the golden path end to end: generate a service from the template, run
# its checks, update it to a new template version, build and run its image,
# and render it with the platform's web-app chart. Only Docker is needed.
#
# Usage: platform-engineering/examples/check.sh [--help]
#
#   1. In a uv container: copier copy, then the service's own checks (uv sync
#      --locked, ruff, mypy, pytest) and its catalog entry; then copier update
#      to a new template version, keeping a local edit.
#   2. docker build the generated service, run it, and call /healthz and /.
#   3. In the Helm lab's tools image: render devops/helm's web-app chart with
#      the service's deploy/ values, then helm lint and kubeconform.
#
# The generated service is left in platform-engineering/examples/out/ (git-ignored).
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/out"
UV_IMAGE="ghcr.io/astral-sh/uv:0.13.5-python3.14-trixie-slim"
TOOLS_IMAGE=helm-lab-tools
SERVICE=orders-api
FAKE_DIGEST="sha256:$(printf 'orders-api' | sha256sum | cut -d' ' -f1)"
export MSYS_NO_PATHCONV=1 # Git Bash on Windows: don't rewrite container paths

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "$0"
  exit 0
fi
host_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
section() { printf -- '--- %s\n' "$*"; }
status=0

mkdir -p "$OUT"
section "generate, check, and update"
docker run --rm -v "$(host_path "$REPO"):/repo:ro" -v "$(host_path "$OUT"):/out" "$UV_IMAGE" \
  bash -c 'apt-get update -qq >/dev/null && apt-get install -y -qq git >/dev/null &&
    bash /repo/platform-engineering/examples/golden-path-python-service/test/generate-and-update.sh \
      /repo/platform-engineering/examples/golden-path-python-service /out' || status=1

section "build and run the image"
image="golden-path/$SERVICE:check"
if docker build -q -t "$image" "$(host_path "$OUT/$SERVICE")" >/dev/null; then
  printf 'ok    docker build\n'
  container="$(docker run -d -p 127.0.0.1::8080 "$image")"
  port="$(docker port "$container" 8080 | head -1 | sed 's/.*://')"
  healthy=false
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
      healthy=true
      break
    fi
    sleep 1
  done
  if $healthy && curl -fsS "http://127.0.0.1:$port/" | grep -q '"service":"orders-api"'; then
    printf 'ok    the container answers /healthz and / as a non-root user (%s)\n' \
      "$(docker exec "$container" id -u)"
  else
    printf 'FAIL  the container didn'\''t answer\n'
    docker logs "$container" 2>&1 | tail -10 | sed 's/^/      | /'
    status=1
  fi
  docker rm -f "$container" >/dev/null
else
  printf 'FAIL  docker build\n'
  status=1
fi

section "render with the platform chart"
if ! docker image inspect "$TOOLS_IMAGE" >/dev/null 2>&1; then
  docker build -q -t "$TOOLS_IMAGE" "$(host_path "$REPO/devops/helm/lab")" >/dev/null
fi
docker run --rm --user 10001 -v "$(host_path "$REPO"):/work:ro" -v "$(host_path "$OUT"):/out:ro" "$TOOLS_IMAGE" -c "
  set -e
  cp -r devops/helm/examples/charts /tmp/charts
  helm dependency build /tmp/charts/web-app >/dev/null
  fails=0
  for env in dev production; do
    args=(-n orders -f /out/$SERVICE/deploy/\$env.yaml
      --set image.repository=registry.example.com/apps/$SERVICE --set image.tag= --set image.digest=$FAKE_DIGEST)
    if helm lint --strict /tmp/charts/web-app \"\${args[@]}\" >/tmp/lint 2>&1; then
      echo \"ok    helm lint --strict with deploy/\$env.yaml\"
    else
      echo \"FAIL  helm lint with deploy/\$env.yaml\"; sed 's/^/      | /' /tmp/lint; fails=1
    fi
    helm template $SERVICE /tmp/charts/web-app \"\${args[@]}\" >/tmp/\$env.yaml
    if grep -q 'containerPort: 8080' /tmp/\$env.yaml && ! grep -q 'podinfo' /tmp/\$env.yaml; then
      echo \"ok    renders the service (port 8080, its own entrypoint) for \$env\"
    else
      echo \"FAIL  rendering for \$env\"; fails=1
    fi
  done
  if kubeconform -strict -summary -kubernetes-version 1.34.0 /tmp/dev.yaml /tmp/production.yaml >/tmp/kc 2>&1; then
    echo \"ok    kubeconform: \$(tail -1 /tmp/kc)\"
  else
    echo 'FAIL  kubeconform'; sed 's/^/      | /' /tmp/kc; fails=1
  fi
  exit \$fails
" || status=1

section "deploy on the Helm lab's cluster"
kubeconfig="$REPO/devops/helm/lab/.kubeconfig"
if [[ -f "$kubeconfig" ]] && docker inspect helm-lab-control-plane >/dev/null 2>&1; then
  # The registry's host port (lab.sh up); the cluster pulls localhost:5001/... from it.
  ref="localhost:5001/golden-path/$SERVICE"
  docker tag "$image" "$ref:check"
  digest="$(docker push "$ref:check" 2>&1 | sed -n 's/.*digest: \(sha256:[a-f0-9]*\).*/\1/p')"
  docker run --rm --user 10001 --network kind -v "$(host_path "$REPO"):/work:ro" -v "$(host_path "$OUT"):/out:ro" \
    -e KUBECONFIG=/work/devops/helm/lab/.kubeconfig "$TOOLS_IMAGE" -c "
    set -e
    cp -r devops/helm/examples/charts /tmp/charts && helm dependency build /tmp/charts/web-app >/dev/null
    kubectl apply -k devops/kubernetes/platform/namespace >/dev/null
    fails=0
    if helm upgrade --install $SERVICE /tmp/charts/web-app -n sample-apps -f /out/$SERVICE/deploy/dev.yaml \
        --set image.repository=$ref --set image.tag=check --set image.digest=$digest \
        --wait --timeout 3m >/tmp/install 2>&1; then
      echo 'ok    installed with the platform chart and deploy/dev.yaml, pulled by digest, ready'
    else
      echo 'FAIL  install'; sed 's/^/      | /' /tmp/install; kubectl -n sample-apps get pods; fails=1
    fi
    if kubectl -n sample-apps get deployment $SERVICE >/dev/null 2>&1; then
      echo 'ok    resources are named after the service ($SERVICE), not the chart'
    else
      echo 'FAIL  no deployment named $SERVICE'; fails=1
    fi
    if helm test $SERVICE -n sample-apps --timeout 2m >/tmp/test 2>&1; then
      echo 'ok    helm test: /readyz answers through the namespace default-deny'
    else
      echo 'FAIL  helm test'; sed 's/^/      | /' /tmp/test; fails=1
    fi
    helm uninstall $SERVICE -n sample-apps --wait >/dev/null
    exit \$fails
  " || status=1
else
  printf 'skip  no Helm lab cluster (devops/helm/lab/lab.sh up to include this)\n'
fi

if [[ $status -ne 0 ]]; then
  printf '\ngolden path checks failed\n'
  exit 1
fi
printf '\ngolden path checks passed\n'
