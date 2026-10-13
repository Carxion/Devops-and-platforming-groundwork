output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  value = aws_s3_bucket.state.arn
}

output "state_kms_key_arn" {
  value = aws_kms_key.state.arn
}

output "backend_config" {
  description = "Paste into a stack's backend.hcl, changing the key per stack and environment."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    key          = "<stack>/<environment>/terraform.tfstate"
    region       = "${var.region}"
    encrypt      = true
    kms_key_id   = "${aws_kms_key.state.arn}"
    use_lockfile = true
  EOT
}
