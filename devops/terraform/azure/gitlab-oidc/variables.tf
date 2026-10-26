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

variable "gitlab_url" {
  description = "GitLab instance URL, which is the ID token issuer: https://gitlab.com, or your self-managed URL. No trailing slash."
  type        = string
  default     = "https://gitlab.com"

  validation {
    condition     = can(regex("^https://[A-Za-z0-9.-]+(:[0-9]+)?$", var.gitlab_url))
    error_message = "Use https://host, with no path or trailing slash."
  }
}

variable "gitlab_project_path" {
  description = "Project allowed to use the identities, as group/project (subgroups allowed: group/subgroup/project)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+$", var.gitlab_project_path))
    error_message = "Use the full project path, such as group/project."
  }
}

variable "plan_branches" {
  description = "Branches whose pipelines may use the plan identity, each as an exact-match federated credential. Include the apply branch so it can plan before applying."
  type        = list(string)
  default     = ["main"]

  validation {
    condition     = alltrue([for b in var.plan_branches : can(regex("^[A-Za-z0-9_./-]+$", b))])
    error_message = "Use exact branch names. For every branch, set plan_any_branch instead."
  }
}

variable "plan_any_branch" {
  description = "Also let pipelines on any branch of the project use the plan identity, so merge request pipelines can plan. Uses a flexible federated identity credential, which Microsoft Entra ID has in preview."
  type        = bool
  default     = false
}

variable "apply_branch" {
  description = "The one branch whose pipelines may use the apply identity. Protect it: no direct pushes, merges only through approved merge requests."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9_./-]+$", var.apply_branch))
    error_message = "Use an exact branch name; wildcards aren't allowed for the apply identity."
  }
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
