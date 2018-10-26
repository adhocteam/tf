variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources, e.g. domain.name"
}

variable "subdomain" {
  description = "Subdomain to register, e.g. api for api.domain.name. Can be more than one-level, e.g. beta.api"
}

variable "target" {
  description = "public DNS name of whatever the subdomain should point to"
}
