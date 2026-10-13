variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "Use 2-21 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "region" {
  description = "AWS region for the state bucket."
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

variable "noncurrent_version_retention_days" {
  description = "How long to keep previous versions of state files. Old versions are how you recover from a bad apply."
  type        = number
  default     = 90
}
