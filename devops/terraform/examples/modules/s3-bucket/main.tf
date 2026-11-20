# A private S3 bucket with the settings every bucket should have: versioning,
# default encryption, public access blocked, ACLs disabled, TLS required, and
# a lifecycle rule so old versions and failed uploads don't pile up.
#
# S3 settings are separate resources in AWS provider 4.0 and later, so each
# one can be read, changed, and imported on its own.

resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_18:Server access logging needs a second bucket; the caller decides where logs go, or uses CloudTrail data events.
  #checkov:skip=CKV_AWS_144:Cross-region replication is a disaster recovery decision for the caller, not a default.
  #checkov:skip=CKV2_AWS_62:Event notifications belong to the caller (the uploads example adds them).
  #checkov:skip=CKV_AWS_145:KMS is supported through kms_key_arn; SSE-S3 is the default so the module works without a key.

  bucket        = var.name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "tidy-up"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # A lifecycle rule on noncurrent versions needs versioning first.
  depends_on = [aws_s3_bucket_versioning.this]
}

data "aws_iam_policy_document" "tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.tls_only.json

  # S3 rejects a bucket policy while the public access block is still being
  # applied, so wait for it.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
