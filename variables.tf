variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "cidr" {
  description = "the CIDR block to provision for the VPC. it should be a /16 block"
  default     = "10.1.0.0/16"
}

variable "region" {
  description = "the preferred AWS region for resources."
  default     = "us-east-1"
}

