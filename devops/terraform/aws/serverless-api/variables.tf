variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string
}

variable "environment" {
  description = "Environment name, for example dev, staging, or prod."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "owner" {
  description = "Team or person accountable for these resources (Owner tag)."
  type        = string
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "api_name" {
  description = "Name of the API, used in resource names."
  type        = string
  default     = "items"
}

variable "jwt_issuer" {
  description = "OIDC issuer URL for the JWT authorizer (for example a Cognito user pool or your IdP). Null leaves the API unauthenticated, which is only appropriate for a demo."
  type        = string
  default     = null
}

variable "jwt_audience" {
  description = "Accepted JWT audiences (client IDs)."
  type        = list(string)
  default     = []
}

variable "throttle_rate_limit" {
  description = "Steady-state requests per second across the API."
  type        = number
  default     = 50
}

variable "throttle_burst_limit" {
  description = "Burst requests allowed above the steady-state rate."
  type        = number
  default     = 100
}

variable "lambda_reserved_concurrency" {
  description = "Cap on concurrent executions, which also caps cost and downstream load. -1 means unreserved."
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "CloudWatch retention for function and access logs."
  type        = number
  default     = 365
}

variable "deletion_protection" {
  description = "Protect the DynamoDB table from deletion."
  type        = bool
  default     = true
}
