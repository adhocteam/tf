variable "base" {
  description = "object reflecting the outputs of the base module"
}

variable "key_pair" {
  type        = string
  description = "OPTIONAL: the name of the key pair that provides access to the jumpbox, defaults to infrastructure"
  default     = "infrastructure"
}

variable "enabled" {
  type        = bool
  description = "OPTIONAL: set to true to enable jumpbox"
  default     = false
}

