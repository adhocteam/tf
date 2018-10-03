variable "name" {
  description = "name of the environment to be created"
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "application_name" {
  description = "name of the application to be hosted. must be unique in the environment."
}

variable "health_check_path" {
  description = "path used by load balancer to health check application. should return 200."
  default     = "/"
}

variable "application_port" {
  description = "port on which the application will be listening."
  default     = "80"
}

variable "loadbalancer_port" {
  description = "port on which the load balancer will be listening. it will terminate TLS on this port."
  default     = "443"
}
