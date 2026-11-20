output "bucket_name" {
  description = "Where clients upload."
  value       = module.bucket.id
}

output "queue_url" {
  description = "The queue the consumer polls."
  value       = aws_sqs_queue.uploads.id
}

output "dead_letter_queue_url" {
  description = "Messages the consumer failed on max_receive_count times. Alarm on its depth."
  value       = aws_sqs_queue.dead_letter.id
}

output "consumer_role_arn" {
  description = "Role to run the consumer as."
  value       = aws_iam_role.consumer.arn
}
