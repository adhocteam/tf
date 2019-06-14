variable "env" {
  type        = string
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "subdomain" {
  type        = string
  default     = "www"
  description = "OPTIONAL: the subdomain for the site. Defaults to www"
}

variable "domain_name" {
  type        = string
  description = "the base domain name for hosting the site"
}

variable "aliases" {
  type        = list(string)
  description = "OPTIONAL: a list of domain aliases that CloudFront CDN should also serve"
  default     = []
}
