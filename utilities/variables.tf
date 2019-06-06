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

variable "jenkins_image" {
  description = "OPTIONAL: the image name for the container to use for the jenkins primary"
  default     = "adhocteam/jenkins:latest"
}

variable "jenkins_github_user" {
  description = "GitHub account to use for Jenkins admin features (e.g., setting up hooks) and posting messages"
  default     = "jenkins-adhoc-team"
}

variable "teleport_github_team" {
  description = "GitHub team who can SSH via Teleport proxy"
  default     = "infrastructure-team"
}

