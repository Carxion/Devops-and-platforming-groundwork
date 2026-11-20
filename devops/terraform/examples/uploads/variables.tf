variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.project))
    error_message = "Use 2 to 20 lowercase letters, digits, and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name, for example dev, staging, or prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Use dev, staging, or prod."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "owner" {
  description = "Team accountable for these resources (Owner tag)."
  type        = string
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "upload_prefixes" {
  description = "Key prefixes that send an event to the queue when an object is created, for example [\"incoming/\"]."
  type        = set(string)
  default     = ["incoming/"]

  validation {
    condition     = length(var.upload_prefixes) > 0 && alltrue([for p in var.upload_prefixes : endswith(p, "/")])
    error_message = "List at least one prefix, and end each with a slash."
  }
}

variable "consumer_service" {
  description = "AWS service that runs the consumer and assumes its role, for example ecs-tasks.amazonaws.com or lambda.amazonaws.com."
  type        = string
  default     = "ecs-tasks.amazonaws.com"
}

variable "visibility_timeout_seconds" {
  description = "How long a received message stays hidden from other consumers. Set it longer than the consumer takes to process one upload."
  type        = number
  default     = 60
}

variable "max_receive_count" {
  description = "Receives before a message moves to the dead-letter queue."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "SQS allows 1 to 1000."
  }
}

variable "force_destroy" {
  description = "Let terraform destroy delete the bucket while it still holds uploads. Only for throwaway environments."
  type        = bool
  default     = false
}
