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
  description = "A list of strings describing workers. Lists are of the form: label,instance_type,number_of_executors}"

  default = [
    "general,t3.medium,6",
    "general,t3.medium,6",
  ]
}

variable "jenkins_url" {
  description = "OPTIONAL: the URL at which jenkins will be served. Default is jenkins.{var.env}.{var.domain_name}"
  default     = ""
}
