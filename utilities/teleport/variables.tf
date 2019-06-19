variable "base" {
  description = "an object representing the outputs of the base module from the tf repo"
}

variable "proxy_count" {
  type        = number
  description = "OPTIONAL: number of proxy instances to create, for HA use 3 to spread across AZs"
  default     = 1
}

variable "auth_count" {
  type        = number
  description = "OPTIONAL: number of proxy instances to create, for HA use 3 to spread across AZs"
  default     = 1
}

variable "key_pair" {
  type        = string
  description = "OPTIONAL: the name of the key pair that provides access to the nodes if jumpbox is used"
  default     = "infrastructure"
}

variable "gh_team" {
  type        = string
  description = "OPTIONAL: the Github team to provide access to via Teleport"
  default     = "infrastructure-team"
}

