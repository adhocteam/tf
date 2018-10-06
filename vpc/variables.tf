variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "cidr" {
  description = "the CIDR block to provision for the VPC. it should be a /16 block"
  default     = "10.1.0.0/16"
}
