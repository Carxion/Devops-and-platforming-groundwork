# 5. Operations

[← Ansible](README.md)

Ansible for day-to-day work on a fleet: quick questions answered across every host, changes rolled out safely, reboots, inventories that follow the cloud, and what to do when a run goes wrong.

## Everyday ad hoc commands

```sh
ansible all -m ansible.builtin.command -a 'uptime' -o
ansible all -m ansible.builtin.shell -a 'df -h / | tail -1' -o
ansible web -b -m ansible.builtin.systemd_service -a 'name=nginx state=restarted' --forks 2
ansible all -m ansible.builtin.command -a 'openssl version' -o | awk -F'[|]' '{ print $4 }' | sort | uniq -c
ansible all -b -m ansible.builtin.dnf -a 'name=openssl state=latest' --limit 'production:&web' --check
```

| Part | Meaning |
|---|---|
| `-o` | One line per host, so the output greps and sorts well |
| `shell -a 'df -h / \| tail -1'` | `shell` is needed for pipes and redirection; `command` doesn't use a shell |
| `systemd_service ... state=restarted --forks 2` | Restart nginx on two hosts at a time, not all at once |
| `command -a 'openssl version' -o \| awk ... \| uniq -c` | Each host's OpenSSL version, counted: how many hosts are still on the old one |
| `--limit 'production:&web'` | Only hosts in both groups |
| `--check` | Show what would change; drop it to apply |

Ad hoc changes aren't recorded anywhere and drift from the playbooks. Use them for questions and emergencies; make lasting changes in a playbook.

## Rolling changes safely

For changes that restart services, work through the fleet in batches and stop at the first sign of trouble:

```yaml
- name: Upgrade the application, a few hosts at a time
  hosts: web
  become: true
  serial: [1, "25%", "100%"]      # one canary, then a quarter, then the rest
  max_fail_percentage: 0
  tasks:
    - name: Take the host out of the load balancer
      ansible.builtin.uri:
        url: "https://lb.example.com/api/pools/web/members/{{ inventory_hostname }}/drain"
        method: POST
      delegate_to: localhost

    - name: Install the new version
      ansible.builtin.dnf:
        name: "example-app-{{ app_version }}"
        state: present
      notify: Restart the application

    - name: Restart now, not at the end of the play
      ansible.builtin.meta: flush_handlers

    - name: Wait until it answers health checks
      ansible.builtin.uri:
        url: "http://{{ ansible_host }}:8080/healthz"
      register: health
      until: health.status == 200
      retries: 20
      delay: 5
      delegate_to: localhost

    - name: Put it back in the load balancer
      ansible.builtin.uri:
        url: "https://lb.example.com/api/pools/web/members/{{ inventory_hostname }}/enable"
        method: POST
      delegate_to: localhost

  handlers:
    - name: Restart the application
      ansible.builtin.systemd_service:
        name: example-app
        state: restarted
```

| Part | Meaning |
|---|---|
| `serial: [1, "25%", "100%"]` | Batch sizes in order: a single canary host first, then 25%, then everything left |
| `max_fail_percentage: 0` | Any failure stops the rollout before the next batch |
| `delegate_to: localhost` | Run this task on the control node (calling the load balancer's API) on behalf of each host |
| `meta: flush_handlers` | Run notified handlers now, so the restart happens before the health check rather than at the end |
| `until` / `retries` / `delay` | Poll: up to 20 tries, 5 seconds apart |

Other tools for rollouts: `run_once: true` (do something once per batch, like a database migration), `throttle: 1` (limit one task's concurrency without changing the batch), and `any_errors_fatal: true` (stop everything at the first failure on any host).

## Reboots after updates

[auto_updates](roles/auto_updates/tasks/main.yml) installs security updates, but kernel and glibc updates only take effect after a reboot, which neither dnf-automatic nor unattended-upgrades does by default. [playbooks/reboot-if-needed.yml](playbooks/reboot-if-needed.yml) checks each host (`needs-restarting -r` on RHEL, `/var/run/reboot-required` on Ubuntu) and reboots only those that need it, one at a time, waiting for each to come back:

```sh
ansible-playbook playbooks/reboot-if-needed.yml --check       # who needs a reboot (reports only)
ansible-playbook playbooks/reboot-if-needed.yml --limit web -e reboot_if_needed_health_url=http://localhost:8080/healthz
```

Schedule it in a maintenance window, from CI or AWX.

## Dynamic inventory from AWS and Azure

Instead of a host list that goes stale, generate the inventory from the cloud's API each run. Inventory plugins read a YAML file whose name must end as shown:

```yaml
# inventory/aws_ec2.yml (amazon.aws collection; uses your AWS credentials)
plugin: amazon.aws.aws_ec2
regions: [eu-west-1]
filters:
  instance-state-name: running
  tag:ManagedBy: ansible
keyed_groups:
  - key: tags.Role                # a group per Role tag: role_web, role_worker
    prefix: role
  - key: tags.Environment
    prefix: env
hostnames: [private-ip-address]
compose:
  ansible_host: private_ip_address
```

```yaml
# inventory/myazure.azure_rm.yml (azure.azcollection; uses az login or a managed identity)
plugin: azure.azcollection.azure_rm
include_vm_resource_groups: [rg-app-prod]
auth_source: auto
keyed_groups:
  - key: tags.Role | default('none')
    prefix: role
conditional_groups:
  linux: os_profile.system == 'linux'
```

```sh
ansible-galaxy collection install amazon.aws azure.azcollection
ansible-inventory -i inventory/aws_ec2.yml --graph
ansible-playbook -i inventory/aws_ec2.yml site.yml --limit role_web
```

Groups come from tags, so tagging consistently (Role, Environment, Owner) is what makes this work. [tag-audit](../../software/python/examples/README.md) finds AWS resources missing required tags.

## Troubleshooting

| Symptom | Likely cause | Try |
|---|---|---|
| `UNREACHABLE` / `Permission denied (publickey)` | Wrong user or key, or the host isn't reachable | `ssh -v deploy@203.0.113.10` by hand; check `ansible_user` and `ansible_host` with `ansible-inventory --host` |
| `Host key verification failed` | First connection, or the host was rebuilt | Verify the key out of band, then add it to `known_hosts` (`ssh-keyscan` only if you trust the network) |
| `Missing sudo password` | The account needs a password for sudo | `-K` to be prompted, or passwordless sudo for an automation account |
| `/usr/bin/python: not found` | No Python on the host, or an unusual path | Install `python3`, or set `ansible_python_interpreter` |
| A task always reports `changed` | `command`/`shell` without `changed_when`, or a template that renders differently each run (a timestamp) | Add `changed_when`; run twice with `--diff` to see what differs |
| `ERROR! couldn't resolve module/action` | Collection not installed, or a typo | `ansible-galaxy collection install -r requirements.yml`; check the FQCN with `ansible-doc` |
| `[WARNING]: Ansible is being run in a world writable directory` | `ansible.cfg` ignored in a shared or mounted folder | Set `ANSIBLE_CONFIG=$PWD/ansible.cfg` |
| A variable has the wrong value | Precedence: something more specific set it | `ansible-inventory --host <host>`; `ansible.builtin.debug: var=name` in the play |
| Runs are slow | Few forks, no pipelining, facts gathered every time | `forks` and `pipelining` in ansible.cfg; `gather_facts: false` or `gather_subset` where facts aren't needed; fact caching |

More output: `-v` shows task results, `-vvv` the SSH commands and module arguments, `-vvvv` connection debugging. To re-run from a point: `--start-at-task "Write the hardening drop-in"`; to confirm each task: `--step`.

## Next

Back to the [Ansible overview](README.md), or to the [Bash scripts](../bash/README.md#scripts) the baseline is based on.
