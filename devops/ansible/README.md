# Ansible

[← DevOps](../README.md)

Scripts work for a handful of servers. Past that, you need a tool that brings every server to the same declared state, can be run again safely, shows what it will change before it changes it, and is tested like code. This folder teaches Ansible from the first ad hoc command to tested roles you can run from CI, and rebuilds the [Bash server baseline](../bash/scripts/bootstrap-server.sh) as five roles for **RHEL** (and Rocky Linux and AlmaLinux) and **Ubuntu**.

> **Status.** CI runs yamllint and ansible-lint's strictest (production) profile on every change. Locally, [Molecule](molecule/default/) applies the baseline to Ubuntu 22.04 and 24.04, Rocky Linux 9, and AlmaLinux 9 containers, applies it a second time and fails on any change (idempotence), then verifies the result and the safety features. Containers don't run systemd, so starting and enabling services is exercised only on real hosts.

## Learning path

| # | Guide | You'll be able to |
|---|---|---|
| 1 | [Basics](01-basics.md) | Install Ansible, write an inventory, run ad hoc commands, and understand modules, idempotency, check mode, and ansible.cfg |
| 2 | [Playbooks and roles](02-playbooks-and-roles.md) | Read and write playbooks and roles: variables and precedence, facts and conditions per distribution, loops, templates, handlers, validation and rollback |
| 3 | [Secrets and Vault](03-secrets-and-vault.md) | Encrypt secrets with Ansible Vault, fetch them from AWS, Azure, or HashiCorp Vault instead, and keep them out of logs |
| 4 | [Testing and CI](04-testing-and-ci.md) | Lint, dry-run, and test roles with Molecule; run playbooks from GitHub Actions, GitLab CI, and Jenkins with safe credentials |
| 5 | [Operations](05-operations.md) | Ad hoc fleet commands, rolling changes with canaries, reboots after updates, dynamic inventory from AWS and Azure, and troubleshooting |

New to Ansible? Read 1 and 2 with this folder open. Already using it? 4 and 5 are the ones to compare against your current practice.

## The baseline

```sh
cd devops/ansible
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml

# Edit inventory/example.yml and inventory/group_vars/ for your hosts and keys, then:
ansible all -m ansible.builtin.ping
ansible-playbook site.yml --check --diff --limit web-01   # preview one host
ansible-playbook site.yml --limit web-01                  # apply to it, then test a NEW SSH login
ansible-playbook site.yml                                 # the rest, a quarter at a time
```

| Role | What it does |
|---|---|
| [base](roles/base/) | Upgrades packages, installs base tools (with the right names on each family), sets hostname and time zone, starts chrony |
| [admin_users](roles/admin_users/) | Administrator accounts in `wheel` (RHEL) or `sudo` (Ubuntu), exactly the listed SSH keys, passwordless sudo only for automation accounts, validated with `visudo` |
| [ssh_hardening](roles/ssh_hardening/) | Key-only SSH, no root login, and more as a drop-in; refuses if nobody has a key; validates the full configuration with `sshd -t` and rolls back if rejected; handles Ubuntu's socket-activated sshd |
| [firewall](roles/firewall/) | Default-deny inbound with firewalld (RHEL) or ufw (Ubuntu), SSH allowed first |
| [auto_updates](roles/auto_updates/) | Automatic security updates with dnf-automatic (RHEL) or unattended-upgrades (Ubuntu) |

Each role's settings are in its `defaults/main.yml`, with comments. [playbooks/reboot-if-needed.yml](playbooks/reboot-if-needed.yml) reboots, one at a time, the hosts whose updates need it.

The same baseline exists as [Bash scripts](../bash/README.md#scripts). Use the scripts for a single server or a first boot (cloud-init); use the roles for a fleet, where you need repeatable runs, previews, and tests.

## Running the checks

```sh
cd devops/ansible
yamllint .
ansible-playbook site.yml --syntax-check
ansible-lint
molecule test          # needs Docker; takes several minutes
```

CI runs the linters and syntax checks ([lint.yml](../../.github/workflows/lint.yml)). Run Molecule locally before changing a role: it needs Docker and takes 10 to 15 minutes.

## Related

- The [tech lead checklist](../../tech-lead/README.md) asks whether configuration management runs are idempotent and repeatable: Molecule's idempotence step is how to show it.
- [Git 101](../../software/git/README.md) for the repository the playbooks live in, and [secrets recovery](../../software/git/04-recovery.md#a-secret-was-committed) if a vault password or key is ever committed.
- The [glossary](../../GLOSSARY.md#infrastructure-as-code) defines configuration management, idempotency, and drift.
