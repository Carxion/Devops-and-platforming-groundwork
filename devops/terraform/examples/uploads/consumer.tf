data "aws_iam_policy_document" "consumer_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.consumer_service]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "consumer" {
  name               = "${local.name}-uploads-consumer"
  assume_role_policy = data.aws_iam_policy_document.consumer_assume.json
}

# Read uploads and work the queue; nothing else.
data "aws_iam_policy_document" "consumer" {
  statement {
    sid       = "ReadUploads"
    actions   = ["s3:GetObject"]
    resources = [for p in var.upload_prefixes : "${module.bucket.arn}/${p}*"]
  }

  statement {
    sid = "WorkTheQueue"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.uploads.arn]
  }
}

resource "aws_iam_role_policy" "consumer" {
  name   = "uploads"
  role   = aws_iam_role.consumer.id
  policy = data.aws_iam_policy_document.consumer.json
}
