# Serverless API: API Gateway HTTP API -> Lambda (Python, arm64) ->
# DynamoDB (on-demand, point-in-time recovery). The function's role can
# touch only its own table and log group. Add a JWT authorizer by setting
# jwt_issuer; access logs and throttling are on by default.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name = "${var.project}-${var.environment}-${var.api_name}"
  auth = var.jwt_issuer != null

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "serverless-api"
  })
}

# --- Data --------------------------------------------------------------------

resource "aws_kms_key" "data" {
  description         = "${local.name} table and logs"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
    ]
  })
}

resource "aws_dynamodb_table" "items" {
  name                        = local.name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "pk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.data.arn
  }
}

# --- Function ----------------------------------------------------------------

data "archive_file" "handler" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.build/handler.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.data.arn
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  statement {
    sid       = "Table"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.items.arn]
  }

  statement {
    sid       = "TableKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.data.arn]
  }

  statement {
    sid       = "Tracing"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda" {
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_lambda_function" "api" {
  #checkov:skip=CKV_AWS_116:Synchronous API invocation; errors return to the caller, so a DLQ would never receive anything.
  #checkov:skip=CKV_AWS_117:The function only calls AWS APIs; running it in a VPC adds NAT cost without reducing exposure.
  #checkov:skip=CKV_AWS_272:Code signing depends on your program's signing setup (AWS Signer profile).
  #checkov:skip=CKV_AWS_173:The only environment variable is the table name, which is not secret.
  function_name                  = local.name
  role                           = aws_iam_role.lambda.arn
  runtime                        = "python3.13"
  architectures                  = ["arm64"]
  handler                        = "handler.handler"
  filename                       = data.archive_file.handler.output_path
  source_code_hash               = data.archive_file.handler.output_base64sha256
  timeout                        = 10
  memory_size                    = 256
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.items.name
    }
  }

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  depends_on = [aws_iam_role_policy.lambda]
}

# --- API ---------------------------------------------------------------------

resource "aws_apigatewayv2_api" "main" {
  name          = local.name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count = local.auth ? 1 : 0

  api_id           = aws_apigatewayv2_api.main.id
  name             = "jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = var.jwt_issuer
    audience = var.jwt_audience
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "items" {
  #checkov:skip=CKV_AWS_309:Authorization is attached when jwt_issuer is set; checkov can't evaluate the conditional.
  for_each = toset(["GET /items/{id}", "PUT /items/{id}", "DELETE /items/{id}"])

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorization_type = local.auth ? "JWT" : "NONE"
  authorizer_id      = local.auth ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.data.arn
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      latency        = "$context.integrationLatency"
      error          = "$context.error.message"
    })
  }
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
