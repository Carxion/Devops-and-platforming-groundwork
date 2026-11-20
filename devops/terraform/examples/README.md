# Terraform examples

The code the [Terraform guides](../README.md#guides) build. Both examples are small enough to read in one sitting and complete enough to deploy: secure defaults, validated inputs, tests, and a lock file.

| Example | Kind | Built in |
|---|---|---|
| [modules/s3-bucket](modules/s3-bucket/) | Child module | [05-modules.md](../05-modules.md) |
| [uploads](uploads/) | Root module (a stack) | [06-building-a-stack.md](../06-building-a-stack.md) |

## s3-bucket

A private S3 bucket with versioning, default encryption (SSE-S3, or SSE-KMS with `kms_key_arn`), public access blocked, ACLs disabled, a TLS-only bucket policy, and a lifecycle rule that expires old versions and abandoned multipart uploads. Inputs and outputs are in its [README](modules/s3-bucket/README.md).

## uploads

```text
client ──PUT──► S3 bucket ──event──► SQS queue ──► consumer (IAM role)
                                         │
                                         └──after N failures──► dead-letter queue
```

| File | Contents |
|---|---|
| `versions.tf` | Terraform and provider versions, partial S3 backend, provider with default tags |
| `variables.tf` | Inputs, validated |
| `main.tf` | Names, tags, and the bucket (through `s3-bucket`) |
| `queue.tf` | The queue, the dead-letter queue, the queue policy, and the bucket notification |
| `consumer.tf` | The consumer's IAM role: read the upload prefixes, work the queue |
| `outputs.tf` | Bucket name, queue URLs, role ARN |
| `tests/plan.tftest.hcl` | Offline tests against a mock provider |
| `tests/apply.tftest.hcl` | Apply tests, for a sandbox account or moto |

Deploy it to a sandbox account, with the state bucket from [04-state.md](../04-state.md#create-a-state-bucket):

```sh
cd devops/terraform/examples/uploads
cp terraform.tfvars.example terraform.tfvars    # then edit
cp backend.hcl.example backend.hcl              # then point it at your state bucket
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

## Tests

```sh
# Offline, from each example's directory
terraform init -backend=false
terraform test -filter=tests/plan.tftest.hcl    # uploads
terraform test                                  # s3-bucket

# Everything, against moto (needs Docker), from the repository root
python devops/terraform/tests/check.py examples
```

`check.py examples` runs both examples' offline tests, checks that the committed lock file is complete, runs the uploads apply tests against moto, and then applies uploads with the example tfvars. The upload has to show up as a message on the queue, a second plan has to make no changes beyond moto's known gaps, and destroy has to remove everything. It finishes with tflint and checkov.
