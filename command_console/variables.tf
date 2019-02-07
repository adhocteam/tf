variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "instance_size" {
  description = "OPTIONAL: ec2 instance type to be used for hosting the app"
  default     = "t3.micro"
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
