# s3-bucket module

A private S3 bucket with versioning, default encryption, public access blocked, ACLs disabled, a TLS-only bucket policy, and a lifecycle rule for old versions and failed uploads. [05-modules.md](../../../05-modules.md) explains how it's put together.

```hcl
module "bucket" {
  source = "../modules/s3-bucket"

  name = "example-uploads-123456789012"
}
```

| Input | Default | Meaning |
|---|---|---|
| `name` | required | Bucket name, validated against the S3 naming rules |
| `kms_key_arn` | `null` | KMS key for SSE-KMS; null uses SSE-S3 |
| `noncurrent_version_expiration_days` | `90` | How long to keep overwritten and deleted versions |
| `force_destroy` | `false` | Let `terraform destroy` delete a bucket that still holds objects |
| `tags` | `{}` | Tags for the bucket, on top of the provider's default tags |

Outputs: `id` (the bucket name) and `arn`.

Test it offline with `terraform init && terraform test`.
