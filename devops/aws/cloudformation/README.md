# CloudFormation templates

YAML templates for IAM and baseline security resources, for programs that use CloudFormation, or that need these pieces before Terraform is in place. Each template is self-contained and documented inline.

> **Status.** Every template passes cfn-lint and checkov in CI. None has been deployed to a real account by this project; deploy to a sandbox first.

| Template | What it creates | Deploy in |
|---|---|---|
| [iam/github-oidc-roles.yaml](iam/github-oidc-roles.yaml) | GitHub OIDC provider; a plan role (pull requests, read-only) and an apply role (protected environment only) | Each workload account |
| [iam/permissions-boundary.yaml](iam/permissions-boundary.yaml) | A boundary that lets a pipeline create roles only if they carry the same boundary, and never touch audit controls | Each workload account, before github-oidc-roles |
| [iam/workload-role.yaml](iam/workload-role.yaml) | One least-privilege role for an ECS task, Lambda, EKS pod (Pod Identity), or EC2 instance: one S3 prefix, one queue, one secret | Per workload |
| [iam/audit-readonly-role.yaml](iam/audit-readonly-role.yaml) | SecurityAudit plus ViewOnlyAccess role, assumable from your security account | Every account (StackSet) |
| [security/kms-key.yaml](security/kms-key.yaml) | Customer-managed key with separate admin and user principals, rotation on, retained on delete | Where data needs it |
| [security/s3-bucket.yaml](security/s3-bucket.yaml) | Private, versioned, KMS-encrypted, TLS-only bucket with lifecycle and optional access logging | Where data needs it |
| [security/cloudtrail.yaml](security/cloudtrail.yaml) | Multi-region trail with log file validation, KMS, and a bucket that denies log deletion | Standalone accounts (organizations use an organization trail) |
| [organizations/scp-baseline.yaml](organizations/scp-baseline.yaml) | SCPs: can't leave the organization, no root user, security services stay on, approved regions only | Management account |
| [cost/budget.yaml](cost/budget.yaml) | Monthly budget with 80% actual and 100% forecast alerts | Every account |

A typical order for a new account: **audit-readonly-role**, then **cloudtrail** (if there's no organization trail), then **budget**, then **permissions-boundary**, then **github-oidc-roles**. After that, the pipeline deploys everything else.

## Deploying

Validate, preview, then deploy:

```sh
# Lint locally
pip install cfn-lint
cfn-lint devops/aws/cloudformation/**/*.yaml

# Create or update a stack (IAM templates need the capability flag)
aws cloudformation deploy \
  --stack-name pipeline-boundary \
  --template-file devops/aws/cloudformation/iam/permissions-boundary.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-execute-changeset          # creates a change set to review instead of applying

aws cloudformation describe-change-set --stack-name pipeline-boundary --change-set-name <name from output> \
  --query "Changes[].ResourceChange.{action:Action, resource:LogicalResourceId, type:ResourceType, replace:Replacement}" --output table
aws cloudformation execute-change-set --stack-name pipeline-boundary --change-set-name <name>
```

With parameters:

```sh
aws cloudformation deploy \
  --stack-name ci \
  --template-file devops/aws/cloudformation/iam/github-oidc-roles.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      GitHubRepository=example-org/example-infra \
      ApplyManagedPolicyArns=arn:aws:iam::111122223333:policy/example-apply \
      PermissionsBoundaryArn=arn:aws:iam::111122223333:policy/pipeline-permissions-boundary
```

Deploy to every account in an organization (for example, the audit role) with a service-managed StackSet:

```sh
aws cloudformation create-stack-set --stack-set-name audit-readonly-role \
  --template-body file://aws/cloudformation/iam/audit-readonly-role.yaml \
  --parameters ParameterKey=TrustedAccountId,ParameterValue=<security account id> \
  --capabilities CAPABILITY_NAMED_IAM \
  --permission-model SERVICE_MANAGED --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false

aws cloudformation create-stack-instances --stack-set-name audit-readonly-role \
  --deployment-targets OrganizationalUnitIds=<ou-id> --regions us-east-1
```

IAM is global, so deploy IAM-only stack sets to a single region.

## Operating stacks

```sh
aws cloudformation describe-stacks --stack-name <stack> --query "Stacks[0].{status:StackStatus, reason:StackStatusReason}"
aws cloudformation describe-stack-events --stack-name <stack> --max-items 20 \
  --query "StackEvents[?contains(ResourceStatus, 'FAILED')].{time:Timestamp, resource:LogicalResourceId, reason:ResourceStatusReason}" --output table

# Drift: did someone change resources by hand?
id=$(aws cloudformation detect-stack-drift --stack-name <stack> --query StackDriftDetectionId --output text)
aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id "$id"
aws cloudformation describe-stack-resource-drifts --stack-name <stack> --stack-resource-drift-status-filters MODIFIED DELETED

# Protect a production stack from deletion
aws cloudformation update-termination-protection --stack-name <stack> --enable-termination-protection
```

| Status | What to do |
|---|---|
| `ROLLBACK_COMPLETE` | Creation failed and rolled back. Read the first `CREATE_FAILED` event, fix the cause, then delete and recreate the stack (it can't be updated). |
| `UPDATE_ROLLBACK_FAILED` | Rollback itself failed, usually because a resource was changed or deleted by hand. Fix the resource, then `aws cloudformation continue-update-rollback --stack-name <stack>`. |
| `DELETE_FAILED` | Often a non-empty bucket or a resource still in use. Resources with `DeletionPolicy: Retain` are left in place by design. |

## Conventions in these templates

- **Partition-aware ARNs** (`arn:${AWS::Partition}:...`), so they work in every AWS partition.
- **`DeletionPolicy: Retain`** on keys, buckets, and logs. Deleting the stack never deletes data.
- **Every checkov exception is in the resource's `Metadata`**, with a reason.
- **Parameters have descriptions and constraints** (`AllowedPattern`, `AllowedValues`), so bad input fails before anything is created.

## Editor setup

VS Code's YAML extension reports `!Ref`, `!Sub`, and other CloudFormation tags as errors unless told about them. Add this to your VS Code settings:

```json
"yaml.customTags": [
  "!And sequence", "!Base64 scalar", "!Cidr sequence", "!Equals sequence", "!FindInMap sequence",
  "!GetAtt scalar", "!GetAtt sequence", "!GetAZs scalar", "!If sequence", "!ImportValue scalar",
  "!Join sequence", "!Not sequence", "!Or sequence", "!Ref scalar", "!Select sequence",
  "!Split sequence", "!Sub scalar", "!Sub sequence", "Condition scalar"
]
```

The [CloudFormation Linter extension](https://marketplace.visualstudio.com/items?itemName=kddejong.vscode-cfn-lint) gives the same checks as CI while you type.
