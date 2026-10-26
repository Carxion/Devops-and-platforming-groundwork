# 1. Ansible basics

[← Ansible](README.md)

Ansible configures servers by connecting to them over SSH and running small programs (modules) that each make one thing true: a package is installed, a file has this content, a service is running. There's no agent on the servers and no central server required: a laptop or a CI job with SSH access is enough.

The key idea is that tasks describe a **state**, not a sequence of commands. "Make sure nginx is installed" does nothing on a server where it already is. That's what makes a playbook safe to run again and again (idempotent), which is the difference between configuration management and a script you hope you only run once.

## Install

Ansible runs on a **control node** (your machine or a CI runner) and needs only SSH and Python on the **managed nodes** (the servers).

```sh
# Recommended: a virtual environment with pinned versions, the same everywhere
cd devops/ansible
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt                    # ansible-core, ansible-lint, molecule, yamllint
ansible-galaxy collection install -r requirements.yml

# Or from the distribution (simpler, older versions)
sudo dnf install -y ansible-core                   # RHEL 9 AppStream
sudo apt-get install -y ansible                    # Ubuntu (ansible-core plus a bundle of collections)

ansible --version                                  # versions, config file in use, Python used
```

`ansible-core` is the engine plus the `ansible.builtin` modules. Everything else (firewalls, cloud providers, databases) comes in **collections**, installed with `ansible-galaxy` from a `requirements.yml` file. The `ansible` package on PyPI is ansible-core plus a large set of community collections; pinning collections yourself, as this folder does, keeps runs reproducible.

On the managed nodes, RHEL 9 and Ubuntu 22.04 and later already have Python 3. The account Ansible logs in as needs SSH key access and sudo.

## Inventory: which servers

The inventory lists hosts and groups them. [inventory/example.yml](inventory/example.yml):

```yaml
all:
  children:
    web:
      hosts:
        web-01:
          ansible_host: 203.0.113.10
        web-02:
          ansible_host: 203.0.113.11
    workers:
      hosts:
        worker-01:
          ansible_host: 203.0.113.20
    production:
      children:
        web:
        workers:
  vars:
    ansible_user: deploy
```

A host can be in several groups (`web-01` is in `web` and `production`), so you can target by role or by environment. Variables for a group go in `inventory/group_vars/<group>.yml` and for a host in `inventory/host_vars/<host>.yml`, next to the inventory file.

```sh
ansible-inventory --graph                  # the group tree
ansible-inventory --host web-01            # every variable web-01 ends up with, after merging
ansible web --list-hosts                   # which hosts a pattern matches
```

Host patterns: `all`, a group (`web`), a host, `web:workers` (either), `production:&web` (both), `production:!web` (production but not web), `web-0*` (wildcard).

For cloud fleets, generate the inventory from the provider's API instead of listing hosts: see [dynamic inventory](05-operations.md#dynamic-inventory-from-aws-and-azure).

## Ad hoc commands

One module, many hosts, no playbook. Good for checking things and one-off fixes.

```sh
ansible all -m ansible.builtin.ping
ansible web -m ansible.builtin.command -a 'uptime'
ansible web -b -m ansible.builtin.dnf -a 'name=nginx state=latest' --check --diff
ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

| Part | Meaning |
|---|---|
| `all`, `web` | The host pattern |
| `-m ansible.builtin.ping` | The module: not ICMP ping, but "can Ansible log in and run Python?" It returns `pong` |
| `-a 'uptime'` | The module's arguments. `command` runs a program (no shell features); `shell` runs through `/bin/sh` |
| `-b` | Become root (sudo). Add `-K` to be asked for the sudo password |
| `--check --diff` | Dry run: report what would change, and show file differences, without changing anything |
| `setup -a 'filter=...'` | Gather **facts** (OS, IPs, memory, disks) and show the ones matching the filter |

More in [Operations](05-operations.md#everyday-ad-hoc-commands).

## Modules, not shell commands

Prefer a module to `command` or `shell` whenever one exists:

```yaml
# Not idempotent: runs every time, always reports "changed", and fails if the user exists
- name: Create the deploy user
  ansible.builtin.command: useradd -m deploy

# Idempotent: checks first, changes only what differs, reports accurately
- name: Create the deploy user
  ansible.builtin.user:
    name: deploy
    create_home: true
```

Modules check the current state, change only what's different, report `changed` honestly, and support `--check`. When you must use `command` or `shell`, tell Ansible when it changed something (`changed_when`) and when it shouldn't run (`creates`, `removes`, or `when`). ansible-lint flags commands that have a module equivalent.

Use fully qualified module names (`ansible.builtin.copy`, not `copy`) so it's unambiguous which collection a module comes from. `ansible-doc` shows any module's documentation offline:

```sh
ansible-doc ansible.builtin.user          # every option, with examples at the end
ansible-doc -l community.general | grep ufw
```

## Configuration: ansible.cfg

Ansible reads the first `ansible.cfg` it finds: the file named by `$ANSIBLE_CONFIG`, then `./ansible.cfg`, then `~/.ansible.cfg`, then `/etc/ansible/ansible.cfg`. This folder's [ansible.cfg](ansible.cfg) sets the inventory, the roles path, more parallel hosts (forks), and SSH pipelining. Ansible ignores `./ansible.cfg` in a world-writable directory, as a security measure (a shared `/tmp`, or a Windows folder mounted into a container); set `ANSIBLE_CONFIG` explicitly there.

```sh
ansible-config dump --only-changed        # what's set, and where from
```

## Next

[Playbooks and roles](02-playbooks-and-roles.md): the baseline in this folder, piece by piece.
