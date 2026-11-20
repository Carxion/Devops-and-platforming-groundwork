# Uploads: a private bucket that puts a message on an SQS queue for every new
# object under the configured prefixes, a dead-letter queue for messages the
# consumer keeps failing on, and an IAM role the consumer runs as.
#
#   client ──PUT──► S3 bucket ──event──► SQS queue ──► consumer (IAM role)
#                                            │
#                                            └──after N failures──► DLQ
#
#   main.tf      names, tags, and the bucket
#   queue.tf     the queues and the bucket's event notifications
#   consumer.tf  the consumer's IAM role
#
# 06-building-a-stack.md builds these files one step at a time.

data "aws_caller_identity" "current" {}

locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "uploads"
  })
}

module "bucket" {
  source = "../modules/s3-bucket"

  # Bucket names are global; the account ID and region make this one unique.
  name          = "${local.name}-uploads-${local.account_id}-${var.region}"
  force_destroy = var.force_destroy
}
