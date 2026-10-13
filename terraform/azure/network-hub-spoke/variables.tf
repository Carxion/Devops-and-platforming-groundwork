variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string
}

variable "environment" {
  description = "Environment name, for example dev, staging, or prod."
  type        = string
}

variable "subscription_id" {
  description = "Subscription to deploy into."
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

variable "hub_address_space" {
  description = "Hub VNet CIDR. A /22 fits the firewall, bastion, and gateway subnets with room to spare."
  type        = string
  default     = "10.0.0.0/22"
}

variable "spokes" {
  description = <<-EOT
    Spoke VNets keyed by name. Each subnet can set a service delegation
    (for example Microsoft.Web/serverFarms) for services that need one.
  EOT
  type = map(object({
    address_space = string
    subnets = map(object({
      address_prefix = string
      delegation     = optional(string)
    }))
  }))
}

variable "egress_mode" {
  description = <<-EOT
    How spoke subnets reach the internet. Azure no longer gives new subnets
    implicit outbound access, so pick one deliberately:
      nat_gateway  one NAT gateway per spoke (default)
      firewall     route 0.0.0.0/0 through Azure Firewall in the hub. Higher
                   cost, and all egress is denied until you add policy rules
      none         no internet egress (private endpoints only)
  EOT
  type        = string
  default     = "nat_gateway"

  validation {
    condition     = contains(["nat_gateway", "firewall", "none"], var.egress_mode)
    error_message = "Use nat_gateway, firewall, or none."
  }
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion in the hub for browser-based VM access without public IPs on VMs."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics retention for the shared workspace."
  type        = number
  default     = 90
}
