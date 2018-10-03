variable "region" {
  description = "the preferred AWS region for resources."
}

variable "name" {
  description = "name of the environment to be created"
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

variable "emergency_jumpbox" {
  description = "1 provisions an emergency jumpbox providing SSH access to Teleport hosts"
  default     = "0"
}
