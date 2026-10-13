# Bash 101

The shell is where most operations work happens: reading logs, checking services, fixing a config at 2 a.m., and automating anything done twice. This folder teaches Bash and the core Linux tools from the first command to complex pipelines, with every complex command broken down piece by piece, and a focus on the two server families you'll meet most: **Red Hat Enterprise Linux** (and its rebuilds, Rocky Linux and AlmaLinux) and **Ubuntu**.

It ends with a [library of scripts](scripts/) for setting up and running servers, each tested on real Ubuntu, Rocky Linux, and UBI (RHEL) systems in CI.

> **Status.** Every script passes ShellCheck and shfmt, the [unit tests](tests/scripts.bats) and [regex tests](tests/regex.bats) run with Bats, and the [integration test](tests/integration.sh) applies the full server baseline for real inside Ubuntu 24.04, Rocky Linux 9, and a dry run on UBI 9, twice, to prove it's idempotent. Containers have no systemd, so starting and enabling services is the one part exercised only on real hosts.

## Learning path

| # | Guide | You'll be able to |
|---|---|---|
| 1 | [Basics](01-basics.md) | Move around, read and edit files, understand permissions, redirect and pipe output, use variables and quoting correctly |
| 2 | [Text processing](02-text-processing.md) | Search, filter, cut, sort, count, and transform text with grep, sed, awk, cut, sort, uniq, xargs, find, and jq |
| 3 | [Regular expressions](03-regex.md) | Read and write regex in all three Linux flavors, with a tested library of patterns for IPs, dates, versions, hostnames, and more |
| 4 | [Writing scripts](04-scripting.md) | Write scripts that fail safely: strict mode, functions, arguments, logging, cleanup, locking, testing, and scheduling with systemd timers or cron |
| 5 | [RHEL and Ubuntu](05-rhel-and-ubuntu.md) | Do the same job on both families: packages, repositories, services, firewalls, SELinux and AppArmor, users, networking, logs, updates |
| 6 | [Administration and troubleshooting](06-administration.md) | Find out what's wrong with a slow, full, or unreachable server, step by step |
| 7 | [Complex commands, broken down](07-complex-commands.md) | Read and build long one-liners, with each part explained |

New to the shell? Read 1 to 3 in order, with a terminal open. Already comfortable? Start at 4, and keep 5 and 7 open as references.

To practice without a server, start a container of either family:

```sh
docker run --rm -it ubuntu:24.04 bash
docker run --rm -it rockylinux/rockylinux:9 bash        # RHEL-compatible
docker run --rm -it registry.access.redhat.com/ubi9/ubi bash   # Red Hat's freely redistributable RHEL base
```

## Scripts

Ready to use, and written to be read: each shows the practices from [Writing scripts](04-scripting.md). Every script supports `--help`, and every one that changes the system supports `--dry-run`.

| Script | What it does |
|---|---|
| [bootstrap-server.sh](scripts/bootstrap-server.sh) | Takes a fresh server to a baseline: updates, base tools, time sync, an admin user, SSH hardening, a firewall, automatic security updates, and optionally Docker or Podman |
| [create-admin-user.sh](scripts/create-admin-user.sh) | Creates an administrator with SSH key login and sudo (`wheel` on RHEL, `sudo` on Ubuntu), validating the key and the sudoers file |
| [harden-ssh.sh](scripts/harden-ssh.sh) | Key-only SSH, no root login, and other hardening as a drop-in file; refuses if nobody has a key; validates with `sshd -t` and rolls back on error |
| [configure-firewall.sh](scripts/configure-firewall.sh) | Default-deny inbound with firewalld (RHEL) or ufw (Ubuntu), always allowing SSH first |
| [enable-auto-updates.sh](scripts/enable-auto-updates.sh) | Automatic security updates with dnf-automatic (RHEL) or unattended-upgrades (Ubuntu) |
| [install-docker.sh](scripts/install-docker.sh) | Docker Engine from Docker's repositories, or Podman on RHEL |
| [system-report.sh](scripts/system-report.sh) | Read-only health snapshot: load, memory, full disks, top processes, failed units, ports, recent errors, pending updates |
| [log-summary.sh](scripts/log-summary.sh) | Summarizes SSH logins or web access logs: failures by IP and user, status codes, top routes, 5xx requests |
| [backup-rotate.sh](scripts/backup-rotate.sh) | Timestamped, verified `.tar.gz` backups of a directory, keeping the newest N |
| [retry.sh](scripts/retry.sh) | Runs a command until it succeeds, with exponential backoff and jitter |
| [wait-for-port.sh](scripts/wait-for-port.sh) | Waits for a TCP port to open, then optionally runs a command |
| [template.sh](scripts/template.sh) | The starting point for a new script, with every convention in place |
| [lib/common.sh](scripts/lib/common.sh) | Shared functions: logging, dry-run aware `run`, OS detection, package helpers, atomic file writes |

### Setting up a new server with them

Copy the folder to the server, preview, then apply. Keep your current session open until a new login works.

```sh
# From your machine: copy the scripts and your public key
scp -r devops/bash/scripts admin@203.0.113.10:/tmp/scripts
scp ~/.ssh/id_ed25519.pub admin@203.0.113.10:/tmp/deploy.pub

# On the server: see every change first, then apply
ssh admin@203.0.113.10
sudo bash /tmp/scripts/bootstrap-server.sh --dry-run --hostname web-01 \
  --admin-user deploy --ssh-key-file /tmp/deploy.pub --allow 443/tcp
sudo bash /tmp/scripts/bootstrap-server.sh --hostname web-01 \
  --admin-user deploy --ssh-key-file /tmp/deploy.pub --allow 443/tcp

# In a NEW terminal, before closing the old one
ssh deploy@203.0.113.10 'sudo -v && echo sudo works'
```

For a fleet, use these as a reference for configuration management (Ansible, cloud-init, or image builds with Packer) rather than running scripts by hand on each host. A cloud-init `runcmd` can call the same script at first boot.

### Running the tests

```sh
# Lint (ShellCheck and shfmt, as CI runs them)
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:v0.11.0 -x -P SCRIPTDIR devops/bash/scripts/*.sh devops/bash/scripts/lib/*.sh
docker run --rm -v "$PWD:/mnt" -w /mnt mvdan/shfmt:v3.14.1 -d -i 2 -ci devops/bash/scripts

# Unit and regex tests (Bats), as a normal user in Ubuntu
docker run --rm -v "$PWD/devops/bash:/work:ro" ubuntu:24.04 bash -c \
  "apt-get update -qq && apt-get install -y -qq bats netcat-openbsd >/dev/null && useradd -m t && su t -c 'bats /work/tests'"

# Integration: the full baseline, for real, in throwaway containers
docker run --rm -v "$PWD/devops/bash:/work:ro" ubuntu:24.04 bash /work/tests/integration.sh
docker run --rm -v "$PWD/devops/bash:/work:ro" rockylinux/rockylinux:9 bash /work/tests/integration.sh
```

The [bash workflow](../../.github/workflows/bash.yml) runs all of these on every change.
