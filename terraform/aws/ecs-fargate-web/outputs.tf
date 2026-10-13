output "alb_dns_name" {
  description = "Point your DNS record (alias) here."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "task_role_arn" {
  description = "Attach the application's own permissions to this role."
  value       = aws_iam_role.task.arn
}
