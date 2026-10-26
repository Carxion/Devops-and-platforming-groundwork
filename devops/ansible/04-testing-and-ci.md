# 4. Testing and CI

[← Ansible](README.md)

A playbook that only ever runs against production is tested in production. This guide layers cheap checks first and real ones after, then runs them, and the playbook itself, from CI.

| Layer | Command | Catches | Speed |
|---|---|---|---|
| YAML | `yamllint .` | Indentation, duplicate keys, truthy values like `yes` | Seconds |
| Syntax | `ansible-playbook site.yml --syntax-check` | Unknown keywords, broken includes, missing roles | Seconds |
| Lint | `ansible-lint` | Bad practices: commands instead of modules, missing `changed_when`, unpinned packages, risky permissions, unprefixed role variables | Seconds |
| Dry run | `ansible-playbook site.yml --check --diff` | What would change on real hosts | Minutes |
| Molecule | `molecule test` | Whether the roles actually work, converge twice without changes, and leave the host right | Minutes |

## Linting

```sh
cd devops/ansible
yamllint .
ansible-playbook site.yml --syntax-check
ansible-lint                     # reads .ansible-lint: the production profile
```

[.ansible-lint](.ansible-lint) uses the **production** profile, the strictest of ansible-lint's built-in profiles (min, basic, moderate, safety, shared, production). Fix findings rather than skipping them. When a rule truly doesn't apply, skip it on that one line with a reason, as the base role does for upgrading every package:

```yaml
- name: Upgrade installed packages (RHEL)
  ansible.builtin.dnf:
    name: "*"
    state: latest # noqa package-latest (upgrading everything is the point here)
```

## Check mode

`--check` asks every module what it would do without doing it, and `--diff` shows file changes line by line. Run it before every real run against production:

```sh
ansible-playbook site.yml --check --diff --limit web-01
```

Two limits: `command` and `shell` tasks are skipped in check mode (Ansible can't know what they'd do), and a task that depends on an earlier task's change (install a package, then configure it) may fail because the earlier change didn't happen. Mark tasks that are safe to run for real even in check mode (read-only checks) with `check_mode: false`.

## Molecule

[Molecule](https://ansible.readthedocs.io/projects/molecule/) creates throwaway instances, applies your roles, and tests the result. The scenario in [molecule/default](molecule/default/) uses Docker containers of each supported distribution:

| File | What it does |
|---|---|
| [molecule.yml](molecule/default/molecule.yml) | Platforms (Ubuntu 22.04 and 24.04, Rocky Linux 9, AlmaLinux 9), the test inventory, and the sequence of steps |
| [prepare.yml](molecule/default/prepare.yml) | Makes the containers look like running servers: an SSH server with host keys, and a test key pair |
| [converge.yml](molecule/default/converge.yml) | Imports the real [site.yml](site.yml), so the test covers the playbook itself |
| [verify.yml](molecule/default/verify.yml) | Checks the result by looking at each host (file modes, `sshd -T`, firewall rules, update settings), then checks the safety features: a private key is rejected, SSH hardening refuses when nobody has a key, and an invalid sshd setting is rolled back |

```sh
molecule test                 # create, prepare, converge, idempotence, verify, destroy
molecule converge             # create and apply, and keep the containers for poking at
molecule login -h rocky-9     # a shell inside one
molecule verify
molecule destroy
```

The **idempotence** step runs the playbook a second time and fails if any task reports `changed`. It's the test that matters most: a role that changes something on every run is either broken or hiding a problem, and its reports of what changed can't be trusted.

Containers don't run systemd, so the test inventory sets each role's `*_manage_services` variable to false, and service tasks are skipped. The Ubuntu containers get the `NET_ADMIN` capability, because the ufw module reads the live firewall rules, which an unprivileged container can't. Everything else is applied for real. Starting and enabling services is the one part exercised only on real hosts or VMs (Molecule has drivers for those too).

## Running from CI

The same commands run in any CI system. This repository's [lint.yml](../../.github/workflows/lint.yml) runs the linters on every change with GitHub Actions; Molecule runs locally, because a full run takes 10 to 15 minutes. To apply the playbook to real servers from a pipeline, the job needs to reach the hosts and authenticate as the Ansible user. Some options, from simplest to best:

- **An SSH private key in a protected CI variable,** with the hosts' public keys pinned in `known_hosts` (never `host_key_checking = false`). Simple, but the key is long-lived: limit it to the deploy account, protect the variable to the main branch, and rotate it.
- **SSH certificates** issued per job by a CA that trusts the pipeline's OIDC identity (HashiCorp Vault's SSH secrets engine, for example), valid for minutes.
- **No SSH at all** on AWS: the `amazon.aws.aws_ssm` connection plugin runs tasks through Systems Manager Session Manager, authenticated by the pipeline's short-lived IAM role. Instances need the SSM agent and an instance profile, and inbound port 22 can stay closed.

### GitLab CI

```yaml
# .gitlab-ci.yml
stages: [lint, test, deploy]

default:
  image: python:3.14-slim
  before_script:
    - apt-get update -qq && apt-get install -y -qq git openssh-client >/dev/null
    - pip install -q -r devops/ansible/requirements.txt
    - cd devops/ansible && ansible-galaxy collection install -r requirements.yml

lint:
  stage: lint
  script:
    - yamllint .
    - ansible-playbook site.yml --syntax-check
    - ansible-lint

molecule:
  stage: test
  services: [docker:27-dind]     # the runner must allow privileged mode for Docker-in-Docker
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  script:
    - apt-get install -y -qq docker-cli rsync >/dev/null   # Molecule's docker driver uses both
    - molecule test

deploy:
  stage: deploy
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual               # a person presses the button for production
  environment: production
  script:
    # SSH_PRIVATE_KEY and SSH_KNOWN_HOSTS are protected, masked "File" variables.
    - install -m 700 -d ~/.ssh && cp "$SSH_KNOWN_HOSTS" ~/.ssh/known_hosts
    - eval "$(ssh-agent -s)" && ssh-add "$SSH_PRIVATE_KEY"
    - ansible-playbook -i inventory/production.yml site.yml --check --diff
    - ansible-playbook -i inventory/production.yml site.yml
```

### Jenkins

```groovy
// Jenkinsfile (declarative). Needs the Docker Pipeline and SSH Agent plugins.
pipeline {
  agent { docker { image 'python:3.14-slim'; args '-u root' } }
  options { disableConcurrentBuilds() }
  stages {
    stage('Install') {
      steps {
        dir('devops/ansible') {
          sh 'apt-get update -qq && apt-get install -y -qq git openssh-client >/dev/null'
          sh 'pip install -q -r requirements.txt && ansible-galaxy collection install -r requirements.yml'
        }
      }
    }
    stage('Lint') {
      steps {
        dir('devops/ansible') {
          sh 'yamllint . && ansible-playbook site.yml --syntax-check && ansible-lint'
        }
      }
    }
    stage('Deploy') {
      when { branch 'main' }
      steps {
        input message: 'Apply the baseline to production?'
        dir('devops/ansible') {
          // A Jenkins credential of type "SSH Username with private key".
          sshagent(credentials: ['ansible-deploy-key']) {
            withCredentials([file(credentialsId: 'production-known-hosts', variable: 'KNOWN_HOSTS')]) {
              sh 'install -m 700 -d ~/.ssh && cp "$KNOWN_HOSTS" ~/.ssh/known_hosts'
              sh 'ansible-playbook -i inventory/production.yml site.yml --check --diff'
              sh 'ansible-playbook -i inventory/production.yml site.yml'
            }
          }
        }
      }
    }
  }
}
```

Run Molecule on a Jenkins agent with Docker available (a dedicated agent label), rather than nesting Docker inside the pipeline's container.

### At scale: AWX and Ansible Automation Platform

When many teams run playbooks, a controller adds what CI lacks: role-based access to who may run what against which inventory, credentials stored and injected without being shown to users, schedules, an audit log of every run, and a web interface and API. [AWX](https://github.com/ansible/awx) is the open-source upstream; Red Hat Ansible Automation Platform is the supported product.

## Next

[Operations](05-operations.md): everyday ad hoc commands, rolling changes, reboots, dynamic inventory, and troubleshooting.
