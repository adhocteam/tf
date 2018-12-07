variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "application_name" {
  description = "name of the application to be hosted. must be unique in the environment."
}

variable "docker_image" {
  description = "Images in the Docker Hub registry are available by default. You can also specify other repositories with either repository-url/image:tag or repository-url/image@digest"
}

variable "application_port" {
  description = "port on which the application will be listening."
  default     = "80"
}

variable "loadbalancer_port" {
  description = "port on which the load balancer will be listening. it will terminate TLS on this port."
  default     = "443"
}

variable "environment_variables" {
  type        = "list"
  description = "environment variables to inject into the docker containers. a list of maps."
  default     = []
}

# Currently not supported by Fargate. Placeholder until it is.
# https://docs.amazonaws.cn/en_us/AmazonECS/latest/developerguide/specifying-sensitive-data.html
# variable "secrets" {
#   type        = "list"
#   description = "list of stored secrets to inject into the docker container. a list of maps."
#   default     = []
# }

