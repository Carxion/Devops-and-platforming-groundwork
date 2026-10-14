# 2. Playbooks and roles

[← Ansible](README.md)

A **playbook** maps groups of hosts to the work they need. A **role** packages that work (tasks, defaults, templates, handlers) so it can be reused and tested on its own. This guide walks through the server baseline in this folder, which does what [bootstrap-server.sh](../bash/scripts/bootstrap-server.sh) does, as five roles.

## The playbook

[site.yml](site.yml):

```yaml
- name: Apply the server baseline
  hosts: all
  become: true
  serial: "{{ baseline_serial | default('25%') }}"
  max_fail_percentage: 0
  roles:
    - role: base
      tags: [base]
    - role: admin_users
      tags: [users]
    - role: ssh_hardening
      tags: [ssh]
    - role: firewall
      tags: [firewall]
    - role: auto_updates
      tags: [updates]
```

| Part | Meaning |
|---|---|
| `hosts: all` | Which inventory hosts this play targets (any [pattern](01-basics.md#inventory-which-servers)) |
| `become: true` | Run tasks as root through sudo |
| `serial: 25%` | Roll through the fleet a quarter at a time: all roles finish on the first batch before the next starts |
| `max_fail_percentage: 0` | Stop the whole run if any host in a batch fails, so a bad change reaches at most one batch |
| `roles:` | Run each role's tasks in order. `tags` let you run some: `--tags ssh,firewall` |

Run it:

```sh
ansible-playbook site.yml --check --diff        # preview: what would change, with file diffs
ansible-playbook site.yml --limit web-01        # one host first
ansible-playbook site.yml                       # everyone, a batch at a time
ansible-playbook site.yml --tags ssh --limit web    # only the SSH role, only web servers
ansible-playbook site.yml --list-tasks          # what would run, in order
```

The summary at the end (`PLAY RECAP`) counts, per host, how many tasks were `ok` (already right), `changed`, `failed`, and `skipped`. On a second run, `changed=0` is what idempotent looks like.

## Anatomy of a role

```text
roles/ssh_hardening/
├── defaults/main.yml      # variables users are meant to override (lowest precedence)
├── vars/main.yml          # internal constants (high precedence; not for overriding)
├── tasks/main.yml         # what the role does, in order
├── handlers/main.yml      # tasks that run only when notified, at the end of the play
├── templates/*.j2         # Jinja2 templates for files
└── meta/main.yml          # description, supported platforms, dependencies
```

| Role | What it does | Bash equivalent |
|---|---|---|
| [base](roles/base/tasks/main.yml) | Upgrades packages, installs base tools (names per family), sets hostname and time zone, starts chrony | `bootstrap-server.sh` packages and time steps |
| [admin_users](roles/admin_users/tasks/main.yml) | Validates each account, creates it in `wheel` or `sudo`, sets exactly the listed SSH keys, manages passwordless sudo with `visudo` validation | [create-admin-user.sh](../bash/scripts/create-admin-user.sh) |
| [ssh_hardening](roles/ssh_hardening/tasks/main.yml) | Refuses if nobody has a key, writes the hardening drop-in, validates with `sshd -t`, rolls back if rejected, reloads sshd | [harden-ssh.sh](../bash/scripts/harden-ssh.sh) |
| [firewall](roles/firewall/tasks/main.yml) | firewalld on RHEL, ufw on Ubuntu, SSH always allowed first | [configure-firewall.sh](../bash/scripts/configure-firewall.sh) |
| [auto_updates](roles/auto_updates/tasks/main.yml) | dnf-automatic or unattended-upgrades, security updates only by default | [enable-auto-updates.sh](../bash/scripts/enable-auto-updates.sh) |

Every role's variables start with the role's name (`ssh_hardening_port`, not `port`), so roles can't collide. ansible-lint's production profile enforces this.

## Variables

Set them in the inventory and let roles' defaults fill in the rest:

```yaml
# inventory/group_vars/all.yml
admin_users_accounts:
  - name: deploy
    ssh_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... deploy@laptop

# inventory/group_vars/web.yml
firewall_allow:
  - 443/tcp
```

When the same variable is set in several places, the more specific one wins. Ansible has 22 levels of precedence; these are the ones you'll use, lowest first:

| Where | Use it for |
|---|---|
| Role `defaults/main.yml` | The role's documented, overridable settings |
| `group_vars/all.yml` | Settings for every host |
| `group_vars/<group>.yml` | Settings for a group (a child group beats its parent) |
| `host_vars/<host>.yml` | One host's exceptions |
| Play `vars:` | Settings for one playbook |
| Role `vars/main.yml` | Constants the role relies on |
| Registered results and `set_fact` | Values computed during the run |
| `-e` / `--extra-vars` on the command line | One-off overrides; always win |

`ansible-inventory --host web-01` shows the merged result for a host. If you need more than these levels, the design is usually too clever.

## Facts and conditions

Before the tasks run, Ansible gathers **facts** about each host: OS family and version, IP addresses, memory, the service manager, and more. Roles use them to do the right thing on each distribution:

```yaml
- name: Start and enable time sync
  ansible.builtin.systemd_service:
    # The chrony unit is chronyd on RHEL and chrony on Ubuntu.
    name: "{{ 'chronyd' if ansible_facts['os_family'] == 'RedHat' else 'chrony' }}"
    state: started
    enabled: true
  when: base_manage_services
```

`ansible_facts['os_family']` is `RedHat` for RHEL, Rocky, and Alma, and `Debian` for Ubuntu. `when:` takes a list, and all items must be true. Bigger differences go in separate task files, included per family, as the [firewall role](roles/firewall/tasks/main.yml) does with `firewalld.yml` and `ufw.yml`.

## Loops, filters, and templates

```yaml
- name: Authorize their SSH keys
  ansible.posix.authorized_key:
    user: "{{ item.name }}"
    key: "{{ item.ssh_keys | join('\n') }}"
    exclusive: true
  loop: "{{ admin_users_accounts }}"
  loop_control:
    label: "{{ item.name }}"
```

`loop` runs the task once per list item, as `item`. `label` keeps the output to the name (without it, Ansible prints every key). `exclusive: true` makes the key list declarative: a key removed from the inventory is removed from the server, which is what you want when someone leaves.

Filters (`| join`, `| default`, `| selectattr`) transform values in `{{ }}`. Templates use the same Jinja2 syntax for whole files. The SSH drop-in, [hardening.conf.j2](roles/ssh_hardening/templates/hardening.conf.j2):

```jinja
{{ ansible_managed | comment }}
{% if ssh_hardening_port | int != 22 %}
Port {{ ssh_hardening_port }}
{% endif %}
PermitRootLogin no
PasswordAuthentication no
{% if ssh_hardening_allow_groups %}
AllowGroups {{ ssh_hardening_allow_groups | join(' ') }}
{% endif %}
```

`ansible_managed | comment` writes a header saying the file is managed by Ansible, so nobody edits it by hand and loses the change at the next run.

## Validate, then apply, and roll back on failure

Changing a critical file safely takes three ideas, all in the SSH role:

```yaml
- name: Apply the SSH configuration, rolling back if sshd rejects it
  block:
    - name: Write the hardening drop-in
      ansible.builtin.template:
        src: hardening.conf.j2
        dest: "{{ ssh_hardening_dropin }}"
        mode: "0600"
      notify: Reload sshd
    - name: Validate the full sshd configuration
      ansible.builtin.command: /usr/sbin/sshd -t
      changed_when: false
  rescue:
    - name: Remove the drop-in sshd rejected
      ansible.builtin.file:
        path: "{{ ssh_hardening_dropin }}"
        state: absent
    - name: Stop, without reloading sshd
      ansible.builtin.fail:
        msg: "sshd -t rejected the configuration ..."
```

| Part | Meaning |
|---|---|
| `block` / `rescue` | Like try/except: if any task in `block` fails, the `rescue` tasks run |
| `notify: Reload sshd` | Queue a handler. It runs once at the end of the play, only if this task changed something, and not at all if the host failed |
| `changed_when: false` | A check never changes anything; say so, or every run reports a change |

For single files, the `validate:` option is simpler: the [admin_users role](roles/admin_users/tasks/main.yml) writes sudoers files with `validate: visudo -cf %s`, so a broken file is never installed. The SSH role validates the whole configuration instead, because a drop-in that's valid alone can still break the combination.

Equally important is refusing to start: the SSH role first checks that some account has an authorized key, and fails before changing anything if not, because turning off password login would lock everyone out.

## Import, include, and collections

- `import_tasks` and `import_playbook` are **static**: resolved before the run starts, so tags and `--list-tasks` see inside them.
- `include_tasks` and `include_role` are **dynamic**: decided while running, so they can depend on facts and loops (the firewall role includes `firewalld.yml` or `ufw.yml` based on the OS family).

Modules beyond `ansible.builtin` come from collections, pinned in [requirements.yml](requirements.yml): `ansible.posix` (authorized_key, firewalld) and `community.general` (ufw, timezone, seport). Pin exact versions; a collection upgrade is a change to review like any other.

## Next

[Secrets and Ansible Vault](03-secrets-and-vault.md).
