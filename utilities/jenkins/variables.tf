variable "env" {
  type        = string
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  type        = string
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "workers" {
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

variable "github_user" {
  type        = string
  description = "OPTIONAL: GitHub account to use for Jenkins admin features (e.g., setting up hooks) and posting messages"
  default     = "jenkins-adhoc-team"
}

variable "docker_user" {
  type        = string
  description = "OPTIONAL: Docker Hub account to use for publishing public images"
  default     = "adhocjenkins"
}

variable "ssh_proxy_sg" {
  type        = string
  description = "OPTIONAL: the security group of the Teleport proxies"
  default     = ""
}

variable "jenkins_image" {
  type        = string
  description = "OPTIONAL: the image tag for the adhocteam/jenkins container to use for the primary"
  default     = "latest"
}

