variable "base" {
  description = "an object representing the outputs of the base module from the tf repo"
}

variable "ingress" {
  description = "An object describing an ingress for exposing Jenkins publicly"
}

variable "jumpbox_enabled" {
  type        = bool
  description = "OPTIONAL: whether or not to enable the jumpbox"
  default     = false
}

variable "jenkins_workers" {
  type        = list(object({ label = string, instance_type = string, executors = number }))
  description = "OPTIONAL: A list of objects describing workers."
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
  description = "OPTIONAL: GitHub account to use for Jenkins admin features (e.g., setting up hooks) and posting messages"
  default     = "jenkins-adhoc-team"
}

variable "teleport_github_team" {
  type        = string
  description = "OPTIONAL: GitHub team who can SSH via Teleport proxy"
  default     = "infrastructure-team"
}

