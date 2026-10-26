# 3. Secrets and Ansible Vault

[← Ansible](README.md)

Playbooks need secrets: database passwords, API tokens, TLS keys. They must never be committed in plain text. Ansible has two answers: encrypt them in the repository with **Ansible Vault**, or fetch them at run time from a **secrets manager**. For anything beyond a small team, the second is better.

## Ansible Vault

Vault encrypts files or single values with AES-256, using a password you supply at run time. The encrypted text can be committed.

```sh
ansible-vault create inventory/group_vars/production/vault.yml   # opens the editor; saves encrypted
ansible-vault edit inventory/group_vars/production/vault.yml
ansible-vault view inventory/group_vars/production/vault.yml
ansible-vault encrypt existing-secrets.yml                         # encrypt a plain file in place
ansible-vault rekey inventory/group_vars/production/vault.yml      # change the password
ansible-vault encrypt_string --name db_password 'example-only-value'          # one value, to paste into a YAML file

ansible-playbook site.yml --ask-vault-pass                         # prompt for the password
ansible-playbook site.yml --vault-password-file ~/.vault-pass      # or read it from a file (never committed)
```

A pattern that keeps secrets findable: put a group's variables in a folder, with the secret ones in an encrypted `vault.yml` and named `vault_*`, and reference them from the plain file:

```yaml
# inventory/group_vars/production/vars.yml (plain text: readable and greppable)
db_password: "{{ vault_db_password }}"

# inventory/group_vars/production/vault.yml (encrypted with ansible-vault)
vault_db_password: example-only-value
```

`grep -r db_password` still finds where it's used, and only the value is hidden.

### Vault IDs: different passwords for different environments

```sh
ansible-vault encrypt --vault-id prod@prompt inventory/group_vars/production/vault.yml
ansible-vault encrypt --vault-id dev@~/.vault-dev inventory/group_vars/dev/vault.yml
ansible-playbook site.yml --vault-id dev@~/.vault-dev --vault-id prod@prompt
```

`label@source` names the password and says where to get it: `prompt`, a file, or an executable script that prints the password (which can fetch it from a secrets manager or the OS keychain). Developers who only have the dev password can't decrypt production.

### Vault's limits

- Everyone who runs the playbook needs the password, so it's shared widely and rarely rotated.
- Rotating a secret means re-encrypting and committing, and the old ciphertext stays in Git history: anyone with the old password can still read the old values.
- There's no audit of who read what.

## Secrets from a secrets manager

Lookup plugins fetch a value when the task runs, using the control node's credentials. Nothing secret is stored in the repository at all:

```yaml
# AWS Systems Manager Parameter Store (amazon.aws collection)
db_password: "{{ lookup('amazon.aws.ssm_parameter', '/prod/app/db_password', region='eu-west-1') }}"

# AWS Secrets Manager
api_token: "{{ lookup('amazon.aws.secretsmanager_secret', 'prod/app/api-token') }}"

# Azure Key Vault (azure.azcollection)
db_password: "{{ lookup('azure.azcollection.azure_keyvault_secret', 'db-password', vault_url='https://example-kv.vault.azure.net') }}"

# HashiCorp Vault (community.hashi_vault)
db_password: "{{ lookup('community.hashi_vault.vault_kv2_get', 'app/db', engine_mount_point='secret').secret.password }}"
```

The control node authenticates the usual way: an IAM role or SSO session on AWS, a managed identity or `az login` on Azure, a Vault token or workload identity for HashiCorp Vault. In CI, that's the pipeline's short-lived OIDC credentials (see [Testing and CI](04-testing-and-ci.md#running-from-ci)). Access is logged by the provider, secrets rotate without touching the repository, and permissions can be scoped per environment.

## Keep secrets out of logs

Ansible prints task arguments and results, and `--diff` prints file contents. Mark tasks that handle secrets:

```yaml
- name: Write the application's credentials
  ansible.builtin.template:
    src: credentials.env.j2
    dest: /etc/app/credentials.env
    owner: app
    group: app
    mode: "0600"
  no_log: true        # hide arguments, results, and the diff, even with -vvv
  diff: false
```

Without `no_log`, a failed task shows its arguments, secrets included, in the CI log. ansible-lint's `no-log-password` rule catches the common cases.

## Checklist

- [ ] No plain-text secrets in the repository or its history (scan with [gitleaks](https://github.com/gitleaks/gitleaks); see [Git recovery](../../software/git/04-recovery.md#a-secret-was-committed) if one got in)
- [ ] Vault password files are in `.gitignore` and outside the repository
- [ ] Production secrets come from a secrets manager, with access scoped to the production pipeline
- [ ] Every task that handles a secret has `no_log: true`
- [ ] Files containing secrets are `0600` or `0640` and owned by the service account

## Next

[Testing and CI](04-testing-and-ci.md).
