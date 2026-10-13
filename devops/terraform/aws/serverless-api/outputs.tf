output "api_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "function_name" {
  value = aws_lambda_function.api.function_name
}

output "table_name" {
  value = aws_dynamodb_table.items.name
}
