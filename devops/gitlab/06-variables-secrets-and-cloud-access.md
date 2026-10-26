# Variables, secrets, and cloud access

[← GitLab](README.md)

Jobs need configuration and credentials: registry logins, API tokens, cloud access. This guide covers CI/CD variables and their protection settings, then the better option for anything in the cloud: **ID tokens**, which let a job exchange a short-lived GitLab-signed token for short-lived cloud credentials, so nothing long-lived is stored in GitLab at all.

## Where variables come from

From highest precedence to lowest (the [variables documentation](https://docs.gitlab.com/ci/variables/) has the full list):

1. Variables entered when running a pipeline or manual job by hand, from a schedule, the API, or a trigger
2. Project variables, then group variables (subgroups over parents), then instance variables
3. Variables passed from earlier jobs through `dotenv` reports
4. Variables in `.gitlab-ci.yml`: a matching rule's `variables`, then the job's, then `workflow`'s, then the top-level ones
5. Predefined variables

The practical reading: settings in the UI override the YAML, so a project can change a pipeline's behavior without a commit, and a variable defined in the YAML can't hide a protected value set in the UI.

## Variable settings

Settings > CI/CD > Variables, at project, group, or (self-managed) instance level:

| Setting | Does | Use |
|---|---|---|
| **Protected** | Only pipelines on protected branches and tags get the variable | Every credential that can change production. Feature branches never see it |
| **Visibility: Masked** | The value is replaced with `[MASKED]` in job logs | Every secret. The value must be a single line of at least 8 characters, without spaces |
| **Visibility: Masked and hidden** | Masked, and the value can't be viewed in the UI after saving | Secrets nobody should read back; you can only replace them |
| **Expand variable reference** | `$OTHER` inside the value is expanded | Leave off for secrets, which may contain `$` |
| **Environment scope** | The variable is only available to jobs deploying to matching environments (`production`, `review/*`) | Different values per environment under one name |
| **Type: File** | The value is written to a temporary file, and the variable holds its path | Config files and certificates: `kubeconfig`, `backend.hcl`, a `.tfvars` file |

Masking is a safety net, not a control: it catches the exact value in logs, but a job can still encode, split, or send the value somewhere. What actually limits exposure is **who can run jobs that receive the variable**, which is why *protected* matters more than *masked*. A Developer who can push a branch can make that branch's pipeline print every unprotected variable.

### Rules for secrets

- **Never in `.gitlab-ci.yml`.** Anything in the repository is readable by everyone who can read the code, forever, in history.
- **Protected and masked** by default for every credential; scope by environment where values differ.
- **Never set `CI_DEBUG_TRACE`** in a job that has secrets: debug logging prints every variable the job has, and masking isn't guaranteed. If you must, delete the job logs afterward.
- **Prefer ID tokens** to any stored cloud key: there's nothing to leak, rotate, or revoke.
- **Prefer the job token** to a stored GitLab token for anything in GitLab itself ([below](#the-job-token)).

## ID tokens (OIDC)

A job can ask GitLab for a signed JSON Web Token by declaring `id_tokens`. GitLab puts the token in the named variable; the job sends it to a cloud provider or Vault, which checks GitLab's signature and the token's claims against a trust policy, and returns short-lived credentials.

```yaml
deploy:
  id_tokens:
    GITLAB_OIDC_TOKEN:              # any variable name
      aud: sts.amazonaws.com       # the audience the receiving service expects
  script:
    - ./deploy.sh                  # uses $GITLAB_OIDC_TOKEN
```

The claims the receiving side checks:

| Claim | Example | Notes |
|---|---|---|
| `iss` | `https://gitlab.com` | The GitLab instance (or `ci_id_tokens_issuer_url`, if set) |
| `aud` | `sts.amazonaws.com` | Whatever the job asked for; must match exactly |
| `sub` | `project_path:example-group/infra:ref_type:branch:ref:main` | The project and ref. The main thing trust policies match |
| `project_id`, `namespace_id` | `67890` | Stable IDs that survive renames |
| `ref_protected` | `true` | Whether the branch or tag is protected |
| `environment`, `environment_protected`, `deployment_tier` | `production`, `true`, `production` | When the job declares an environment |

Two things to know before relying on it:

- **The receiver must be able to fetch GitLab's public keys** from `<issuer>/.well-known/openid-configuration`. GitLab.com is reachable from anywhere. A self-managed instance on a private network isn't reachable by AWS or Azure: publish the OpenID configuration and keys at a public URL and set `ci_id_tokens_issuer_url` to it. Cloud providers also require an `https` issuer.
- **What the receiver can match differs.** Vault can check any claim, including `ref_protected` and `environment`. AWS matches `sub` and `aud` (on GitLab.com also `project_id` and `namespace_id`), and Azure's standard federated credentials match one exact `sub`. With AWS and Azure, the apply identity is therefore scoped to a branch, and is only as safe as that branch's protection.

### AWS

The [aws/gitlab-oidc](../terraform/aws/gitlab-oidc/) stack creates the OIDC provider and two roles: **plan**, assumable from any branch of one project, read-only; and **apply**, assumable only from the protected apply branch. A job then needs no AWS CLI step: the AWS SDKs, the Terraform provider, and the S3 backend all read `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE` and assume the role themselves:

```yaml
# .gitlab-ci.yml
check-aws-identity:
  image:
    name: amazon/aws-cli:2.38.5
    entrypoint: [""]
  id_tokens:
    GITLAB_OIDC_TOKEN:
      aud: sts.amazonaws.com
  variables:
    AWS_ROLE_ARN: $AWS_PLAN_ROLE_ARN                       # a project variable: the plan_role_arn output
    AWS_WEB_IDENTITY_TOKEN_FILE: $CI_PROJECT_DIR/.oidc-token
    AWS_ROLE_SESSION_NAME: gitlab-$CI_PROJECT_ID-$CI_JOB_ID # shows in CloudTrail
  script:
    - printf '%s' "$GITLAB_OIDC_TOKEN" > "$AWS_WEB_IDENTITY_TOKEN_FILE"
    - aws sts get-caller-identity
```

The [Terraform example](examples/terraform/.gitlab-ci.yml) uses exactly this for plan and apply, and the lab check runs it against moto. If a role can't be assumed, compare the job's `sub` with the stack's `trusted_subjects` output ([Troubleshooting](09-troubleshooting.md#cloud-authentication-fails)).

### Azure

The [azure/gitlab-oidc](../terraform/azure/gitlab-oidc/) stack creates two Entra ID applications with federated credentials: **plan**, for the branches you list (Reader), and **apply**, for the protected apply branch. Name the ID token `ARM_OIDC_TOKEN` and the azurerm provider and backend read it directly:

```yaml
# .gitlab-ci.yml
.azure-oidc:
  id_tokens:
    ARM_OIDC_TOKEN:
      aud: api://AzureADTokenExchange
  variables:
    ARM_USE_OIDC: "true"
    ARM_TENANT_ID: $AZURE_TENANT_ID              # project variables, from the stack's outputs
    ARM_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID

terraform-plan:
  extends: .azure-oidc
  image:
    name: hashicorp/terraform:1.16.5
    entrypoint: [""]
  variables:
    ARM_CLIENT_ID: $AZURE_PLAN_CLIENT_ID
  script:
    - terraform init -backend-config="$TF_BACKEND_CONFIG"
    - terraform plan

az-cli-check:
  extends: .azure-oidc
  image: mcr.microsoft.com/azure-cli:2.91.0
  variables:
    ARM_CLIENT_ID: $AZURE_PLAN_CLIENT_ID
  script:
    - az login --service-principal -u "$ARM_CLIENT_ID" -t "$ARM_TENANT_ID" --federated-token "$ARM_OIDC_TOKEN"
    - az account show
```

Merge request pipelines run on their source branch, and a standard federated credential matches one exact subject, so planning every merge request needs the stack's `plan_any_branch` option: a flexible federated credential that matches `...:ref_type:branch:ref:*`. Entra ID has flexible federated credentials in preview; check that's acceptable before turning it on.

### HashiCorp Vault

Vault's JWT auth method can check any claim, which makes it the most precise receiver. A role that only protected-branch pipelines of one project can log in to:

```sh
vault write auth/jwt/config oidc_discovery_url="https://gitlab.example.com" bound_issuer="gitlab.example.com"

vault write auth/jwt/role/infra-production - <<'EOF'
{
  "role_type": "jwt",
  "policies": ["infra-production"],
  "token_explicit_max_ttl": 600,
  "user_claim": "user_email",
  "bound_audiences": "https://vault.example.com",
  "bound_claims": {
    "project_id": "42",
    "ref_type": "branch",
    "ref": "main",
    "ref_protected": "true"
  }
}
EOF
```

```yaml
# .gitlab-ci.yml
read-secret:
  image: hashicorp/vault:2.2
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com
  variables:
    VAULT_ADDR: https://vault.example.com
  script:
    - export VAULT_TOKEN="$(vault write -field=token auth/jwt/login role=infra-production jwt="$VAULT_ID_TOKEN")"
    - vault kv get -field=password secret/infra/database > /dev/null
```

## The secrets keyword (Premium)

In Premium and Ultimate, `secrets:` fetches values from HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, or Google Cloud Secret Manager before the job's script starts, using an ID token. The runner does the fetching, and the values never pass through GitLab:

```yaml
# Premium. Vault: production/db is the path, password the field, ops the secrets engine mount.
migrate:
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com
  secrets:
    DATABASE_PASSWORD:
      vault: production/db/password@ops
      token: $VAULT_ID_TOKEN
      file: false                  # a variable; the default (true) writes a file and gives its path
  script:
    - ./migrate.sh

# Premium. AWS Secrets Manager, through the role in AWS_ROLE_ARN.
migrate-aws:
  variables:
    AWS_REGION: us-east-1
    AWS_ROLE_ARN: $AWS_SECRETS_ROLE_ARN
  id_tokens:
    AWS_ID_TOKEN:
      aud: sts.amazonaws.com
  secrets:
    DATABASE_PASSWORD:
      aws_secrets_manager:
        secret_id: app-secrets/database
        field: password
      file: false
  script:
    - ./migrate.sh
```

On Free, the same result is a few lines of script: get credentials with the ID token, then read the secret with the provider's CLI, as in the Vault example above.

## The job token

Every job gets `CI_JOB_TOKEN`, valid only while the job runs, with the permissions of the user who started the pipeline but limited to a set of actions: cloning, the container and package registries, downloading artifacts, releases, deployments, environments, and a few other API endpoints. Since GitLab 19.0 it's a JWT.

- **Use it instead of stored tokens** for anything inside GitLab: `CI_REGISTRY_PASSWORD` is the job token, `git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.example.com/group/other.git` clones another project, and the package registries accept it.
- **The allowlist controls who can use their job tokens on your project:** by default only the project itself. Add the specific groups or projects that need to clone from it or pull its packages (Settings > CI/CD > Job token permissions), and nothing more. Fine-grained permissions can further limit which API endpoints an allowed project's job tokens can reach.

## Next

[Environments and deployments](07-environments-and-deployments.md).
