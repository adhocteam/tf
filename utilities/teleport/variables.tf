variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "proxy_count" {
  description = "number of proxy instances to create, for HA use 3 to spread across AZs"
  default     = "1"
}

variable "auth_count" {
  description = "number of proxy instances to create, for HA use 3 to spread across AZs"
  default     = "1"
}

variable "key_pair" {
  description = "the name of the key pair that provides access to the nodes if jumpbox is used"
  default     = "infrastructure"
}

variable "gh_team" {
  description = "OPTIONAL: the Github team to provide access to via Teleport"
  default     = "infrastructure-team"
}
