# AWS operations

Command-line guides for running and investigating AWS accounts, plus CloudFormation templates for IAM and baseline security resources. They pair with the [onboarding checklist](../../tech-lead/README.md): most "find out" items in sections 3, 7, and 8 are a few commands away.

| Guide | Covers |
|---|---|
| [Identity and access](guides/identity-and-access.md) | Who you are, who has admin, access keys, unused permissions, policy simulation, decoding access-denied errors, Organizations and SCPs |
| [Networking](guides/networking.md) | VPC layout, security groups open to the internet, who owns an IP, Reachability Analyzer, flow logs, DNS |
| [Compute and containers](guides/compute-and-containers.md) | EC2 through Session Manager (no SSH), ECS services and failed tasks, Lambda, ECR images and scans |
| [Storage and data](guides/storage-and-data.md) | S3 exposure and recovery, RDS and DynamoDB point-in-time restore, AWS Backup, Secrets Manager, KMS |
| [Logging and monitoring](guides/logging-and-monitoring.md) | CloudTrail "who did this", CloudWatch Logs and Logs Insights, alarms, AWS Config |
| [Security and incident response](guides/security-and-incident-response.md) | GuardDuty, Security Hub, Inspector, and runbooks for leaked keys, compromised instances, and compromised roles |
| [Cost](guides/cost.md) | Spend by service and tag, forecasts, anomalies, idle and orphaned resources |
| [CloudFormation templates](cloudformation/README.md) | GitHub OIDC roles, permissions boundary, workload roles, audit role, KMS, S3, CloudTrail, SCPs, budget |

Kubernetes on EKS has its own guide: [devops/kubernetes/OPERATIONS.md](../kubernetes/OPERATIONS.md). Terraform state and plans: [devops/terraform/OPERATIONS.md](../terraform/OPERATIONS.md). Setting up metrics, logs, traces, and alerting: [devops/observability/aws](../observability/aws/README.md). Testing APIs: [software/api-testing/aws.md](../../software/api-testing/aws.md).

---

## Setup

### Install

| Tool | Install |
|---|---|
| AWS CLI v2 | `winget install Amazon.AWSCLI`, `brew install awscli`, or the [installer](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Session Manager plugin | Needed for `aws ssm start-session`. See the [install guide](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html). |
| jq (optional) | `winget install jqlang.jq` or `brew install jq` |

[AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html) in the console has the CLI preinstalled and already signed in, which is useful on a locked-down workstation.

### Sign in with IAM Identity Center (SSO)

Never configure long-lived access keys on a laptop. Set up an SSO session once, then a profile per account and role:

```sh
aws configure sso          # prompts for the SSO start URL, region, account, and role
aws sso login --profile prod-readonly
aws sts get-caller-identity --profile prod-readonly
```

The result in `~/.aws/config` looks like this, and you can add profiles by hand:

```ini
[sso-session corp]
sso_start_url = https://example.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access

[profile prod-readonly]
sso_session = corp
sso_account_id = 111122223333
sso_role_name = ReadOnlyAccess
region = us-east-1

[profile prod-admin]
sso_session = corp
sso_account_id = 111122223333
sso_role_name = AdministratorAccess
region = us-east-1
```

Use the read-only profile by default, and switch to an admin profile only for the change you're making.

```sh
export AWS_PROFILE=prod-readonly          # PowerShell: $env:AWS_PROFILE = "prod-readonly"
aws configure list-profiles
aws configure list                        # which profile, region, and credential source are in effect
```

### Make output usable

```sh
aws configure set cli_pager ""            # don't open a pager for every command
aws ec2 describe-instances --output table # table, json (default), yaml, or text
aws ec2 describe-instances --region us-west-2   # override the profile's region for one call
```

`--query` filters output with [JMESPath](https://jmespath.org) before printing it. Most examples in these guides use it:

```sh
# Pick fields
aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId, State.Name]" --output table

# Filter, then pick
aws ec2 describe-volumes --query "Volumes[?State=='available'].{id:VolumeId, size:Size}" --output table

# A tag value
aws ec2 describe-instances --query "Reservations[].Instances[].{id:InstanceId, name:Tags[?Key=='Name']|[0].Value}"
```

`--filters` (server-side) beats `--query` (client-side) when both work, because less data comes back. The CLI paginates automatically. Use `--max-items` to stop early, and `--output text` to feed IDs into another command.

### Quoting

The examples use bash or zsh quoting. In PowerShell, JSON arguments need escaping. Write them to a file and pass `file://filter.json` instead, which works the same in every shell.

---

## Habits that prevent incidents

- **Check the account before acting:** `aws sts get-caller-identity`. Put the profile name in your shell prompt.
- **Read with a read-only profile**, and assume an admin role only for the change.
- **Use `--dry-run`** where it exists (most `ec2` mutating calls). It checks permissions and parameters without making the change.
- **Prefer infrastructure as code.** Fixing something by hand creates drift; follow up with a pull request to the Terraform or CloudFormation that owns it.
- **Record what you did during an incident:** timestamps, commands, and outputs. CloudTrail records the API calls, but not why you made them.
