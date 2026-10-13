output "plan_role_arn" {
  description = "Use in pull request workflows with aws-actions/configure-aws-credentials."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Use only in jobs that declare the protected apply environment."
  value       = aws_iam_role.apply.arn
}
