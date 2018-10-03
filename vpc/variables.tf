variable "name" {
  description = "name of the environment to be created"
}

variable "cidr" {
  description = "the CIDR block to provision for the VPC. it should be a /16 block"
  default     = "10.1.0.0/16"
}
