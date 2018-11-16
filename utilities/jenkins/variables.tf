variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "workers" {
  description = "A list of strings describing workers. Lists are of the form: label,instance_type,number_of_executors}"

  default = [
    "general,t3.medium,6",
    "general,t3.medium,6",
  ]
}

variable "github_user" {
  description = "GitHub account to use for Jenkins admin features (e.g., setting up hooks) and posting messages"
  default     = "jenkins-adhoc-team"
}

variable "docker_user" {
  description = "Docker Hub account to use for publishing public images"
  default     = "adhocjenkins"
}

variable "admin_team" {
  description = "GitHub team to have admin access in the form: organization*team"
  default     = "adhocteam"
}

variable "jumpbox_sg" {
  description = "OPTIONAL: the security group of any jumpbox to provide SSH access"
  default     = ""
}

variable "ssh_proxy_sg" {
  description = "OPTIONAL: the security group of the Teleport proxies"
  default     = ""
}

variable "jenkins_url" {
  description = "OPTIONAL: the URL at which jenkins will be served. Default is jenkins.{var.env}.{var.domain_name}"
  default     = ""
}
