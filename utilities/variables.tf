variable "env" {
  type        = string
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  type        = string
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "jumpbox_enabled" {
  type        = bool
  description = "OPTIONAL: whether or not to enable the jumpbox"
  default     = false
}

variable "jenkins_workers" {
  type        = list(object({ label = string, instance_type = string, executors = number }))
  description = "A list of objects describing workers."

  default = [
    {
      label         = "general",
      instance_type = "t3.medium",
      executors     = 6
    }
  ]
}

variable "jenkins_image" {
  type        = string
  description = "OPTIONAL: the tag for adhocteam/jenkins to use for the primary"
  default     = "latest"
}

variable "jenkins_github_user" {
  type        = string
  description = "GitHub account to use for Jenkins admin features (e.g., setting up hooks) and posting messages"
  default     = "jenkins-adhoc-team"
}

variable "teleport_github_team" {
  type        = string
  description = "GitHub team who can SSH via Teleport proxy"
  default     = "infrastructure-team"
}

