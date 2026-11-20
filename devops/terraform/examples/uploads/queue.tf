resource "aws_sqs_queue" "dead_letter" {
  name                      = "${local.name}-uploads-dlq"
  message_retention_seconds = 1209600 # 14 days, the SQS maximum
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "uploads" {
  name                       = "${local.name}-uploads"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# Only this bucket, in this account, may send to the queue.
data "aws_iam_policy_document" "queue" {
  statement {
    sid       = "AllowBucketEvents"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.uploads.arn]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [module.bucket.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_sqs_queue_policy" "uploads" {
  queue_url = aws_sqs_queue.uploads.id
  policy    = data.aws_iam_policy_document.queue.json
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket = module.bucket.id

  dynamic "queue" {
    for_each = var.upload_prefixes

    content {
      id            = "created-${trimsuffix(queue.value, "/")}"
      queue_arn     = aws_sqs_queue.uploads.arn
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = queue.value
    }
  }

  # S3 sends a test message when the notification is saved, and rejects the
  # configuration if the queue policy doesn't allow it yet.
  depends_on = [aws_sqs_queue_policy.uploads]
}
