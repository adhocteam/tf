variable "name" {
  description = "name of the environment to be created"
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "application_name" {
  description = "name of the application to be hosted. must be unique in the environment."
}

variable "instance_size" {
  description = "ec2 instance type to be used for hosting the app"
  default     = "t3.micro"
}

variable "instance_count" {
  description = "number of instances to create"
  default     = "1"
}

variable "application_port" {
  description = "port on which the application will be listening."
  default     = "80"
}

variable "loadbalancer_port" {
  description = "port on which the load balancer will be listening. it will terminate TLS on this port."
  default     = "443"
}
