#!/usr/bin/env bash
# The bash -c check bodies are single-quoted on purpose: they expand in the child shell.
# shellcheck disable=SC2016
#
# Integration test for devops/bash/scripts: runs the real scripts as root inside a
# throwaway Ubuntu or RHEL-family container, then checks the results.
#
#   docker run --rm -v "$PWD/devops/bash:/work:ro" ubuntu:24.04 bash /work/tests/integration.sh
#   docker run --rm -v "$PWD/devops/bash:/work:ro" rockylinux/rockylinux:9 bash /work/tests/integration.sh
#
# Never run this on a real machine: it creates users and rewrites SSH config.
# Containers have no systemd, so service steps are skipped by the scripts
# themselves; everything else is applied for real.

set -Euo pipefail # no -e: run every check and report all failures
S=/work/scripts
FAILURES=0

[[ -f /.dockerenv || -n "${container:-}" ]] || {
  echo "Refusing to run outside a container." >&2
  exit 1
}

pass() { printf 'PASS  %s\n' "$*"; }
fail() {
  printf 'FAIL  %s\n' "$*"
  FAILURES=$((FAILURES + 1))
}
check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi
}

# shellcheck source=/dev/null
. /etc/os-release
echo "== ${PRETTY_NAME}"

# sshd and ssh-keygen, which a real server has and a container image doesn't.
if command -v apt-get >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq openssh-server >/dev/null
  ADMIN_GROUP=sudo
else
  dnf install -y -q openssh-server openssh-clients >/dev/null
  ADMIN_GROUP=wheel
fi
mkdir -p /run/sshd
ssh-keygen -A >/dev/null # host keys, so sshd -t can validate

ssh-keygen -q -t ed25519 -N '' -C test@example -f /tmp/deploy
run_bootstrap() {
  bash "$S/bootstrap-server.sh" --yes --admin-user deploy --ssh-key-file /tmp/deploy.pub \
    --allow 443/tcp --allow 8000-8100/tcp
}

echo "== First run"
if run_bootstrap >/tmp/run1.log 2>&1; then pass "bootstrap completes"; else
  fail "bootstrap completes"
  tail -30 /tmp/run1.log
fi

echo "== Second run (idempotency)"
if run_bootstrap >/tmp/run2.log 2>&1; then pass "bootstrap is idempotent"; else
  fail "bootstrap is idempotent"
  tail -30 /tmp/run2.log
fi

echo "== Results"
check "base packages installed (jq, git, chrony)" command -v jq git chronyd
check "deploy user exists" id deploy
check "deploy is in ${ADMIN_GROUP}" bash -c "id -nG deploy | grep -qw ${ADMIN_GROUP}"
check "authorized_keys has mode 600" bash -c '[[ $(stat -c %a ~deploy/.ssh/authorized_keys) == 600 ]]'
check ".ssh has mode 700 and is owned by deploy" bash -c '[[ $(stat -c "%a %U" ~deploy/.ssh) == "700 deploy" ]]'
check "authorized_keys holds the key" cmp /tmp/deploy.pub /home/deploy/.ssh/authorized_keys
check "sshd config is valid" /usr/sbin/sshd -t
check "sshd: password authentication off" bash -c '/usr/sbin/sshd -T | grep -qx "passwordauthentication no"'
check "sshd: root login off" bash -c '/usr/sbin/sshd -T | grep -qx "permitrootlogin no"'
check "sshd: hardening file mode 600" bash -c '[[ $(stat -c %a /etc/ssh/sshd_config.d/10-hardening.conf) == 600 ]]'

if [[ "$ADMIN_GROUP" == sudo ]]; then
  check "ufw rule for ssh saved" bash -c 'ufw show added | grep -q "22/tcp"'
  check "ufw rule for 443 saved" bash -c 'ufw show added | grep -q "443/tcp"'
  check "ufw range written as 8000:8100" bash -c 'ufw show added | grep -q "8000:8100/tcp"'
  check "unattended-upgrades enabled" grep -q 'Unattended-Upgrade "1"' /etc/apt/apt.conf.d/20auto-upgrades
else
  check "firewalld installed" rpm -q firewalld
  check "dnf-automatic applies updates" grep -qx 'apply_updates = yes' /etc/dnf/automatic.conf
  check "dnf-automatic security only" grep -qx 'upgrade_type = security' /etc/dnf/automatic.conf
fi

echo "== Safety checks"
# harden-ssh must refuse when nobody has a key, so it can't lock everyone out.
if [[ -f /home/deploy/.ssh/authorized_keys ]]; then
  mv /home/deploy/.ssh/authorized_keys /tmp/ak
  if bash "$S/harden-ssh.sh" >/dev/null 2>&1; then fail "harden-ssh refuses without any authorized key"; else pass "harden-ssh refuses without any authorized key"; fi
  mv /tmp/ak /home/deploy/.ssh/authorized_keys
else
  fail "harden-ssh refuses without any authorized key (no deploy key to move)"
fi
# A broken setting must be rolled back, not left for the next restart.
cp /etc/ssh/sshd_config /tmp/sshd_config.orig
echo "NotARealOption yes" >>/etc/ssh/sshd_config
if bash "$S/harden-ssh.sh" >/dev/null 2>&1; then fail "harden-ssh fails on invalid config"; else pass "harden-ssh fails on invalid config"; fi
check "harden-ssh rolled back its drop-in" bash -c '[[ ! -e /etc/ssh/sshd_config.d/10-hardening.conf ]]'
cp /tmp/sshd_config.orig /etc/ssh/sshd_config
check "create-admin-user rejects a private key" bash -c "! bash $S/create-admin-user.sh eve --ssh-key-file /tmp/deploy"
check "create-admin-user rejects a bad user name" bash -c "! bash $S/create-admin-user.sh 'Bad Name' --ssh-key-file /tmp/deploy.pub"
check "--nopasswd sudoers file validates" bash -c "bash $S/create-admin-user.sh robot --ssh-key-file /tmp/deploy.pub --nopasswd && visudo -cf /etc/sudoers.d/90-robot"

echo "== Read-only scripts"
check "system-report runs" bash "$S/system-report.sh"
check "log-summary ssh on fixtures" bash "$S/log-summary.sh" ssh /work/tests/fixtures/secure.log
check "log-summary access on fixtures" bash "$S/log-summary.sh" access /work/tests/fixtures/access.log

echo
if ((FAILURES)); then
  echo "${FAILURES} check(s) failed"
  exit 1
fi
echo "All checks passed"
