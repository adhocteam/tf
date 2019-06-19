variable "base" {
  description = "object with the outputs of the base module"
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

variable "image_tag" {
  type        = string
  description = "OPTIONAL: the image tag for the adhocteam/jenkins container to use for the primary"
  default     = "latest"
}

