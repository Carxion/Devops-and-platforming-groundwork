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

variable "vpc_cidr" {
  description = "VPC CIDR block. A /16 leaves room for three /20 subnets per tier across up to four AZs."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use, for example [\"us-east-1a\", \"us-east-1b\", \"us-east-1c\"]. Listed explicitly so subnets never move when AWS adds a zone."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 4
    error_message = "Use 2 to 4 availability zones."
  }
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. Cheaper, but an AZ outage takes out egress for every AZ. Fine for non-prod."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for VPC flow logs. Set to your program's log retention requirement."
  type        = number
  default     = 365
}
