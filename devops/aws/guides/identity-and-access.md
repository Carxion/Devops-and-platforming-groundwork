# AWS identity and access

[← AWS operations](../README.md)

## Who am I, and where?

```sh
aws sts get-caller-identity                          # account, ARN, and user or role ID
aws configure list                                   # profile, region, and where credentials came from
aws iam list-account-aliases                         # the account's friendly name, if set
```

### Assume another role

For a one-off call:

```sh
aws sts assume-role \
  --role-arn arn:aws:iam::111122223333:role/security-audit-readonly \
  --role-session-name "$(whoami)-investigation"
```

For regular use, add a profile instead, and the CLI handles the refresh:

```ini
[profile audit-prod]
role_arn = arn:aws:iam::111122223333:role/security-audit-readonly
source_profile = security-account
role_session_name = jdoe
```

Always set a meaningful session name. It appears in CloudTrail as the identity behind every call.

## Who has access?

```sh
# Who holds AdministratorAccess (users, groups, roles)
aws iam list-entities-for-policy --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Roles, with their creation date and last use
aws iam list-roles --query "Roles[].{name:RoleName, created:CreateDate}" --output table
aws iam get-role --role-name <role> --query "Role.{lastUsed:RoleLastUsed, boundary:PermissionsBoundary.PermissionsBoundaryArn}"

# What a role trusts (who can assume it)
aws iam get-role --role-name <role> --query "Role.AssumeRolePolicyDocument"

# Its permissions
aws iam list-attached-role-policies --role-name <role>
aws iam list-role-policies --role-name <role>                    # inline policy names
aws iam get-role-policy --role-name <role> --policy-name <name>  # inline policy body
```

Read trust policies carefully. A role trusting `arn:aws:iam::<other account>:root` trusts every principal in that account that has permission to call `sts:AssumeRole`.

## IAM users and access keys

The guide treats every long-lived key as debt ([section 3.2](../../../tech-lead/README.md#32-identity-and-access)). Find them:

```sh
aws iam generate-credential-report
aws iam get-credential-report --query Content --output text | base64 --decode > credential-report.csv
```

The CSV has one row per user, with `password_last_used`, `mfa_active`, `access_key_1_active`, `access_key_1_last_rotated`, and `access_key_1_last_used_date`. Look for active keys older than 90 days, keys never used, and console users without MFA.

```sh
aws iam list-users --query "Users[].{user:UserName, created:CreateDate, lastPassword:PasswordLastUsed}" --output table
aws iam list-access-keys --user-name <user>
aws iam get-access-key-last-used --access-key-id <AKIA...>
aws iam list-mfa-devices --user-name <user>
```

Disable a key before deleting it, so you can turn it back on if something breaks:

```sh
aws iam update-access-key --user-name <user> --access-key-id <AKIA...> --status Inactive
# wait and watch for failures, then:
aws iam delete-access-key --user-name <user> --access-key-id <AKIA...>
```

## Unused permissions

Last-accessed data shows which services a role actually uses, so you can shrink its policy:

```sh
job=$(aws iam generate-service-last-accessed-details --arn arn:aws:iam::111122223333:role/<role> --query JobId --output text)
aws iam get-service-last-accessed-details --job-id "$job" \
  --query "ServicesLastAccessed[?TotalAuthenticatedEntities==\`0\`].ServiceNamespace" --output text
```

That lists services the role can use but never has. IAM Access Analyzer can also generate a policy from actual CloudTrail activity.

## Why was I denied?

```sh
# Some services return an encoded message with the AccessDenied error
aws sts decode-authorization-message --encoded-message <encoded message> --query DecodedMessage --output text | jq .

# Would this role be allowed to do this?
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::111122223333:role/<role> \
  --action-names s3:GetObject kms:Decrypt \
  --resource-arns arn:aws:s3:::example-bucket/reports/q3.csv \
  --query "EvaluationResults[].{action:EvalActionName, decision:EvalDecision}" --output table
```

The simulator evaluates identity policies and permissions boundaries. It doesn't evaluate SCPs or resource policies in other accounts. If it says allowed but the call fails, check the resource's own policy (bucket or key policy) and the organization's SCPs.

Common causes of an unexpected `AccessDenied`:

- **An explicit Deny** in an SCP, a permissions boundary, a resource policy, or a session policy. A Deny anywhere beats every Allow.
- **The KMS key policy** doesn't allow the principal. S3 objects and EBS volumes encrypted with a customer-managed key need both the S3 or EC2 permission and `kms:Decrypt`.
- **A condition** didn't match, such as `aws:SourceIp`, `aws:SecureTransport`, `aws:PrincipalTag`, or MFA presence.
- **The wrong account or region:** check with `aws sts get-caller-identity`.

## Check a policy before deploying it

```sh
aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY --policy-document file://policy.json \
  --query "findings[].{type:findingType, issue:issueCode, detail:findingDetails}" --output table
```

Findings include errors, security warnings (such as `iam:PassRole` with `*`), and suggestions.

## External access

IAM Access Analyzer reports resources shared outside your account or organization: buckets, keys, roles, queues, and secrets.

```sh
aws accessanalyzer list-analyzers --query "analyzers[].{name:name, type:type, arn:arn}"
aws accessanalyzer list-findings-v2 --analyzer-arn <analyzer arn> \
  --filter '{"status": {"eq": ["ACTIVE"]}}' \
  --query "findings[].{resource:resource, type:resourceType, created:createdAt}" --output table
```

If there's no analyzer, create one: `aws accessanalyzer create-analyzer --analyzer-name account-analyzer --type ACCOUNT`.

## Organizations and SCPs

From the management account, or a delegated administrator:

```sh
aws organizations describe-organization
aws organizations list-accounts --query "Accounts[].{id:Id, name:Name, status:Status}" --output table
aws organizations list-roots
aws organizations list-organizational-units-for-parent --parent-id <root or OU id>
aws organizations list-policies --filter SERVICE_CONTROL_POLICY --query "Policies[].{id:Id, name:Name}" --output table
aws organizations list-policies-for-target --target-id <account or OU id> --filter SERVICE_CONTROL_POLICY
aws organizations describe-policy --policy-id <p-xxxx> --query Policy.Content --output text | jq .
```

An SCP never grants anything. It caps what IAM can grant in the accounts below it. See [scp-baseline.yaml](../cloudformation/organizations/scp-baseline.yaml) for a starting set.

## IAM Identity Center

```sh
aws sso-admin list-instances
aws sso-admin list-permission-sets --instance-arn <instance arn>
aws sso-admin describe-permission-set --instance-arn <instance arn> --permission-set-arn <permission set arn>
aws sso-admin list-accounts-for-provisioned-permission-set --instance-arn <instance arn> --permission-set-arn <permission set arn>
```

Who can sign in to which account with which permission set is easiest to review in the Identity Center console, or through the `identitystore` API for user and group lookups.
