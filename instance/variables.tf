variable "base" {
  description = "an object representing the outputs of the base module from the tf repo"
}

variable "application_name" {
  type        = string
  description = "name of the application to be hosted. will be used as the subdomain if exposed via ingress"
}

variable "instance_size" {
  type        = string
  description = "OPTIONAL: ec2 instance type to be used for hosting the app"
  default     = "t3.micro"
}

variable "instance_count" {
  type        = number
  description = "OPTIONAL: number of instances to create"
  default     = 1
}

variable "application_port" {
  type        = number
  description = "OPTIONAL: port on which the application will be listening."
  default     = 80
}

variable "health_check_path" {
  type        = string
  description = "OPTIONAL: path used by load balancer to health check application. should return 200."
  default     = "/"
}

variable "key_pair" {
  type        = string
  description = "OPTIONAL: name of key pair to use with optional SSH jumpbox"
  default     = "infrastructure"
}

variable "user_data" {
  type        = string
  description = "OPTIONAL: user data script to run on initialization"
  default     = ""
}

variable "volume_size" {
  type        = number
  description = "OPTIONAL: Size in GB for the EBS volume"
  default     = 20
}
