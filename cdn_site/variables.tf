variable "base" {
  description = "an object representing the outputs of the base module from the tf repo"
}

variable "subdomain" {
  type        = string
  default     = "www"
  description = "OPTIONAL: the subdomain for the site. Defaults to www"
}

variable "aliases" {
  type        = list(string)
  description = "OPTIONAL: a list of domain aliases that CloudFront CDN should also serve"
  default     = []
}
