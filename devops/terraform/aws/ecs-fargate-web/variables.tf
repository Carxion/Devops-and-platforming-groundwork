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

variable "service_name" {
  description = "Name of the service, used in resource names."
  type        = string
  default     = "web"
}

# --- Network (from network-vpc outputs) --------------------------------------

variable "vpc_id" {
  description = "VPC to deploy into."
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets for the load balancer."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Subnets for the tasks. They need a route to ECR and CloudWatch, through NAT or VPC endpoints."
  type        = list(string)
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the load balancer."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- Service -----------------------------------------------------------------

variable "certificate_arn" {
  description = "ACM certificate for the HTTPS listener."
  type        = string
}

variable "container_image" {
  description = "Image to run, pinned by digest or immutable tag. Pull from your approved registry or mirror."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path the load balancer uses for health checks."
  type        = string
  default     = "/"
}

variable "cpu" {
  description = "Task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Initial number of tasks. Autoscaling manages it after the first apply."
  type        = number
  default     = 2
}

variable "max_count" {
  description = "Upper bound for autoscaling."
  type        = number
  default     = 6
}

variable "environment_variables" {
  description = "Non-secret environment variables for the container. Put secrets in Secrets Manager and reference them instead."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch retention for container logs."
  type        = number
  default     = 365
}

variable "enable_waf" {
  description = "Attach an AWS WAF web ACL with the AWS managed common and known-bad-inputs rule sets."
  type        = bool
  default     = true
}

variable "alb_access_logs_bucket" {
  description = "Existing S3 bucket for ALB access logs. Null disables access logs."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protect the load balancer from deletion. Turn off only to tear down non-prod."
  type        = bool
  default     = true
}
