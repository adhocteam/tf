variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "ssh_bastion" {
  description = "Set to 0 (zero) to disable the ssh proxy bastion, Teleport"
  default     = 1
}

variable "jumpbox" {
  description = "Set to 1 (one) to enable the emergency SSH jumpbox host"
  default     = 0
}

variable "jenkins" {
  description = "Set to 0 (zero) to disable the local install of jenkins at jenksin.domain_name"
  default     = 1
}
