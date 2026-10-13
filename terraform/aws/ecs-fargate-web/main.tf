# Containerized web service: internet-facing ALB (HTTPS only, optional WAF)
# in public subnets, Fargate tasks in private subnets, an immutable ECR
# repository, CPU-based autoscaling, and a deployment circuit breaker that
# rolls back failed deploys.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name = "${var.project}-${var.environment}-${var.service_name}"

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "ecs-fargate-web"
  })
}

# --- Registry ----------------------------------------------------------------

resource "aws_kms_key" "ecr" {
  description         = "${local.name} ECR images"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AccountAdministration"
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_ecr_repository" "app" {
  name                 = local.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the most recent 100 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 100
      }
      action = { type = "expire" }
    }]
  })
}

# --- Logs and IAM ------------------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  #checkov:skip=CKV_AWS_158:Uses the CloudWatch default encryption; add a customer-managed key if your program requires one.
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Used by ECS itself to pull the image and write logs.
resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_kms" {
  statement {
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.ecr.arn]
  }
}

resource "aws_iam_role_policy" "execution_kms" {
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_kms.json
}

# Used by the application. Starts with no permissions; grant only what the
# app needs.
resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# --- Cluster, task, service --------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # Read-only root filesystem with a writable scratch volume at /tmp.
  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([{
    name                   = var.service_name
    image                  = var.container_image
    essential              = true
    readonlyRootFilesystem = true
    user                   = "1000"

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    mountPoints = [{
      sourceVolume  = "tmp"
      containerPath = "/tmp"
      readOnly      = false
    }]

    environment = [for k, v in var.environment_variables : { name = k, value = v }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.region
        awslogs-stream-prefix = var.service_name
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  name                   = var.service_name
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.app.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  propagate_tags         = "SERVICE"
  enable_execute_command = false

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count] # owned by autoscaling
  }

  depends_on = [aws_lb_listener.https]
}

resource "aws_appautoscaling_target" "app" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.desired_count
  max_capacity       = var.max_count
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.app.service_namespace
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# --- Security groups ---------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Load balancer for ${local.name}"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from allowed clients"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  #checkov:skip=CKV_AWS_260:Port 80 only serves a redirect to HTTPS.
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP from allowed clients, redirected to HTTPS"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_service" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To tasks"
  referenced_security_group_id = aws_security_group.service.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_security_group" "service" {
  name        = "${local.name}-service"
  description = "Tasks for ${local.name}"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  security_group_id            = aws_security_group.service.id
  description                  = "From the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "service_https" {
  security_group_id = aws_security_group.service.id
  description       = "HTTPS out for ECR, CloudWatch, and AWS APIs. Narrow to VPC endpoints or a proxy where policy requires."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# --- Load balancer -----------------------------------------------------------

resource "aws_lb" "main" {
  #checkov:skip=CKV2_AWS_76:The web ACL includes AWSManagedRulesKnownBadInputsRuleSet; checkov can't follow the count-indexed association.
  name                       = substr(local.name, 0, 32)
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection

  dynamic "access_logs" {
    for_each = var.alb_access_logs_bucket == null ? [] : [var.alb_access_logs_bucket]
    content {
      bucket  = access_logs.value
      prefix  = local.name
      enabled = true
    }
  }
}

resource "aws_lb_target_group" "app" {
  name                 = substr(local.name, 0, 32)
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  #checkov:skip=CKV_AWS_2:This listener only redirects to HTTPS.
  #checkov:skip=CKV_AWS_103:This listener only redirects to HTTPS.
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# --- WAF ---------------------------------------------------------------------

resource "aws_wafv2_web_acl" "main" {
  #checkov:skip=CKV2_AWS_31:WAF logging needs a destination your program chooses (CloudWatch, S3, or Firehose).
  count = var.enable_waf ? 1 : 0

  name  = local.name
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-common"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      metric_name                = "${local.name}-common"
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-known-bad-inputs"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      metric_name                = "${local.name}-bad-inputs"
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    metric_name                = local.name
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "main" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}
