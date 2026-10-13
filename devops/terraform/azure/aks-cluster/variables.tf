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

variable "kubernetes_version" {
  description = "AKS Kubernetes version, for example \"1.34\". Pin it and upgrade deliberately; list options with `az aks get-versions --location <region>`."
  type        = string
}

# --- Network (from network-hub-spoke outputs) --------------------------------

variable "node_subnet_id" {
  description = "Subnet for nodes. Pods use an overlay network, so a /22 or /23 is usually enough."
  type        = string
}

variable "outbound_type" {
  description = "Must match how the subnet reaches the internet: userAssignedNATGateway (network-hub-spoke egress_mode = nat_gateway), userDefinedRouting (egress_mode = firewall), or loadBalancer."
  type        = string
  default     = "userAssignedNATGateway"
}

variable "log_analytics_workspace_id" {
  description = "Workspace for Container Insights and control plane diagnostics."
  type        = string
}

variable "private_cluster" {
  description = "Give the API server a private endpoint only. Operators then need network access to the VNet (VPN, ExpressRoute, or Bastion)."
  type        = bool
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDRs allowed to reach a public API server. Ignored for private clusters. Empty allows all, which is not recommended."
  type        = list(string)
  default     = []
}

# --- Access ------------------------------------------------------------------

variable "admin_group_object_ids" {
  description = "Entra ID groups granted cluster admin. Local accounts are disabled, so this is the only way in."
  type        = list(string)
}

# --- Nodes -------------------------------------------------------------------

variable "system_node_vm_size" {
  description = "VM size for the system pool. Must support ephemeral OS disks of os_disk_size_gb."
  type        = string
  default     = "Standard_D4ds_v5"
}

variable "user_node_vm_size" {
  description = "VM size for the user (workload) pool."
  type        = string
  default     = "Standard_D4ds_v5"
}

variable "user_node_min_count" {
  description = "Minimum nodes in the user pool."
  type        = number
  default     = 2
}

variable "user_node_max_count" {
  description = "Maximum nodes in the user pool."
  type        = number
  default     = 6
}

variable "os_disk_size_gb" {
  description = "Must fit the VM size's cache for an ephemeral OS disk (Standard_D4ds_v5 allows up to 150 GB)."
  type        = number
  default     = 100
}

variable "host_encryption" {
  description = "Encrypt temp and cache disks at the host. Requires the EncryptionAtHost feature registered on the subscription."
  type        = bool
  default     = true
}
