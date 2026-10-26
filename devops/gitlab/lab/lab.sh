#!/usr/bin/env bash
# Start, inspect, or remove the local GitLab lab (compose.yaml next to this script).
#
# Usage: lab.sh up | status | down | --help
#
#   up      Start GitLab, the runner, and moto; wait until GitLab answers; create
#           an admin API token; and register two runners with authentication
#           tokens (the current workflow, not registration tokens): one for every
#           job, and one for jobs tagged image-build. Safe to rerun.
#   status  Show the containers and whether the API answers with the lab token.
#   down    Remove the containers, volumes, and the lab's credentials file.
#
# Credentials are generated on first `up` and kept in .env.lab next to this
# script (git-ignored). The check script reads the token from there:
#   python scripts/check_gitlab_examples.py
#
# Lab only: plain HTTP on 127.0.0.1:8929, root user, throwaway data.
set -Eeuo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$LAB_DIR/.env.lab"
URL="http://127.0.0.1:8929"
# Git Bash on Windows rewrites paths like /var/run/docker.sock; stop it.
export MSYS_NO_PATHCONV=1

usage() { sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "$0"; }
log() { printf '%s\n' "lab: $*" >&2; }
die() {
  log "error: $*"
  exit 1
}
# Run from the lab directory with a relative path, which works in every shell,
# including Git Bash with path conversion off.
compose() { (cd "$LAB_DIR" && docker compose -f compose.yaml "$@"); }

random_string() { head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c "$1"; }

load_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    umask 077
    {
      printf 'GITLAB_LAB_ROOT_PASSWORD=%s\n' "Lab-$(random_string 24)"
      printf 'GITLAB_LAB_TOKEN=glpat-%s\n' "$(random_string 24)"
    } >"$ENV_FILE"
    log "generated credentials in $ENV_FILE"
  fi
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  export GITLAB_LAB_ROOT_PASSWORD GITLAB_LAB_TOKEN
}

api() {
  local method="$1" path="$2"
  shift 2
  curl -fsS -X "$method" -H "PRIVATE-TOKEN: $GITLAB_LAB_TOKEN" "$URL/api/v4$path" "$@"
}

wait_for_gitlab() {
  local deadline=$((SECONDS + 900))
  log "waiting for GitLab to answer (first start takes 3 to 5 minutes)"
  until [[ "$(curl -s -o /dev/null -w '%{http_code}' "$URL/users/sign_in")" == "200" ]]; do
    if ((SECONDS > deadline)); then
      die "GitLab didn't start in 15 minutes; see: docker compose -f $LAB_DIR/compose.yaml logs gitlab"
    fi
    sleep 10
  done
}

ensure_token() {
  if api GET /user >/dev/null 2>&1; then
    return
  fi
  log "creating the lab's admin API token (takes about a minute)"
  # The token goes in through the environment, so it isn't in the process list.
  compose exec -T -e LAB_TOKEN="$GITLAB_LAB_TOKEN" gitlab gitlab-rails runner "
    user = User.find_by_username('root')
    token = user.personal_access_tokens.create!(name: 'lab', scopes: %w[api admin_mode write_repository], expires_at: 30.days.from_now)
    token.set_token(ENV.fetch('LAB_TOKEN'))
    token.save!
  " >/dev/null
  api GET /user >/dev/null || die "the API token doesn't work"
}

# register_runner NAME DESCRIPTION RUN_UNTAGGED TAGS [extra register flags...]
# Creates an instance runner through the API (which returns its glrt- token)
# and registers it in the runner container, unless one with NAME exists.
register_runner() {
  local name="$1" description="$2" untagged="$3" tags="$4"
  shift 4
  if compose exec -T runner grep -q "name = \"$name\"" /etc/gitlab-runner/config.toml 2>/dev/null; then
    log "runner $name already registered"
    return
  fi
  log "creating and registering runner $name"
  local token
  token="$(api POST /user/runners -d runner_type=instance_type -d "description=$description" \
    -d "run_untagged=$untagged" -d "tag_list=$tags" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
  [[ "$token" == glrt-* ]] || die "didn't get a runner authentication token"
  compose exec -T runner gitlab-runner register --non-interactive \
    --url http://gitlab.local --clone-url http://gitlab.local --token "$token" \
    --name "$name" --executor docker --docker-image alpine:3.24 \
    --docker-network-mode gitlab-lab \
    --docker-volumes gitlab-lab-containers-conf:/etc/containers/registries.conf.d:ro \
    "$@" >/dev/null 2>&1
}

ensure_runners() {
  # Every untagged job: Docker's default seccomp profile, no privileges.
  register_runner lab-docker "lab docker runner" true ""
  # Jobs tagged image-build only (Buildah): seccomp relaxed so Buildah can
  # create the user namespace its RUN steps need. Still no privileged mode.
  register_runner lab-image-build "lab image build runner" false image-build \
    --docker-security-opt seccomp=unconfined
  compose exec -T runner sed -i 's/^concurrent = .*/concurrent = 4/' /etc/gitlab-runner/config.toml
}

cmd_up() {
  command -v docker >/dev/null || die "docker is required"
  load_env
  compose up -d
  wait_for_gitlab
  ensure_token
  ensure_runners
  log "ready: $URL (user root; password and API token in $ENV_FILE)"
}

cmd_status() {
  load_env
  compose ps
  if api GET /version; then
    printf '\n'
  else
    log "API not answering with the lab token"
  fi
}

cmd_down() {
  # compose.yaml requires the password variable even to tear down; any value
  # works when the credentials file is already gone.
  if [[ -f "$ENV_FILE" ]]; then
    load_env
  else
    export GITLAB_LAB_ROOT_PASSWORD=unused
  fi
  compose down -v --remove-orphans
  rm -f "$ENV_FILE"
  log "removed"
}

case "${1:-}" in
  up) cmd_up ;;
  status) cmd_status ;;
  down) cmd_down ;;
  -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
