variable "project" {
  description = "Short project name, used as a prefix for resource names."
  type        = string
}

variable "environment" {
  description = "Environment name, for example dev, staging, or prod."
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

variable "kubernetes_version" {
  description = "EKS Kubernetes version, for example \"1.34\". Pin it and upgrade deliberately; list options with `aws eks describe-cluster-versions`."
  type        = string
}

# --- Network (from network-vpc outputs) --------------------------------------

variable "private_subnet_ids" {
  description = "Private subnets for the control plane ENIs and nodes."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API endpoint publicly. Keep false where operators reach the VPC through VPN or Direct Connect."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint, when it is enabled."
  type        = list(string)
  default     = []
}

# --- Access ------------------------------------------------------------------

variable "cluster_admin_principal_arns" {
  description = "IAM role ARNs (for example an SSO admin role) granted cluster admin through EKS access entries."
  type        = list(string)
  default     = []
}

# --- Nodes -------------------------------------------------------------------

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "node_min_size" {
  description = "Minimum nodes in the node group."
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Initial node count. The cluster autoscaler owns it after creation."
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum nodes in the node group."
  type        = number
  default     = 6
}

variable "node_disk_size_gb" {
  description = "Root volume size per node."
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "CloudWatch retention for control plane logs."
  type        = number
  default     = 365
}
