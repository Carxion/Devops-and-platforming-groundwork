variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string
}

variable "subscription_id" {
  description = "Subscription the pipeline manages."
  type        = string
}

variable "owner" {
  description = "Team or person accountable for these identities."
  type        = string
}

variable "github_repository" {
  description = "Repository allowed to use the identities, as owner/name."
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
  description = "GitHub environment whose jobs may use the apply identity. Protect it with required reviewers."
  type        = string
  default     = "production"
}

variable "state_storage_account_id" {
  description = "State storage account from bootstrap-state."
  type        = string
}

variable "scope_id" {
  description = "Scope the pipeline manages: a subscription or resource group ID. Defaults to the whole subscription."
  type        = string
  default     = null
}

variable "apply_role_definition_name" {
  description = "Role for the apply identity. Contributor can't grant access; stacks that create role assignments need Role Based Access Control Administrator as well, ideally with a condition limiting which roles it can assign."
  type        = string
  default     = "Contributor"
}
