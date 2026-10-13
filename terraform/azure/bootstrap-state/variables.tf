variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.project))
    error_message = "Use 2-12 lowercase letters or digits, starting with a letter (storage account names allow nothing else)."
  }
}

variable "subscription_id" {
  description = "Subscription that holds the state storage."
  type        = string
}

variable "location" {
  description = "Azure region, for example eastus2."
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

variable "replication_type" {
  description = "Storage replication. ZRS survives a zone outage; GZRS also survives a regional one."
  type        = string
  default     = "ZRS"
}

variable "allowed_ip_ranges" {
  description = "Public IPs or CIDRs (for example CI runner egress) allowed through the storage firewall. Empty with public access enabled allows all; prefer a private endpoint where you can."
  type        = list(string)
  default     = []
}

variable "state_contributor_principal_ids" {
  description = "Object IDs (users, groups, or pipeline identities) granted read/write on state blobs. The identity running this stack is added automatically."
  type        = list(string)
  default     = []
}

variable "soft_delete_retention_days" {
  description = "How long deleted blobs and previous versions can be recovered."
  type        = number
  default     = 30
}
