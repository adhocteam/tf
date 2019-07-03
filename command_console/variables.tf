variable "base" {
  description = "an object representing the outputs of the base module from the tf repo"
}

variable "fargate_cluster" {
  description = "object representing the fargate cluster that we want to create a command console version of"
}

variable "environment_variables" {
  type        = map
  description = "OPTIONAL: map of environment variables to set by default when running the docker image"
  default     = {}
}

variable "default_command" {
  type        = string
  description = "OPTIONAL: Default command to execute when running inside the docker container. Defaults to running a shell"
  default     = "/bin/sh"
}
