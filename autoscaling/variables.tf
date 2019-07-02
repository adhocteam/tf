variable "base" {
  description = "an object representing the outputs of the base module from the tf repo"
}

variable "application_name" {
  type        = string
  description = "name of the application to be hosted. will be used as the subdomain if exposed via ingress"
}

variable "ami" {
  description = "OPTIONAL: object describing the AMI to use for the autoscaling group. defaults to base ami"
  default     = ""
}

variable "instance_size" {
  type        = string
  description = "OPTIONAL: ec2 instance type to be used for hosting the app"
  default     = "t3.medium"
}

variable "desired_count" {
  type        = number
  description = "OPTIONAL: target number of copies to run before autoscaling kicks in."
  default     = 2
}

variable "max_count" {
  type        = number
  description = "OPTIONAL: maximum number of copies that autoscaling will spin up"
  default     = 16
}

variable "application_ports" {
  type        = list(number)
  description = "OPTIONAL: ports on which the application will be listening. the first listed port will be used for health checks"
  default     = [80]
}

variable "health_check_path" {
  type        = string
  description = "OPTIONAL: path used by load balancer to health check on the first application port. should return 200."
  default     = "/"
}

variable "user_data" {
  type        = string
  description = "OPTIONAL: user data script to run on initialization"
  default     = ""
}

variable "volume_size" {
  type        = number
  description = "OPTIONAL: Size in GB for the EBS volume"
  default     = 80
}
