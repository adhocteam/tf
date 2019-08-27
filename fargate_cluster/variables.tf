variable "base" {
  description = "an object representing the outputs of the base module from the tf repo"
}

variable "application_name" {
  type        = string
  description = "name of the application to be hosted. must be unique in the environment."
}

variable "docker_image" {
  type        = string
  description = "Images in the Docker Hub registry are available by default. You can also specify other repositories with either repository-url/image:tag or repository-url/image@digest"
}

variable "container_size" {
  type        = string
  description = "OPTIONAL: Roughly tracks t2/t3 sizing for cpu and memory. Valid values: nano, micro, small, medium, large, xlarge"
  default     = "micro"
}

locals {
  size_mapping = {
    "nano"   = { cpu = 512, memory = 1024 },   # 0.5 vCPU,  1GB memory
    "micro"  = { cpu = 1024, memory = 2048 },  #   1 vCPU,  2GB memory
    "small"  = { cpu = 2048, memory = 2048 },  #   2 vCPU,  2GB memory
    "medium" = { cpu = 2048, memory = 4096 },  #   2 vCPU,  4GB memory
    "large"  = { cpu = 2048, memory = 8192 },  #   2 vCPU,  8GB memory
    "xlarge" = { cpu = 4096, memory = 16384 }, #   4 vCPU, 16GB memory
  }
  cpu_size    = local.size_mapping[var.container_size].cpu
  memory_size = local.size_mapping[var.container_size].memory
}

variable "desired_count" {
  type        = number
  description = "OPTIONAL: minimum number of container copies to run before autoscaling kicks in."
  default     = 2
}

variable "max_count" {
  type        = number
  description = "OPTIONAL: maximum number of container copies that autoscaling will spin up"
  default     = 16
}

variable "public" {
  type        = bool
  description = "OPTIONAL: whether or not to expose the application publicly"
  default     = true
}

# For now only first port will be operational until this is released:
# https://github.com/aws/containers-roadmap/issues/12
# https://github.com/aws/containers-roadmap/issues/104
variable "application_ports" {
  type        = list(number)
  description = "OPTIONAL: port on which the application will be listening. The first port listed will be used for the health check"
  default     = [80]
}

variable "health_check_path" {
  type        = string
  description = "OPTIONAL: path used by load balancer to health check application. should return 200."
  default     = "/"
}

variable "environment_variables" {
  type        = list(map(any))
  description = "OPTIONAL: environment variables to inject into the docker containers. a list of maps with keys name and value."
  default     = []
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html
variable "secrets" {
  type        = list(map(any))
  description = "OPTIONAL: list of stored secrets in Secrets Manager to inject into the docker container. a list of maps with keys: name and valueFrom (ARN of the secret)."
  default     = []
}
