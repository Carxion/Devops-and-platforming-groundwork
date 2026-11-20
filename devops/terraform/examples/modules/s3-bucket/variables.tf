variable "name" {
  description = "Bucket name. Globally unique across all AWS accounts, so include something unique such as the account ID."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.name))
    error_message = "Use 3 to 63 lowercase letters, digits, dots, and hyphens, starting and ending with a letter or digit."
  }
}

variable "kms_key_arn" {
  description = "KMS key for default encryption. Null uses S3-managed keys (SSE-S3)."
  type        = string
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep an object version after it is overwritten or deleted."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "Keep old versions for at least one day."
  }
}

variable "force_destroy" {
  description = "Let terraform destroy delete a bucket that still holds objects. Keep false for anything you can't recreate."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags for the bucket, added to the provider's default tags."
  type        = map(string)
  default     = {}
}
