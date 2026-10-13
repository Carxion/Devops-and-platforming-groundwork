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

variable "app_name" {
  description = "Name of the app, used in resource names."
  type        = string
  default     = "web"
}

# --- Network (from network-hub-spoke outputs) --------------------------------

variable "vnet_id" {
  description = "Spoke VNet holding the subnets below; the database's private DNS zone links to it."
  type        = string
}

variable "app_subnet_id" {
  description = "Subnet delegated to Microsoft.Web/serverFarms for outbound VNet integration."
  type        = string
}

variable "db_subnet_id" {
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace for diagnostics and Application Insights."
  type        = string
}

# --- App ---------------------------------------------------------------------

variable "app_service_sku" {
  description = "App Service plan SKU. P0v3 or larger for zone redundancy and production workloads."
  type        = string
  default     = "P0v3"
}

variable "zone_balancing" {
  description = "Spread instances across availability zones. Needs a Premium v3 SKU and at least 2 workers."
  type        = bool
  default     = true
}

variable "worker_count" {
  description = "Number of App Service instances. Use 2 or more with zone balancing."
  type        = number
  default     = 2
}

variable "container_image" {
  description = "Image name and tag (or digest), without the registry host, for example web@sha256:<digest>."
  type        = string
}

variable "container_registry_url" {
  description = "Registry URL, for example https://myregistry.azurecr.io."
  type        = string
}

variable "acr_id" {
  description = "Azure Container Registry ID. If set, the app pulls with its managed identity and gets AcrPull on it."
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "Path App Service probes; unhealthy instances are replaced."
  type        = string
  default     = "/healthz"
}

variable "app_settings" {
  description = "Non-secret app settings. Reference secrets with Key Vault references instead."
  type        = map(string)
  default     = {}
}

# --- Database ----------------------------------------------------------------

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "postgres_sku" {
  description = "Flexible server SKU. Burstable (B_) is fine for dev; use General Purpose for production."
  type        = string
  default     = "GP_Standard_D2ds_v5"
}

variable "postgres_storage_mb" {
  description = "Initial database storage. Auto-grow is on."
  type        = number
  default     = 32768
}

variable "postgres_high_availability" {
  description = "Zone-redundant standby. Roughly doubles database cost."
  type        = bool
  default     = false
}

variable "postgres_admin_group_object_id" {
  description = "Entra ID group that administers the database. Password auth is disabled."
  type        = string
}

variable "postgres_admin_group_name" {
  description = "Display name of that group, used as its database role name."
  type        = string
}

variable "backup_retention_days" {
  description = "Point-in-time restore window, 7 to 35 days."
  type        = number
  default     = 35
}
