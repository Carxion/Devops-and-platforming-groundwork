output "id" {
  # The bucket attribute is the name we passed in, so it's known at plan time,
  # and callers can use it in plans and tests. References still wait for the
  # bucket to exist, because they depend on the resource, not the attribute.
  description = "Bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "arn" {
  description = "Bucket ARN, for IAM policies."
  value       = aws_s3_bucket.this.arn
}
