variable "vpc" {
  description = "object describing the vpc module"
}

variable "env" {
  type        = string
  description = "Name of the environment"
}

variable "domain_name" {
  type        = string
  description = "the TLD for the project"
}

variable "external_dns" {
  description = "object describing an Route53 zone for external DNS entries"
}

variable "wildcard" {
  description = "object describing a wildcard ACM certificate"
}

variable "public" {
  type        = bool
  description = "OPTIONAL: whether or not this is publicly exposed or expected to sit behind another proxy (e.g., nginx)"
  default     = true
}
