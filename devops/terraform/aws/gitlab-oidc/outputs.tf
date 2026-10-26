output "plan_role_arn" {
  description = "AWS_ROLE_ARN for plan jobs in merge request and branch pipelines."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "AWS_ROLE_ARN for the apply job, in a CI/CD variable protected to the apply branch."
  value       = aws_iam_role.apply.arn
}

output "trusted_subjects" {
  description = "The sub claims each role trusts, to compare with a failing job's ID token."
  value = {
    plan  = local.plan_subjects
    apply = local.apply_subject
  }
}
