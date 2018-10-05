variable "name" {
  description = "name of the environment to be created"
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
