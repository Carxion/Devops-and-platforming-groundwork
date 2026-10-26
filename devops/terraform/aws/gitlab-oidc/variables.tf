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
  description = "Project allowed to assume the roles, as group/project (subgroups allowed: group/subgroup/project)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+$", var.gitlab_project_path))
    error_message = "Use the full project path, such as group/project."
  }
}

variable "gitlab_project_id" {
  description = "The project's numeric ID. On GitLab.com, also requiring it means a renamed or transferred path can't inherit the trust. Leave null on GitLab Self-Managed, where AWS can match only sub and aud."
  type        = number
  default     = null
}

variable "audience" {
  description = "The aud claim the pipeline requests in id_tokens. It must match exactly."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "plan_additional_subjects" {
  description = "Extra subjects trusted by the plan role, such as \"project_path:group/project:ref_type:tag:ref:*\" for tag pipelines. Every pipeline matching one gets read access, so add only what you need."
  type        = list(string)
  default     = []
}

variable "apply_branch" {
  description = "The one branch whose pipelines may assume the apply role. Protect it: no direct pushes, merges only through approved merge requests."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9_./-]+$", var.apply_branch))
    error_message = "Use an exact branch name; wildcards aren't allowed for the apply role."
  }
}

variable "create_oidc_provider" {
  description = "Create the GitLab OIDC provider. An account can have only one per issuer URL; set false if it already exists."
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
