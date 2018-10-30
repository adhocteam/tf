variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "num_workers" {
  description = "How many worker nodes to create"
  default     = 2
}

variable "num_executors" {
  description = "How many execution slots per node"
  default     = 4
}

variable "jumpbox_sg" {
  description = "OPTIONAL: the security group of any jumpbox to provide SSH access"
  default     = ""
}

variable "ssh_proxy_sg" {
  description = "OPTIONAL: the security group of the Teleport proxies"
  default     = ""
}
