variable "env" {
  type        = string
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  type        = string
  description = "the external domain name for reaching the public resources."
}

variable "cidr" {
  type        = string
  description = "OPTIONAL: the CIDR block to provision for the VPC. it should be a /16 block"
  default     = "10.1.0.0/16"
}

variable "region" {
  type        = string
  description = "OPTIONAL: the preferred AWS region for resources."
  default     = "us-east-1"
}

variable "ssh_key" {
  type        = string
  description = "OPTIONAL: the name of an AWS key pair to use for jumpbox and instance access"
  default     = "infrastructure"
}

variable "public_ingress" {
  type        = bool
  description = "OPTIONAL: whether or not to expose the ingress publicly. If not, must provide a reverse proxy to it."
  default     = true
}
