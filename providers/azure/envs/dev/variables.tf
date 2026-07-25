variable "name_prefix" {
  description = "Lowercase, globally unique prefix supplied by the operator."
  type        = string
  default     = "sopazv3"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.name_prefix))
    error_message = "name_prefix must be 3-16 lowercase letters, digits, or hyphens and start with a letter."
  }
}

variable "location" {
  description = "One supported Flex Consumption region, confirmed before deployment."
  type        = string
  default     = "centralus"
}

variable "resource_group_name" {
  description = "Resource group name; must be unique only within the operator subscription."
  type        = string
  default     = "sop-azure-centralus-v3-dev"
}

variable "log_retention_days" {
  description = "Short retention for the ephemeral trial."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "diagnostic_daily_cap_gb" {
  description = "Log Analytics daily cap; this limits collection, not total spend."
  type        = number
  default     = 0.1

  validation {
    condition     = var.diagnostic_daily_cap_gb > 0 && var.diagnostic_daily_cap_gb <= 1
    error_message = "diagnostic_daily_cap_gb must be greater than zero and no more than 1 GB."
  }
}
