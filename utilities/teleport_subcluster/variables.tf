variable "base" {
  description = "an object representing the outputs of the base module from the tf re  po"
}

variable "proxy_count" {
  type        = number
  description = "number of proxy instances to create, for HA use 3 to spread across AZs"
  default     = 1
}

variable "auth_count" {
  type        = number
  description = "number of proxy instances to create, for HA use 3 to spread across AZs"
  default     = 1
}

variable "main_cluster" {
  type        = string
  description = "OPTIONAL: The cluster_name (generally env) of the main cluster. Defaults to dev"
  default     = "dev"
}

