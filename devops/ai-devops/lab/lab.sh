#!/usr/bin/env bash
# Start, check, or remove the AI DevOps lab: Ollama, LiteLLM, Langfuse, and
# MLflow in Docker Compose (compose.yaml), and a tools image the checks run in.
#
# Usage: lab.sh up | check | down | --help
#
#   up      Build the tools image, start the stack, pull the two models, and
#           wait until LiteLLM, Langfuse, and MLflow answer. Safe to rerun.
#   check   Run every check (scripts/check_ai_devops_lab.py): the gateway,
#           tracing, prompts and the evaluation gate, promptfoo, the training
#           pipeline and registry, and model scanning.
#   down    Stop the stack and delete its volumes (models, traces, runs).
#
# Needs Docker with about 8 GB of free memory and 6 GB of disk.
set -Eeuo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$LAB_DIR/../../.." && pwd)"
IMAGE=ai-devops-lab-tools
MODELS=(qwen2.5:1.5b-instruct qwen2.5:0.5b-instruct)
# Git Bash on Windows rewrites paths like /work; stop it.
export MSYS_NO_PATHCONV=1

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "$0"; }
log() { printf '%s\n' "lab: $*" >&2; }
die() {
  log "error: $*"
  exit 1
}
host_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
compose() { docker compose -f "$(host_path "$LAB_DIR/compose.yaml")" "$@"; }

wait_for() {
  local name=$1 url=$2 tries=${3:-60}
  for ((i = 0; i < tries; i++)); do
    if curl -fsS -o /dev/null "$url"; then
      log "$name is up"
      return 0
    fi
    sleep 5
  done
  die "$name did not answer at $url; see: docker compose -f $LAB_DIR/compose.yaml logs"
}

cmd_up() {
  command -v docker >/dev/null || die "docker is required"
  log "building the tools image"
  docker build -q -t "$IMAGE" "$(host_path "$LAB_DIR")" >/dev/null
  log "starting the stack (the first start pulls about 5 GB of images)"
  compose up -d --wait ollama postgres clickhouse minio redis
  for model in "${MODELS[@]}"; do
    log "pulling $model"
    compose exec -T ollama ollama pull "$model" >/dev/null
  done
  compose up -d
  wait_for LiteLLM http://127.0.0.1:4000/health/liveliness
  wait_for Langfuse http://127.0.0.1:3300/api/public/health
  wait_for MLflow http://127.0.0.1:5500/health
  log "ready: lab.sh check"
}

cmd_check() {
  docker image inspect "$IMAGE" >/dev/null 2>&1 || die "run lab.sh up first"
  # On Windows, python3 can be a Store stub that exits without running anything.
  local python=python3
  if ! python3 -c '' >/dev/null 2>&1; then python=python; fi
  "$python" "$(host_path "$REPO_DIR/scripts/check_ai_devops_lab.py")"
}

cmd_down() {
  compose down -v
  log "removed (the tools image stays; docker rmi $IMAGE to remove it)"
}

case "${1:-}" in
  up) cmd_up ;;
  check) cmd_check ;;
  down) cmd_down ;;
  -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
