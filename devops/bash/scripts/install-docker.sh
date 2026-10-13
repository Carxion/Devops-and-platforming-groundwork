#!/usr/bin/env bash
#
# install-docker.sh: install Docker Engine from Docker's official repositories
# on Ubuntu or RHEL-family systems, or Podman from the distribution on RHEL.
#
# Usage: install-docker.sh [-n] [--podman] [--add-user USER]
#
#   --podman         RHEL family: install Podman (the distribution's supported
#                    engine, daemonless and rootless) instead of Docker
#   --add-user USER  add USER to the docker group (root-equivalent; see below)
#   -n, --dry-run    show the commands, change nothing
#   -h, --help       this help
#
# Follows Docker's install docs (docs.docker.com/engine/install). Membership of
# the docker group lets a user run any container as root on the host: grant it
# like sudo, or use rootless mode instead.

set -Eeuo pipefail
# Resolve symlinks, so a link in /usr/local/sbin still finds lib/ next to the real file.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }

PODMAN=0
ADD_USER=""
while (($# > 0)); do
  case "$1" in
    --podman) PODMAN=1 ;;
    --add-user)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      ADD_USER="$2"
      shift
      ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" 2 ;;
  esac
  shift
done

require_root
detect_os

DOCKER_PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)

install_ubuntu() {
  [[ "$OS_ID" == ubuntu ]] || die "Debian-family support here is Ubuntu only; for Debian use download.docker.com/linux/debian"
  # Remove distribution packages that conflict with Docker's (missing ones are fine).
  local old
  for old in docker.io docker-doc docker-compose podman-docker containerd runc; do
    if pkg_installed "$old"; then run apt-get remove -y "$old"; fi
  done
  pkg_update
  pkg_install ca-certificates curl
  run install -m 0755 -d /etc/apt/keyrings
  run curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  run chmod a+r /etc/apt/keyrings/docker.asc
  # UBUNTU_CODENAME is set on Ubuntu derivatives too; VERSION_CODENAME on Ubuntu itself.
  local codename arch
  # shellcheck source=/dev/null
  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  arch="$(dpkg --print-architecture)"
  write_file /etc/apt/sources.list.d/docker.sources 0644 <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  pkg_update
  pkg_install "${DOCKER_PACKAGES[@]}"
}

install_rhel_docker() {
  # Docker publishes a repository per distribution: rhel for RHEL, centos for
  # CentOS Stream and compatible rebuilds (Rocky, AlmaLinux), fedora for Fedora.
  local repo
  case "$OS_ID" in
    rhel) repo=rhel ;;
    fedora) repo=fedora ;;
    *) repo=centos ;;
  esac
  # Podman, Buildah, and runc from the distribution conflict with Docker's packages.
  run dnf remove -y -q podman buildah runc docker docker-client docker-common docker-engine || true
  pkg_install dnf-plugins-core
  local repo_url="https://download.docker.com/linux/${repo}/docker-ce.repo"
  if dnf --version 2>/dev/null | head -1 | grep -q '^dnf5'; then
    # dnf5 (Fedora 41 and later) changed the config-manager syntax.
    run dnf config-manager addrepo --from-repofile="$repo_url"
  else
    run dnf config-manager --add-repo "$repo_url"
  fi
  pkg_install "${DOCKER_PACKAGES[@]}"
}

install_rhel_podman() {
  # podman-docker provides a "docker" command that runs podman, for scripts
  # and habits that expect it.
  pkg_install podman podman-docker buildah skopeo
  if [[ "$DRY_RUN" != 1 ]]; then run podman --version; fi
  log_info "Podman installed. Rootless by default: run containers as your own user, no daemon, no group."
}

if ((PODMAN)); then
  [[ "$OS_FAMILY" == rhel ]] || die "--podman is for RHEL-family systems; on Ubuntu use: apt-get install podman"
  install_rhel_podman
  exit 0
fi

case "$OS_FAMILY" in
  debian) install_ubuntu ;;
  rhel) install_rhel_docker ;;
esac

if has_systemd; then
  run systemctl enable --now docker
  if [[ "$DRY_RUN" != 1 ]]; then run docker run --rm hello-world >/dev/null && log_info "docker run hello-world succeeded"; fi
else
  log_warn "No systemd; not starting the docker service here."
fi

if [[ -n "$ADD_USER" ]]; then
  log_warn "Adding $ADD_USER to the docker group: that is root-equivalent access to this host."
  run usermod -aG docker "$ADD_USER"
  log_info "$ADD_USER must log out and back in for the group to apply."
fi
