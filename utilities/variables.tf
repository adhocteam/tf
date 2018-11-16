variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "jumpbox_enabled" {
  description = "OPTIONAL: whether or not to enable the jumpbox"
  default     = "false"
}

variable "jenkins_workers" {
  description = "A list of maps describing workers. Lists are of the form: like { \"label\" = \"\", \"instance_type\"= \"\", \"number_of_executors\"= \"\"}"

  default = [
    {
      "label"               = "general"
      "instance_type"       = "t3.medium"
      "number_of_executors" = "6"
    },
    {
      "label"               = "general"
      "instance_type"       = "t3.medium"
      "number_of_executors" = "6"
    },
  ]
}
