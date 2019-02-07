variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "application_name" {
  description = "name of the application to be hosted. must be unique in the environment."
}

variable "instance_size" {
  description = "OPTIONAL: ec2 instance type to be used for hosting the app"
  default     = "t3.micro"
}

variable "instance_count" {
  description = "OPTIONAL: number of instances to create"
  default     = "1"
}

variable "application_port" {
  description = "OPTIONAL: port on which the application will be listening."
  default     = "80"
}

variable "loadbalancer_port" {
  description = "OPTIONAL: port on which the load balancer will be listening. it will terminate TLS on this port."
  default     = "443"
}

variable "key_pair" {
  description = "OPTIONAL: name of key pair to use with optional SSH jumpbox"
  default     = "infrastructure"
}

variable "user_data" {
  description = "OPTIONAL: user data script to run on initialization"
  default     = ""
}

variable "jumpbox_sg" {
  description = "OPTIONAL: the security group of any jumpbox to provide SSH access"
  default     = ""
}
