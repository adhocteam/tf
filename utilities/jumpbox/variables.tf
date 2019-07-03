variable "base" {
  description = "object reflecting the outputs of the base module"
}

variable "enabled" {
  type        = bool
  description = "OPTIONAL: set to true to enable jumpbox"
  default     = false
}

