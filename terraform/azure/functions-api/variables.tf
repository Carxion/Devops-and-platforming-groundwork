variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.project))
    error_message = "Use 2-12 lowercase letters or digits, starting with a letter (storage account names allow nothing else)."
  }
}

variable "environment" {
  description = "Environment name, for example dev, staging, or prod."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,8}$", var.environment))
    error_message = "Use up to 8 lowercase letters or digits."
  }
}

variable "subscription_id" {
  description = "Subscription to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region that supports Flex Consumption, for example eastus2."
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

variable "entra_client_id" {
  description = "Client ID of an Entra ID app registration that callers get tokens for. Enables App Service Authentication, which rejects unauthenticated requests with 401. Null leaves the API open, which is only appropriate for a demo."
  type        = string
  default     = null
}

variable "python_version" {
  description = "Python runtime version supported by Flex Consumption."
  type        = string
  default     = "3.12"
}

variable "maximum_instance_count" {
  description = "Cap on scale-out, which also caps cost and downstream load."
  type        = number
  default     = 40
}

variable "instance_memory_in_mb" {
  description = "Memory per instance: 512, 2048, or 4096."
  type        = number
  default     = 2048
}

variable "log_retention_days" {
  description = "Log Analytics retention."
  type        = number
  default     = 90
}
