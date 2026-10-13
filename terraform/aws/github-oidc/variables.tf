variable "project" {
  description = "Short project name, used as a prefix for resource names."
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

variable "github_repository" {
  description = "Repository allowed to assume the roles, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use the form owner/name."
  }
}

variable "plan_additional_subjects" {
  description = "Extra OIDC subjects trusted by the plan identity, for example \"repo:owner/name:ref:refs/heads/main\" for scheduled drift detection. Every workflow matching a subject gets read access, so add only what you need."
  type        = list(string)
  default     = []
}

variable "apply_environment" {
  description = "GitHub environment whose jobs may assume the apply role. Protect it with required reviewers."
  type        = string
  default     = "production"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. An account can have only one; set false if it already exists."
  type        = bool
  default     = true
}

variable "state_bucket_arn" {
  description = "State bucket from bootstrap-state."
  type        = string
}

variable "state_kms_key_arn" {
  description = "State KMS key from bootstrap-state."
  type        = string
}

variable "plan_policy_arns" {
  description = "Managed policies for the plan role. Null means AWS ReadOnlyAccess, which is broad (it can read some data); narrow it if your program requires."
  type        = list(string)
  default     = null
}

variable "apply_policy_arns" {
  description = "Managed policies for the apply role. No default: decide deliberately what the pipeline may change."
  type        = list(string)
}

variable "apply_permissions_boundary_arn" {
  description = "Permissions boundary for the apply role, to stop it from granting itself more access. Strongly recommended."
  type        = string
  default     = null
}
